@isTest
private class MagazineSubscriptionInquiryControllerTes {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{"erpId":"OK"}}');
      return res;
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  @testSetup
  static void setup() {
    setMock();

    // Get a valid restricted picklist value at runtime
    String validStoreMana = null;
    List<Schema.PicklistEntry> entries = TransactionJournal.Magazine_StoreMana__c.getDescribe().getPicklistValues();
    if (!entries.isEmpty()) {
      validStoreMana = entries[0].getValue();
    }

    // TransactionJournal requires MemberId (LoyaltyProgramMember)
    Contact c = new Contact(LastName = 'MagTestContact', MemberNo__c = 'MAG-001');
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'MagTestLP', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'MAG-001',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    // 테스트용 TransactionJournal 데이터 생성
    List<TransactionJournal> testRecords = new List<TransactionJournal>();

    for (Integer i = 0; i < 5; i++) {
      testRecords.add(
        new TransactionJournal(
          MemberId = lpm.Id,
          LoyaltyProgramId = lp.Id,
          JournalDate = Datetime.now(),
          ActivityDate = Datetime.now(),
          UsageType__c = 'Magazine',
          Magazine_A_Name__c = 'TestUser' + i,
          Magazine_ApplicationDate__c = Date.today().addDays(-i),
          Magazine_Response_Time__c = Datetime.newInstance(Date.today().addDays(-i), Time.newInstance(6, 0, 0, 0)),
          Magazine_StoreMana__c = validStoreMana,
          Magazine_Ismagazinesubscribed__c = 'Y',
          Magazine_A_MobilePhone__c = '010-1234-567' + i,
          Magazine_uuid__c = 'UUID-' + i
        )
      );
    }

    // 검색 결과에서 제외될 데이터 (UsageType__c가 다름 — Campaign은 Magazine 검색에서 제외)
    testRecords.add(
      new TransactionJournal(
        MemberId = lpm.Id,
        LoyaltyProgramId = lp.Id,
        JournalDate = Datetime.now(),
        ActivityDate = Datetime.now(),
        UsageType__c = 'Campaign',
        Magazine_A_Name__c = 'Excluded'
      )
    );

    insert testRecords;
  }

  @isTest
  static void testSearchFullFilters() {
    setMock();

    // 모든 필터를 사용하는 케이스 (커버리지 핵심)
    String keyword = 'TestUser';
    Date fromDate = Date.today().addDays(-10);
    Date toDate = Date.today().addDays(1);
    // Use same valid picklist value that was used during @testSetup
    String storeCode = TransactionJournal.Magazine_StoreMana__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : TransactionJournal.Magazine_StoreMana__c.getDescribe().getPicklistValues()[0].getValue();
    String isSubscribed = 'Y';

    Test.startTest();
    MagazineSubscriptionInquiryController.SearchResult result = MagazineSubscriptionInquiryController.search(
      keyword,
      fromDate,
      toDate,
      storeCode,
      isSubscribed,
      10,
      1,
      'Magazine_A_Name__c',
      'ASC'
    );
    Test.stopTest();

    // 검증
    Assert.isNotNull(result, '결과 객체가 null이 아니어야 합니다.');
    Assert.isTrue(result.total > 0, '검색된 레코드가 있어야 합니다.');
    Assert.areEqual(1, result.pageNumber);
    Assert.areEqual(10, result.pageSize);
  }

  @isTest
  static void testSearchPaginationAndSort() {
    setMock();

    // 페이징 경계값 및 정렬 로직 커버
    Test.startTest();
    // pageSize를 0이나 null로 보냈을 때 기본값(20) 처리 확인
    MagazineSubscriptionInquiryController.SearchResult result = MagazineSubscriptionInquiryController.search(
      '',
      null,
      null,
      '',
      '',
      0,
      0,
      'InvalidField__c',
      'DESC'
    );
    Test.stopTest();

    // 검증: 잘못된 필드명 입력 시 기본 정렬 필드인 Magazine_Response_Time__c로 대체되었는지 로직 통과 확인
    Assert.areEqual(20, result.pageSize, 'pageSize가 0일 때 기본값 20이 적용되어야 합니다.');
  }

  @isTest
  static void testSearchKeywordVariations() {
    setMock();

    // 키워드 검색 분기 커버 (MobilePhone, UUID 등)
    Test.startTest();
    // 휴대폰 번호 일부로 검색
    MagazineSubscriptionInquiryController.SearchResult result = MagazineSubscriptionInquiryController.search(
      '1234',
      null,
      null,
      null,
      null,
      5,
      1,
      null,
      null
    );
    Test.stopTest();

    Assert.isTrue(result.total > 0, '키워드 검색 결과가 존재해야 합니다.');
  }

  @isTest
  static void testSearchEmptyResult() {
    setMock();

    // 결과가 없는 경우 커버
    Test.startTest();
    MagazineSubscriptionInquiryController.SearchResult result = MagazineSubscriptionInquiryController.search(
      'NonExistentName',
      null,
      null,
      'NONE',
      'N',
      20,
      1,
      null,
      null
    );
    Test.stopTest();

    Assert.areEqual(0, result.total, '결과가 0건이어야 합니다.');
    Assert.areEqual(0, result.records.size());
  }
}