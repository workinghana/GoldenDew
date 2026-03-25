public with sharing class GdReturnServiceImpl implements GdReturnService {
  public enum Status {
    Draft,
    saleSuccess
  }

  /**
   * 반품 등록
   */
  public ApiResult createReturn(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', true); // 반품 번호
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('OriginalOrderId'), 'OriginalOrderId', true); // 원판매 번호
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true); // 등록자

      // 판매번호(SaleNo__c) 중복 체크
      if ([SELECT COUNT() FROM Order WHERE SaleNo__c = :saleNo] > 0) {
        throw new CustomException(400, 'SaleNo__c already exists.');
      }

      // 원판매 번호 조회
      List<Order> originalOrderList = [SELECT Id, AccountId, StoreCode__c, MemberNo__c FROM Order WHERE SaleNo__c = :originalOrderId LIMIT 1];
      if (originalOrderList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 원판매 번호입니다. ' + originalOrderId);
      }

      // Standard Pricebook 조회
      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Order o = new Order();
      o.AccountId = originalOrderList[0].AccountId;
      o.StoreCode__c = originalOrderList[0].StoreCode__c;
      o.SaleStatus__c = '03';
      o.Status = String.valueOf(Status.Draft);
      o.EffectiveDate = Date.today();
      o.MemberNo__c = originalOrderList[0].MemberNo__c;
      o.SaleNo__c = saleNo;
      if (actualPaymentAmount != null) {
        o.ActualPaymentAmount__c = actualPaymentAmount;
      }
      o.Pricebook2Id = standardPricebookId;
      o.InsertId__c = insertId;
      o.IsReductionOrder = true;
      o.OriginalOrderId = originalOrderList[0].Id;

      Database.SaveResult insertResult = Database.insert(o);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      data.put('orderId', o.Id);
      data.put('originalOrderId', originalOrderList[0].Id);

      return ApiResult.ok(200, '반품 등록 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 반품 전체 삭제
   */
  public ApiResult deleteReturn(String saleNo) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Order> oList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 반품 번호입니다. ' + saleNo);
      }

      oList[0].DeleteDateTime__c = System.now();
      oList[0].IsDeleted__c = true;
      oList[0].Status = 'returnDeletedDraft';

      Database.SaveResult result = Database.update(oList[0]);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      data.put('orderId', oList[0].Id);

      return ApiResult.ok(200, '반품 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}