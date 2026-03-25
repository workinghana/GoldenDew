public with sharing class MonthlyCouponIssueBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual'; // 저널 유형 : 포인트/쿠폰 지급
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_ISSUE = 'Coupon Issue'; // 저널 하위 유형 : 쿠폰 지급

  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  private final String VOUCHER_CATEGORY_NAME_MONTHLY_COUPON = 'MonthlyCoupon';
  private final String VOUCHER_LIMIT_TYPE_NAME_GRADE_INCLUDE_LIST = 'GradeIncludeList'; // 쿠폰 한도 Type__c 값 (사용 가능 회원 등급)

  public Database.QueryLocator start(Database.BatchableContext bc) {
    String soql =
      'SELECT LoyaltyMember.Contact.MemberNo__c, LoyaltyTierId, LoyaltyMemberId, LoyaltyMember.ProgramId, LoyaltyMember.Program.Name ' +
      'FROM LoyaltyMemberTier ' +
      'WHERE LoyaltyMemberId != NULL AND LoyaltyMember.Contact.MemberNo__c != NULL AND LoyaltyMember.MemberStatus = \'Active\'';

    return Database.getQueryLocator(soql);
  }

  public void execute(Database.BatchableContext bc, List<LoyaltyMemberTier> lmtList) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(MonthlyCouponIssueBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (lmtList == null || lmtList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      Set<String> lpmIdSet = new Set<String>();
      for (LoyaltyMemberTier lmt : lmtList) {
        lpmIdSet.add((String) lmt.LoyaltyMemberId);
      }
      logger.setScopedIds(lpmIdSet);

      // 쿠폰 카테고리 조회
      List<VoucherCategory__c> vcList = [
        SELECT Id
        FROM VoucherCategory__c
        WHERE Code__c = :VOUCHER_CATEGORY_NAME_MONTHLY_COUPON
        LIMIT 1
      ];
      if (vcList.isEmpty()) {
        for (LoyaltyMemberTier lmt : lmtList) {
          failIds.add((String) lmt.LoyaltyMemberId);
        }

        logger.setStatus('ERROR');
        logger.setErrorCode('NOT_FOUND');
        logger.setErrorMessage('VoucherCategory not found: ' + VOUCHER_CATEGORY_NAME_MONTHLY_COUPON);
        return;
      }

      // VoucherDefinition 조회
      List<VoucherDefinition> vdList = [
        SELECT Id, CouponManNo__c, Name
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

      Map<Id, Id> tierIdByMemberId = new Map<Id, Id>(); // LoyaltyProgramMemberId : LoyaltyTierId
      Map<Id, String> memberNoByMemberId = new Map<Id, String>(); // LoyaltyProgramMemberId : MemberNo__c

      for (LoyaltyMemberTier lmt : lmtList) {
        if (lmt.LoyaltyMemberId == null || lmt.LoyaltyTierId == null) {
          continue;
        }
        tierIdByMemberId.put(lmt.LoyaltyMemberId, lmt.LoyaltyTierId);
        memberNoByMemberId.put(lmt.LoyaltyMemberId, lmt.LoyaltyMember.Contact.MemberNo__c);
      }

      if (tierIdByMemberId.isEmpty()) {
        for (LoyaltyMemberTier lmt : lmtList) {
          failIds.add((String) lmt.LoyaltyMemberId);
        }
        logger.setStatus('ERROR');
        logger.setErrorCode('NO_TARGET');
        logger.setErrorMessage('No valid LoyaltyMemberTier in scope.');
        return;
      }

      // 쿠폰 한도 조회(등급 허용 리스트)
      Map<Id, VoucherDefinition> vdById = new Map<Id, VoucherDefinition>();
      Set<Id> vdIdSet = new Set<Id>(); // VoucherDefinitionId__c
      for (VoucherDefinition vd : vdList) {
        vdIdSet.add(vd.Id);
        vdById.put(vd.Id, vd);
      }

      // GradeIncludeList: (VoucherDefinitionId__c, Value__c=TierId 가정)
      List<VoucherLimit__c> vlList = [
        SELECT Id, VoucherDefinitionId__c, Value__c, Type__c, IsActive__c
        FROM VoucherLimit__c
        WHERE
          IsActive__c = TRUE
          AND Type__c = :VOUCHER_LIMIT_TYPE_NAME_GRADE_INCLUDE_LIST
          AND VoucherDefinitionId__c IN :vdIdSet
          AND VoucherDefinitionId__c != NULL
          AND Value__c != NULL
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
          allowedTierIdsByVdId.put(vl.VoucherDefinitionId__c, new Set<Id>()); // 쿠폰 Master Id로 키 설정
        }
        allowedTierIdsByVdId.get(vl.VoucherDefinitionId__c).add(tierId); // 해당 쿠폰에 티어 Id 추가
      }

      // 회원 등급에 맞는 쿠폰 지급
      // - 한도(허용등급 리스트)가 없는 쿠폰은 모두에게 지급
      // - 한도가 있는 쿠폰은 해당 tierId인 회원에게만 지급
      Map<Id, TransactionJournal> tjByMemberId = new Map<Id, TransactionJournal>();

      for (Id memberId : tierIdByMemberId.keySet()) {
        Id memberTierId = tierIdByMemberId.get(memberId);
        String memberNo = memberNoByMemberId.get(memberId);

        if (String.isBlank(memberNo)) {
          failIds.add((String) memberId);
          failMsgs.add('No MemberNo. LoyaltyMemberId=' + memberId);
          continue;
        }

        TransactionJournal tj = new TransactionJournal();
        tj.ActivityDate = Datetime.now();
        tj.JournalDate = Datetime.now();
        tj.LoyaltyProgramId = lmtList[0].LoyaltyMember.ProgramId;
        tj.MemberId = memberId;
        tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
        tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_ISSUE, true);
        tj.Status = 'Processed';

        Boolean hasEligible = false;
        for (VoucherDefinition vd : vdList) {
          Set<Id> allowed = allowedTierIdsByVdId.get(vd.Id);
          if (allowed == null || allowed.isEmpty() || allowed.contains(memberTierId)) {
            hasEligible = true;
            break;
          }
        }
        if (hasEligible) {
          tjByMemberId.put(memberId, tj);
        }
      }

      // 트랜잭션 저널 insert (부분 성공)
      List<TransactionJournal> tjList = tjByMemberId.values();
      Database.SaveResult[] tjResults = Database.insert(tjList, false);

      Set<Id> successMemberIdSet = new Set<Id>();
      Set<Id> journalSuccessMemberIdSet = new Set<Id>();

      for (Integer i = 0; i < tjResults.size(); i++) {
        TransactionJournal tj = tjList[i];
        Database.SaveResult sr = tjResults[i];

        if (sr.isSuccess()) {
          successMemberIdSet.add(tj.MemberId);
          journalSuccessMemberIdSet.add(tj.MemberId);
        } else {
          failIds.add((String) tj.MemberId);

          // 트랜잭션 저널 insert 실패 건 Log 기록
          for (Database.Error err : sr.getErrors()) {
            failMsgs.add('Journal insert failed. memberId=' + tj.MemberId + ', msg=' + err.getMessage());
          }
        }
      }

      // 성공한 트랜잭선 저널만 로열티 쿠폰 지급
      List<Map<String, Object>> voucherIssueReqList = new List<Map<String, Object>>();

      for (Id memberId : successMemberIdSet) {
        Id memberTierId = tierIdByMemberId.get(memberId);
        String memberNo = memberNoByMemberId.get(memberId);
        TransactionJournal tj = tjByMemberId.get(memberId);

        for (VoucherDefinition vd : vdList) {
          Set<Id> allowedTierIds = allowedTierIdsByVdId.get(vd.Id);

          Boolean eligible = (allowedTierIds == null || allowedTierIds.isEmpty()) || allowedTierIds.contains(memberTierId);
          // 등급 조건이 없는 쿠폰이거나 해당 멤버의 등급이 쿠폰 등급 조건에 해당하는 쿠폰이 존재할 경우 True

          if (!eligible) {
            // 지급 할 쿠폰이 없을 경우 continue
            continue;
          }

          voucherIssueReqList.add(
            new Map<String, Object>{
              'loyaltyProgramMemberId' => memberId,
              'programName' => lmtList[0].LoyaltyMember.Program.Name,
              'voucherDefinitionName' => vd.Name,
              'journalId' => tj.Id
            }
          );
        }
      }

      Integer loyaltyFailCnt = 0;

      if (!voucherIssueReqList.isEmpty()) {
        // 로열티 쿠폰 지급
        List<LoyaltyManagement.IssueVoucherOutput> resList = LoyaltyVoucherService.issueVoucherV2(voucherIssueReqList);

        Set<Id> issuedVoucherIdSet = new Set<Id>();

        for (LoyaltyManagement.IssueVoucherOutput res : resList) {
          // 로열티 쿠폰 지급 실패 케이스
          if (!res.isSuccess()) {
            loyaltyFailCnt++;

            String errMsg = 'Voucher issue failed.';

            if (!String.isBlank(res.getErrors().get(0).getCode())) {
              errMsg += ', errorCode=' + res.getErrors().get(0).getCode();
            }
            if (!String.isBlank(res.getErrors().get(0).getMessage())) {
              errMsg += ', errorMessage=' + res.getErrors().get(0).getMessage();
            }
            failMsgs.add(errMsg);

            continue; // 실패 건은 ERP 지급 X
          }

          // 로열티 쿠폰 발급 성공한 건들 담기
          String vid = res.getVoucherId();
          if (!String.isBlank(vid)) {
            try {
              issuedVoucherIdSet.add((Id) vid);
            } catch (Exception ex) {
              failMsgs.add('Invalid voucherId returned: ' + vid);
            }
          }
        }

        List<Voucher> loyaltyIssuedVouchers = [
          SELECT Id, LoyaltyProgramMember.Contact.MemberNo__c, VoucherDefinition.CouponManNo__c, VoucherCode
          FROM Voucher
          WHERE Id IN :issuedVoucherIdSet
        ];

        ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
        couponIssueReq.couponDetailModels = new List<ErpCouponReqDto.CouponDetailModel>();

        Set<Id> voucherIds = new Set<Id>();
        for (Voucher v : loyaltyIssuedVouchers) {
          String couponManNo = v.VoucherDefinition.CouponManNo__c != null ? v.VoucherDefinition.CouponManNo__c : null;
          String memberNo = (v.LoyaltyProgramMember.Contact.MemberNo__c != null) ? v.LoyaltyProgramMember.Contact.MemberNo__c : null;
          String voucherCode = v.VoucherCode;

          if (String.isBlank(couponManNo) || String.isBlank(memberNo)) {
            failMsgs.add('ERP mapping missing. voucherId=' + v.Id);
            continue;
          }

          couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(couponManNo, voucherCode, memberNo, UserInfo.getName()));

          successIds.add((String) v.LoyaltyProgramMemberId);

          voucherIds.add(v.Id);
        }

        if (couponIssueReq.couponDetailModels != null && !couponIssueReq.couponDetailModels.isEmpty()) {
          // ERP 쿠폰 지급 API 비동기 호출 (execute 트랜잭션당 1회만 enqueue)

          System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIds));
        }
      }

      // 성공한 건은 실패 목록에서 제거
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
    logger.logging(MonthlyCouponIssueBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();

    String msg = 'Status=' + status + ', success=' + successCnt + ', fail=' + failCnt + ', jobId=' + bc.getJobId();
    SchedulerNotificationPublisher.publishResult('MonthlyCouponIssueBatch', notifStatus, msg, bc.getJobId(), null);
  }
}