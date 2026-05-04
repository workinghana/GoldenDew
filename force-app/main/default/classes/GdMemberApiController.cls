//@RestResource(urlMapping='/gd/member')
global with sharing class GdMemberApiController {
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
  //@HttpPost
  global static void createMember() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
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

      // Voucher, TransactionJournal insert
      ApiResult voucherResult = getVoucherService().issueSignupCoupon(reqData);
      resData.put('CouponList', voucherResult.data.get('CouponList'));

      ApiResult result = ApiResult.ok(200, '회원 등록 성공.', resData);

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }

  /**
   * 회원 수정
   * Contact update
   */
  //@HttpPatch
  global static void updateMember() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
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

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }

  /**
   * 회원 탈퇴
   * Contact update
   * LoyaltyProgramMember update
   */
  //@HttpPut
  global static void inactiveMember() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(500, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Contact update
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      List<Contact> cList = [SELECT Id, Email FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
      if (cList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }
      Contact c = cList[0];
      if (String.isNotBlank(c.Email)) {
        c.Email = 'del_' + DateTime.now().format('yyyyMMdd_HHmmss') + '_' + c.Email;
      }
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
      lpm.MembershipEndDate = System.today();
      lpm.MemberStatus = 'Inactive';
      Database.SaveResult lpmResult = Database.update(lpm);
      if (!lpmResult.isSuccess()) {
        Database.Error err = lpmResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      //회원 탈퇴 시, 포인트 소멸
      Id anyCurrencySubTypeId = [
        SELECT Id
        FROM LoyaltyPgmCurrencySubtype
        LIMIT 1
      ]
      .Id;

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT Id, PointsBalance, LoyaltyProgramCurrencyId
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :lpm.Id
      ];

      List<LoyaltyAggrSubPointExprLedger__c> expireLedgers = new List<LoyaltyAggrSubPointExprLedger__c>();

      for (LoyaltyMemberCurrency lmc : lmcList) {
        if (lmc.PointsBalance <= 0)
          continue;

        expireLedgers.add(
          new LoyaltyAggrSubPointExprLedger__c(
            LoyaltyProgramMemberId__c = lpm.Id,
            LoyaltyProgramCurrencyId__c = lmc.LoyaltyProgramCurrencyId,
            CurrencySubTypeId__c = anyCurrencySubTypeId,
            ExpiryDate__c = System.today(),
            isExpired__c = true,
            ExpiredPoints__c = lmc.PointsBalance
          )
        );
      }
      insert expireLedgers;

      //회원 탈퇴 시,쿠폰 소멸

      List<Voucher> vouchersToExpire = [
        SELECT Id, Status
        FROM Voucher
        WHERE LoyaltyProgramMemberId = :lpm.Id AND Status IN ('Issued', 'Reserved')
      ];

      for (Voucher v : vouchersToExpire) {
        v.Status = 'Expired';
        // v.ExpiredResult__c = '만료 성공';
        v.Reason = '회원 탈퇴로 인한 쿠폰 소멸';
        v.ExpirationDate = System.today();
      }

      if (!vouchersToExpire.isEmpty()) {
        update vouchersToExpire;
      }

      ApiResult result = ApiResult.ok(200, '회원 탈퇴 성공.', reqData);

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }
}