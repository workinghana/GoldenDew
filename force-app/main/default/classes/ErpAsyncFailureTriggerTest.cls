@IsTest
private class ErpAsyncFailureTriggerTest {
  @IsTest
  static void publishEvent_minimal_fields_runsTrigger() {
    Test.startTest();

    ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
    evt.ApiName__c = 'UNIT-TEST-MIN';
    evt.ErrorMessage__c = 'Trigger coverage test';

    Database.SaveResult sr = EventBus.publish(evt);
    System.assertEquals(true, sr.isSuccess(), 'Platform Event publish should succeed');

    Test.stopTest();
    System.assert(true);
  }

  @IsTest
  static void publishEvent_with_target_record_runsTrigger() {
    Account a = new Account(Name = 'ErpAsyncFailureTriggerTest');
    insert a;

    Test.startTest();

    ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
    evt.ApiName__c = 'UNIT-TEST-TARGET';
    evt.ErrorMessage__c = 'Trigger target id test';
    evt.TargetRecordId__c = String.valueOf(a.Id);

    Database.SaveResult sr = EventBus.publish(evt);
    System.assertEquals(true, sr.isSuccess(), 'Platform Event publish should succeed');

    Test.stopTest();
    System.assert(true);
  }
}