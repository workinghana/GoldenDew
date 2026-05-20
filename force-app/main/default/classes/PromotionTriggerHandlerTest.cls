@IsTest
private class PromotionTriggerHandlerTest {
  private static final Date BASE_DATE = Date.newInstance(2026, 1, 1);

  @IsTest
  static void afterInsert_setsPromotionCodeAndWritesSuccessLogWhenTriggerIsEnabled() {
    enablePromotionTrigger();

    Test.startTest();
    Promotion insertedPromotion = insertPromotion('INSERT');
    Test.stopTest();

    Promotion actual = [
      SELECT PromotionNo__c, PromotionCode
      FROM Promotion
      WHERE Id = :insertedPromotion.Id
    ];

    List<ApexAuditTrail__c> handlerLogs = [
      SELECT Status__c, Description__c, SuccessRecordIds__c, FailedRecordIds__c
      FROM ApexAuditTrail__c
      WHERE ApexClass__c = 'PromotionTriggerHandler'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    System.assertEquals(
      actual.PromotionNo__c,
      actual.PromotionCode,
      'afterInsert should copy PromotionNo__c to PromotionCode when PromotionTrigger is enabled.'
    );
    System.assertEquals(1, handlerLogs.size(), 'Handler log should be written when PromotionTrigger is enabled.');
    System.assertEquals('SUCCESS', handlerLogs[0].Status__c, 'Handler log should be successful.');
    System.assert(
      handlerLogs[0].Description__c.contains('ERP promotion master create done.'),
      'Handler log should describe the create processing result.'
    );
    System.assert(
      handlerLogs[0].SuccessRecordIds__c.contains(String.valueOf(insertedPromotion.Id)),
      'Inserted Promotion Id should be recorded as a successful record.'
    );
    System.assertEquals(null, handlerLogs[0].FailedRecordIds__c, 'No records should fail in the happy path.');

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void afterUpdate_executesWithoutChangingPromotionCode() {
    disablePromotionTrigger();
    Promotion existingPromotion = insertPromotion('UPDATE');
    PromotionTriggerHandler handler = new PromotionTriggerHandler();

    Test.startTest();
    handler.afterUpdate();
    Test.stopTest();

    Promotion actual = [
      SELECT PromotionNo__c, PromotionCode
      FROM Promotion
      WHERE Id = :existingPromotion.Id
    ];
    System.assertEquals(
      'CODE-UPDATE',
      actual.PromotionCode,
      'afterUpdate has no active logic and should not mutate PromotionCode when invoked directly.'
    );
    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void afterDelete_executesWithoutException() {
    PromotionTriggerHandler handler = new PromotionTriggerHandler();

    Test.startTest();
    handler.afterDelete();
    Test.stopTest();

    System.assert(true, 'afterDelete currently has no active logic and should complete without exception.');
  }

  @IsTest
  static void isErpSyncRelevantChange_returnsFalseWhenComparedFieldsAreSame() {
    Promotion oldPromotion = buildComparisonPromotion();
    Promotion newPromotion = buildComparisonPromotion();

    System.assertEquals(
      false,
      PromotionTriggerHandler.isErpSyncRelevantChange(oldPromotion, newPromotion),
      'Identical ERP sync fields should not be relevant.'
    );
  }

  @IsTest
  static void isErpSyncRelevantChange_returnsTrueForNullOrChangedFields() {
    Promotion oldPromotion = buildComparisonPromotion();
    Promotion samePromotion = buildComparisonPromotion();

    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(null, samePromotion));
    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(oldPromotion, null));

    assertRelevantChange(oldPromotion, new Promotion(Name = 'Changed Name'));
    System.assertEquals(
      true,
      PromotionTriggerHandler.isErpSyncRelevantChange(oldPromotion, buildComparisonPromotion('PROMO-CHANGED')),
      'A change to PromotionNo__c should be relevant.'
    );
    assertRelevantChange(
      oldPromotion,
      new Promotion(BrandCode__c = alternatePicklistValue(Schema.SObjectType.Promotion.fields.BrandCode__c, oldPromotion.BrandCode__c))
    );
    assertRelevantChange(
      oldPromotion,
      new Promotion(TypeCode__c = alternatePicklistValue(Schema.SObjectType.Promotion.fields.TypeCode__c, oldPromotion.TypeCode__c))
    );
    assertRelevantChange(oldPromotion, new Promotion(StartDate = BASE_DATE.addDays(1)));
    assertRelevantChange(oldPromotion, new Promotion(EndDate = BASE_DATE.addDays(31)));
    assertRelevantChange(oldPromotion, new Promotion(PublishStartDate__c = BASE_DATE.addDays(2)));
    assertRelevantChange(oldPromotion, new Promotion(PublishEndDate__c = BASE_DATE.addDays(32)));
    assertRelevantChange(
      oldPromotion,
      new Promotion(StatusCode__c = alternatePicklistValue(Schema.SObjectType.Promotion.fields.StatusCode__c, oldPromotion.StatusCode__c))
    );
    assertRelevantChange(oldPromotion, new Promotion(IsCouponAllowed__c = false));
    assertRelevantChange(oldPromotion, new Promotion(IsFixedAmountCouponAllowed__c = true));
    assertRelevantChange(oldPromotion, new Promotion(IsRateCouponAllowed__c = false));
    assertRelevantChange(oldPromotion, new Promotion(IsSpecificCouponAllowed__c = true));
    assertRelevantChange(oldPromotion, new Promotion(IsPointUsageAllowed__c = false));
    assertRelevantChange(oldPromotion, new Promotion(IsAllStore__c = false));
    assertRelevantChange(oldPromotion, new Promotion(IsAllItem__c = false));
    assertRelevantChange(oldPromotion, new Promotion(InsertId__c = 'INSERT-CHANGED'));
    assertRelevantChange(oldPromotion, new Promotion(ResponId__c = 'RESPON-CHANGED'));
  }

  private static Promotion insertPromotion(String suffix) {
    Promotion promotion = buildPromotion(suffix);
    insert promotion;
    return promotion;
  }

  private static void enablePromotionTrigger() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>{
      'PromotionTrigger' => new Apex_Trigger_Setting__mdt(
        IsActive__c = true,
        Before_Insert__c = true,
        After_Insert__c = true,
        Before_Update__c = true,
        After_Update__c = true,
        Before_Delete__c = true,
        After_Delete__c = true,
        After_Undelete__c = true
      )
    };
  }

  private static void disablePromotionTrigger() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>{
      'PromotionTrigger' => new Apex_Trigger_Setting__mdt(IsActive__c = false)
    };
  }

  private static Promotion buildPromotion(String suffix) {
    return new Promotion(
      Name = 'Promotion Handler Test ' + suffix,
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

  private static Promotion buildComparisonPromotion() {
    return buildComparisonPromotion('PROMO-BASE');
  }

  private static Promotion buildComparisonPromotion(String promotionNo) {
    Promotion promotion = promotionWithPromotionNo(promotionNo);
    promotion.Name = 'Comparable Promotion';
    promotion.BrandCode__c = firstPicklistValue(Schema.SObjectType.Promotion.fields.BrandCode__c);
    promotion.TypeCode__c = firstPicklistValue(Schema.SObjectType.Promotion.fields.TypeCode__c);
    promotion.StartDate = BASE_DATE;
    promotion.EndDate = BASE_DATE.addDays(30);
    promotion.PublishStartDate__c = BASE_DATE;
    promotion.PublishEndDate__c = BASE_DATE.addDays(30);
    promotion.StatusCode__c = firstPicklistValue(Schema.SObjectType.Promotion.fields.StatusCode__c);
    promotion.IsCouponAllowed__c = true;
    promotion.IsFixedAmountCouponAllowed__c = false;
    promotion.IsRateCouponAllowed__c = true;
    promotion.IsSpecificCouponAllowed__c = false;
    promotion.IsPointUsageAllowed__c = true;
    promotion.IsAllStore__c = true;
    promotion.IsAllItem__c = true;
    promotion.InsertId__c = 'INSERT-BASE';
    promotion.ResponId__c = 'RESPON-BASE';
    return promotion;
  }

  private static Promotion promotionWithPromotionNo(String promotionNo) {
    return (Promotion) JSON.deserialize('{"attributes":{"type":"Promotion"},"PromotionNo__c":"' + promotionNo + '"}', Promotion.class);
  }

  private static void assertRelevantChange(Promotion oldPromotion, Promotion changedFields) {
    Promotion newPromotion = buildComparisonPromotion();
    for (String fieldName : changedFields.getPopulatedFieldsAsMap().keySet()) {
      newPromotion.put(fieldName, changedFields.get(fieldName));
    }

    System.assertEquals(
      true,
      PromotionTriggerHandler.isErpSyncRelevantChange(oldPromotion, newPromotion),
      'A change to ' + String.join(new List<String>(changedFields.getPopulatedFieldsAsMap().keySet()), ',') + ' should be relevant.'
    );
  }

  private static String firstPicklistValue(Schema.DescribeFieldResult fieldDescribe) {
    return activePicklistValues(fieldDescribe)[0];
  }

  private static String alternatePicklistValue(Schema.DescribeFieldResult fieldDescribe, String currentValue) {
    for (String value : activePicklistValues(fieldDescribe)) {
      if (value != currentValue) {
        return value;
      }
    }
    return currentValue + '_CHANGED';
  }

  private static List<String> activePicklistValues(Schema.DescribeFieldResult fieldDescribe) {
    List<String> values = new List<String>();
    for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
      if (entry.isActive()) {
        values.add(entry.getValue());
      }
    }
    System.assert(!values.isEmpty(), fieldDescribe.getName() + ' should have at least one active picklist value.');
    return values;
  }
}