@IsTest
private class PromotionDTOTest {
  private static Promotion insertPromotion(Boolean isActive, Date startDate, Date endDate) {
    String storeTypeValue = null;
    // List<Schema.PicklistEntry> entries = Promotion.StoreType__c.getDescribe().getPicklistValues();
    // if (!entries.isEmpty()) {
    //     storeTypeValue = entries[0].getValue();
    // }

    Promotion p = new Promotion(
      Name = 'TestPromo',
      DisplayName = 'TestPromo Display',
      PromotionCode = 'PDTO-' + String.valueOf(Math.random()).substring(2, 8),
      IsActive = isActive,
      StartDate = startDate,
      EndDate = endDate
      // ,
      // StoreType__c  = storeTypeValue
    );
    insert p;

    return [
      SELECT Id, Name, PromotionNo__c, IsActive, StartDate, EndDate
      FROM Promotion
      WHERE Id = :p.Id
      LIMIT 1
    ];
  }

  @IsTest
  static void constructor_activePromotion_mapsAllFields() {
    Date startDt = Date.today();
    Date endDt = Date.today().addDays(30);
    Promotion p = insertPromotion(true, startDt, endDt);

    Test.startTest();
    PromotionDTO dto = new PromotionDTO(p);
    Test.stopTest();

    System.assertEquals(p.Name, dto.Name, 'Name 매핑 확인');
    System.assertEquals(p.PromotionNo__c, dto.PromotionNo, 'PromotionNo__c → PromotionNo');
    System.assertEquals(true, dto.IsActive, 'IsActive=true');
    System.assertEquals(startDt, dto.StartDate, 'StartDate 매핑 확인');
    System.assertEquals(endDt, dto.EndDate, 'EndDate 매핑 확인');
  }

  @IsTest
  static void constructor_inactivePromotion_isActiveFalse() {
    Promotion p = insertPromotion(false, Date.today(), Date.today().addDays(10));

    Test.startTest();
    PromotionDTO dto = new PromotionDTO(p);
    Test.stopTest();

    System.assertEquals(false, dto.IsActive, 'IsActive=false');
  }

  @IsTest
  static void constructor_promotionNo_autoAssigned() {
    Promotion p = insertPromotion(true, Date.today(), Date.today().addDays(5));

    Test.startTest();
    PromotionDTO dto = new PromotionDTO(p);
    Test.stopTest();

    // PromotionNo__c 는 자동 채번 — null이 아닌지 확인
    System.assertNotEquals(null, dto.PromotionNo, 'PromotionNo는 null이 아니어야 함');
  }
}