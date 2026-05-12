public with sharing class GdReturnServiceImpl implements GdReturnService {
  public enum Status {
    Draft,
    saleSuccess
  }

  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

  private static void logTiming(String label, Long startMs, Integer startCpu) {
    Long elapsedMs = Datetime.now().getTime() - startMs;
    Integer elapsedCpu = Limits.getCpuTime() - startCpu;
    System.debug(LoggingLevel.WARN, '[TIMING] ' + label + ' | 누적 ' + elapsedMs + 'ms | CPU ' + elapsedCpu + 'ms');
  }

  /**
   * 반품 등록
   */
  public ApiResult createReturn(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
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
      logTiming('GdReturnServiceImpl.createReturn.loadOrderContext', totalStartMs, totalStartCpu);

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
      o.IsReductionOrder__c = true;
      o.OriginalOrderId__c = originalOrderList[0].Id;

      // [Return Register Validation Removed 2026-05-08]
      //   기존: A판매 OrderId 의 모든 적립 LL 의 사용 LLT 가 있으면 차단.
      //   문제: A판매 입금 중 적립 대상 아닌 입금 (쿠폰/포인트/상품권 등) 만 환불하려는 부분 반품도 부당 차단.
      //         예: A판매 = 현금 + 포인트 + 쿠폰 결제 → 쿠폰만 환불 시 적립 영향 없으나 차단됨.
      //   해결: createReturn 단계 검증 제거. 검증을 insertSaleDepositHistoryByUpdate (반품 입금 등록) 단계로 이전.
      //         그 단계에서 sourceTj.PaymentMethod 가 적립 대상인 경우만 검증 → 입금별 차별 가능.

      Database.SaveResult insertResult = Database.insert(o);
      logTiming('GdReturnServiceImpl.createReturn.insertOrder', totalStartMs, totalStartCpu);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      data.put('orderId', o.Id);
      data.put('originalOrderId', originalOrderList[0].Id);
      logTiming('GdReturnServiceImpl.createReturn.total', totalStartMs, totalStartCpu);

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