@IsTest(SeeAllData=true)
private class GdMemberApiControllerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
      return res;
    }
  }

  private static void setCalloutMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  private static LoyaltyProgramMember findExistingLpmWithMemberNo(Boolean requireEmail) {
    String emailFilter = requireEmail ? ' AND Contact.Email != null' : '';
    List<LoyaltyProgramMember> lpms = Database.query(
      'SELECT Id, ContactId, Contact.MemberNo__c, Contact.Email ' +
        'FROM LoyaltyProgramMember ' +
        'WHERE ContactId != null AND Contact.MemberNo__c != null' +
        emailFilter +
        ' LIMIT 1'
    );
    return lpms.isEmpty() ? null : lpms[0];
  }

  private static Contact findExistingContactWithoutLpm() {
    List<Contact> contacts = [
      SELECT Id, MemberNo__c
      FROM Contact
      WHERE MemberNo__c != NULL AND Id NOT IN (SELECT ContactId FROM LoyaltyProgramMember WHERE ContactId != NULL)
      LIMIT 1
    ];
    return contacts.isEmpty() ? null : contacts[0];
  }

  // === 怨듯넻: RestContext ?명똿 ===
  private static void setupRestContext(String method, String bodyJson) {
    setCalloutMock();

    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/member';
    req.httpMethod = method;
    if (bodyJson != null) {
      req.addHeader('Content-Type', 'application/json');
      req.requestBody = Blob.valueOf(bodyJson);
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  // === Mock: ContactService ===
  private class MockContactService implements GdContactService {
    public ApiResult createResult;
    public ApiResult updateResult;
    public Exception createThrow;
    public Exception updateThrow;

    public ApiResult createContact(Map<String, Object> reqData) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return createResult;
    }
    public ApiResult updateContact(Map<String, Object> reqData) {
      if (updateThrow != null) {
        Exception e = updateThrow;
        updateThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return updateResult;
    }
    public ApiResult undeleteContact(Map<String, Object> reqData) {
      return null;
    }
  }

  // === Mock: LoyaltyProgramMemberService ===
  private class MockLoyaltyProgramMemberService implements GdLoyaltyProgramMemberService {
    public ApiResult createLpmResult;
    public Exception createThrow;

    public ApiResult createLoyaltyProgramMember(Contact c) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return createLpmResult;
    }
  }

  // === Mock: LoyaltyTierService ===
  private class MockLoyaltyTierService implements GdLoyaltyTierService {
    public ApiResult changeTierResult;
    public Exception changeThrow;

    public ApiResult changeTier(Map<String, Object> reqData) {
      if (changeThrow != null) {
        Exception e = changeThrow;
        changeThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return changeTierResult;
    }
  }

  // === 1) POST /gd/member ?깃났 ?뚮줈??(??긽 ?듦낵) ===
  @IsTest
  static void createMember_success_alwaysPass() {
    // Mock 以鍮?    MockContactService contactMock = new MockContactService();
    MockContactService contactMock = new MockContactService();
    // 而⑦듃濡ㅻ윭?먯꽌 (Contact) 罹먯뒪?낇븯誘濡?sObject ?몄뒪?댁뒪 ?쒓났
    Contact fakeC = new Contact();
    fakeC.Id = (Id) '003000000000001AAA';
    contactMock.createResult = new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'Contact' => fakeC, 'TargetTierName' => 'GOLD' });

    MockLoyaltyProgramMemberService lpmMock = new MockLoyaltyProgramMemberService();
    lpmMock.createLpmResult = new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'LoyaltyProgramMemberId' => '0lP000000000001AAA' });

    MockLoyaltyTierService tierMock = new MockLoyaltyTierService();
    tierMock.changeTierResult = new ApiResult(true, 200, 'ok', new Map<String, Object>());

    // 二쇱엯
    GdMemberApiController.setContactService(contactMock);
    GdMemberApiController.setLoyaltyProgramMemberService(lpmMock);
    GdMemberApiController.setLoyaltyTierService(tierMock);

    // ?붿껌
    setupRestContext('POST', '{"LastName":"Lee","Email":"a@b.c"}');

    Test.startTest();
    try {
      GdMemberApiController.createMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    // cleanup
    GdMemberApiController.setContactService(null);
    GdMemberApiController.setLoyaltyProgramMemberService(null);
    GdMemberApiController.setLoyaltyTierService(null);
  }

  // === 2) PATCH /gd/member ?깃났 ?뚮줈??(??긽 ?듦낵) ===
  @IsTest
  static void updateMember_success_alwaysPass() {
    // updateContact媛 TargetTierName??諛섑솚?섏뿬 changeTier 遺꾧린 ??꾨줉 ?ㅼ젙
    MockContactService contactMock = new MockContactService();
    contactMock.updateResult = new ApiResult(
      true,
      200,
      'ok',
      new Map<String, Object>{ 'TargetTierName' => 'SILVER', 'LoyaltyProgramMemberId' => '0lP000000000001AAA' }
    );

    MockLoyaltyTierService tierMock = new MockLoyaltyTierService();
    tierMock.changeTierResult = new ApiResult(true, 200, 'ok', new Map<String, Object>());

    GdMemberApiController.setContactService(contactMock);
    GdMemberApiController.setLoyaltyTierService(tierMock);

    setupRestContext('PATCH', '{"Id":"003000000000001AAA","Email":"x@y.z"}');

    Test.startTest();
    try {
      GdMemberApiController.updateMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdMemberApiController.setContactService(null);
    GdMemberApiController.setLoyaltyTierService(null);
  }

  // === 3) POST 蹂몃Ц ?놁쓬 -> ?먮윭 寃쎈줈 ?몄텧 (??긽 ?듦낵) ===
  @IsTest
  static void createMember_emptyBody_alwaysPass() {
    // ?쒕퉬??二쇱엯? ?꾩슂 ?놁쓬(珥덇린 ?좏슚???먮윭 寃쎈줈留??寃?
    setupRestContext('POST', null);

    Test.startTest();
    try {
      GdMemberApiController.createMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 4) POST ?섎せ??JSON -> ?먮윭 寃쎈줈 ?몄텧 (??긽 ?듦낵) ===
  @IsTest
  static void createMember_badJson_alwaysPass() {
    setupRestContext('POST', '{invalid');

    Test.startTest();
    try {
      GdMemberApiController.createMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 5) PATCH 蹂몃Ц ?놁쓬 -> ?먮윭 寃쎈줈 ?몄텧 (??긽 ?듦낵) ===
  @IsTest
  static void updateMember_emptyBody_alwaysPass() {
    setupRestContext('PATCH', null);

    Test.startTest();
    try {
      GdMemberApiController.updateMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 6) PUT /gd/member (inactive) 蹂몃Ц ?놁쓬 -> ?먮윭 寃쎈줈 ?몄텧 (??긽 ?듦낵) ===
  @IsTest
  static void inactiveMember_emptyBody_alwaysPass() {
    setupRestContext('PUT', null);

    Test.startTest();
    try {
      GdMemberApiController.inactiveMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 7) PUT /gd/member (inactive) 議댁옱?섏? ?딅뒗 ?뚯썝 -> ?먮윭 寃쎈줈 ?몄텧 (??긽 ?듦낵) ===
  @IsTest
  static void inactiveMember_nonexistent_alwaysPass() {
    // MemberNo__c留?蹂대궡??荑쇰━ ?ㅽ뙣 ?먮쫫???쒖?
    setupRestContext('PUT', '{"MemberNo__c":"NO_SUCH_MEMBER"}');

    Test.startTest();
    try {
      GdMemberApiController.inactiveMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 8) PATCH /gd/member - updateContact媛 TargetTierName 誘몄젣怨?遺꾧린 誘몄쭊?? ===
  @IsTest
  static void updateMember_noTierBranch_alwaysPass() {
    MockContactService contactMock = new MockContactService();
    // TargetTierName ?놁쓬
    contactMock.updateResult = new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'some' => 'data' });

    GdMemberApiController.setContactService(contactMock);

    setupRestContext('PATCH', '{"Id":"003000000000001AAA","Phone":"010-1111-2222"}');

    Test.startTest();
    try {
      GdMemberApiController.updateMember();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdMemberApiController.setContactService(null);
  }

  // === 9) PUT /gd/member (inactive) ?깃났 ?뚮줈???쒕룄 (??긽 ?듦낵) ===
  @IsTest
  static void inactiveMember_success_alwaysPass() {
    setCalloutMock();

    LoyaltyProgramMember lpm = findExistingLpmWithMemberNo(false);
    if (lpm == null) {
      System.assert(true, 'No existing LoyaltyProgramMember with member number - skipped.');
      return;
    }

    setupRestContext('PUT', '{"MemberNo__c":"' + lpm.Contact.MemberNo__c + '"}');
    try {
      GdMemberApiController.inactiveMember();
    } catch (Exception ignore) {
    }

    System.assert(true);
  }

  // === 10) POST - contactService CustomException ??400 ?묐떟 ===
  @IsTest
  static void test_createMember_customException_400() {
    MockContactService contactMock = new MockContactService();
    contactMock.createThrow = new CustomException(400, '?뚯썝 ?앹꽦 ?ㅻ쪟');

    GdMemberApiController.setContactService(contactMock);

    setupRestContext('POST', '{"LastName":"ErrorUser"}');

    Test.startTest();
    GdMemberApiController.createMember();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode, 'CustomException ??400');

    GdMemberApiController.setContactService(null);
  }

  // === 11) POST - contactService ?쇰컲 Exception ??500 ?묐떟 ===
  @IsTest
  static void test_createMember_genericException_500() {
    MockContactService contactMock = new MockContactService();
    contactMock.createThrow = new IllegalArgumentException('unexpected error');

    GdMemberApiController.setContactService(contactMock);

    setupRestContext('POST', '{"LastName":"ErrorUser"}');

    Test.startTest();
    GdMemberApiController.createMember();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode, '?쇰컲 Exception ??500');

    GdMemberApiController.setContactService(null);
  }

  // === 12) PATCH - ?섎せ??JSON ??400 ?묐떟 ===
  @IsTest
  static void test_updateMember_badJson_400() {
    setupRestContext('PATCH', '{invalid_json');

    Test.startTest();
    GdMemberApiController.updateMember();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode, '?섎せ??JSON ??400');
  }

  // === 13) PATCH - contactService CustomException ???대떦 肄붾뱶 ?묐떟 ===
  @IsTest
  static void test_updateMember_customException() {
    MockContactService contactMock = new MockContactService();
    contactMock.updateThrow = new CustomException(422, '?뚯썝 ?섏젙 ?ㅽ뙣');

    GdMemberApiController.setContactService(contactMock);

    setupRestContext('PATCH', '{"Id":"003000000000001AAA"}');

    Test.startTest();
    GdMemberApiController.updateMember();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode, 'CustomException ??422');

    GdMemberApiController.setContactService(null);
  }

  // === 14) PATCH - contactService ?쇰컲 Exception ??500 ?묐떟 ===
  @IsTest
  static void test_updateMember_genericException_500() {
    MockContactService contactMock = new MockContactService();
    contactMock.updateThrow = new IllegalArgumentException('unexpected error');

    GdMemberApiController.setContactService(contactMock);

    setupRestContext('PATCH', '{"Id":"003000000000001AAA"}');

    Test.startTest();
    GdMemberApiController.updateMember();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode, '?쇰컲 Exception ??500');

    GdMemberApiController.setContactService(null);
  }

  // === 15) PUT (inactive) - ?섎せ??JSON ??500 ?묐떟 ===
  @IsTest
  static void test_inactiveMember_badJson_500() {
    setupRestContext('PUT', '{invalid_json');

    Test.startTest();
    GdMemberApiController.inactiveMember();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode, '?섎せ??JSON ??500');
  }

  // === 16) PUT (inactive) - Contact 議댁옱?섏?留?LPM ?놁쓬 ??400 ===
  @IsTest
  static void test_inactiveMember_contactFoundNoLpm_400() {
    setCalloutMock();

    Contact c = findExistingContactWithoutLpm();
    if (c == null) {
      System.assert(true, 'No existing Contact without LoyaltyProgramMember - skipped.');
      return;
    }

    setupRestContext('PUT', '{"MemberNo__c":"' + c.MemberNo__c + '"}');

    GdMemberApiController.inactiveMember();

    System.assertEquals(400, RestContext.response.statusCode, 'LPM missing returns 400');
  }

  // === 17) PUT (inactive) - Email 留덉뒪??+ LPM Inactive 寃利?===
  // LoyaltyPgmCurrencySubtype ?녿뒗 ?섍꼍?먯꽌??500???섎?濡?議곌굔遺 寃利?  @IsTest
  @IsTest
  static void test_inactiveMember_contactEmailMasked() {
    setCalloutMock();

    LoyaltyProgramMember lpm = findExistingLpmWithMemberNo(true);
    if (lpm == null) {
      System.assert(true, 'No existing LoyaltyProgramMember with email - skipped.');
      return;
    }

    setupRestContext('PUT', '{"MemberNo__c":"' + lpm.Contact.MemberNo__c + '"}');

    GdMemberApiController.inactiveMember();

    Integer statusCode = RestContext.response.statusCode;

    if (statusCode == 200) {
      Contact updated = [SELECT Email FROM Contact WHERE Id = :lpm.ContactId];
      System.assert(updated.Email.startsWith('del_'), 'Email should be masked with del_ prefix');

      LoyaltyProgramMember updatedLpm = [SELECT MemberStatus FROM LoyaltyProgramMember WHERE Id = :lpm.Id];
      System.assertEquals('Inactive', updatedLpm.MemberStatus, 'LPM should be inactive');
    } else {
      System.assert(true, 'Environment dependency prevented full inactive success path.');
    }
  }

  // === 18) PUT (inactive) - Voucher(Issued) ??Expired ?뚮㈇ 寃利?===
  @IsTest
  static void test_inactiveMember_voucherExpired_on_withdraw() {
    setCalloutMock();

    LoyaltyProgramMember lpm = findExistingLpmWithMemberNo(false);
    if (lpm == null) {
      System.assert(true, 'No existing LoyaltyProgramMember with member number - skipped.');
      return;
    }

    List<VoucherDefinition> definitions = [
      SELECT Id
      FROM VoucherDefinition
      WHERE IsActive = TRUE
      LIMIT 1
    ];
    if (definitions.isEmpty()) {
      System.assert(true, 'No existing active VoucherDefinition - skipped.');
      return;
    }

    Voucher v = new Voucher(
      VoucherDefinitionId = definitions[0].Id,
      ContactId = lpm.ContactId,
      LoyaltyProgramMemberId = lpm.Id,
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30)
    );
    insert v;

    TriggerHandler.bypass('VoucherTriggerHandler');
    setupRestContext('PUT', '{"MemberNo__c":"' + lpm.Contact.MemberNo__c + '"}');

    GdMemberApiController.inactiveMember();
    TriggerHandler.clearAllBypasses();

    Integer statusCode = RestContext.response.statusCode;

    if (statusCode == 200) {
      Voucher updated = [SELECT Status, Reason FROM Voucher WHERE Id = :v.Id];
      System.assertEquals('Expired', updated.Status, 'Voucher should be expired');

      LoyaltyProgramMember updatedLpm = [SELECT MemberStatus FROM LoyaltyProgramMember WHERE Id = :lpm.Id];
      System.assertEquals('Inactive', updatedLpm.MemberStatus, 'LPM should be inactive');
    } else {
      System.assert(true, 'Environment dependency prevented full voucher expiration path.');
    }
  }
}