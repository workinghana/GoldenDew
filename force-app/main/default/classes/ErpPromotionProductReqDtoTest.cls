@IsTest
private class ErpPromotionProductReqDtoTest {
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

  private static Product2 createProduct() {
    Product2 prod = new Product2(Name = uniq('Prod'), ProductCode = uniq('CODE'), IsActive = true);
    insert prod;
    return prod;
  }

  private static PromotionProduct createPromotionProduct(Id promotionId, Id productId) {
    PromotionProduct pp = new PromotionProduct(PromotionId = promotionId, ProductId = productId);
    insert pp;
    return pp;
  }

  @IsTest
  static void test_outer_constructor() {
    ErpPromotionProductReqDto dto = new ErpPromotionProductReqDto();
    System.assertNotEquals(null, dto);
  }

  @IsTest
  static void test_createRequest_default_assignment() {
    ErpPromotionProductReqDto.CreateRequest req = new ErpPromotionProductReqDto.CreateRequest();
    req.no_prom = 'PROM001';
    req.cd_item = 'ITEM001';
    req.id_insert = 'tester';
    req.id_update = 'updater';

    System.assertEquals('PROM001', req.no_prom);
    System.assertEquals('ITEM001', req.cd_item);
    System.assertEquals('tester', req.id_insert);
    System.assertEquals('updater', req.id_update);
  }

  @IsTest
  static void test_createRequest_fromPromotionProduct() {
    Promotion p = createPromotionRecord();
    Product2 prod = createProduct();
    PromotionProduct inserted = createPromotionProduct(p.Id, prod.Id);

    PromotionProduct src = [
      SELECT Id, Promotion.PromotionNo__c, Product.ProductCode
      FROM PromotionProduct
      WHERE Id = :inserted.Id
      LIMIT 1
    ];

    ErpPromotionProductReqDto.CreateRequest req = new ErpPromotionProductReqDto.CreateRequest(src);

    System.assertEquals(src.Promotion.PromotionNo__c, req.no_prom);
    System.assertEquals(src.Product.ProductCode, req.cd_item);
    System.assertEquals(UserInfo.getUserName(), req.id_insert);
    System.assertEquals(UserInfo.getUserName(), req.id_update);
  }

  @IsTest
  static void test_createRequestList_fromPromotionProducts() {
    Promotion p = createPromotionRecord();
    Product2 prod = createProduct();
    PromotionProduct inserted = createPromotionProduct(p.Id, prod.Id);

    List<PromotionProduct> srcList = [
      SELECT Id, Promotion.PromotionNo__c, Product.ProductCode
      FROM PromotionProduct
      WHERE Id = :inserted.Id
    ];

    ErpPromotionProductReqDto.CreateRequestList req = new ErpPromotionProductReqDto.CreateRequestList(srcList);

    System.assertEquals(1, req.promotionItemList.size());
    System.assertEquals(srcList[0].Promotion.PromotionNo__c, req.promotionItemList[0].no_prom);
    System.assertEquals(srcList[0].Product.ProductCode, req.promotionItemList[0].cd_item);
    System.assertEquals(UserInfo.getUserName(), req.promotionItemList[0].id_insert);
    System.assertEquals(UserInfo.getUserName(), req.promotionItemList[0].id_update);
  }

  @IsTest
  static void test_deleteRequest_default_assignment() {
    ErpPromotionProductReqDto.DeleteRequest req = new ErpPromotionProductReqDto.DeleteRequest();
    req.no_prom = 'PROM002';
    req.cd_item = 'ITEM002';
    req.id_delete = 'deleter';

    System.assertEquals('PROM002', req.no_prom);
    System.assertEquals('ITEM002', req.cd_item);
    System.assertEquals('deleter', req.id_delete);
  }

  @IsTest
  static void test_deleteRequest_fromPromotionProduct() {
    Promotion p = createPromotionRecord();
    Product2 prod = createProduct();
    PromotionProduct inserted = createPromotionProduct(p.Id, prod.Id);

    PromotionProduct src = [
      SELECT Id, Promotion.PromotionNo__c, Product.ProductCode
      FROM PromotionProduct
      WHERE Id = :inserted.Id
      LIMIT 1
    ];

    ErpPromotionProductReqDto.DeleteRequest req = new ErpPromotionProductReqDto.DeleteRequest(src);

    System.assertEquals(src.Promotion.PromotionNo__c, req.no_prom);
    System.assertEquals(src.Product.ProductCode, req.cd_item);
    System.assertEquals(UserInfo.getUserName(), req.id_delete);
  }

  @IsTest
  static void test_updateRequest_default_assignment() {
    ErpPromotionProductReqDto.UpdateRequest req = new ErpPromotionProductReqDto.UpdateRequest();
    req.no_prom = 'PROM003';
    req.cd_item = 'ITEM003';
    req.id_update = 'updater';

    System.assertEquals('PROM003', req.no_prom);
    System.assertEquals('ITEM003', req.cd_item);
    System.assertEquals('updater', req.id_update);
  }

  @IsTest
  static void test_updateRequestList_fromPromotionProducts() {
    Promotion p = createPromotionRecord();
    Product2 prod = createProduct();
    PromotionProduct inserted = createPromotionProduct(p.Id, prod.Id);

    List<PromotionProduct> srcList = [
      SELECT Id, Promotion.PromotionNo__c, Product.ProductCode
      FROM PromotionProduct
      WHERE Id = :inserted.Id
    ];

    ErpPromotionProductReqDto.UpdateRequestList req = new ErpPromotionProductReqDto.UpdateRequestList(srcList);

    System.assertEquals(1, req.promotionItemList.size());
    System.assertEquals(srcList[0].Promotion.PromotionNo__c, req.promotionItemList[0].no_prom);
    System.assertEquals(srcList[0].Product.ProductCode, req.promotionItemList[0].cd_item);
    System.assertEquals(UserInfo.getUserName(), req.promotionItemList[0].id_update);
  }

  @IsTest
  static void test_deleteRequestList_fromPromotionProducts() {
    Promotion p = createPromotionRecord();
    Product2 prod = createProduct();
    PromotionProduct inserted = createPromotionProduct(p.Id, prod.Id);

    List<PromotionProduct> srcList = [
      SELECT Id, Promotion.PromotionNo__c, Product.ProductCode
      FROM PromotionProduct
      WHERE Id = :inserted.Id
    ];

    ErpPromotionProductReqDto.DeleteRequestList req = new ErpPromotionProductReqDto.DeleteRequestList(srcList);

    System.assertEquals(1, req.promotionItemList.size());
    System.assertEquals(srcList[0].Promotion.PromotionNo__c, req.promotionItemList[0].no_prom);
    System.assertEquals(srcList[0].Product.ProductCode, req.promotionItemList[0].cd_item);
    System.assertEquals(UserInfo.getUserName(), req.promotionItemList[0].id_delete);
  }

  @IsTest
  static void test_helper_dateToYmd() {
    System.assertEquals('', ErpPromotionProductReqDto.dateToYmd(null));
    System.assertEquals('20260309', ErpPromotionProductReqDto.dateToYmd(Date.newInstance(2026, 3, 9)));
  }

  @IsTest
  static void test_helper_dtToYmd() {
    System.assertEquals('', ErpPromotionProductReqDto.dtToYmd(null));
    Datetime dt = Datetime.newInstance(2026, 3, 9, 10, 20, 30);
    System.assertEquals('20260309', ErpPromotionProductReqDto.dtToYmd(dt));
  }

  @IsTest
  static void test_helper_boolToYn() {
    System.assertEquals('Y', ErpPromotionProductReqDto.boolToYn(true));
    System.assertEquals('N', ErpPromotionProductReqDto.boolToYn(false));
    System.assertEquals('N', ErpPromotionProductReqDto.boolToYn(null));
  }

  @IsTest
  static void test_helper_isStrNull() {
    System.assertEquals('', ErpPromotionProductReqDto.isStrNull(null));
    System.assertEquals('', ErpPromotionProductReqDto.isStrNull(''));
    System.assertEquals('', ErpPromotionProductReqDto.isStrNull('   '));
    System.assertEquals('A', ErpPromotionProductReqDto.isStrNull('A'));
  }
}