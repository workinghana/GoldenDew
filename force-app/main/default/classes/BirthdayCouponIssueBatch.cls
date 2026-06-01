public with sharing class BirthdayCouponIssueBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual'; // 저널 유형 : 포인트/쿠폰 지급
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_ISSUE = 'Coupon Issue'; // 저널 하위 유형 : 쿠폰 지급

  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  private final String VOUCHER_CATEGORY_NAME_BIRTHDAY_COUPON = 'BirthdayCoupon';
  private final String VOUCHER_LIMIT_TYPE_NAME_GRADE_INCLUDE_LIST = 'GradeIncludeList'; // 등급 허용 리스트

  public Database.QueryLocator start(Database.BatchableContext bc) {
    Integer thisMonth = Date.today().month();
    // 기존
    // String soql =
    //   'SELECT Id, LoyaltyMemberId, LoyaltyTierId, ' +
    //   '       LoyaltyMember.ProgramId, LoyaltyMember.Program.Name, ' +
    //   '       LoyaltyMember.Contact.MemberNo__c, LoyaltyMember.Contact.Birthdate ' +
    //   'FROM LoyaltyMemberTier ' +
    //   'WHERE LoyaltyMemberId != NULL ' +
    //   '  AND LoyaltyMember.MemberStatus = \'Active\' ' +
    //   '  AND LoyaltyTierId != NULL ' +
    //   '  AND LoyaltyMember.Contact.Birthdate != NULL ' +
    //   '  AND CALENDAR_MONTH(LoyaltyMember.Contact.Birthdate) = ' +
    //   thisMonth;

    // 26.05.01 GD 수정 - 법정 생년월일로 변경
    String monthStr = String.valueOf(thisMonth).leftPad(2, '0');
    String likePattern = '__' + monthStr + '__';

    String soql =
      'SELECT Id, LoyaltyMemberId, LoyaltyTierId, ' +
      '       LoyaltyMember.ProgramId, LoyaltyMember.Program.Name, ' +
      '       LoyaltyMember.Contact.MemberNo__c, LoyaltyMember.Contact.LegalBirthdate__c ' +
      'FROM LoyaltyMemberTier ' +
      'WHERE LoyaltyMemberId != NULL ' +
      '  AND LoyaltyMember.MemberStatus = \'Active\' ' +
      '  AND LoyaltyTierId != NULL ' +
      '  AND LoyaltyMember.Contact.LegalBirthdate__c != NULL ' +
      '  AND LoyaltyMember.Contact.LegalBirthdate__c LIKE :likePattern';

    return Database.getQueryLocator(soql);
  }

  public void execute(Database.BatchableContext bc, List<LoyaltyMemberTier> lmtList) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(BirthdayCouponIssueBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    if (lmtList != null && !lmtList.isEmpty()) {
      logger.setScopedIds((List<SObject>) lmtList, 'Id');
    }

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (lmtList == null || lmtList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      // 쿠폰 카테고리 조회
      List<VoucherCategory__c> vcList = [
        SELECT Id
        FROM VoucherCategory__c
        WHERE Code__c = :VOUCHER_CATEGORY_NAME_BIRTHDAY_COUPON
        LIMIT 1
      ];
      if (vcList.isEmpty()) {
        for (LoyaltyMemberTier lmt : lmtList) {
          failIds.add((String) lmt.LoyaltyMemberId);
        }
        logger.setStatus('ERROR');
        logger.setErrorCode('NOT_FOUND');
        logger.setErrorMessage('VoucherCategory not found: ' + VOUCHER_CATEGORY_NAME_BIRTHDAY_COUPON);
        return;
      }

      // 2) 쿠폰 마스터 조회
      List<VoucherDefinition> vdList = [
        SELECT Id, Name, CouponManNo__c, IsUpgrade__c
        FROM VoucherDefinition
        WHERE IsActive = TRUE AND VoucherCategoryId__c = :vcList[0].Id
        LIMIT 10
      ];
      if (vdList.isEmpty()) {
        for (LoyaltyMemberTier lmt : lmtList) {
          failIds.add((String) lmt.LoyaltyMemberId);
        }
        logger.setStatus('ERROR');
        logger.setErrorCode('NOT_FOUND');
        logger.setErrorMessage('VoucherDefinition not found. categoryId=' + vcList[0].Id);
        return;
      }
      Map<Id, VoucherDefinition> vdById = new Map<Id, VoucherDefinition>(vdList);
      Set<Id> vdIdSet = vdById.keySet();

      // 3) 쿠폰 한도(등급 허용 리스트) 조회
      List<VoucherLimit__c> vlList = [
        SELECT Id, VoucherDefinitionId__c, Value__c, Type__c, IsActive__c
        FROM VoucherLimit__c
        WHERE IsActive__c = TRUE AND Type__c = :VOUCHER_LIMIT_TYPE_NAME_GRADE_INCLUDE_LIST AND VoucherDefinitionId__c IN :vdIdSet AND Value__c != NULL
      ];

      Map<Id, Set<Id>> allowedTierIdsByVdId = new Map<Id, Set<Id>>();
      for (VoucherLimit__c vl : vlList) {
        Id tierId;
        try {
          tierId = (Id) vl.Value__c;
        } catch (Exception ignore) {
          continue;
        }

        if (!allowedTierIdsByVdId.containsKey(vl.VoucherDefinitionId__c)) {
          allowedTierIdsByVdId.put(vl.VoucherDefinitionId__c, new Set<Id>());
        }
        allowedTierIdsByVdId.get(vl.VoucherDefinitionId__c).add(tierId);
      }

      // 4) 대상 member(=LoyaltyMemberId=LPMId)별 필수 정보 맵 구성
      Map<Id, Id> tierIdByMemberId = new Map<Id, Id>(); // LPMId -> TierId
      Map<Id, String> memberNoByMemberId = new Map<Id, String>(); // LPMId -> MemberNo__c
      Map<Id, Id> programIdByMemberId = new Map<Id, Id>(); // LPMId -> ProgramId
      Map<Id, String> programNameByMemberId = new Map<Id, String>(); // LPMId -> Program.Name

      for (LoyaltyMemberTier lmt : lmtList) {
        if (lmt.LoyaltyMemberId == null || lmt.LoyaltyTierId == null) {
          continue;
        }

        // Contact.MemberNo__c가 null일 수 있으니 방어
        String memberNo = (lmt.LoyaltyMember != null && lmt.LoyaltyMember.Contact != null) ? lmt.LoyaltyMember.Contact.MemberNo__c : null;
        if (String.isBlank(memberNo)) {
          failIds.add((String) lmt.LoyaltyMemberId);
          failMsgs.add('No MemberNo. LoyaltyMemberId=' + lmt.LoyaltyMemberId);
          continue;
        }

        tierIdByMemberId.put(lmt.LoyaltyMemberId, lmt.LoyaltyTierId);
        memberNoByMemberId.put(lmt.LoyaltyMemberId, memberNo);

        Id programId = (lmt.LoyaltyMember != null) ? lmt.LoyaltyMember.ProgramId : null;
        String programName = (lmt.LoyaltyMember != null && lmt.LoyaltyMember.Program != null) ? lmt.LoyaltyMember.Program.Name : null;

        if (programId != null) {
          programIdByMemberId.put(lmt.LoyaltyMemberId, programId);
        }
        if (!String.isBlank(programName)) {
          programNameByMemberId.put(lmt.LoyaltyMemberId, programName);
        }
      }

      if (tierIdByMemberId.isEmpty()) {
        for (LoyaltyMemberTier lmt : lmtList) {
          if (lmt.LoyaltyMemberId != null) {
            failIds.add((String) lmt.LoyaltyMemberId);
          }
        }
        logger.setStatus('ERROR');
        logger.setErrorCode('NO_TARGET');
        logger.setErrorMessage('No valid LoyaltyMemberTier in scope.');
        return;
      }

      // 5) 멤버별로 "지급 대상 쿠폰이 하나라도 있는지" 체크 후 TJ 생성 대상 구성
      Map<Id, TransactionJournal> tjByMemberId = new Map<Id, TransactionJournal>(); // LPMId -> TJ

      // 거래 유형/ 거래 하위 유형 조회
      Id journalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      Id journalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_ISSUE, true);

      for (Id memberId : tierIdByMemberId.keySet()) {
        Id tierId = tierIdByMemberId.get(memberId);

        Boolean hasEligible = false;
        for (VoucherDefinition vd : vdList) {
          Set<Id> allowed = allowedTierIdsByVdId.get(vd.Id);
          if (allowed == null || allowed.isEmpty() || allowed.contains(tierId)) {
            hasEligible = true;
            break;
          }
        }
        if (hasEligible) {
          // 정책: 지급할 쿠폰이 전혀 없으면 스킵(실패로 잡고 싶으면 failIds 추가)
          continue;
        }

        Id programId = programIdByMemberId.get(memberId);
        if (programId == null) {
          failIds.add((String) memberId);
          failMsgs.add('No ProgramId. LoyaltyMemberId=' + memberId);
          continue;
        }

        TransactionJournal tj = new TransactionJournal();
        tj.ActivityDate = Datetime.now();
        tj.JournalDate = Datetime.now();
        tj.LoyaltyProgramId = programId;
        tj.MemberId = memberId; // LPMId
        tj.JournalTypeId = journalTypeId;
        tj.JournalSubTypeId = journalSubTypeId;
        tj.Status = 'Processed';

        tjByMemberId.put(memberId, tj);
      }

      if (tjByMemberId.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('No eligible targets after tier/limits. chunkSize=' + lmtList.size());
        return;
      }

      // 6) TJ insert (부분 성공)
      List<TransactionJournal> tjList = tjByMemberId.values();
      Database.SaveResult[] tjResults = Database.insert(tjList, false);

      Set<Id> journalSuccessMemberIdSet = new Set<Id>();
      for (Integer i = 0; i < tjResults.size(); i++) {
        TransactionJournal tj = tjList[i];
        Database.SaveResult sr = tjResults[i];

        if (sr.isSuccess()) {
          journalSuccessMemberIdSet.add(tj.MemberId);
        } else {
          failIds.add((String) tj.MemberId);
          for (Database.Error err : sr.getErrors()) {
            failMsgs.add('Journal insert failed. memberId=' + tj.MemberId + ', msg=' + err.getMessage());
          }
        }
      }

      if (journalSuccessMemberIdSet.isEmpty()) {
        logger.setStatus('ERROR');
        logger.setErrorCode('JOURNAL_FAIL');
        logger.setErrorMessage('All journals failed in scope.');
        return;
      }

      // 7) 저널 성공 멤버만 로열티 쿠폰 지급 요청 생성
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (Id memberId : journalSuccessMemberIdSet) {
        Id tierId = tierIdByMemberId.get(memberId);
        TransactionJournal tj = tjByMemberId.get(memberId);

        String programName = programNameByMemberId.get(memberId);
        if (String.isBlank(programName)) {
          failIds.add((String) memberId);
          failMsgs.add('No Program.Name. memberId=' + memberId);
          continue;
        }

        for (VoucherDefinition vd : vdList) {
          Set<Id> allowed = allowedTierIdsByVdId.get(vd.Id);
          Boolean eligible = (allowed == null || allowed.isEmpty()) || allowed.contains(tierId);
          if (!eligible) {
            // 지급할 쿠폰이 없는 경우 지급 X
            continue;
          }

          // 로열티 쿠폰 지급 객체 생성
          reqList.add(
            new Map<String, Object>{
              'loyaltyProgramMemberId' => memberId,
              'programName' => programName,
              'voucherDefinitionName' => vd.Name,
              'journalId' => tj.Id
            }
          );
        }
      }

      Integer loyaltyFailCnt = 0;

      if (!reqList.isEmpty()) {
        List<LoyaltyManagement.IssueVoucherOutput> resList = LoyaltyVoucherService.issueVoucherV2(reqList);

        Set<Id> issuedVoucherIdSet = new Set<Id>();

        for (LoyaltyManagement.IssueVoucherOutput res : resList) {
          if (!res.isSuccess()) {
            loyaltyFailCnt++;

            String errMsg = 'Voucher issue failed.';
            if (res.getErrors() != null && !res.getErrors().isEmpty()) {
              if (!String.isBlank(res.getErrors()[0].getCode())) {
                errMsg += ', errorCode=' + res.getErrors()[0].getCode();
              }
              if (!String.isBlank(res.getErrors()[0].getMessage())) {
                errMsg += ', errorMessage=' + res.getErrors()[0].getMessage();
              }
            }
            failMsgs.add(errMsg);
            continue;
          }

          String vid = res.getVoucherId();
          if (!String.isBlank(vid)) {
            try {
              issuedVoucherIdSet.add((Id) vid);
            } catch (Exception ex) {
              failMsgs.add('Invalid voucherId returned: ' + vid);
            }
          }
        }

        // 업글레이드 쿠폰 금액 0원으로 수정
        normalizeIssuedUpgradeVouchers(issuedVoucherIdSet);

        // ! ERP 동기화 하지 않음.
        // 8) 발급 성공 voucherId 재조회 → ERP DTO 생성 + 최종 성공 집계
        // if (!issuedVoucherIdSet.isEmpty()) {
        //   List<Voucher> issued = [
        //     SELECT Id, LoyaltyProgramMemberId, LoyaltyProgramMember.Contact.MemberNo__c, VoucherDefinition.CouponManNo__c, VoucherCode
        //     FROM Voucher
        //     WHERE Id IN :issuedVoucherIdSet
        //   ];

        //   ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
        //   couponIssueReq.couponDetailModels = new List<ErpCouponReqDto.CouponDetailModel>();

        //   Set<Id> voucherIdsForCallback = new Set<Id>();

        //   for (Voucher v : issued) {
        //     String couponManNo = v.VoucherDefinition.CouponManNo__c;
        //     String memberNo = v.LoyaltyProgramMember.Contact.MemberNo__c;
        //     String voucherCode = v.VoucherCode;

        //     if (String.isBlank(couponManNo) || String.isBlank(memberNo)) {
        //       failMsgs.add('ERP mapping missing. voucherId=' + v.Id);
        //       continue;
        //     }

        //     couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(couponManNo, voucherCode, memberNo, UserInfo.getName()));

        //     // 최종 성공은 "Voucher 재조회 성공" 기준으로 member 집계
        //     successIds.add((String) v.LoyaltyProgramMemberId);
        //     voucherIdsForCallback.add(v.Id);
        //   }

        //   if (couponIssueReq.couponDetailModels != null && !couponIssueReq.couponDetailModels.isEmpty()) {
        //     System.enqueueJob(
        //       new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIdsForCallback)
        //     );
        //   }
        // }
      }

      // member 단위 성공/실패 정리
      failIds.removeAll(successIds);

      Boolean hasAnyFail = !failIds.isEmpty() || loyaltyFailCnt > 0;
      Boolean hasAnySuccess = !successIds.isEmpty();

      if (hasAnyFail && hasAnySuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasAnyFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'chunkSize=' +
          lmtList.size() +
          ', journalSuccess=' +
          journalSuccessMemberIdSet.size() +
          ', voucherSuccess=' +
          successIds.size() +
          ', journalFail=' +
          failIds.size() +
          ', loyaltyFailCnt=' +
          loyaltyFailCnt
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      if (!successIds.isEmpty()) {
        logger.setSuccessRecordIds(successIds);
      }
      if (!failIds.isEmpty()) {
        logger.setFailedRecordIds(failIds);
      }
      if (!failMsgs.isEmpty()) {
        logger.setErrorMessage(String.join(failMsgs, ' | '));
      }

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  public void finish(Database.BatchableContext bc) {
    totalFail.removeAll(totalSuccess);

    Integer successCnt = totalSuccess.size();
    Integer failCnt = totalFail.size();

    String status;
    SchedulerNotificationPublisher.ResultStatus notifStatus;

    if (failCnt > 0 && successCnt > 0) {
      status = 'PARTIAL';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.PARTIAL;
    } else if (failCnt > 0) {
      status = 'ERROR';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.ERROR;
    } else {
      status = 'SUCCESS';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.SUCCESS;
    }

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(BirthdayCouponIssueBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();

    String msg = 'Status=' + status + ', success=' + successCnt + ', fail=' + failCnt + ', jobId=' + bc.getJobId();
    SchedulerNotificationPublisher.publishResult('BirthdayCouponIssueBatch', notifStatus, msg, bc.getJobId(), null);
  }

  private static void normalizeIssuedUpgradeVouchers(Set<Id> issuedVoucherIds) {
    if (issuedVoucherIds == null || issuedVoucherIds.isEmpty()) {
      return;
    }

    List<Voucher> upgradeVoucherList = [
      SELECT Id, FaceValue, VoucherDefinition.IsUpgrade__c
      FROM Voucher
      WHERE Id IN :issuedVoucherIds AND VoucherDefinition.IsUpgrade__c = TRUE
    ];

    for (Voucher voucher : upgradeVoucherList) {
      voucher.FaceValue = 0;
    }

    if (!upgradeVoucherList.isEmpty()) {
      update upgradeVoucherList;
    }
  }
}