/**
 *  판매 입금 관련 API 컨트롤러
 */
@RestResource(urlMapping='/gd/v1/sale/deposit')
global with sharing class GdSaleDepositApiControllerV1 {
  private static GdSaleDepositService saleDepositService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setSaleDepositService(GdSaleDepositService mock) {
    saleDepositService = mock;
  }

  private static GdSaleDepositService getSaleDepositService() {
    if (saleDepositService == null) {
      saleDepositService = new GdSaleDepositServiceImpl();
    }
    return saleDepositService;
  }

  /**
   * ! 보류
   * 판매 입금 등록
   */
  @HttpPost
  global static void createSaleDeposit() {
    // RestRequest req = RestContext.request;
    // Savepoint sp = Database.setSavepoint();
    // try {
    //   String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
    //   if (String.isBlank(raw)) {
    //     throw new CustomException(400, '요청 본문이 비었습니다.');
    //   }

    //   Map<String, Object> reqData;
    //   Map<String, Object> resData;
    //   try {
    //     reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
    //     resData = reqData;
    //   } catch (Exception e) {
    //     throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
    //   }

    //   {
    //     // Order insert
    //     ApiResult orderResult = getOrderService().createOrder(reqData);
    //     reqData.put('orderId', orderResult.data.get('orderId'));
    //   }

    //   {
    //     // OrderItem insert
    //     getOrderItemService().createOrderItem(reqData);
    //   }

    //   {
    //     // TransactionJournal insert - 입금 내역
    //     resData.put('DebitPointList', getTransactionJournalService().createOrderDepositHistory(reqData).data.get('DebitPointList'));
    //   }

    //   ApiResult result = ApiResult.ok(200, '주문 등록 완료', resData);

    //   RestResponseUtil.handleSuccess(result);
    // } catch (CustomException ce) {
    //   RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    // } catch (Exception e) {
    //   RestResponseUtil.handleException(e, sp, 500);
    // }
  }

  /**
   * ! 사용 X
   * * 개발 완료
   * 판매 입금 조회
   */
  @HttpGet
  global static void getSaleDepositList() {
    try {
      RestRequest req = RestContext.request;

      String saleNo = ValidationUtil.stringValidation(req.params.get('saleNo'), 'saleNo', true);

      ApiResult result = getSaleDepositService().getSaleDepositList(saleNo);

      RestResponseUtil.handleSuccess(result);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500);
    }
  }

  /**
   * ! 보류
   * 판매 입금 수정
   */
  @HttpPatch
  global static void updateSaleDeposit() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      //   ApiResult result = getOrderDepositService().createOrderDepositHistory(reqData);

      //   RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }

  /**
   * * 개발 완료
   * 판매 입금 삭제
   */
  @HttpDelete
  global static void deleteSaleDeposit() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdSaleDepositApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Map<String, Object> resData = new Map<String, Object>();
    Savepoint sp = Database.setSavepoint();
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String depositNo = ValidationUtil.stringValidationEx(req.params.get('DepositNo__c'), 'DepositNo__c', true, false); // 입금 번호
      String deposiSeqNo = ValidationUtil.stringValidationEx(req.params.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true, false); // 입금 일련 번호

      depositNo += '-' + deposiSeqNo;

      ApiResult saleDepositResult = getSaleDepositService().deleteSaleDeposit(depositNo);

      resData.put('CancelPointList', saleDepositResult.data.get('pointRedemptionCanceled'));
      resData.put('CancelPointsCreditedList', saleDepositResult.data.get('purchasePointAccrualCanceled'));
      resData.put('CancelCoupon', saleDepositResult.data.get('couponCanceled'));

      ApiResult result = ApiResult.ok(200, '판매 입금 삭제 삭제 완료', resData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }

  public class DepositResponseDTO {
    public String CD_TYPE_APPR; // 결제 구분
    public Decimal AM_DEPOSIT; // 금액
    public String NO_COUPON_ALL; // 쿠폰 코드
    public String NM_COUPON; // 쿠폰명
    public Date DT_EXP; // 만료 날짜
    public Integer RT_DISC; // 할인율
    public Decimal AM_DISC; // 할인 금액
    public String TX_REMARK; // 비고
  }
}