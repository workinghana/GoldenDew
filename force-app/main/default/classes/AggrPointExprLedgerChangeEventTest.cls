@IsTest
public with sharing class AggrPointExprLedgerChangeEventTest {
  @IsTest
  static void test_afterInsert_execute() {
    // given
    AggrPointExprLedgerChangeEventTriHandler handler = new AggrPointExprLedgerChangeEventTriHandler();

    // when
    Test.startTest();
    handler.afterInsert();
    Test.stopTest();

    // then
    System.assert(true, 'afterInsert가 예외 없이 실행되어야 합니다.');
  }
}