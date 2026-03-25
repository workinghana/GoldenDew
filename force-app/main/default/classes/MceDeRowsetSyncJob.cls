// ! 보류
public with sharing class MceDeRowsetSyncJob {
  /*implements Queueable, Database.AllowsCallouts {
  // ======= 설정 =======
  private static final String NC_NAME = 'MCE_REST';
  private static final String DE_KEY = '25AC0C5A-C1A7-42C1-8373-F8944E4CC947';
  private static final Integer PAGE_SIZE = 200;

  // DE 내 “당일” 기준 컬럼명 (필수 수정)
  //   private static final String MCE_DATE_FIELD = 'regDate';

  // 대상 오브젝트/매핑 (필수 수정)
  //   private static final String TARGET_OBJECT_API = 'Mce_Magazine_Subscription__c';
  //   private static final Map<String, String> FIELD_MAP = new Map<String, String>{
  // 'subscriberKey' => 'SubscriberKey__c',
  // 'email' => 'Email__c',
  // 'regDate' => 'RegDate__c'
  //   };

  private Date targetDate;
  private Integer page;

  public MceDeRowsetSyncJob(Date targetDate, Integer page) {
    this.targetDate = targetDate;
    this.page = (page == null || page < 1) ? 1 : page;
  }

  public void execute(QueueableContext ctx) {
    ApexLogger jobLogger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, ctx.getJobId(), null);
    jobLogger.logging(MceDeRowsetSyncJob.class.getName());
    jobLogger.setRequestDatetime(Datetime.now());
    jobLogger.setMethod('GET');

    Set<String> okIds = new Set<String>();
    Set<String> ngIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    Integer insertedOk = 0;
    Integer insertedNg = 0;

    try {
      String endpointPath = buildRowsetPath(targetDate, page, PAGE_SIZE);
      String fullEndpoint = 'callout:' + NC_NAME + endpointPath;

      // 페이지별 API 로그 (원하면 실패시에만 남기도록 조정 가능)
      ApexLogger apiLogger = new ApexLogger(ApexLogger.JobType.API);
      apiLogger.logging('MceRowsetApiClient');
      apiLogger.setRequestDatetime(Datetime.now());
      apiLogger.setMethod('GET');
      apiLogger.setRequestUrl(fullEndpoint);
      apiLogger.setDescription('Rowset GET date=' + String.valueOf(targetDate) + ', page=' + page);

      HttpResponse res;
      try {
        res = doGet(endpointPath);
        apiLogger.setHttpStatusCode(String.valueOf(res.getStatusCode()));
        apiLogger.setResponseBody(res.getBody());
        apiLogger.setResponseDatetime(Datetime.now());

        if (res.getStatusCode() != 200) {
          apiLogger.setStatus('ERROR');
          apiLogger.setErrorCode('MCE_ROWSET_FAIL');
          apiLogger.setErrorMessage('status=' + res.getStatusCode());
          failMsgs.add('Rowset fail status=' + res.getStatusCode() + ', page=' + page);
          jobLogger.setStatus('ERROR');
          return;
        }
        apiLogger.setStatus('SUCCESS');
      } catch (Exception ex) {
        apiLogger.setStatus('ERROR');
        apiLogger.setErrorCode('EXCEPTION');
        apiLogger.setErrorMessage(ex.getMessage());
        failMsgs.add('Rowset exception page=' + page + ' msg=' + ex.getMessage());
        jobLogger.setStatus('ERROR');
        return;
      } finally {
        apiLogger.addLog();
      }

      MceRowsetResponse dto = (MceRowsetResponse) JSON.deserialize(res.getBody(), MceRowsetResponse.class);
      if (dto == null || dto.items == null || dto.items.isEmpty()) {
        // 더 이상 데이터 없음 -> 정상 종료
        jobLogger.setStatus('SUCCESS');
        jobLogger.setDescription('No items. finish. date=' + String.valueOf(targetDate) + ', page=' + page);
        return;
      }

      // 이번 페이지 적재
      //   List<SObject> toInsert = new List<SObject>();
      for (MceRowsetItem item : dto.items) {
        System.debug('Processing item: ' + item);
        // SObject sob = mapToSObject(item);
        // if (sob != null) {
        //   toInsert.add(sob);
        // }
      }

      //   if (!toInsert.isEmpty()) {
      //     Database.SaveResult[] srList = Database.insert(toInsert, false);
      //     for (Integer i = 0; i < srList.size(); i++) {
      //       if (srList[i].isSuccess()) {
      //         insertedOk++;
      //         okIds.add(String.valueOf(srList[i].getId()));
      //       } else {
      //         insertedNg++;
      //         ngIds.add('IDX_' + page + '_' + i);
      //         if (srList[i].getErrors() != null && !srList[i].getErrors().isEmpty()) {
      //           failMsgs.add('DML fail page=' + page + ' idx=' + i + ' msg=' + srList[i].getErrors()[0].getMessage());
      //         }
      //       }
      //     }
      //   }

      // 상태
      if (insertedNg > 0 && insertedOk > 0) {
        jobLogger.setStatus('PARTIAL');
      } else if (insertedNg > 0) {
        jobLogger.setStatus('ERROR');
      } else {
        jobLogger.setStatus('SUCCESS');
      }

      jobLogger.setDescription(
        'Page done. date=' +
          String.valueOf(targetDate) +
          ', page=' +
          page +
          ', fetched=' +
          dto.items.size() +
          ', insertedOk=' +
          insertedOk +
          ', insertedNg=' +
          insertedNg
      );

      // 다음 페이지가 더 있으면 다음 Queueable enqueue (체이닝)
      if (dto.items.size() == PAGE_SIZE) {
        System.enqueueJob(new MceDeRowsetSyncJob(targetDate, page + 1));
      }
    } catch (Exception e) {
      try {
        jobLogger.createExceptionLog(e);
      } catch (Exception ignore) {
        // 무시
      }
      jobLogger.setStatus('ERROR');
      failMsgs.add('Unhandled exception: ' + e.getMessage());
    } finally {
      try {
        if (!okIds.isEmpty()) {
          jobLogger.setSuccessRecordIds(okIds);
        }
        if (!ngIds.isEmpty()) {
          jobLogger.setFailedRecordIds(ngIds);
        }
        if (!failMsgs.isEmpty()) {
          jobLogger.setErrorMessage(String.join(failMsgs, ' | '));
        }
      } catch (Exception ignore) {
        // 무시
      }

      jobLogger.setResponseDatetime(Datetime.now());
      jobLogger.addLog();

      try {
        ApexLogger.insertLogs();
      } catch (Exception ignore) {
        // 무시
      }
    }
  }

  // -------- callout --------
  private static HttpResponse doGet(String endpointPath) {
    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('callout:' + NC_NAME + endpointPath);
    req.setTimeout(120000);
    req.setHeader('Accept', 'application/json');
    return new Http().send(req);
  }

  private static String buildRowsetPath(Date day, Integer page, Integer pageSize) {
    Datetime dt = Datetime.newInstanceGmt(day.year(), day.month(), day.day(), 0, 0, 0);
    String ymd = dt.formatGmt('yyyy-MM-dd');
    // String filter = MCE_DATE_FIELD + ' = \'' + ymd + '\'';

    return '/data/v1/customobjectdata/key/' + DE_KEY + '/rowset' + '?page=' + String.valueOf(page) + '&pagesize=' + String.valueOf(pageSize);
    //   '&filter=' +
    //   EncodingUtil.urlEncode(filter, 'UTF-8');
  }

  //   private static SObject mapToSObject(MceRowsetItem item) {
  //     if (item == null) {
  //       return null;
  //     }

  //     Map<String, Object> flat = new Map<String, Object>();
  //     if (item.keys != null) {
  //       flat.putAll(item.keys);
  //     }
  //     if (item.values != null) {
  //       flat.putAll(item.values);
  //     }

  //     SObject sob = Schema.getGlobalDescribe().get(TARGET_OBJECT_API).newSObject();
  //     for (String mceField : FIELD_MAP.keySet()) {
  //       if (!flat.containsKey(mceField)) {
  //         continue;
  //       }
  //       Object v = flat.get(mceField);
  //       if (v == null) {
  //         continue;
  //       }
  //       sob.put(FIELD_MAP.get(mceField), v);
  //     }
  //     return sob;
  //   }

  // -------- DTO --------
  public class MceRowsetResponse {
    public Integer page;
    public Integer pageSize;
    public Integer count;
    public List<MceRowsetItem> items;
  }
  public class MceRowsetItem {
    public Map<String, Object> keys;
    public Map<String, Object> values;
  }
}
*/
}