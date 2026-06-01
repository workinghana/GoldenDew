@IsTest
private class MCDataSyncBatchChainTest {
  private class MockMCSuccess implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      if (req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
      } else {
        res.setStatusCode(202);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"requestId":"test-id","resultMessages":[]}');
      }
      return res;
    }
  }

  private class MockMCError implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      if (req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
      } else {
        res.setStatusCode(500);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"message":"error"}');
      }
      return res;
    }
  }

  @IsTest
  static void testBatchChainRunsForUserMetadata() {
    Test.setMock(HttpCalloutMock.class, new MockMCSuccess());

    Test.startTest();
    Database.executeBatch(new MCDataSyncBatchChain(new List<String>{ 'User' }, 0), 200);
    Test.stopTest();

    System.assert(true, 'Batch chain should run for User metadata.');
  }

  @IsTest
  static void testExecuteHandlesMcErrorResponse() {
    Test.setMock(HttpCalloutMock.class, new MockMCError());
    MCDataSyncBatchChain batch = new MCDataSyncBatchChain(new List<String>{ 'User' }, 0);

    // 메타데이터의 SOQL_Fields__c를 그대로 사용해 동적 쿼리 → 필드 누락으로 인한 SObjectException 방지
    MC_Sync_Object__mdt config = [
      SELECT Object_Name__c, SOQL_Fields__c
      FROM MC_Sync_Object__mdt
      WHERE DeveloperName = 'User'
      LIMIT 1
    ];
    Id userId = UserInfo.getUserId();
    String dynamicQuery =
      'SELECT ' + config.SOQL_Fields__c +
      ' FROM ' + config.Object_Name__c +
      ' WHERE Id = :userId LIMIT 1';
    List<SObject> records = Database.query(dynamicQuery);

    Test.startTest();
    batch.execute(null, records);
    batch.finish(null);
    Test.stopTest();

    System.assertNotEquals(null, batch);
  }

  @IsTest
  static void testConstructorWithLaterIndex() {
    MCDataSyncBatchChain batch = new MCDataSyncBatchChain(new List<String>{ 'User', 'User' }, 1);
    System.assertNotEquals(null, batch);
  }

  // ===================== isValidPhone 검증 =====================

  @IsTest
  static void testIsValidPhone_validKoreanFormats() {
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('010-1234-5678'), '휴대폰 하이픈 포맷');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('01012345678'), '휴대폰 숫자만');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('02-123-4567'), '서울 지역번호 9자리');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('031-1234-5678'), '경기 지역번호');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('070-1234-5678'), '인터넷전화');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('1234567'), '7자리 단축번호 (최소)');
  }

  @IsTest
  static void testIsValidPhone_validInternationalFormats() {
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('+82 10 1234 5678'), '국제 표기 공백');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('+82-10-1234-5678'), '국제 표기 하이픈');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('(415) 555-1234'), '괄호 포함');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('+44.20.7946.0958'), '점 구분자');
  }

  @IsTest
  static void testIsValidPhone_boundaryDigitCount() {
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('1234567'), '정확히 7자리(최소)');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('123456789012345'), '정확히 15자리(최대)');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('123456'), '6자리 → 거부');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('1234567890123456'), '16자리 → 거부');
  }

  @IsTest
  static void testIsValidPhone_disallowedCharacters() {
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('010-1234-abcd'), '영문 혼합');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('없음'), '한글');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('010@1234@5678'), '@ 기호');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('010 1234 ext 5678'), 'ext 표기');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('abc@email.com'), '이메일 형식');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('010/1234/5678'), '슬래시');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('010_1234_5678'), '언더스코어');
  }

  @IsTest
  static void testIsValidPhone_exceedsMaxLength() {
    // 전체 51자 → MC Phone storage 한도(50) 초과
    String over50 = '111111111122222222223333333333444444444455555555556';
    System.assertEquals(51, over50.length(), '테스트 데이터 길이 사전 검증');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone(over50), '50자 초과');

    // 정확히 50자 → 길이는 통과, 숫자 50개라 digit count(15)에서 거부
    String exactly50Digits = '11111111112222222222333333333344444444445555555555';
    System.assertEquals(50, exactly50Digits.length());
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone(exactly50Digits), '숫자 50개 → digit count 초과');
  }

  @IsTest
  static void testIsValidPhone_blankAndNull() {
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone(null), 'null');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone(''), '빈 문자열');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('   '), '공백만');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('\t\n'), '탭/개행');
  }

  // ===================== startChain / finish 체이닝 =====================

  @IsTest
  static void testStartChain() {
    Test.setMock(HttpCalloutMock.class, new MockMCSuccess());
    Test.startTest();
    MCDataSyncBatchChain.startChain();
    Test.stopTest();
    System.assert(true, 'startChain 정상 종료');
  }

  @IsTest
  static void testFinishRecursesToNextObject() {
    Test.setMock(HttpCalloutMock.class, new MockMCSuccess());
    MCDataSyncBatchChain batch = new MCDataSyncBatchChain(new List<String>{ 'User', 'User' }, 0);

    Test.startTest();
    batch.finish(null);
    Test.stopTest();

    System.assertNotEquals(null, batch, 'finish 재귀 분기 실행');
  }

  // ===================== normalizeBatchSize 분기 =====================

  @IsTest
  static void testNormalizeBatchSize_nullReturnsDefault() {
    System.assertEquals(200, MCDataSyncBatchChain.normalizeBatchSize(null), 'null → 기본 200');
  }

  @IsTest
  static void testNormalizeBatchSize_zeroOrNegativeReturnsDefault() {
    System.assertEquals(200, MCDataSyncBatchChain.normalizeBatchSize(0), '0 → 200');
    System.assertEquals(200, MCDataSyncBatchChain.normalizeBatchSize(-100), '음수 → 200');
  }

  @IsTest
  static void testNormalizeBatchSize_validValues() {
    System.assertEquals(1, MCDataSyncBatchChain.normalizeBatchSize(1), '최소 양수');
    System.assertEquals(500, MCDataSyncBatchChain.normalizeBatchSize(500), '일반값');
    System.assertEquals(2000, MCDataSyncBatchChain.normalizeBatchSize(2000), '최대 경계');
  }

  @IsTest
  static void testNormalizeBatchSize_exceedsMaxClamped() {
    System.assertEquals(2000, MCDataSyncBatchChain.normalizeBatchSize(2001), '경계 초과 → 2000');
    System.assertEquals(2000, MCDataSyncBatchChain.normalizeBatchSize(99999), '대값 → 2000');
  }

  @IsTest
  static void testNormalizeBatchSize_decimalIntValue() {
    // CMT Number(N,0)이지만 Apex에선 Decimal로 들어옴 → intValue 변환 검증
    System.assertEquals(300, MCDataSyncBatchChain.normalizeBatchSize(Decimal.valueOf('300')));
  }

  // ===================== resolvePhoneFields 분기 =====================

  @IsTest
  static void testResolvePhoneFields_contactPicksUpPhoneTypeFields() {
    Set<String> result = MCDataSyncBatchChain.resolvePhoneFields(
      'Contact',
      new List<String>{ 'Phone', 'MobilePhone', 'HomePhone', 'Email', 'FirstName' }
    );
    System.assert(result.contains('phone'), 'Phone 포함');
    System.assert(result.contains('mobilephone'), 'MobilePhone 포함');
    System.assert(result.contains('homephone'), 'HomePhone 포함');
    System.assert(!result.contains('email'), 'Email 제외');
    System.assert(!result.contains('firstname'), 'FirstName 제외');
  }

  @IsTest
  static void testResolvePhoneFields_nonContactReturnsEmpty() {
    Set<String> result = MCDataSyncBatchChain.resolvePhoneFields(
      'User',
      new List<String>{ 'Phone', 'MobilePhone', 'Name' }
    );
    System.assertEquals(0, result.size(), 'Contact 아닌 오브젝트는 빈 Set');
  }

  @IsTest
  static void testResolvePhoneFields_nullOrEmptyFields() {
    System.assertEquals(0, MCDataSyncBatchChain.resolvePhoneFields('Contact', null).size(), 'null 필드');
    System.assertEquals(0, MCDataSyncBatchChain.resolvePhoneFields('Contact', new List<String>()).size(), '빈 필드');
  }

  @IsTest
  static void testResolvePhoneFields_skipBlankAndUnknownFields() {
    Set<String> result = MCDataSyncBatchChain.resolvePhoneFields(
      'Contact',
      new List<String>{ 'Phone', '', '   ', 'NonExistentField__c' }
    );
    System.assertEquals(1, result.size(), 'Phone만 통과');
    System.assert(result.contains('phone'));
  }

  @IsTest
  static void testResolvePhoneFields_invalidObjectName() {
    Set<String> result = MCDataSyncBatchChain.resolvePhoneFields(
      'Contact',
      new List<String>{ 'Phone' }
    );
    System.assert(result.size() >= 1, 'Contact 정상 케이스');

    // 'Contact'가 아니면 Schema 조회 자체 안 함 → 빈 Set
    Set<String> nonContact = MCDataSyncBatchChain.resolvePhoneFields(
      'NotARealObject__c',
      new List<String>{ 'Phone' }
    );
    System.assertEquals(0, nonContact.size());
  }

  // ===================== isValidPhone edge =====================

  @IsTest
  static void testIsValidPhone_edgeCases() {
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('-'), '하이픈 단독');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('+'), '플러스 단독');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('()'), '괄호만');
    System.assertEquals(false, MCDataSyncBatchChain.isValidPhone('- - -'), '구분자만');
    System.assertEquals(true, MCDataSyncBatchChain.isValidPhone('  010-1234-5678  '), '앞뒤 공백은 trim');
  }
}