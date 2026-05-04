@IsTest
private class PromotionProductUploadControllerV1Test {
  private static String uniq(String prefix) {
    return prefix + String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  @TestSetup
  static void setup() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());

    String key = uniq('PPU');

    insert new Promotion(
      Name = 'Upload Promo ' + key,
      BrandCode__c = '01',
      TypeCode__c = '01',
      StatusCode__c = '01',
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(30),
      InsertId__c = 'I' + key,
      ResponId__c = 'R' + key
    );

    insert new List<Product2>{
      new Product2(Name = 'Upload Product 1 ' + key, ProductCode = 'PRD-' + key + '-1', IsActive = true),
      new Product2(Name = 'Upload Product 2 ' + key, ProductCode = 'PRD-' + key + '-2', IsActive = true)
    };
  }

  private static String toBase64(String csvText) {
    return EncodingUtil.base64Encode(Blob.valueOf(csvText));
  }

  private static List<Product2> createExtraProducts(Integer count) {
    String key = uniq('EXTRA');
    List<Product2> products = new List<Product2>();
    for (Integer i = 1; i <= count; i++) {
      products.add(new Product2(Name = 'Upload Extra Product ' + key + '-' + i, ProductCode = 'PRD-' + key + '-' + i, IsActive = true));
    }
    insert products;
    return products;
  }

  @IsTest
  static void testParseUploadFile_success() {
    Promotion promotion = [SELECT Id, PromotionNo__c FROM Promotion LIMIT 1];
    Product2 product = [SELECT ProductCode, Name FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    String csvText = 'ProductCode' + '\n' + product.ProductCode;

    Test.startTest();
    PromotionProductUploadControllerV1.UploadPreviewResult result = PromotionProductUploadControllerV1.parseUploadFile(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
    System.assertEquals(1, result.previewRows.size());
    System.assertEquals(product.ProductCode, result.previewRows[0].productCode);
    System.assertEquals(product.Name, result.previewRows[0].productName);
    System.assertEquals(promotion.PromotionNo__c, result.previewRows[0].promotionNo);
  }

  @IsTest
  static void testParseUploadFile_invalidAndDuplicateRows() {
    Promotion promotion = [SELECT Id FROM Promotion LIMIT 1];
    Product2 product = [SELECT ProductCode, Name FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    String csvText = 'ProductCode' + '\n' + product.ProductCode + '\n' + product.ProductCode + '\n' + 'NOT-FOUND';

    Test.startTest();
    PromotionProductUploadControllerV1.UploadPreviewResult result = PromotionProductUploadControllerV1.parseUploadFile(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(2, result.failCount);

    PromotionProductUploadControllerV1.RowErrorDTO duplicateError;
    for (PromotionProductUploadControllerV1.RowErrorDTO errorRow : result.errors) {
      if (errorRow.productCode == product.ProductCode) {
        duplicateError = errorRow;
        break;
      }
    }

    System.assertNotEquals(null, duplicateError);
    System.assertEquals(product.Name, duplicateError.productName);
  }

  @IsTest
  static void testInsertPromotionProducts_success() {
    Promotion promotion = [SELECT Id FROM Promotion LIMIT 1];
    Product2 product = [SELECT Id, ProductCode FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    String csvText = 'ProductCode' + '\n' + product.ProductCode;

    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    Test.startTest();
    PromotionProductUploadControllerV1.UploadResult result = PromotionProductUploadControllerV1.insertPromotionProducts(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
    System.assertEquals(1, [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :promotion.Id AND ProductId = :product.Id]);
  }

  @IsTest
  static void testInsertPromotionProducts_existingDuplicate() {
    Promotion promotion = [SELECT Id FROM Promotion LIMIT 1];
    Product2 product = [SELECT Id, ProductCode FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    insert new PromotionProduct(PromotionId = promotion.Id, ProductId = product.Id);

    String csvText = 'ProductCode' + '\n' + product.ProductCode;

    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    Test.startTest();
    PromotionProductUploadControllerV1.UploadResult result = PromotionProductUploadControllerV1.insertPromotionProducts(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(0, result.successCount);
    System.assert(result.failCount > 0);
  }

  @IsTest
  static void testInsertPromotionProducts_bulkInsert() {
    Promotion promotion = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = createExtraProducts(3);
    List<String> lines = new List<String>{ 'ProductCode' };
    for (Product2 product : products) {
      lines.add(product.ProductCode);
    }

    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    PromotionProductUploadControllerV1.UploadResult result;
    Test.startTest();
    result = PromotionProductUploadControllerV1.insertPromotionProducts(toBase64(String.join(lines, '\n')), promotion.Id);
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(3, result.successCount);
    System.assertEquals(0, result.failCount);
    System.assertEquals(3, result.insertedIds.size());
    System.assertEquals(3, [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :promotion.Id]);
  }
}