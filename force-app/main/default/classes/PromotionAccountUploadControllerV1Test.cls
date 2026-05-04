@IsTest
private class PromotionAccountUploadControllerV1Test {
  private static String uniq(String prefix) {
    return prefix + String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  @TestSetup
  static void setup() {
    String key = uniq('PAU');

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

    insert new List<Account>{
      new Account(Name = 'Upload Store 1 ' + key, CompanyCode__c = '1000', StoreCode__c = 'STR-' + key + '-1'),
      new Account(Name = 'Upload Store 2 ' + key, CompanyCode__c = '1000', StoreCode__c = 'STR-' + key + '-2')
    };
  }

  private static String toBase64(String csvText) {
    return EncodingUtil.base64Encode(Blob.valueOf(csvText));
  }

  @IsTest
  static void testParseUploadFileSuccess() {
    Promotion promotion = [SELECT Id, PromotionNo__c FROM Promotion LIMIT 1];
    Account accountRecord = [SELECT StoreCode__c, Name FROM Account ORDER BY CreatedDate ASC LIMIT 1];

    String csvText = 'StoreCode' + '\n' + accountRecord.StoreCode__c;

    Test.startTest();
    PromotionAccountUploadControllerV1.UploadPreviewResult result = PromotionAccountUploadControllerV1.parseUploadFile(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
    System.assertEquals(1, result.previewRows.size());
    System.assertEquals(accountRecord.StoreCode__c, result.previewRows[0].storeCode);
    System.assertEquals(accountRecord.Name, result.previewRows[0].storeName);
    System.assertEquals(promotion.PromotionNo__c, result.previewRows[0].promotionNo);
  }

  @IsTest
  static void testParseUploadFileInvalidAndDuplicateRows() {
    Promotion promotion = [SELECT Id FROM Promotion LIMIT 1];
    Account accountRecord = [SELECT StoreCode__c, Name FROM Account ORDER BY CreatedDate ASC LIMIT 1];

    String csvText = 'StoreCode' + '\n' + accountRecord.StoreCode__c + '\n' + accountRecord.StoreCode__c + '\n' + 'NOT-FOUND';

    Test.startTest();
    PromotionAccountUploadControllerV1.UploadPreviewResult result = PromotionAccountUploadControllerV1.parseUploadFile(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(2, result.failCount);

    PromotionAccountUploadControllerV1.RowErrorDTO duplicateError;
    for (PromotionAccountUploadControllerV1.RowErrorDTO errorRow : result.errors) {
      if (errorRow.storeCode == accountRecord.StoreCode__c) {
        duplicateError = errorRow;
        break;
      }
    }

    System.assertNotEquals(null, duplicateError);
    System.assertEquals(accountRecord.Name, duplicateError.storeName);
  }

  @IsTest
  static void testInsertPromotionAccountsSuccess() {
    Promotion promotion = [SELECT Id FROM Promotion LIMIT 1];
    Account accountRecord = [SELECT Id, StoreCode__c FROM Account ORDER BY CreatedDate ASC LIMIT 1];

    String csvText = 'StoreCode' + '\n' + accountRecord.StoreCode__c;

    Test.startTest();
    PromotionAccountUploadControllerV1.UploadResult result = PromotionAccountUploadControllerV1.insertPromotionAccounts(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
    System.assertEquals(1, [SELECT COUNT() FROM PromotionAccount__c WHERE PromotionId__c = :promotion.Id AND AccountId__c = :accountRecord.Id]);
  }

  @IsTest
  static void testInsertPromotionAccountsExistingDuplicate() {
    Promotion promotion = [SELECT Id FROM Promotion LIMIT 1];
    Account accountRecord = [SELECT Id, StoreCode__c FROM Account ORDER BY CreatedDate ASC LIMIT 1];

    insert new PromotionAccount__c(PromotionId__c = promotion.Id, AccountId__c = accountRecord.Id);

    String csvText = 'StoreCode' + '\n' + accountRecord.StoreCode__c;

    Test.startTest();
    PromotionAccountUploadControllerV1.UploadResult result = PromotionAccountUploadControllerV1.insertPromotionAccounts(
      toBase64(csvText),
      promotion.Id
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(0, result.successCount);
    System.assert(result.failCount > 0);
  }
}