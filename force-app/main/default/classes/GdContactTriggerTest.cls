@IsTest
private class GdContactTriggerTest {

  @IsTest
  static void beforeUpdate_firesWithoutError() {
    Contact c = new Contact(LastName = 'TriggerTest');
    insert c;

    Test.startTest();
    c.LastName = 'TriggerTestUpdated';
    update c;
    Test.stopTest();

    Contact updated = [SELECT LastName FROM Contact WHERE Id = :c.Id LIMIT 1];
    System.assertEquals('TriggerTestUpdated', updated.LastName);
  }
}