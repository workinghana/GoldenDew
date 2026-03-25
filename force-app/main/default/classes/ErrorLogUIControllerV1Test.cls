@IsTest
private class ErrorLogUIControllerV1Test {
  @IsTest
  static void test_getDetail_success() {
    // given: ApexAuditTrail__c 레코드 생성
    ApexAuditTrail__c log = new ApexAuditTrail__c();

    // ✅ 최소 필드: Name은 거의 항상 있거나 자동 채번이지만,
    // org 설정에 따라 Name이 필수(텍스트)일 수 있어서 안전하게 세팅
    // log.Name = 'TEST-LOG';

    // 아래는 필수일 수도 있는 필드들(조직마다 Required가 다를 수 있음)
    // Required가 아니라면 있어도 무방. Required라면 없으면 insert가 실패하므로
    // 운영 org의 필수값에 맞게 유지/추가하세요.
    log.Status__c = 'SUCCESS'; // picklist라면 실제 값에 맞춰 수정
    log.HttpStatusCode__c = '200';
    log.RequestDateTime__c = System.now();
    log.ApexClass__c = 'ErrorLogUIControllerV1';
    log.Method__c = 'POST';
    log.RequestUrl__c = '/services/apexrest/test';

    insert log;

    // when
    Test.startTest();
    ApexAuditTrail__c result = ErrorLogUIControllerV1.getDetail(log.Id);
    Test.stopTest();

    // then
    System.assertNotEquals(null, result);
    System.assertEquals(log.Id, result.Id);
    // System.assertEquals('TEST-LOG', result.Name);

    // 쿼리로 가져오는 필드 중 일부 검증(존재 확인 겸)
    System.assertEquals('SUCCESS', result.Status__c);
    System.assertEquals('200', result.HttpStatusCode__c);
    System.assertEquals('/services/apexrest/test', result.RequestUrl__c);
  }

  @IsTest
  static void test_getDetail_not_found_throws() {
    // 존재하지 않는 Id로 호출하면 QueryException이 발생하는게 정상
    // (컨트롤러가 try/catch로 감싸지 않았기 때문)
    // Id fakeId = (Id) ('a00' + String.valueOf(Crypto.getRandomLong()).abs().format().leftPad(12, '0'));
    // ↑ prefix는 예시. org에서 ApexAuditTrail__c prefix가 다를 수 있어요.
    // 그래서 보통 아래처럼 "실제로 존재하지 않는 recordId"를 안전하게 만들기 위해
    // insert 하지 않은 log.Id를 쓰는 방식을 추천합니다.

    ApexAuditTrail__c log = new ApexAuditTrail__c();
    insert log;
    delete log;

    Test.startTest();
    try {
      ErrorLogUIControllerV1.getDetail(log.Id); // 삭제된 Id → 조회 실패
      System.assert(false, 'Expected QueryException');
    } catch (QueryException qe) {
      System.assert(true);
    }
    Test.stopTest();
  }
}