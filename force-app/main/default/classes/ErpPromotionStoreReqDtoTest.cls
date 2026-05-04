@IsTest
private class ErpPromotionStoreReqDtoTest {
  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static Promotion createPromotionRecord() {
    Promotion p = new Promotion(
      Name = uniq('Promo'),
      StartDate = Date.today(),
      EndDate = Date.today().addDays(7),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(3),
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = false,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = false,
      IsAllStore__c = false,
      IsAllItem__c = false
    );
    insert p;
    return p;
  }

  private static Account createStoreAccount() {
    Account a = new Account(
      Name = uniq('Store'),
      CompanyCode__c = '1000',
      StoreCode__c = 'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(4)
    );
    insert a;
    return a;
  }

  private static PromotionAccount__c createPromotionAccount(Id promotionId, Id accountId) {
    PromotionAccount__c pa = new PromotionAccount__c(PromotionId__c = promotionId, AccountId__c = accountId);
    insert pa;
    return pa;
  }

  @IsTest
  static void test_outer_constructor() {
    ErpPromotionStoreReqDto dto = new ErpPromotionStoreReqDto();
    System.assertNotEquals(null, dto);
  }

  @IsTest
  static void test_request_constructors_and_lists() {
    Promotion p = createPromotionRecord();
    Account a = createStoreAccount();
    PromotionAccount__c inserted = createPromotionAccount(p.Id, a.Id);

    PromotionAccount__c src = [
      SELECT Id, PromotionId__r.PromotionNo__c, AccountId__r.CompanyCode__c, AccountId__r.StoreCode__c, AccountId__r.Name
      FROM PromotionAccount__c
      WHERE Id = :inserted.Id
      LIMIT 1
    ];

    ErpPromotionStoreReqDto.CreateRequest createReq = new ErpPromotionStoreReqDto.CreateRequest(src);
    ErpPromotionStoreReqDto.CreateRequest directCreateReq = new ErpPromotionStoreReqDto.CreateRequest(
      src.AccountId__r.CompanyCode__c,
      src.PromotionId__r.PromotionNo__c,
      src.AccountId__r.StoreCode__c,
      src.AccountId__r.Name,
      'tester'
    );
    ErpPromotionStoreReqDto.CreateRequestList createList = new ErpPromotionStoreReqDto.CreateRequestList(new List<PromotionAccount__c>{ src });

    ErpPromotionStoreReqDto.DeleteRequest deleteReq = new ErpPromotionStoreReqDto.DeleteRequest(src);
    ErpPromotionStoreReqDto.DeleteRequest directDeleteReq = new ErpPromotionStoreReqDto.DeleteRequest(
      src.PromotionId__r.PromotionNo__c,
      src.AccountId__r.StoreCode__c,
      'deleter'
    );
    ErpPromotionStoreReqDto.DeleteRequestList deleteList = new ErpPromotionStoreReqDto.DeleteRequestList(new List<PromotionAccount__c>{ src });

    ErpPromotionStoreReqDto.UpdateRequest updateReq = new ErpPromotionStoreReqDto.UpdateRequest(
      src.AccountId__r.CompanyCode__c,
      src.PromotionId__r.PromotionNo__c,
      src.AccountId__r.StoreCode__c,
      src.AccountId__r.Name,
      'updater'
    );
    ErpPromotionStoreReqDto.UpdateRequestList updateList = new ErpPromotionStoreReqDto.UpdateRequestList(new List<PromotionAccount__c>{ src });

    System.assertEquals(src.AccountId__r.CompanyCode__c, createReq.cd_company);
    System.assertEquals(src.AccountId__r.StoreCode__c, directCreateReq.cd_store);
    System.assertEquals(1, createList.promotionStoreList.size());
    System.assertEquals(src.PromotionId__r.PromotionNo__c, deleteReq.no_prom);
    System.assertEquals(src.AccountId__r.StoreCode__c, directDeleteReq.cd_store);
    System.assertEquals(1, deleteList.promotionStoreList.size());
    System.assertEquals(src.AccountId__r.StoreCode__c, updateReq.cd_store);
    System.assertEquals(1, updateList.promotionStoreList.size());
  }

  @IsTest
  static void test_helpers() {
    System.assertEquals('Y', ErpPromotionStoreReqDto.boolToYn(true));
    System.assertEquals('N', ErpPromotionStoreReqDto.boolToYn(false));
    System.assertEquals('N', ErpPromotionStoreReqDto.boolToYn(null));
    System.assertEquals('', ErpPromotionStoreReqDto.isStrNull(null));
    System.assertEquals('', ErpPromotionStoreReqDto.isStrNull(''));
    System.assertEquals('', ErpPromotionStoreReqDto.isStrNull('   '));
    System.assertEquals('A', ErpPromotionStoreReqDto.isStrNull('A'));
  }
}