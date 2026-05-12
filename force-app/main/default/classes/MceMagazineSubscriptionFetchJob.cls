/**
 * MC 매거진 구독 정보 Fetch + Contact 업데이트 Job
 * - MCE Rowset 조회 → TJ 적재 → Contact 업데이트
 * - Contact 업데이트 "성공" 건만 Platform Event 발행
 *   → (Platform Event Trigger)에서 ErpMemberJob enqueue → ERP callout
 *
 * @author Changhwan Kim
 * @since 2026-02-26
 */
public with sharing class MceMagazineSubscriptionFetchJob implements Queueable, Database.AllowsCallouts {
  // =========================================================
  // Config
  // =========================================================
  private static final String NC_NAME = 'MarketingCloudApiNC';
  private static final String DE_KEY = '36F3065F-5E08-4879-947B-D5E339611C4B';
  private static final Integer PAGE_SIZE = 200;

  // ERP PE 발행도 200건 단위(운영 기준)
  private static final Integer ERP_CHUNK_SIZE = 200;

  private static final String LOYALTY_PROGRAM_NAME = System.Label.LoyaltyProgramName;
  private static final Id LOYALTY_PROGRAM_ID = SObjectUtil.findIdByName(LoyaltyProgram.SObjectType, LOYALTY_PROGRAM_NAME, true);
  @TestVisible
  private static Id loyaltyProgramIdForTest;
  @TestVisible
  private static Integer publishedMagazineEventCountForTest = 0;

  private static Id resolveLoyaltyProgramId() {
    if (Test.isRunningTest() && loyaltyProgramIdForTest != null) {
      return loyaltyProgramIdForTest;
    }
    return LOYALTY_PROGRAM_ID;
  }

  // =========================================================
  // Contact update field API Names
  // =========================================================
  private static final String CONTACT_SUBSCRIBED_FIELD = 'IsMagazineSubscribed__c'; // 매거진 구독 여부
  private static final String CONTACT_SUBSCRIBED_DATE_FIELD = 'MagazineSubscriptionDate__c';  // 매거진 구독 일자
  // 26.05.05 GD - 매거진 시즌 필드 추가
  private static final String CONTACT_SUBSCRIPTION_SEASON_FIELD = 'MagazineSubscriptionSeason__c'; // 매거진 구독 시즌
  //
  private static final String CONTACT_MAILING_STREET_FIELD = 'MailingStreet'; // 주소
  private static final String CONTACT_ADDRESS_DETAIL_FIELD = 'AddressDetail__c';  // 상세 주소

  // TJ 업데이트 플래그 필드
  private static final String TJ_IS_UPDATED_FIELD = 'Magazine_IsUpdated__c';

  // =========================================================
  // Runtime args
  // =========================================================
  private Date targetDate;
  private Integer page;

  public MceMagazineSubscriptionFetchJob(Date targetDate, Integer page) {
    this.targetDate = (targetDate == null) ? Date.today().addDays(-1) : targetDate;
    this.page = (page == null || page < 1) ? 1 : page;
  }

  // =========================================================
  // Execute
  // =========================================================
  public void execute(QueueableContext ctx) {
    ApexLogger jobLogger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, ctx.getJobId(), null);
    jobLogger.logging(MceMagazineSubscriptionFetchJob.class.getName());
    jobLogger.setRequestDatetime(Datetime.now());
    jobLogger.setMethod('GET');

    Set<String> okIds = new Set<String>();
    Set<String> ngIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    Integer fetchedCnt = 0;
    Integer insOk = 0;
    Integer insNg = 0;
    Integer erpSkippedWithdrawn = 0;

    ApexLogger apiLogger;

    // phase 로깅(원인 추적)
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
      apiLogger.setDescription('MCE Magazine Rowset GET ymd=' + targetDate.format() + ', page=' + page + ', pageSize=' + PAGE_SIZE);

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

      // 이번 page의 ContactKey(=ContactId) 수집 + keys/values 캐시
      phase = 'COLLECT_KEYS_VALUES';
      Set<String> memberNoSet = new Set<String>();
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
        if (String.isNotBlank(memberNo)) {
          memberNoSet.add(memberNo);
        }
      }

      // ContactId -> LPM (MembershipNumber 포함: ERP NO_MBR 용)
      phase = 'QUERY_LPM';
      Map<String, LoyaltyProgramMember> lpmByMemberNo = new Map<String, LoyaltyProgramMember>();
      Map<Id, LoyaltyProgramMember> lpmByContactId = new Map<Id, LoyaltyProgramMember>();
      if (!memberNoSet.isEmpty()) {
        Id effectiveProgramId = resolveLoyaltyProgramId();
        if (effectiveProgramId == null) {
          for (LoyaltyProgramMember lpm : [
            SELECT Id, ContactId, MembershipNumber, Contact.MemberNo__c
            FROM LoyaltyProgramMember
            WHERE Contact.MemberNo__c IN :memberNoSet
          ]) {
            if (String.isNotBlank(lpm.Contact.MemberNo__c) && !lpmByMemberNo.containsKey(lpm.Contact.MemberNo__c)) {
              lpmByMemberNo.put(lpm.Contact.MemberNo__c, lpm);
            }
            if (lpm.ContactId != null && !lpmByContactId.containsKey(lpm.ContactId)) {
              lpmByContactId.put(lpm.ContactId, lpm);
            }
          }
        } else {
          for (LoyaltyProgramMember lpm : [
            SELECT Id, ContactId, MembershipNumber, Contact.MemberNo__c
            FROM LoyaltyProgramMember
            WHERE Contact.MemberNo__c IN :memberNoSet AND ProgramId = :effectiveProgramId
          ]) {
            if (String.isNotBlank(lpm.Contact.MemberNo__c) && !lpmByMemberNo.containsKey(lpm.Contact.MemberNo__c)) {
              lpmByMemberNo.put(lpm.Contact.MemberNo__c, lpm);
            }
            if (lpm.ContactId != null && !lpmByContactId.containsKey(lpm.ContactId)) {
              lpmByContactId.put(lpm.ContactId, lpm);
            }
          }
        }
      }

      // Contact 조회 (비교/업데이트용)
      phase = 'QUERY_CONTACT';
      Map<Id, Contact> contactById = new Map<Id, Contact>();
      if (!memberNoSet.isEmpty()) {
        for (Contact c : [
          SELECT Id, LastName, Name, MobilePhone, LegalBirthdate__c, IsMagazineSubscribed__c, MagazineSubscriptionDate__c, MemberNo__c, IsWithdrawn__c // 26.05.01 법정 생년월일로 쿼리 수정
          FROM Contact
          WHERE MemberNo__c IN :memberNoSet
        ]) {
          contactById.put(c.Id, c);
        }
      }

      // Contact 업데이트 누적(중복 Contact 발생 대비)
      Map<Id, ContactUpdateState> contactUpdateStateById = new Map<Id, ContactUpdateState>();

      // "Contact 업데이트 성공 시 TJ 플래그 true"를 위해,
      // 이번 실행에서 생성한 TJ가 어떤 ContactId에 연결되는지 추적
      List<TransactionJournal> toInsert = new List<TransactionJournal>();
      List<Id> tjContactIdList = new List<Id>(); // toInsert와 인덱스 1:1
      List<Boolean> tjNeedsMarkList = new List<Boolean>(); // 이 TJ가 "매칭되어 Contact 업데이트 대상"인지

      // 3) map -> TransactionJournal list
      phase = 'MAP_ITEMS';
      for (Integer i = 0; i < itemKeyList.size(); i++) {
        try {
          phaseIdx = i;
          Map<String, Object> keys = itemKeyList[i];
          Map<String, Object> values = itemValList[i];

          String memberNo = String.valueOf(keys.get('contactkey'));

          LoyaltyProgramMember lpm = (memberNo == null) ? null : lpmByMemberNo.get(memberNo);
          Id lpmId = (lpm == null) ? null : lpm.Id;

          if (lpmId == null) {
            insNg++;
            ngIds.add('NO_LPM_' + page + '_' + i);
            failMsgs.add('phase=' + phase + ' | No LPM for memberNo=' + memberNo + ' (page=' + page + ', idx=' + i + ')');
            continue;
          }

          // Contact 비교 후 업데이트 누적
          Boolean isMatched = false;
          Contact c = (lpm.ContactId == null) ? null : contactById.get(lpm.ContactId);
          if (c != null) {
            String respName = asString(values.get('a_name'));
            String respPhone = asString(values.get('a_phone'));
            Date respBirth = parseUsDateTimeToDate(values.get('a_birthdate'));

            if (isContactMatched(c, respName, respPhone, respBirth)) {
              isMatched = true;

              Boolean subscribed = toBooleanY(values.get('ismagazinesubscribed__c'));
              // 26.05.05 GD - 응답 시간 Datetime 추가
              Datetime reqDateTime = parseUsDateTime(values.get('response_time'));
              //
              Date reqDate = parseFlexibleDate(values.get('response_time'));
              String season = ValidationUtil.stringValidation(values.get('mag_season'), 'mag_season', false);

              ContactUpdateState st = contactUpdateStateById.get(c.Id);
              if (st == null) {
                st = new ContactUpdateState();
                contactUpdateStateById.put(c.Id, st);
              }

              // 기존
              // st.mailingStreet = trimToNull(values.get('a_address1'));
              // st.addressDetail = trimToNull(values.get('a_address2'));
              // 여러 row가 있으면 true 우선
              st.subscribed = (st.subscribed == true) ? true : subscribed;

              // 26.05.05 GD - 응답 시간 Datetime 기준으로 로직 수정 - 구독 true일 때 최신 응답시각만 (같은 날짜 내에서도 시간 단위로 최신값 우선)
              if (subscribed == true && reqDateTime != null) {
                if (st.responseDatetime == null || reqDateTime > st.responseDatetime) {
                  st.responseDatetime = reqDateTime;
                  st.subscribedDate = reqDate;
                  st.season = season;
                  st.mailingStreet = trimToNull(values.get('a_address1'));
                  st.addressDetail = trimToNull(values.get('a_address2'));
                }
              }
              //
            }
          }

          // 26.05.05 GD - 매칭 실패 시 거래 이력 생성하지 않음
          if (!isMatched) {
            insNg++;
            ngIds.add('NOT_MATCHED_' + page + '_' + i);
            failMsgs.add('phase=' + phase + ' | Contact not matched (page=' + page + ', idx=' + i + ', memberNo=' + memberNo + ')');
            continue;
          }
          //

          // TJ 생성
          TransactionJournal tj = mapToTransactionJournal(keys, values, lpmId);

          if (tj != null) {
            // 기본은 false(또는 null). 최종적으로 Contact 업데이트 성공하면 true로 바꿀 거임.
            tj.put(TJ_IS_UPDATED_FIELD, false);

            toInsert.add(tj);
            tjContactIdList.add(c == null ? null : c.Id);
            tjNeedsMarkList.add(isMatched); // "매칭된 경우"만 후속으로 true 대상 후보
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

      // 4) TJ insert
      phase = 'DML_INSERT_TJ';

      // contactId -> insertedTjIds (매칭된 TJ만 모아두기)
      Map<Id, List<Id>> insertedTjIdsByContactId = new Map<Id, List<Id>>();

      if (!toInsert.isEmpty()) {
        Database.SaveResult[] srList = Database.insert(toInsert, false);

        for (Integer i = 0; i < srList.size(); i++) {
          if (srList[i].isSuccess()) {
            insOk++;
            Id tjId = srList[i].getId();
            okIds.add(String.valueOf(tjId));

            // "매칭된 TJ"만 contactId 기준으로 보관
            if (i < tjContactIdList.size() && i < tjNeedsMarkList.size()) {
              Id cId = tjContactIdList[i];
              Boolean needsMark = tjNeedsMarkList[i];

              if (needsMark == true && cId != null) {
                if (!insertedTjIdsByContactId.containsKey(cId)) {
                  insertedTjIdsByContactId.put(cId, new List<Id>());
                }
                insertedTjIdsByContactId.get(cId).add(tjId);
              }
            }
          } else {
            insNg++;
            ngIds.add('DML_TJ_' + page + '_' + i);
            if (srList[i].getErrors() != null && !srList[i].getErrors().isEmpty()) {
              failMsgs.add('phase=' + phase + ' | TJ Insert fail page=' + page + ' idx=' + i + ' msg=' + srList[i].getErrors()[0].getMessage());
            } else {
              failMsgs.add('phase=' + phase + ' | TJ Insert fail page=' + page + ' idx=' + i);
            }
          }
        }
      }

      // 5) Contact update (일치한 것들만)
      phase = 'DML_UPDATE_CONTACT';

      // Contact 업데이트 성공한 ContactId만 모아두기
      Set<Id> updatedContactIds = new Set<Id>();

      if (!contactUpdateStateById.isEmpty()) {
        List<Contact> cToUpdate = new List<Contact>();

        for (Id cId : contactUpdateStateById.keySet()) {
          ContactUpdateState st = contactUpdateStateById.get(cId);
          if (st == null || st.subscribed == null) {
            continue;
          }

          Contact upd = new Contact(Id = cId);
          upd.put(CONTACT_SUBSCRIBED_FIELD, st.subscribed);
          upd.put(CONTACT_MAILING_STREET_FIELD, st.mailingStreet);
          upd.put(CONTACT_ADDRESS_DETAIL_FIELD, st.addressDetail);

          if (st.subscribed == true && st.subscribedDate != null) {
            upd.put(CONTACT_SUBSCRIBED_DATE_FIELD, st.subscribedDate);
            // 26.05.05 GD - 매거진 시즌 필드 업데이트
            upd.put(CONTACT_SUBSCRIPTION_SEASON_FIELD, seasonNameToCode(st.season));
            //
          }

          cToUpdate.add(upd);
        }

        if (!cToUpdate.isEmpty()) {
          Database.SaveResult[] cu = Database.update(cToUpdate, false);

          for (Integer i = 0; i < cu.size(); i++) {
            if (cu[i].isSuccess()) {
              updatedContactIds.add(cToUpdate[i].Id);
            } else {
              insNg++;
              ngIds.add('DML_CONTACT_' + page + '_' + i);
              if (cu[i].getErrors() != null && !cu[i].getErrors().isEmpty()) {
                failMsgs.add('phase=' + phase + ' | Contact update fail page=' + page + ' idx=' + i + ' msg=' + cu[i].getErrors()[0].getMessage());
              } else {
                failMsgs.add('phase=' + phase + ' | Contact update fail page=' + page + ' idx=' + i);
              }
            }
          }
        }
      }

      // 5.5) Platform Event publish (Contact update 성공 건만, 200건 chunk)
      phase = 'PUBLISH_PE_ERP_MAGAZINE';
      erpSkippedWithdrawn = this.publishErpMagazineEvents(
        updatedContactIds,
        contactUpdateStateById,
        lpmByContactId,
        contactById,
        targetDate,
        page,
        failMsgs
      );

      // Contact 업데이트가 "성공"한 경우에만,
      // 해당 Contact에 매칭되어 생성된 TJ들의 Magazine_IsUpdated__c = true로 업데이트
      phase = 'DML_UPDATE_TJ_ISUPDATED';

      if (!updatedContactIds.isEmpty() && !insertedTjIdsByContactId.isEmpty()) {
        List<TransactionJournal> tjToUpdate = new List<TransactionJournal>();

        for (Id cId : updatedContactIds) {
          List<Id> tjIds = insertedTjIdsByContactId.get(cId);
          if (tjIds == null || tjIds.isEmpty()) {
            continue;
          }

          for (Id tjId : tjIds) {
            TransactionJournal updTj = new TransactionJournal(Id = tjId);
            updTj.put(TJ_IS_UPDATED_FIELD, true);
            tjToUpdate.add(updTj);
          }
        }

        if (!tjToUpdate.isEmpty()) {
          Database.SaveResult[] tu = Database.update(tjToUpdate, false);
          for (Integer i = 0; i < tu.size(); i++) {
            if (!tu[i].isSuccess()) {
              insNg++;
              ngIds.add('DML_TJ_MARK_' + page + '_' + i);
              String emsg = (tu[i].getErrors() != null && !tu[i].getErrors().isEmpty()) ? tu[i].getErrors()[0].getMessage() : 'unknown';
              failMsgs.add('phase=' + phase + ' | TJ mark(update flag) fail page=' + page + ' idx=' + i + ' msg=' + emsg);
            }
          }
        }
      }

      // 6) status
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
          insNg +
          ', erpSkippedWithdrawn=' +
          erpSkippedWithdrawn
      );

      // 7) chain next page (enqueue는 여기서 1번만!)
      if (fetchedCnt == PAGE_SIZE) {
        System.enqueueJob(new MceMagazineSubscriptionFetchJob(targetDate, page + 1));
      }
    } catch (Exception e) {
      try {
        jobLogger.createExceptionLog(e);
      } catch (Exception ignore) {
        // 무시
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
        if (!okIds.isEmpty())
          jobLogger.setSuccessRecordIds(okIds);
        if (!ngIds.isEmpty())
          jobLogger.setFailedRecordIds(ngIds);
        if (!failMsgs.isEmpty())
          jobLogger.setErrorMessage(String.join(failMsgs, ' | '));
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

  // =========================================================
  // Platform Event publish (ERP)
  // =========================================================
  private Integer publishErpMagazineEvents(
    Set<Id> updatedContactIds,
    Map<Id, ContactUpdateState> contactUpdateStateById,
    Map<Id, LoyaltyProgramMember> lpmByContactId,
    Map<Id, Contact> contactById,
    Date targetDate,
    Integer page,
    List<String> failMsgs
  ) {
    Integer skippedWithdrawn = 0;

    if (updatedContactIds == null || updatedContactIds.isEmpty()) {
      return skippedWithdrawn;
    }

    List<ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel> models = new List<ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel>();

    for (Id cId : updatedContactIds) {
      ContactUpdateState st = contactUpdateStateById.get(cId);
      if (st == null || st.subscribed == null) {
        continue;
      }

      Contact c = contactById.get(cId);
      if (isExcludedFromErpMagazineSync(c)) {
        skippedWithdrawn++;
        continue;
      }

      LoyaltyProgramMember lpm = lpmByContactId.get(cId);
      if (lpm == null || String.isBlank(lpm.MembershipNumber)) {
        continue;
      }

      String ym = (st.subscribed == true) ? 'Y' : 'N';

      // subscribed=false면 날짜 null (ERP 스펙에 따라 ''로 바꿔도 됨)
      String dt = (st.subscribed == true && st.subscribedDate != null) ? formatErpDate(st.subscribedDate) : null;

      models.add(new ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel(lpm.MembershipNumber, ym, dt, st.season));
    }

    if (models.isEmpty()) {
      return skippedWithdrawn;
    }

    List<MagazineSubscriptionSync__e> events = new List<MagazineSubscriptionSync__e>();

    for (Integer i = 0; i < models.size(); i += ERP_CHUNK_SIZE) {
      Integer endIdx = Math.min(i + ERP_CHUNK_SIZE, models.size());

      ErpMemberReqDto.UpdateMagazineSubscriptionRequest req = new ErpMemberReqDto.UpdateMagazineSubscriptionRequest();
      req.ID_UPDATE = 'MCE_MAGAZINE_FETCH';
      for (Integer j = i; j < endIdx; j++) {
        req.memebrModelList.add(models[j]);
      }

      MagazineSubscriptionSync__e evt = new MagazineSubscriptionSync__e();
      evt.Payload__c = JSON.serialize(req);

      // 아래 3개 필드는 PE에 생성한 경우만 사용하세요.
      // (필드 없으면 컴파일 에러입니다. 없으면 주석 처리!)
      evt.Source__c = 'MCE_MAGAZINE_FETCH';
      evt.TargetDate__c = targetDate;
      evt.Page__c = page;

      events.add(evt);
    }

    if (Test.isRunningTest()) {
      publishedMagazineEventCountForTest += events.size();
    }

    if (!events.isEmpty()) {
      try {
        // 결과까지 확인하고 싶으면 SaveResult로 받아 로깅 가능
        EventBus.publish(events);
      } catch (Exception ex) {
        if (failMsgs != null) {
          failMsgs.add('phase=PUBLISH_PE_ERP_MAGAZINE | publish fail msg=' + ex.getMessage());
        }
      }
    }

    return skippedWithdrawn;
  }

  private static String formatErpDate(Date d) {
    if (d == null)
      return null;

    // 날짜 포맷을 고정하기 위해 Date -> Datetime(GMT 00:00:00)로 변환
    Datetime dtGmt = Datetime.newInstanceGmt(d.year(), d.month(), d.day(), 0, 0, 0);

    // ERP가 yyyyMMdd 원하면 'yyyyMMdd'로 변경
    return dtGmt.formatGmt('yyyyMMdd');
  }

  private static Boolean isExcludedFromErpMagazineSync(Contact c) {
    return c != null && c.IsWithdrawn__c == true;
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
  // Mapping
  // =========================================================
  private static TransactionJournal mapToTransactionJournal(Map<String, Object> keys, Map<String, Object> values, Id lpmId) {
    if (values == null)
      values = new Map<String, Object>();
    if (keys == null)
      keys = new Map<String, Object>();

    String pk = asString(values.get('pk'));
    if (String.isBlank(pk)) {
      return null;
    }

    TransactionJournal tj = new TransactionJournal();
    tj.put('MemberId', lpmId);
    tj.ActivityDate = System.now();

    tj.put('Magazine_Grade__c', asString(values.get('grade__c')));
    tj.put('Magazine_Ismagazinesubscribed__c', asString(values.get('ismagazinesubscribed__c')));

    Date appliedDate = parseUsDateTimeToDateOnly(values.get('mag_req_dt'));
    tj.put('Magazine_ApplicationDate__c', appliedDate);

    Date sentDate = parseUsDateTimeToDateOnly(values.get('sentdate'));
    tj.put('Magazine_SentDate__c', sentDate);

    tj.put('Magazine_Grade__c', asString(values.get('grade__c')));
    // tj.put('Magazine_StoreMana__c', asString(values.get('storemana__c'))); // 보류
    tj.put('Magazine_MemberType__c', asString(values.get('membertype__c')));
    tj.put('Magazine_Season__c', asString(values.get('mag_season')));
    tj.put('Magazine_YN_NEWJOIN__c', asString(values.get('yn_newjoin')));
    tj.put('Magazine_PUR_10YEAR_YN__c', asString(values.get('pur_10year_yn')));
    tj.put('Magazine_EXI_SUB_YN__c', asString(values.get('exi_sub_yn')));
    tj.put('Magazine_Thisyear__c', asString(values.get('thisyear')));
    tj.put('Magazine_A_sns_YN__c', asString(values.get('a_sns_yn')));
    tj.put('Magazine_A_account_YN__c', asString(values.get('a_account_yn')));
    tj.put('Magazine_A_Name__c', asString(values.get('a_name')));
    tj.put('Magazine_A_MobilePhone__c', asString(values.get('a_phone')));

    Date birthDate = parseUsDateTimeToDate(values.get('a_birthdate'));
    tj.put('Magazine_A_Birthdate__c', birthDate);

    tj.put('Magazine_Address__c', combineAddress(values.get('a_address1'), values.get('a_address2')));
    tj.put('Magazine_A_ZIP_Code__c', asString(values.get('a_zip_code')));
    tj.put('Magazine_A_Sub_Reason__c', asString(values.get('a_sub_reason')));
    tj.put('Magazine_Response_Time__c', parseUsDateTime(values.get('response_time')));

    tj.UsageType__c = 'Magazine';
    return tj;
  }

  // =========================================================
  // Contact update state
  // =========================================================
  private class ContactUpdateState {
    public Boolean subscribed;
    public Date subscribedDate;
    // 26.05.05 GD - 같은 날짜 내 시간 비교용
    public Datetime responseDatetime;
    //
    public String season; // 시즌 
    public String mailingStreet;
    public String addressDetail;
  }

  // =========================================================
  // Utils
  // =========================================================
  private static String asString(Object v) {
    return (v == null) ? null : String.valueOf(v);
  }

  private static String trimToNull(Object v) {
    String s = asString(v);
    return String.isBlank(s) ? null : s.trim();
  }

  // 26.05.05 GD - 매거진 시즌 한글 → 코드
  private static String seasonNameToCode(String name) {
    if (String.isBlank(name)) return null;
    switch on name.trim() {
      when '봄'   { return '01'; }
      when '여름' { return '02'; }
      when '가을' { return '03'; }
      when '겨울' { return '04'; }
      when else   { return null; }
    }
  }

  private static String combineAddress(Object address1, Object address2) {
    List<String> parts = new List<String>();

    String addr1 = asString(address1);
    if (String.isNotBlank(addr1)) {
      parts.add(addr1.trim());
    }

    String addr2 = asString(address2);
    if (String.isNotBlank(addr2)) {
      parts.add(addr2.trim());
    }

    return parts.isEmpty() ? null : String.join(parts, ' ');
  }

  private static Id toId(Object v) {
    try {
      String s = asString(v);
      if (String.isBlank(s))
        return null;
      return (Id) s;
    } catch (Exception e) {
      return null;
    }
  }

  private static String safeLeft(String s, Integer n) {
    if (s == null)
      return null;
    if (n == null || n <= 0)
      return '';
    return (s.length() <= n) ? s : s.left(n);
  }

  private static Boolean toBooleanY(Object v) {
    String s = asString(v);
    if (s == null)
      return false;
    return s.trim().equalsIgnoreCase('Y');
  }

  private static Date parseUsDateTimeToDate(Object v) {
    String s = asString(v);
    if (String.isBlank(s))
      return null;
    s = s.trim();

    String datePart = s.contains(' ') ? s.split(' ')[0] : s;
    List<String> mdY = datePart.split('/');
    if (mdY.size() != 3)
      return null;

    Integer mm = Integer.valueOf(mdY[0]);
    Integer dd = Integer.valueOf(mdY[1]);
    Integer yyyy = Integer.valueOf(mdY[2]);

    return Date.newInstance(yyyy, mm, dd);
  }

  private static Date parseFlexibleDate(Object v) {
    String s = asString(v);
    if (String.isBlank(s))
      return null;
    s = s.trim();

    if (s.contains('/')) {
      return parseUsDateTimeToDate(s);
    }

    if (s.contains('-')) {
      List<String> p = s.split('-');
      if (p.size() == 3) {
        try {
          Integer yyyy = Integer.valueOf(p[0]);
          Integer mm = Integer.valueOf(p[1]);
          Integer dd = Integer.valueOf(p[2].left(2));
          return Date.newInstance(yyyy, mm, dd);
        } catch (Exception e) {
          return null;
        }
      }
    }

    if (s.length() >= 8) {
      try {
        Integer yyyy = Integer.valueOf(s.substring(0, 4));
        Integer mm = Integer.valueOf(s.substring(4, 6));
        Integer dd = Integer.valueOf(s.substring(6, 8));
        return Date.newInstance(yyyy, mm, dd);
      } catch (Exception e) {
        return null;
      }
    }
    return null;
  }

  private static Boolean isContactMatched(Contact c, String respName, String respPhone, Date respBirth) {
    if (c == null)
      return false;

    String cName = normalizeName(c.LastName);
    String rName = normalizeName(respName);
    if (String.isBlank(cName) || String.isBlank(rName) || cName != rName)
      return false;

    String cPhone = normalizePhone(c.MobilePhone);
    String rPhone = normalizePhone(respPhone);
    if (String.isBlank(cPhone) || String.isBlank(rPhone) || cPhone != rPhone)
      return false;

    // 기존
    // if (c.Birthdate == null || respBirth == null)
    //   return false;
    // if (c.Birthdate != respBirth)
    //   return false;

    // 26.05.01 GD - 법정 생년월일 기준으로 변경
    if (String.isBlank(c.LegalBirthdate__c) || respBirth == null) {
        return false;
    }

    Datetime dtRespBirth = Datetime.newInstance(respBirth.year(), respBirth.month(), respBirth.day());
    String formattedRespBirth = dtRespBirth.format('yyMMdd');
    
    if (c.LegalBirthdate__c != formattedRespBirth) {
        return false;
    }

    return true;
  }

  private static String normalizeName(String s) {
    if (String.isBlank(s))
      return null;
    return s.replaceAll('\\s+', '').trim();
  }

  private static String normalizePhone(String s) {
    if (String.isBlank(s))
      return null;
    String onlyDigits = s.replaceAll('[^0-9]', '');
    return String.isBlank(onlyDigits) ? null : onlyDigits;
  }

  private static Datetime parseUsDateTime(Object v) {
    String s = asString(v);
    if (String.isBlank(s))
      return null;
    s = s.trim(); // "1/14/2026 9:52:40 AM"

    List<String> parts = s.split(' ');
    if (parts.size() < 3)
      return null;

    // date
    List<String> mdY = parts[0].split('/');
    Integer mm = Integer.valueOf(mdY[0]);
    Integer dd = Integer.valueOf(mdY[1]);
    Integer yyyy = Integer.valueOf(mdY[2]);

    // time
    List<String> hms = parts[1].split(':');
    Integer hh = Integer.valueOf(hms[0]);
    Integer mi = Integer.valueOf(hms[1]);
    Integer ss = Integer.valueOf(hms[2]);

    String ampm = parts[2].toUpperCase();
    if (ampm == 'PM' && hh < 12)
      hh += 12;
    if (ampm == 'AM' && hh == 12)
      hh = 0;

    return Datetime.newInstance(yyyy, mm, dd, hh, mi, ss);
  }

  private static Date parseUsDateTimeToDateOnly(Object v) {
    String s = asString(v);
    if (String.isBlank(s))
      return null;
    s = s.trim(); // "1/14/2026 9:52:40 AM"

    List<String> parts = s.split(' ');
    if (parts.size() < 1)
      return null;

    List<String> mdY = parts[0].split('/');
    if (mdY.size() != 3)
      return null;

    Integer mm = Integer.valueOf(mdY[0]);
    Integer dd = Integer.valueOf(mdY[1]);
    Integer yyyy = Integer.valueOf(mdY[2]);

    return Date.newInstance(yyyy, mm, dd);
  }
}