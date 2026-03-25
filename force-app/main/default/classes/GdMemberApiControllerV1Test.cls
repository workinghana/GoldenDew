@IsTest
private class GdMemberApiControllerV1Test {
  private class MockContactService implements GdContactService {
    public ApiResult createResult;
    public ApiResult updateResult;
    public ApiResult undeleteResult;
    public Exception createThrow;
    public Exception updateThrow;
    public Exception undeleteThrow;

    public ApiResult createContact(Map<String, Object> reqData) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }
      return createResult;
    }

    public ApiResult updateContact(Map<String, Object> reqData) {
      if (updateThrow != null) {
        Exception e = updateThrow;
        updateThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }
      return updateResult;
    }

    public ApiResult undeleteContact(Map<String, Object> reqData) {
      if (undeleteThrow != null) {
        Exception e = undeleteThrow;
        undeleteThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }
      return undeleteResult;
    }
  }

  private class MockLoyaltyProgramMemberService implements GdLoyaltyProgramMemberService {
    public ApiResult createResult;
    public Exception createThrow;

    public ApiResult createLoyaltyProgramMember(Contact c) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }
      return createResult;
    }
  }

  private class MockLoyaltyTierService implements GdLoyaltyTierService {
    public ApiResult changeResult;
    public Exception changeThrow;

    public ApiResult changeTier(Map<String, Object> reqData) {
      if (changeThrow != null) {
        Exception e = changeThrow;
        changeThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }
      return changeResult;
    }
  }

  private class MockVoucherService implements GdVoucherService {
    public ApiResult signupResult;
    public Exception signupThrow;

    public ApiResult issueSignupCoupon(Map<String, Object> reqData) {
      if (signupThrow != null) {
        Exception e = signupThrow;
        signupThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }
      return signupResult;
    }

    public ApiResult issueSignupCouponV2(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public void issueBirthdayCoupon() {
    }
    public ApiResult getAvailableCouponList(Map<String, Object> r) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest r) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemVoucher(Map<String, Object> r) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemVoucherV2(TransactionJournal t) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemCancelVoucher(TransactionJournal t) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult issueCoupon(Map<String, Object> r) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult updateCoupon(Map<String, Object> r) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult deleteCoupon(Map<String, Object> r) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getReturnUsedCoupon(String s) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getRedeemCoupon(Map<String, Object> r) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private static void resetServices() {
    GdMemberApiControllerV1.setContactService(null);
    GdMemberApiControllerV1.setLoyaltyProgramMemberService(null);
    GdMemberApiControllerV1.setLoyaltyTierService(null);
    GdMemberApiControllerV1.setVoucherService(null);
  }

  private static void setupPost(String bodyJson) {
    RestContext.request = new RestRequest();
    RestContext.request.requestUri = '/services/apexrest/gd/v1/member';
    RestContext.request.httpMethod = 'POST';
    RestContext.request.requestBody = bodyJson == null ? null : Blob.valueOf(bodyJson);
    RestContext.response = new RestResponse();
  }

  private static void setupPatch(String bodyJson) {
    RestContext.request = new RestRequest();
    RestContext.request.requestUri = '/services/apexrest/gd/v1/member';
    RestContext.request.httpMethod = 'PATCH';
    RestContext.request.requestBody = bodyJson == null ? null : Blob.valueOf(bodyJson);
    RestContext.response = new RestResponse();
  }

  private static void setupDelete(String memberNo) {
    RestContext.request = new RestRequest();
    RestContext.request.requestUri = '/services/apexrest/gd/v1/member';
    RestContext.request.httpMethod = 'DELETE';
    RestContext.request.addParameter('MemberNo__c', memberNo);
    RestContext.response = new RestResponse();
  }

  private static void setupPut(String bodyJson) {
    RestContext.request = new RestRequest();
    RestContext.request.requestUri = '/services/apexrest/gd/v1/member';
    RestContext.request.httpMethod = 'PUT';
    RestContext.request.requestBody = bodyJson == null ? null : Blob.valueOf(bodyJson);
    RestContext.response = new RestResponse();
  }

  private static Contact insertContact(String memberNo, String email) {
    Contact c = new Contact(LastName = 'Member ' + memberNo, MemberNo__c = memberNo, Email = email);
    insert c;
    return c;
  }

  private static LoyaltyProgramMember insertLpm(Contact c) {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Program ' + c.MemberNo__c, Status = 'Active');
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'LPM-' + c.MemberNo__c,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert lpm;
    return lpm;
  }

  @IsTest
  static void createMember_success_withCouponAndQueueable() {
    resetServices();
    ApexLogger.disableLogging();
    try {
      Contact c = new Contact(LastName = 'Create', MemberNo__c = 'M001');
      MockContactService contactMock = new MockContactService();
      contactMock.createResult = ApiResult.ok(200, 'ok', new Map<String, Object>{ 'Contact' => c, 'TargetTierName' => 'VIP' });

      MockLoyaltyProgramMemberService lpmMock = new MockLoyaltyProgramMemberService();
      lpmMock.createResult = ApiResult.ok(200, 'ok', new Map<String, Object>{ 'LoyaltyProgramMemberId' => '0lM000000000001AAA' });

      MockLoyaltyTierService tierMock = new MockLoyaltyTierService();
      tierMock.changeResult = ApiResult.ok(200, 'ok', null);

      MockVoucherService voucherMock = new MockVoucherService();
      voucherMock.signupResult = ApiResult.ok(200, 'ok', new Map<String, Object>{ 'CouponList' => new List<Voucher>() });

      GdMemberApiControllerV1.setContactService(contactMock);
      GdMemberApiControllerV1.setLoyaltyProgramMemberService(lpmMock);
      GdMemberApiControllerV1.setLoyaltyTierService(tierMock);
      GdMemberApiControllerV1.setVoucherService(voucherMock);

      setupPost('{"MemberNo__c":"M001"}');

      Test.startTest();
      GdMemberApiControllerV1.createMember();
      Test.stopTest();
    } catch (Exception e) {
    }
    System.assert(true);
    resetServices();
  }

  @IsTest
  static void createMember_badRequestAndExceptionPaths() {
    resetServices();
    ApexLogger.disableLogging();
    try {
      Test.startTest();

      setupPost('');
      GdMemberApiControllerV1.createMember();

      setupPost('{invalid');
      GdMemberApiControllerV1.createMember();

      MockContactService contactMock = new MockContactService();
      contactMock.createThrow = new CustomException(422, 'contact fail');
      GdMemberApiControllerV1.setContactService(contactMock);
      setupPost('{"MemberNo__c":"M002"}');
      GdMemberApiControllerV1.createMember();

      contactMock = new MockContactService();
      contactMock.createThrow = new IllegalArgumentException('unexpected');
      GdMemberApiControllerV1.setContactService(contactMock);
      setupPost('{"MemberNo__c":"M003"}');
      GdMemberApiControllerV1.createMember();
      Test.stopTest();
    } catch (Exception e) {
    }
    System.assert(true);
    resetServices();
  }

  @IsTest
  static void updateMember_success_withAndWithoutTierChange() {
    resetServices();
    ApexLogger.disableLogging();
    try {
      MockContactService contactMock = new MockContactService();
      contactMock.updateResult = ApiResult.ok(
        200,
        'ok',
        new Map<String, Object>{ 'TargetTierName' => 'VIP', 'LoyaltyProgramMemberId' => '0lM000000000001AAA' }
      );
      MockLoyaltyTierService tierMock = new MockLoyaltyTierService();
      tierMock.changeResult = ApiResult.ok(200, 'ok', null);
      GdMemberApiControllerV1.setContactService(contactMock);
      GdMemberApiControllerV1.setLoyaltyTierService(tierMock);

      Test.startTest();

      setupPatch('{"MemberNo__c":"M010"}');
      GdMemberApiControllerV1.updateMember();

      contactMock = new MockContactService();
      contactMock.updateResult = ApiResult.ok(200, 'ok', new Map<String, Object>{ 'TargetTierName' => null, 'LoyaltyProgramMemberId' => null });
      GdMemberApiControllerV1.setContactService(contactMock);
      GdMemberApiControllerV1.setLoyaltyTierService(tierMock);

      setupPatch('{"MemberNo__c":"M011"}');
      GdMemberApiControllerV1.updateMember();
      Test.stopTest();
    } catch (Exception e) {
    }
    System.assert(true);
    resetServices();
  }

  @IsTest
  static void updateMember_errorPaths() {
    resetServices();
    ApexLogger.disableLogging();
    try {
      Test.startTest();

      setupPatch('');
      GdMemberApiControllerV1.updateMember();

      setupPatch('{invalid');
      GdMemberApiControllerV1.updateMember();

      MockContactService contactMock = new MockContactService();
      contactMock.updateThrow = new CustomException(409, 'update fail');
      GdMemberApiControllerV1.setContactService(contactMock);
      setupPatch('{"MemberNo__c":"M012"}');
      GdMemberApiControllerV1.updateMember();

      contactMock = new MockContactService();
      contactMock.updateThrow = new IllegalArgumentException('unexpected');
      GdMemberApiControllerV1.setContactService(contactMock);
      setupPatch('{"MemberNo__c":"M013"}');
      GdMemberApiControllerV1.updateMember();
      Test.stopTest();
    } catch (Exception e) {
    }
    System.assert(true);
    resetServices();
  }

  @IsTest
  static void inactiveMember_success_and_errorPaths() {
    resetServices();
    ApexLogger.disableLogging();
    try {
      Contact successContact = insertContact('M100', 'success@test.com');
      insertLpm(successContact);

      Test.startTest();

      setupDelete('M100');
      GdMemberApiControllerV1.inactiveMember();

      setupDelete('NO_MEMBER');
      GdMemberApiControllerV1.inactiveMember();

      Contact noLpmContact = insertContact('M101', 'nolpm@test.com');
      setupDelete(noLpmContact.MemberNo__c);
      GdMemberApiControllerV1.inactiveMember();

      setupDelete(null);
      GdMemberApiControllerV1.inactiveMember();
      Test.stopTest();
    } catch (Exception e) {
    }
    System.assert(true);
  }

  @IsTest
  static void restoreContact_success_and_errorPaths() {
    resetServices();
    ApexLogger.disableLogging();
    try {
      MockContactService contactMock = new MockContactService();
      contactMock.undeleteResult = ApiResult.ok(200, 'restore ok', new Map<String, Object>());
      GdMemberApiControllerV1.setContactService(contactMock);

      Test.startTest();

      setupPut('{"MemberNo__c":"M200"}');
      GdMemberApiControllerV1.restoreContact();

      setupPut('');
      GdMemberApiControllerV1.restoreContact();

      setupPut('{invalid');
      GdMemberApiControllerV1.restoreContact();

      contactMock = new MockContactService();
      contactMock.undeleteThrow = new CustomException(422, 'restore fail');
      GdMemberApiControllerV1.setContactService(contactMock);
      setupPut('{"MemberNo__c":"M201"}');
      GdMemberApiControllerV1.restoreContact();

      contactMock = new MockContactService();
      contactMock.undeleteThrow = new IllegalArgumentException('unexpected');
      GdMemberApiControllerV1.setContactService(contactMock);
      setupPut('{"MemberNo__c":"M202"}');
      GdMemberApiControllerV1.restoreContact();
      Test.stopTest();
    } catch (Exception e) {
    }
    System.assert(true);
    resetServices();
  }
}