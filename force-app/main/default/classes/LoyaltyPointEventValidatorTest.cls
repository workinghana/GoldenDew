@IsTest
private class LoyaltyPointEventValidatorTest {
  @IsTest
  static void validateSaleDelete_whenSaleMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleDelete('NO_SUCH_SALE');

    System.assertEquals(false, result.isValid);
    System.assertEquals('SALE_DELETE', result.eventType);
    System.assertEquals('삭제 판매를 찾을 수 없습니다.', result.summary);
  }

  @IsTest
  static void validateReturnCreate_whenReturnMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnCreate('NO_SUCH_RETURN');

    System.assertEquals(false, result.isValid);
    System.assertEquals('RETURN_CREATE', result.eventType);
    System.assertEquals('반품 판매를 찾을 수 없습니다.', result.summary);
  }

  @IsTest
  static void validateSaleDepositDelete_whenDepositMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleDepositDelete('NO_SUCH_DEPOSIT');

    System.assertEquals(false, result.isValid);
    System.assertEquals('SALE_DEPOSIT_DELETE', result.eventType);
    System.assertEquals('삭제 입금 TransactionJournal을 찾을 수 없습니다.', result.summary);
  }

  @IsTest
  static void validateReturnDepositDelete_whenDepositMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnDepositDelete('NO_SUCH_DEPOSIT');

    System.assertEquals(false, result.isValid);
    System.assertEquals('RETURN_DEPOSIT_DELETE', result.eventType);
    System.assertEquals('삭제 입금 TransactionJournal을 찾을 수 없습니다.', result.summary);
  }
}