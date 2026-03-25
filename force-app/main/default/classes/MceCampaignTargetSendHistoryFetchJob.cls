/**
 * MC 캠페인 타겟 발송 이력 데이터를 Marketing Cloud에서 조회하여 TransactionJournal로 적재하는 Batch 클래스
 * @author Changhwan Kim
 * @since 2026-02-26
 */
public with sharing class MceCampaignTargetSendHistoryFetchJob implements Queueable, Database.AllowsCallouts {
  // =========================================================
  // Config
  // =========================================================
  private static final String NC_NAME = 'MarketingCloudApiNC';

  private static final String DE_KEY = '25AC0C5A-C1A7-42C1-8373-F8944E4CC947';

  private static final Integer PAGE_SIZE = 200;

  private static final String LOYALTY_PROGRAM_NAME = System.Label.LoyaltyProgramName;
  private static final Id LOYALTY_PROGRAM_ID = SObjectUtil.findIdByName(LoyaltyProgram.SObjectType, LOYALTY_PROGRAM_NAME, true);

  // TransactionJournal UsageType__c 구분값
  private static final String TJ_USAGE_TYPE = 'Campaign';

  // =========================================================
  // Runtime args
  // =========================================================
  private Date targetDate;
  private Integer page;

  public MceCampaignTargetSendHistoryFetchJob(Date targetDate, Integer page) {
    // 기본: 어제 데이터
    this.targetDate = (targetDate == null) ? Date.today().addDays(-1) : targetDate;
    this.page = (page == null || page < 1) ? 1 : page;
  }

  // =========================================================
  // Execute
  // =========================================================
  public void execute(QueueableContext ctx) {
    ApexLogger jobLogger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, ctx.getJobId(), null);
    jobLogger.logging(MceCampaignTargetSendHistoryFetchJob.class.getName());
    jobLogger.setRequestDatetime(Datetime.now());
    jobLogger.setMethod('GET');

    Set<String> okIds = new Set<String>();
    Set<String> ngIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    Integer fetchedCnt = 0;
    Integer insOk = 0;
    Integer insNg = 0;

    ApexLogger apiLogger;

    String phase = 'INIT';
    Integer phaseIdx = null;

    try {
      // 1) callout
      phase = 'BUILD_ENDPOINT';
      String endpointPath = buildRowsetPath(targetDate, page, PAGE_SIZE);
      String fullEndpoint = 'callout:' + NC_NAME + endpointPath;

      apiLogger = new ApexLogger(ApexLogger.JobType.API);
      apiLogger.logging('MceRowsetApiClient');
      apiLogger.setRequestDatetime(Datetime.now());
      apiLogger.setMethod('GET');
      apiLogger.setRequestUrl(fullEndpoint);
      apiLogger.setDescription(
        'MCE Campaign Target SendHistory Rowset GET ymd=' + targetDate.format() + ', page=' + page + ', pageSize=' + PAGE_SIZE
      );

      phase = 'HTTP_SEND';
      HttpResponse res = doGet(endpointPath);

      apiLogger.setHttpStatusCode(String.valueOf(res.getStatusCode()));
      apiLogger.setResponseBody(res.getBody());
      apiLogger.setResponseDatetime(Datetime.now());

      if (res.getStatusCode() != 200) {
        apiLogger.setStatus('ERROR');
        apiLogger.setErrorCode('MCE_ROWSET_FAIL');
        apiLogger.setErrorMessage('phase=' + phase + ' status=' + res.getStatusCode() + ', body=' + safeLeft(res.getBody(), 2000));

        failMsgs.add('phase=' + phase + ' | Rowset fail status=' + res.getStatusCode() + ', page=' + page);
        jobLogger.setStatus('ERROR');
        return;
      }

      apiLogger.setStatus('SUCCESS');
      apiLogger.addLog();

      // 2) parse (untyped)
      phase = 'PARSE_JSON';
      Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
      List<Object> items = (root == null) ? null : (List<Object>) root.get('items');

      fetchedCnt = (items == null) ? 0 : items.size();
      if (fetchedCnt == 0) {
        jobLogger.setStatus('SUCCESS');
        jobLogger.setDescription('phase=' + phase + ' | No items. finish. ymd=' + targetDate.format() + ', page=' + page);
        return;
      }

      // 3) collect member numbers + cache keys/values
      phase = 'COLLECT_KEYS_VALUES';
      Set<String> memberNos = new Set<String>();
      List<Map<String, Object>> itemKeyList = new List<Map<String, Object>>();
      List<Map<String, Object>> itemValList = new List<Map<String, Object>>();

      for (Integer i = 0; i < items.size(); i++) {
        phaseIdx = i;
        Map<String, Object> item = (Map<String, Object>) items[i];

        Map<String, Object> keys = (item != null && item.get('keys') != null) ? (Map<String, Object>) item.get('keys') : new Map<String, Object>();

        Map<String, Object> values = (item != null &&
          item.get('values') != null)
          ? (Map<String, Object>) item.get('values')
          : new Map<String, Object>();

        itemKeyList.add(keys);
        itemValList.add(values);

        String memberNo = String.valueOf(keys.get('contactkey'));
        System.debug('String.valueOf(keys.get(contactkey)) : ' + String.valueOf(keys.get('contactkey')));
        System.debug('memberNo : ' + memberNo);
        if (!String.isBlank(memberNo)) {
          memberNos.add(memberNo);
        }
      }

      // 4) MemberNo -> LoyaltyProgramMemberId
      phase = 'QUERY_LPM';
      Map<String, Id> lpmIdByMemberNo = new Map<String, Id>();
      if (!memberNos.isEmpty()) {
        for (LoyaltyProgramMember lpm : [
          SELECT Id, ContactId, Contact.MemberNo__c
          FROM LoyaltyProgramMember
          WHERE Contact.MemberNo__c IN :memberNos AND ProgramId = :LOYALTY_PROGRAM_ID
        ]) {
          if (lpm.Contact.MemberNo__c != null && !lpmIdByMemberNo.containsKey(lpm.Contact.MemberNo__c)) {
            lpmIdByMemberNo.put(lpm.Contact.MemberNo__c, lpm.Id);
          }
        }
      }

      // 5) map -> TransactionJournal list (Contact 업데이트는 없음)
      phase = 'MAP_ITEMS';
      List<TransactionJournal> toInsert = new List<TransactionJournal>();

      for (Integer i = 0; i < itemKeyList.size(); i++) {
        try {
          phaseIdx = i;

          Map<String, Object> keys = itemKeyList[i];
          Map<String, Object> values = itemValList[i];

          String memberNo = String.valueOf(keys.get('contactkey'));
          Id lpmId = (memberNo == null) ? null : lpmIdByMemberNo.get(memberNo);

          if (lpmId == null) {
            insNg++;
            ngIds.add('NO_LPM_' + page + '_' + i);
            failMsgs.add('phase=' + phase + ' | No LPM for memberNo=' + String.valueOf(memberNo) + ' (page=' + page + ', idx=' + i + ')');
            continue;
          }

          TransactionJournal tj = mapToTransactionJournal(keys, values, lpmId);

          if (tj != null) {
            toInsert.add(tj);
          } else {
            insNg++;
            ngIds.add('SKIP_' + page + '_' + i);
            failMsgs.add('phase=' + phase + ' | Skip: missing required values (page=' + page + ', idx=' + i + ')');
          }
        } catch (Exception ex) {
          insNg++;
          ngIds.add('MAP_' + page + '_' + i);
          failMsgs.add(
            'phase=' + phase + ' | Map fail page=' + page + ' idx=' + i + ' msg=' + ex.getMessage() + ' stack=' + ex.getStackTraceString()
          );
        }
      }

      // 6) TJ insert
      phase = 'DML_INSERT_TJ';
      if (!toInsert.isEmpty()) {
        Database.SaveResult[] srList = Database.insert(toInsert, false);

        for (Integer i = 0; i < srList.size(); i++) {
          if (srList[i].isSuccess()) {
            insOk++;
            okIds.add(String.valueOf(srList[i].getId()));
          } else {
            insNg++;
            ngIds.add('DML_TJ_' + page + '_' + i);

            String emsg = (srList[i].getErrors() != null && !srList[i].getErrors().isEmpty()) ? srList[i].getErrors()[0].getMessage() : 'unknown';
            failMsgs.add('phase=' + phase + ' | TJ Insert fail page=' + page + ' idx=' + i + ' msg=' + emsg);
          }
        }
      }

      // 7) status
      phase = 'FINALIZE';
      if (insNg > 0 && insOk > 0) {
        jobLogger.setStatus('PARTIAL');
      } else if (insNg > 0) {
        jobLogger.setStatus('ERROR');
      } else {
        jobLogger.setStatus('SUCCESS');
      }

      jobLogger.setDescription(
        'phase=' +
          phase +
          ' | Page done. ymd=' +
          targetDate.format() +
          ', page=' +
          page +
          ', fetched=' +
          fetchedCnt +
          ', inserted=' +
          toInsert.size() +
          ', insertedOk=' +
          insOk +
          ', insertedNg=' +
          insNg
      );

      // 8) chain next page
      if (fetchedCnt == PAGE_SIZE) {
        System.enqueueJob(new MceCampaignTargetSendHistoryFetchJob(targetDate, page + 1));
      }
    } catch (Exception e) {
      try {
        jobLogger.createExceptionLog(e);
      } catch (Exception ignore) {
      }
      jobLogger.setStatus('ERROR');
      failMsgs.add(
        'phase=' +
          phase +
          ' | Unhandled exception: ' +
          e.getMessage() +
          ' | page=' +
          page +
          ' | idx=' +
          String.valueOf(phaseIdx) +
          ' | stack=' +
          e.getStackTraceString()
      );
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

  // =========================================================
  // Callout
  // =========================================================
  private static HttpResponse doGet(String endpointPath) {
    HttpRequest req = new HttpRequest();
    req.setMethod('GET');
    req.setEndpoint('callout:' + NC_NAME + endpointPath);
    req.setTimeout(120000);
    req.setHeader('Accept', 'application/json');
    return new Http().send(req);
  }

  // =========================================================
  // URL Builder
  // =========================================================
  private static String buildRowsetPath(Date day, Integer page, Integer pageSize) {
    Datetime dtGmt = Datetime.newInstanceGmt(day.year(), day.month(), day.day(), 0, 0, 0);
    String ymd = dtGmt.formatGmt('yyyyMMdd');

    String rawFilter = 'pk like \'%' + ymd + '%\'';
    String encFilter = EncodingUtil.urlEncode(rawFilter, 'UTF-8').replace('+', '%20');

    return '/data/v1/customobjectdata/key/' +
      DE_KEY +
      '/rowset' +
      '?page=' +
      String.valueOf(page) +
      '&pagesize=' +
      String.valueOf(pageSize) +
      '&$filter=' +
      encFilter;
  }

  // =========================================================
  // Mapping (캠페인 타겟 발송 이력 → TransactionJournal)
  // =========================================================
  private static TransactionJournal mapToTransactionJournal(Map<String, Object> keys, Map<String, Object> values, Id lpmId) {
    if (values == null) {
      values = new Map<String, Object>();
    }
    if (keys == null) {
      keys = new Map<String, Object>();
    }

    // pk 필수
    String pk = asString(values.get('pk'));
    if (String.isBlank(pk)) {
      return null;
    }

    TransactionJournal tj = new TransactionJournal();
    tj.put('MemberId', lpmId);
    tj.ActivityDate = System.now();

    // 발송일시(sentdate)가 있으면 그걸 ActivityDate로, 없으면 now

    // UsageType 구분값 (원하는 값으로 고정)
    tj.UsageType__c = TJ_USAGE_TYPE;

    // =========================
    // keys 매핑
    // =========================
    tj.put('CS_CAMP_NAME__c', asString(keys.get('camp_name')));
    tj.put('CS_CAMP_DTL_NAME__c', asString(keys.get('camp_dtl_name')));
    tj.put('CS_JOURNEY_ID__c', asString(keys.get('journey_id')));
    tj.put('CS_ACTIVITY_ID__c', asString(keys.get('activity_id')));

    Datetime sentDt = parseUsDateTime(keys.get('sentdate'));
    Date sentDateOnly = (sentDt == null) ? null : sentDt.date();
    tj.put('CS_Sentdate__c', sentDateOnly);

    // =========================
    // values 매핑
    // =========================
    tj.put('CS_CHANNEL1__c', asString(values.get('channel1')));
    tj.put('CS_CHANNEL2__c', asString(values.get('channel2')));
    tj.put('CS_CHANNEL1_F_CODE__c', asString(values.get('channel1_f_code')));
    tj.put('CS_CHANNEL2_F_CODE__c', asString(values.get('channel2_f_code')));

    return tj;
  }

  // =========================================================
  // Utils
  // =========================================================
  private static String asString(Object v) {
    return (v == null) ? null : String.valueOf(v);
  }

  private static String safeLeft(String s, Integer n) {
    if (s == null) {
      return null;
    }
    if (n == null || n <= 0) {
      return '';
    }
    return (s.length() <= n) ? s : s.left(n);
  }

  // "1/14/2026 9:52:40 AM" -> Datetime
  private static Datetime parseUsDateTime(Object v) {
    String s = asString(v);
    if (String.isBlank(s)) {
      return null;
    }
    s = s.trim();

    List<String> parts = s.split(' ');
    if (parts.size() < 3) {
      return null;
    }

    List<String> mdY = parts[0].split('/');
    Integer mm = Integer.valueOf(mdY[0]);
    Integer dd = Integer.valueOf(mdY[1]);
    Integer yyyy = Integer.valueOf(mdY[2]);

    List<String> hms = parts[1].split(':');
    Integer hh = Integer.valueOf(hms[0]);
    Integer mi = Integer.valueOf(hms[1]);
    Integer ss = Integer.valueOf(hms[2]);

    String ampm = parts[2].toUpperCase();
    if (ampm == 'PM' && hh < 12) {
      hh += 12;
    }
    if (ampm == 'AM' && hh == 12) {
      hh = 0;
    }

    return Datetime.newInstance(yyyy, mm, dd, hh, mi, ss);
  }
}