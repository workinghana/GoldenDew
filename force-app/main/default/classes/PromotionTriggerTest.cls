@IsTest
private class PromotionTriggerTest {
  private static final Date BASE_DATE = Date.newInstance(2026, 1, 1);

  @IsTest
  static void afterInsert_whenEnabled_writesTriggerAndHandlerLogs() {
    enablePromotionTrigger();

    Test.startTest();
    Promotion promotion = insertPromotion('INSERT');
    Test.stopTest();

    Promotion actual = [
      SELECT PromotionNo__c, PromotionCode
      FROM Promotion
      WHERE Id = :promotion.Id
    ];
    System.assertEquals(
      actual.PromotionNo__c,
      actual.PromotionCode,
      'PromotionTrigger should execute PromotionTriggerHandler after insert.'
    );

    ApexAuditTrail__c triggerLog = latestLog('PromotionTrigger');
    System.assertEquals('SUCCESS', triggerLog.Status__c, 'PromotionTrigger log should be successful.');
    System.assertEquals(
      'Handler executed. size=1',
      triggerLog.Description__c,
      'PromotionTrigger should record successful handler execution.'
    );

    ApexAuditTrail__c handlerLog = latestLog('PromotionTriggerHandler');
    System.assertEquals('SUCCESS', handlerLog.Status__c, 'PromotionTriggerHandler log should be successful.');

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void afterUpdate_whenEnabled_writesTriggerLog() {
    disablePromotionTrigger();
    Promotion promotion = insertPromotion('UPDATE');
    enablePromotionTrigger();

    Test.startTest();
    promotion.Name = 'Promotion Trigger Updated';
    update promotion;
    Test.stopTest();

    ApexAuditTrail__c triggerLog = latestLog('PromotionTrigger');
    System.assertEquals('SUCCESS', triggerLog.Status__c, 'PromotionTrigger update log should be successful.');
    System.assertEquals('Handler executed. size=1', triggerLog.Description__c);

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void afterDelete_whenEnabled_writesTriggerLog() {
    disablePromotionTrigger();
    Promotion promotion = insertPromotion('DELETE');
    enablePromotionTrigger();

    Test.startTest();
    delete promotion;
    Test.stopTest();

    ApexAuditTrail__c triggerLog = latestLog('PromotionTrigger');
    System.assertEquals('SUCCESS', triggerLog.Status__c, 'PromotionTrigger delete log should be successful.');
    System.assertEquals('Handler executed. size=1', triggerLog.Description__c);

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void triggerReturnsWithoutLogWhenDisabled() {
    disablePromotionTrigger();

    Test.startTest();
    insertPromotion('DISABLED');
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM ApexAuditTrail__c WHERE ApexClass__c = 'PromotionTrigger'],
      'Disabled PromotionTrigger should return before creating a trigger log.'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM ApexAuditTrail__c WHERE ApexClass__c = 'PromotionTriggerHandler'],
      'Disabled PromotionTrigger should not invoke the handler.'
    );

    TriggerHandler.mockCache = null;
  }

  private static Promotion insertPromotion(String suffix) {
    Promotion promotion = buildPromotion(suffix);
    insert promotion;
    return promotion;
  }

  private static Promotion buildPromotion(String suffix) {
    return new Promotion(
      Name = 'Promotion Trigger Test ' + suffix,
      BrandCode__c = firstPicklistValue(Schema.SObjectType.Promotion.fields.BrandCode__c),
      TypeCode__c = firstPicklistValue(Schema.SObjectType.Promotion.fields.TypeCode__c),
      StatusCode__c = firstPicklistValue(Schema.SObjectType.Promotion.fields.StatusCode__c),
      StartDate = BASE_DATE,
      EndDate = BASE_DATE.addDays(30),
      PublishStartDate__c = BASE_DATE,
      PublishEndDate__c = BASE_DATE.addDays(30),
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = false,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = true,
      IsAllStore__c = true,
      IsAllItem__c = true,
      InsertId__c = ('I-' + suffix).left(20),
      ResponId__c = ('R-' + suffix).left(20),
      PromotionCode = 'CODE-' + suffix
    );
  }

  private static ApexAuditTrail__c latestLog(String apexClassName) {
    return [
      SELECT Status__c, Description__c
      FROM ApexAuditTrail__c
      WHERE ApexClass__c = :apexClassName
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
  }

  private static void enablePromotionTrigger() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>{
      'PromotionTrigger' => new Apex_Trigger_Setting__mdt(
        IsActive__c = true,
        After_Insert__c = true,
        After_Update__c = true,
        After_Delete__c = true
      )
    };
  }

  private static void disablePromotionTrigger() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>{
      'PromotionTrigger' => new Apex_Trigger_Setting__mdt(IsActive__c = false)
    };
  }

  private static String firstPicklistValue(Schema.DescribeFieldResult fieldDescribe) {
    for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
      if (entry.isActive()) {
        return entry.getValue();
      }
    }
    System.assert(false, fieldDescribe.getName() + ' should have at least one active picklist value.');
    return null;
  }
}