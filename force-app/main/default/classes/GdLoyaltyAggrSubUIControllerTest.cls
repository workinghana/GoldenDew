@IsTest
private class GdLoyaltyAggrSubUIControllerTest {
  private class McCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result":"ok"}');
      return res;
    }
  }

  /* ===============================
       테스트 데이터 생성
       =============================== */
  private static Id createMemberWithLedgers() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());
    Contact c = new Contact(LastName = 'PointTester', MemberNo__c = 'M' + String.valueOf(System.now().getTime()));
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Point Program ' + String.valueOf(System.now().getTime()), IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'LPM-' + String.valueOf(System.now().getTime()),
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert lpm;

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      Name = '기본 포인트',
      LoyaltyProgramId = lp.Id,
      CurrencyType = 'NonQualifying',
      IsActive = true,
      ExpiryPeriodFrequency = 2,
      ExpiryModel = 'Fixed',
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert lpc;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      Name = '일반 구매 적립',
      LoyaltyProgramCurrencyId = lpc.Id,
      IsActive = true,
      UsagePriorityNumber = 1,
      PointTypeCode__c = '01'
    );
    insert subtype;

    /* Ledger 1 */
    LoyaltyAggrSubPointExprLedger__c ledger1 = new LoyaltyAggrSubPointExprLedger__c(
      LoyaltyProgramMemberId__c = lpm.Id,
      CurrencySubTypeName__c = '기본 포인트',
      CurrencySubTypeId__c = subtype.Id,
      AccruedPoints__c = 1000,
      RedeemedPoints__c = 300,
      ExpiredPoints__c = 100,
      ExpiryDate__c = Date.today().addDays(10)
    );

    /* Ledger 2 */
    LoyaltyAggrSubPointExprLedger__c ledger2 = new LoyaltyAggrSubPointExprLedger__c(
      LoyaltyProgramMemberId__c = lpm.Id,
      CurrencySubTypeName__c = '이벤트 포인트',
      CurrencySubTypeId__c = subtype.Id,
      AccruedPoints__c = 500,
      RedeemedPoints__c = 200,
      ExpiredPoints__c = 0,
      ExpiryDate__c = Date.today().addDays(30)
    );

    insert new List<LoyaltyAggrSubPointExprLedger__c>{ ledger1, ledger2 };

    return lpm.Id;
  }

  /* ===============================
       null 파라미터 테스트
       =============================== */
  @IsTest
  static void getPointDetails_nullId_returnsEmpty() {
    Test.startTest();
    List<GdLoyaltyAggrSubUIController.PointDetailDTO> result = GdLoyaltyAggrSubUIController.getPointDetails(null);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(0, result.size());
  }

  /* ===============================
       Ledger 없는 회원 테스트
       =============================== */
  @IsTest
  static void getPointDetails_memberWithoutLedger() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());
    Contact c = new Contact(LastName = 'NoLedger', MemberNo__c = 'N' + System.now().getTime());
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'NoLedgerProgram', IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'NOLEDGER',
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert lpm;

    Test.startTest();
    List<GdLoyaltyAggrSubUIController.PointDetailDTO> result = GdLoyaltyAggrSubUIController.getPointDetails(lpm.Id);
    Test.stopTest();

    System.assertEquals(0, result.size());
  }

  /* ===============================
       정상 Ledger 매핑 테스트
       =============================== */
  @IsTest
  static void getPointDetails_mapsLedgerCorrectly() {
    Id lpmId = createMemberWithLedgers();

    Test.startTest();
    List<GdLoyaltyAggrSubUIController.PointDetailDTO> result = GdLoyaltyAggrSubUIController.getPointDetails(lpmId);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(2, result.size());

    /* ExpiryDate 오름차순 확인 */
    GdLoyaltyAggrSubUIController.PointDetailDTO first = result[0];

    System.assertEquals('기본 포인트', first.pointTypeName);
    System.assertEquals(1000, first.accruedPoints);
    System.assertEquals(300, first.usedPoints);
    System.assertEquals(100, first.expiredPoints);

    /* remaining 계산 */
    System.assertEquals(600, first.remainingPoints);

    System.assertNotEquals(null, first.ledgerId);
    System.assertEquals(Date.today().addDays(10), first.expirationDate);

    GdLoyaltyAggrSubUIController.PointDetailDTO second = result[1];

    System.assertEquals('이벤트 포인트', second.pointTypeName);
    System.assertEquals(500, second.accruedPoints);
    System.assertEquals(200, second.usedPoints);
    System.assertEquals(0, second.expiredPoints);

    System.assertEquals(300, second.remainingPoints);

    System.assertNotEquals(null, second.ledgerId);
    System.assertEquals(Date.today().addDays(30), second.expirationDate);
  }
}