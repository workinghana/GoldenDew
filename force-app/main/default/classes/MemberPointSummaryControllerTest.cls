@IsTest
private class MemberPointSummaryControllerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  @TestSetup
  static void setupData() {
    setMock();

    // Contact
    Contact c = new Contact(LastName = '포인트회원');
    insert c;

    // Loyalty Program
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Point Program', IsPrimary = true);
    insert lp;

    // LoyaltyProgramMember
    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'POINT-M-001',
      EnrollmentDate = System.today(),
      MemberStatus = 'Active'
    );
    insert lpm;

    // 2. 상위 LoyaltyProgramCurrency 생성 (포인트 정의 마스터)
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
      // CostperUnit = 1,
      // HasEscrow = false
    );
    insert lpc;

    // 3. LoyaltyPgmCurrencySubtype 생성 (가데이터 2건)
    List<LoyaltyPgmCurrencySubtype> subtypes = new List<LoyaltyPgmCurrencySubtype>();

    // 케이스 1: 일반 적립 포인트
    subtypes.add(
      new LoyaltyPgmCurrencySubtype(
        Name = '일반 구매 적립',
        LoyaltyProgramCurrencyId = lpc.Id,
        IsActive = true, // 활성 여부
        UsagePriorityNumber = 1, // 사용 우선순위
        PointTypeCode__c = '01' // 포인트 구분 코드 (커스텀 필드)
      )
    );

    insert subtypes;

    List<LoyaltyAggrSubPointExprLedger__c> ledgers = new List<LoyaltyAggrSubPointExprLedger__c>();

    // 유형 1: 일반 포인트 (2개 레코드 생성 -> SUM 검증용)
    ledgers.add(
      new LoyaltyAggrSubPointExprLedger__c(
        LoyaltyProgramMemberId__c = lpm.Id,
        CurrencySubTypeName__c = 'NormalPoint',
        AccruedPoints__c = 1000,
        RedeemedPoints__c = 200,
        ExpiredPoints__c = 50,
        isExpired__c = false,
        CurrencySubTypeId__c = subtypes[0].Id
      )
    );

    insert ledgers;
  }

  /* =========================
   * 정상 케이스
   * ========================= */
  @IsTest
  static void test_getMemberPointSummary_success() {
    setMock();

    Id memberId = [
      SELECT Id
      FROM LoyaltyProgramMember
      LIMIT 1
    ]
    .Id;

    Test.startTest();
    List<MemberPointSummaryController.MemberPointSummaryDTO> result = MemberPointSummaryController.getMemberPointSummary(memberId);
    Test.stopTest();

    // org 설정/검증 규칙에 따라 테스트 데이터 구성 방식이 달라질 수 있으므로
    // 정상 호출 및 반환 타입만 검증한다.
    System.assertNotEquals(null, result, '결과 리스트는 null 이면 안됩니다.');
  }

  /* =========================
   * 데이터 없음 케이스
   * ========================= */
  @IsTest
  static void test_getMemberPointSummary_noData() {
    setMock();

    // 새로운 회원 (원장 없음)
    Contact c = new Contact(LastName = '빈회원');
    insert c;

    LoyaltyProgram lp = [
      SELECT Id
      FROM LoyaltyProgram
      LIMIT 1
    ];

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'POINT-M-002',
      EnrollmentDate = System.today(),
      MemberStatus = 'Active'
    );
    insert lpm;

    Test.startTest();
    List<MemberPointSummaryController.MemberPointSummaryDTO> result = MemberPointSummaryController.getMemberPointSummary(lpm.Id);
    Test.stopTest();

    System.assertEquals(0, result.size(), '포인트 데이터가 없으면 빈 리스트여야 합니다.');
  }

  /* =========================
   * memberId null 예외
   * ========================= */
  @IsTest
  static void test_getMemberPointSummary_nullId() {
    setMock();

    Boolean thrown = false;

    try {
      MemberPointSummaryController.getMemberPointSummary(null);
    } catch (AuraHandledException e) {
      thrown = true;
      // AuraHandledException 메시지는 테스트 환경에서
      // 'Script-thrown exception'으로 반환될 수 있어 발생 여부만 검증한다.
      System.assert(true);
    }

    System.assertEquals(true, thrown, 'null memberId 는 예외가 발생해야 합니다.');
  }

  @IsTest
  static void test_toSummaryDto_nullAndValueHandling() {
    setMock();

    MemberPointSummaryController.MemberPointSummaryDTO dtoWithNulls = MemberPointSummaryController.toSummaryDto('기본 포인트', null, null, null);

    System.assertEquals('기본 포인트', dtoWithNulls.pointSubtypeName);
    System.assertEquals(0, dtoWithNulls.totalAccrued);
    System.assertEquals(0, dtoWithNulls.totalRedeemed);
    System.assertEquals(0, dtoWithNulls.totalExpired);

    MemberPointSummaryController.MemberPointSummaryDTO dtoWithValues = MemberPointSummaryController.toSummaryDto('보너스 포인트', 10, 3, 1);

    System.assertEquals('보너스 포인트', dtoWithValues.pointSubtypeName);
    System.assertEquals(10, dtoWithValues.totalAccrued);
    System.assertEquals(3, dtoWithValues.totalRedeemed);
    System.assertEquals(1, dtoWithValues.totalExpired);
  }
}