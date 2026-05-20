@RestResource(urlMapping='/gd/v1/member')
global with sharing class GdMemberApiControllerV1 {
  private static GdContactService contactService;
  private static GdLoyaltyProgramMemberService loyaltyProgramMemberService;
  private static GdLoyaltyTierService loyaltyTierService;
  private static GdVoucherService voucherService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setContactService(GdContactService mock) {
    contactService = mock;
  }

  private static GdContactService getContactService() {
    if (contactService == null) {
      contactService = new GdContactServiceImpl();
    }
    return contactService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setLoyaltyProgramMemberService(GdLoyaltyProgramMemberService mock) {
    loyaltyProgramMemberService = mock;
  }

  private static GdLoyaltyProgramMemberService getLoyaltyProgramMemberService() {
    if (loyaltyProgramMemberService == null) {
      loyaltyProgramMemberService = new GdLoyaltyProgramMemberServiceImpl();
    }
    return loyaltyProgramMemberService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setLoyaltyTierService(GdLoyaltyTierService mock) {
    loyaltyTierService = mock;
  }

  private static GdLoyaltyTierService getLoyaltyTierService() {
    if (loyaltyTierService == null) {
      loyaltyTierService = new GdLoyaltyTierServiceImpl();
    }
    return loyaltyTierService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  private static GdVoucherService getVoucherService() {
    if (voucherService == null) {
      voucherService = new GdVoucherServiceImpl();
    }
    return voucherService;
  }

  /**
   * 회원 생성
   * Contact insert
   * LoyaltyProgramMember insert
   */
  @HttpPost
  global static void createMember() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdMemberApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        // 에러 로그 설정
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
        // 에러 로그 설정
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());

        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Contact insert
      ApiResult contactResult = getContactService().createContact(reqData);
      Contact c = (Contact) contactResult.data.get('Contact');
      reqData.put('TargetTierName', contactResult.data.get('TargetTierName'));

      // LoyaltyProgramMember insert
      ApiResult loyaltyProgramMemberResult = getLoyaltyProgramMemberService().createLoyaltyProgramMember(c);
      reqData.put('LoyaltyProgramMemberId', loyaltyProgramMemberResult.data.get('LoyaltyProgramMemberId'));
      reqData.put('ChangeReason', '회원 등록');

      // LoyaltyTier insert
      ApiResult loyaltyTierResult = getLoyaltyTierService().changeTier(reqData);

      // [수정 전 - 무조건 쿠폰 발급]
      // // 로열티 쿠폰 생성
      // // Voucher, TransactionJournal insert
      // ❌ SMS동의 여부 무시하고 무조건 발급
      // ApiResult voucherResult = getVoucherService().issueSignupCoupon(reqData);
      //
      // if (voucherResult != null) {
      //   // 쿠폰 개별 지급 비동기 처리 큐에 등록
      //   List<Voucher> couponList = (List<Voucher>) voucherResult.data.get('CouponList');
      //   if (couponList != null && !couponList.isEmpty()) {
      //     ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
      //     for (Voucher coupon : couponList) {
      //       couponIssueReq.couponDetailModels.add(
      //         new ErpCouponReqDto.CouponDetailModel(coupon.VoucherDefinition.CouponManNo__c, coupon.VoucherCode, c.MemberNo__c, UserInfo.getName())
      //       );
      //       System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), coupon.Id));
      //     }
      //   }
      // }

      // [수정 후 - 2026-04-09 by wina]
      // ✅ SMS동의 여부 확인 후 조건부 쿠폰 발급
      if (c.IsSMSAgreed__c) {
        // 로열티 쿠폰 생성 (SMS 동의한 회원만)
        // Voucher, TransactionJournal insert
        ApiResult voucherResult = getVoucherService().issueSignupCoupon(reqData);

        /*
        ! 쿠폰 동기화 하지 않음으로 ERP API 호출하지 않는다.
        if (voucherResult != null) {
          // 쿠폰 개별 지급 비동기 처리 큐에 등록
          List<Voucher> couponList = (List<Voucher>) voucherResult.data.get('CouponList');
          if (couponList != null && !couponList.isEmpty()) {
            ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
            Set<Id> couponIds = new Set<Id>();
            for (Voucher coupon : couponList) {
              couponIssueReq.couponDetailModels.add(
                new ErpCouponReqDto.CouponDetailModel(coupon.VoucherDefinition.CouponManNo__c, coupon.VoucherCode, c.MemberNo__c, UserInfo.getName())
              );
              couponIds.add(coupon.Id);
            }
            System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), couponIds));
          }
        }
        */
      } else {
        // SMS 미동의: 쿠폰 발급 스킵
      }

      ApiResult result = ApiResult.ok(200, '회원 등록 성공.', resData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
  }

  /**
   * 회원 수정
   * Contact update
   */
  @HttpPatch
  global static void updateMember() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdMemberApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Contact 수정
      ApiResult contactResult = getContactService().updateContact(reqData);
      if (String.isNotBlank(ValidationUtil.stringValidation(contactResult.data.get('TargetTierName'), 'TargetTierName', false))) {
        reqData.put('TargetTierName', contactResult.data.get('TargetTierName'));
        reqData.put('LoyaltyProgramMemberId', contactResult.data.get('LoyaltyProgramMemberId'));
        reqData.put('ChangeReason', '회원 수정');

        // LoyaltyTier update
        ApiResult loyaltyTierResult = getLoyaltyTierService().changeTier(reqData);
      }

      ApiResult result = ApiResult.ok(200, '회원 수정 성공.', reqData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }

  /**
   * 회원 탈퇴
   * Contact update
   * LoyaltyProgramMember update
   */
  @HttpDelete
  global static void inactiveMember() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdMemberApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Map<String, Object> resData = new Map<String, Object>();
    Savepoint sp = Database.setSavepoint();
    try {
      // String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      // logger.setRequestUrl(req.requestURI); // 요청 URL
      // logger.setRequestDatetime(Datetime.now()); // 요청 시간
      // logger.setRequestBody(raw); // 요청 본문 내용
      // if (String.isBlank(raw)) {
      //   logger.setErrorCode('BAD_REQUEST');
      //   logger.setErrorMessage('Empty body');
      //   throw new CustomException(400, '요청 본문이 비었습니다.');
      // }

      // Map<String, Object> reqData;
      // try {
      //   reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      // } catch (Exception e) {
      //   logger.setErrorCode('BAD_REQUEST');
      //   logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
      //   throw new CustomException(500, 'JSON 역직렬화 실패: ' + e.getMessage());
      // }

      // Contact update
      // String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String memberNo = ValidationUtil.stringValidationEx(req.params.get('MemberNo__c'), 'MemberNo__c', true, false);
      Date memberDropDate = resolveMemberDropDate(req.params.get('MemberDropDate__c'));

      resData.put('MemberNo__c', memberNo);
      resData.put('MemberDropDate__c', memberDropDate);

      // String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      List<Contact> cList = [SELECT Id, IsWithdrawn__c, Email, MemberDropDate__c FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
      if (cList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      Contact c = cList[0];

      if (String.isNotBlank(c.Email)) {
        c.Email = 'del_' + DateTime.now().format('yyyyMMdd_HHmmss') + '_' + c.Email;
      }
      c.IsWithdrawn__c = true;
      c.MemberDropDate__c = memberDropDate;

      Database.SaveResult cResult = Database.update(c);
      if (!cResult.isSuccess()) {
        Database.Error err = cResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      // LoyaltyProgramMember update
      List<LoyaltyProgramMember> lpmList = [SELECT Id, MembershipEndDate, MemberStatus FROM LoyaltyProgramMember WHERE ContactId = :c.Id LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '로열티 멤버이 아닙니다. ' + memberNo);
      }
      LoyaltyProgramMember lpm = lpmList[0];
      lpm.MembershipEndDate = memberDropDate;
      lpm.MemberStatus = 'Inactive';
      Database.SaveResult lpmResult = Database.update(lpm);
      if (!lpmResult.isSuccess()) {
        Database.Error err = lpmResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      // // 해당 회원이 보유한 쿠폰 만료 처리
      // List<Voucher> vList = [
      //   SELECT Id, Status
      //   FROM Voucher
      //   WHERE LoyaltyProgramMemberId = :lpmList[0].Id AND Status = 'Issued'
      // ];
      // if (!vList.isEmpty()) {
      //   for (Voucher v : vList) {
      //     v.Status = 'Expired';
      //   }
      // }
      // Database.SaveResult[] vResults = Database.update(vList);
      // if (!vResults.isEmpty()) {
      //   for (Database.SaveResult result : vResults) {
      //     if (!result.isSuccess()) {
      //       Database.Error err = result.getErrors()[0];
      //       throw new CustomException(400, err.getMessage());
      //     }
      //   }
      // }

      ApiResult result = ApiResult.ok(200, '회원 탈퇴 성공.', resData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
  }

  private static Date resolveMemberDropDate(String rawMemberDropDate) {
    Date memberDropDate = ValidationUtil.dateValidation(rawMemberDropDate, 'MemberDropDate__c', false);
    return memberDropDate == null ? Date.today() : memberDropDate;
  }

  /* 회원 탈퇴 복원 */

  @HttpPut
  global static void restoreContact() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdMemberApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();

    try {
      String raw = req.requestBody == null ? null : req.requestBody.toString();

      logger.setRequestUrl(req.requestURI);
      logger.setRequestDatetime(Datetime.now());
      logger.setRequestBody(raw);

      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;

      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패');
        throw new CustomException(400, 'JSON 역직렬화 실패');
      }

      ApiResult result = getContactService().undeleteContact(reqData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }
}