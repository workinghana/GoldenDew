/**
 * 판매 등록, 수정, 전체 삭제에 관한 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 */
@RestResource(urlMapping='/gd/v1/sale')
global with sharing class GdSaleApiControllerV1 {
  private static GdOrderService orderService;
  private static GdSaleService saleService;
  private static GdOrderItemService orderItemService;
  private static GdSaleItemService saleItemService;
  private static GdVoucherService voucherService;
  private static GdSaleDepositService saleDepositService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setOrderService(GdOrderService mock) {
    orderService = mock;
  }

  private static GdOrderService getOrderService() {
    if (orderService == null) {
      orderService = new GdOrderServiceImpl();
    }
    return orderService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setSaleService(GdSaleService mock) {
    saleService = mock;
  }

  private static GdSaleService getSaleService() {
    if (saleService == null) {
      saleService = new GdSaleServiceImpl();
    }
    return saleService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setOrderItemService(GdOrderItemService mock) {
    orderItemService = mock;
  }

  private static GdOrderItemService getOrderItemService() {
    if (orderItemService == null) {
      orderItemService = new GdOrderItemServiceImpl();
    }
    return orderItemService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setSaleItemService(GdSaleItemService mock) {
    saleItemService = mock;
  }

  private static GdSaleItemService getSaleItemService() {
    if (saleItemService == null) {
      saleItemService = new GdSaleItemServiceImpl();
    }
    return saleItemService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  @TestVisible
  private static GdVoucherService getVoucherService() {
    if (voucherService == null) {
      voucherService = new GdVoucherServiceImpl();
    }
    return voucherService;
  }

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
   * 판매 등록
   * @throws CustomException
   */
  @HttpPost
  global static void createSale() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdSaleApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      {
        // Order 생성

        ApiResult orderResult = getOrderService().createSale(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
        reqData.put('storeTypeFour', orderResult.data.get('storeTypeFour'));
      }

      {
        // OrderItem 생성
        ApiResult orderItemResult = getOrderItemService().createSaleItem(reqData);
        reqData.put('oiList', orderItemResult.data.get('oiList'));
      }

      {
        // TransactionJournal 생성 - 입금 내역
        ApiResult transactionJournalResult = getSaleDepositService().createSaleDepositHistory(reqData);
        if (transactionJournalResult.data.containsKey('DebitPointList')) {
          resData.put('DebitPointList', transactionJournalResult.data.get('DebitPointList'));
        }
        if (transactionJournalResult.data.containsKey('CreditPointList')) {
          resData.put('CreditPointList', transactionJournalResult.data.get('CreditPointList'));
        }
      }

      Id orderId = (Id) reqData.get('orderId');
      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        logger.setErrorCode('ORDER_NOT_FOUND');
        logger.setErrorMessage('order is not found');
        throw new CustomException(400, 'order is not found');
      }
      oList[0].Status = 'saleSuccess';
      Database.SaveResult updateResult = Database.update(oList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }

      ApiResult result = ApiResult.ok(200, '판매 등록 완료', resData);

      RestResponseUtil.handleSuccess(result, logger);
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

  /**
   * 판매 수정
   * @throws CustomException
   */
  @HttpPatch
  global static void updateSale() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdSaleApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      {
        // Order update
        ApiResult orderResult = getOrderService().updateSale(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
      }

      {
        // OrderItem upsert
        if (reqData.containsKey('OrderItem')) {
          ApiResult orderItemResult = getOrderItemService().upsertSaleItem(reqData);
        }
      }

      {
        // TransactionJournal insert
        if (reqData.containsKey('TransactionJournal')) {
          ApiResult saleDepositResult = getSaleDepositService().upsertSaleDeposit(reqData);
          if (saleDepositResult.data.containsKey('CancelPointList')) {
            resData.put('CancelPointList', saleDepositResult.data.get('CancelPointList'));
          }
          if (saleDepositResult.data.containsKey('DebitPointList')) {
            resData.put('DebitPointList', saleDepositResult.data.get('DebitPointList'));
          }
          if (saleDepositResult.data.containsKey('CreditPointList')) {
            resData.put('CreditPointList', saleDepositResult.data.get('CreditPointList'));
          }
        }
      }

      ApiResult result = ApiResult.ok(200, '판매 수정 완료', reqData);

      RestResponseUtil.handleSuccess(result, logger);
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

  /**
   * 판매 전체 삭제
   * Order update
   */
  @HttpDelete
  global static void deleteSale() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdSaleApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Map<String, Object> resData = new Map<String, Object>();
    Savepoint sp = Database.setSavepoint();
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String saleNo = ValidationUtil.stringValidationEx(req.params.get('SaleNo__c'), 'SaleNo__c', true, false);

      // Order update
      ApiResult saleResult = getSaleService().deleteSale(saleNo);

      Id orderId = (Id) ValidationUtil.stringValidationEx(saleResult.data.get('orderId'), 'orderId', true, false);

      // OrderItem update
      getSaleItemService().deleteSaleItem(orderId);

      // 판매 입금 전체 삭제 할 때 입금 건들에 대한 포인트 사용 취소, 포인트 적립 취소 로직이 필요함
      ApiResult saleDepositResult = getSaleDepositService().deleteAllSaleDeposits(orderId);

      resData.put('CancelPointList', saleDepositResult.data.get('pointRedemptionCanceled'));
      resData.put('CancelPointsCreditedList', saleDepositResult.data.get('purchasePointAccrualCanceled'));
      resData.put('CancelCoupon', saleDepositResult.data.get('couponCanceled'));

      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        logger.setErrorCode('ORDER_NOT_FOUND');
        logger.setErrorMessage('order is not found');
        throw new CustomException(400, 'order is not found');
      }
      oList[0].Status = 'saleDeleted';
      Database.SaveResult updateResult = Database.update(oList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }

      ApiResult result = ApiResult.ok(200, '판매 전체 삭제 완료', resData);

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
}