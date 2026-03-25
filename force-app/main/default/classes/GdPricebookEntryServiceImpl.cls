public with sharing class GdPricebookEntryServiceImpl implements GdPricebookEntryService {
  public GdPricebookEntryServiceImpl() {
  }

  /**
   * 가격 항목 등록 - PricebookEntry 생성
   */
  public ApiResult createPricebookEntryByProduct2(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      Decimal unitPrice = ValidationUtil.decimalValidation(reqData.get('UnitPrice'), 'UnitPrice', true);
      String productId = ValidationUtil.stringValidation(reqData.get('productId'), 'productId', true);
      Boolean isActive = ValidationUtil.booleanValidation(reqData.get('IsActive'), 'IsActive', false);

      List<Pricebook2> pbList = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
      if (pbList.isEmpty()) {
        throw new CustomException(400, '표준 가격표가 없습니다.');
      }
      Pricebook2 pb = pbList[0];

      PricebookEntry pbe = new PricebookEntry();
      pbe.Pricebook2Id = pb.Id;
      pbe.Product2Id = productId;
      pbe.UnitPrice = unitPrice;
      pbe.IsActive = isActive ?? false;

      Database.SaveResult result = Database.insert(pbe);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(pbe));

      return ApiResult.ok(200, '가격 항목 생성 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 가격 항목 수정
   * PricebookEntry update
   */
  public ApiResult updatePricebookEntryByProduct2(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      Decimal unitPrice = ValidationUtil.decimalValidation(reqData.get('UnitPrice'), 'UnitPrice', false);
      String productId = ValidationUtil.stringValidation(reqData.get('productId'), 'productId', true);
      Boolean isActive = ValidationUtil.booleanValidation(reqData.get('IsActive'), 'IsActive', false);

      List<Pricebook2> pbList = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
      if (pbList.isEmpty()) {
        throw new CustomException(400, '표준 가격표가 없습니다.');
      }
      Pricebook2 pb = pbList[0];

      List<PricebookEntry> pbeList = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId AND Pricebook2Id = :pb.Id LIMIT 1];
      if (pbeList.isEmpty()) {
        throw new CustomException(400, '해당 가격 항목이 없습니다.');
      }
      PricebookEntry pbe = pbeList[0];
      if (unitPrice != null) {
        pbe.UnitPrice = unitPrice;
      }
      if (isActive != null) {
        pbe.IsActive = isActive;
      }

      Database.SaveResult result = Database.update(pbe);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      return ApiResult.ok(200, '가격 항목 수정 완료', null);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}