@IsTest
private class PromotionResDTOTest {
  private static Promotion buildPromotion(Boolean allFlagsOn) {
    Promotion p = new Promotion(
      Name = 'TestPromotion',
      DisplayName = 'TestPromotion Display',
      PromotionCode = 'PROMO-TEST-' + (allFlagsOn ? 'Y' : 'N') + '-' + String.valueOf(Datetime.now().getTime()),
      IsActive = true,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(20),
      DiscountRate__c = 5,
      IsCouponAllowed__c = allFlagsOn,
      IsFixedAmountCouponAllowed__c = allFlagsOn,
      IsRateCouponAllowed__c = allFlagsOn,
      IsSpecificCouponAllowed__c = allFlagsOn,
      IsPointUsageAllowed__c = allFlagsOn,
      IsAllStore__c = allFlagsOn,
      IsAllItem__c = allFlagsOn,
      IsDiscountRateApplicable__c = allFlagsOn
    );
    insert p;

    return [
      SELECT
        Id,
        Name,
        PromotionNo__c,
        BrandCode__c,
        TypeCode__c,
        StartDateTime,
        EndDateTime,
        PublishStartDate__c,
        PublishEndDate__c,
        StatusCode__c,
        IsCouponAllowed__c,
        IsFixedAmountCouponAllowed__c,
        IsRateCouponAllowed__c,
        IsSpecificCouponAllowed__c,
        IsPointUsageAllowed__c,
        IsAllStore__c,
        IsAllItem__c,
        IsDiscountRateApplicable__c
      FROM Promotion
      WHERE Id = :p.Id
      LIMIT 1
    ];
  }

  @IsTest
  static void constructor_allFlagsTrue_returnsY() {
    Promotion p = buildPromotion(true);

    Test.startTest();
    PromotionResDTO dto = new PromotionResDTO(p);
    Test.stopTest();

    System.assertEquals('Y', dto.YN_USE_COUPON);
    System.assertEquals('Y', dto.YN_USE_FIXED_COUPON);
    System.assertEquals('Y', dto.YN_USE_RATE_COUPON);
    System.assertEquals('Y', dto.YN_USE_SPECIFIC_COUPON);
    System.assertEquals('Y', dto.YN_USE_POINT);
    System.assertEquals('Y', dto.YN_ALL_STORE);
    System.assertEquals('Y', dto.YN_ALL_ITEM);
    System.assertEquals('Y', dto.YN_ALL_COUPON);
    System.assertEquals('Y', dto.YN_PROM_DC);
  }

  @IsTest
  static void constructor_allFlagsFalse_returnsN() {
    Promotion p = buildPromotion(false);

    Test.startTest();
    PromotionResDTO dto = new PromotionResDTO(p);
    Test.stopTest();

    System.assertEquals('N', dto.YN_USE_COUPON);
    System.assertEquals('N', dto.YN_USE_FIXED_COUPON);
    System.assertEquals('N', dto.YN_USE_RATE_COUPON);
    System.assertEquals('N', dto.YN_USE_SPECIFIC_COUPON);
    System.assertEquals('N', dto.YN_USE_POINT);
    System.assertEquals('N', dto.YN_ALL_STORE);
    System.assertEquals('N', dto.YN_ALL_ITEM);
    System.assertEquals('N', dto.YN_ALL_COUPON);
    System.assertEquals('N', dto.YN_PROM_DC);
  }

  @IsTest
  static void constructor_stringFields_mappedCorrectly() {
    Promotion p = buildPromotion(false);

    Test.startTest();
    PromotionResDTO dto = new PromotionResDTO(p);
    Test.stopTest();

    System.assertEquals(p.PromotionNo__c, dto.NO_PROM);
    System.assertEquals(p.Name, dto.NM_PROM);
    System.assertEquals(p.BrandCode__c, dto.NM_BRAND);
    System.assertEquals(p.TypeCode__c, dto.NM_TYPE_PROM);
    System.assertEquals(p.StatusCode__c, dto.NM_STAT);
  }

  @IsTest
  static void constructor_nullDateTimes_returnsEmptyStrings() {
    Promotion p = buildPromotion(false);

    Test.startTest();
    PromotionResDTO dto = new PromotionResDTO(p);
    Test.stopTest();

    if (p.StartDateTime == null) {
      System.assertEquals('', dto.DT_START);
    } else {
      System.assertEquals(8, dto.DT_START.length());
    }

    if (p.EndDateTime == null) {
      System.assertEquals('', dto.DT_END);
    } else {
      System.assertEquals(8, dto.DT_END.length());
    }
  }

  @IsTest
  static void constructor_publishDates_formattedWithoutHyphens() {
    Promotion p = buildPromotion(false);

    Test.startTest();
    PromotionResDTO dto = new PromotionResDTO(p);
    Test.stopTest();

    if (p.PublishStartDate__c != null) {
      System.assert(!dto.DT_EVENT_START.contains('-'));
      System.assertEquals(8, dto.DT_EVENT_START.length());
    } else {
      System.assertEquals('', dto.DT_EVENT_START);
    }

    if (p.PublishEndDate__c != null) {
      System.assert(!dto.DT_EVENT_END.contains('-'));
      System.assertEquals(8, dto.DT_EVENT_END.length());
    } else {
      System.assertEquals('', dto.DT_EVENT_END);
    }
  }
}