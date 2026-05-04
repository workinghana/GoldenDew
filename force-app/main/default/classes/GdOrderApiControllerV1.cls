/**
 * 주문 등록, 수정에 관한 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 */
@RestResource(urlMapping='/gd/v1/order')
global with sharing class GdOrderApiControllerV1 {
  private static GdOrderService orderService;
  private static GdOrderItemService orderItemService;
  private static GdTransactionJournalService transactionJournalService;
  private static GdVoucherService voucherService;
  private static GdOrderDepositService orderDepositService;

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
  private static void setOrderItemService(GdOrderItemService mock) {
    orderItemService = mock;
  }

  private static GdOrderItemService getOrderItemService() {
    if (orderItemService == null) {
      orderItemService = new GdOrderItemServiceImpl();
    }
    return orderItemService;
  }

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setTransactionJournalService(GdTransactionJournalService mock) {
  //   transactionJournalService = mock;
  // }

  // private static GdTransactionJournalService getTransactionJournalService() {
  //   if (transactionJournalService == null) {
  //     transactionJournalService = new GdTransactionJournalServiceImpl();
  //   }
  //   return transactionJournalService;
  // }

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  private static GdVoucherService getVoucherService() {
    if (voucherService == null) {
      voucherService = new GdVoucherServiceImpl();
    }
    return voucherService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setOrderDepositService(GdOrderDepositService mock) {
    orderDepositService = mock;
  }

  private static GdOrderDepositService getOrderDepositService() {
    if (orderDepositService == null) {
      orderDepositService = new GdOrderDepositServiceImpl();
    }
    return orderDepositService;
  }

  /**
   * 주문 등록
   * @throws CustomException
   */
  @HttpPost
  global static void createOrder() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdOrderApiControllerV1.class.getName());

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
        // Order insert
        ApiResult orderResult = getOrderService().createOrder(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
        reqData.put('storeTypeFour', orderResult.data.get('storeTypeFour'));
        reqData.put('storeType', orderResult.data.get('storeType'));
      }

      {
        // OrderItem insert
        ApiResult orderItemResult = getOrderItemService().createOrderItem(reqData);
        reqData.put('oiList', orderItemResult.data.get('oiList'));
        reqData.put('isGoldenBar', orderItemResult.data.get('isGoldenBar'));
      }

      {
        // TransactionJournal insert - 입금 내역
        // resData.put('DebitPointList', getTransactionJournalService().createOrderDepositHistory(reqData).data.get('DebitPointList'));
        resData.put('DebitPointList', getOrderDepositService().createOrderDepositHistory(reqData).data.get('DebitPointList'));
      }

      Id orderId = (Id) reqData.get('orderId');
      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        logger.setErrorCode('ORDER_NOT_FOUND');
        logger.setErrorMessage('order is not found');
        throw new CustomException(400, 'order is not found');
      }
      oList[0].Status = 'orderSuccess';
      Database.SaveResult updateResult = Database.update(oList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }

      ApiResult result = ApiResult.ok(200, '주문 등록 완료', resData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
  }

  /**
   * 주문 수정
   * @throws CustomException
   */
  @HttpPatch
  global static void updateOrder() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdOrderApiControllerV1.class.getName());

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
        ApiResult orderResult = getOrderService().updateOrder(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
      }

      {
        // OrderItem upsert
        if (reqData.containsKey('OrderItem')) {
          ApiResult orderItemResult = getOrderItemService().upsertOrderItem(reqData);
        }
      }

      {
        if (reqData.containsKey('TransactionJournal')) {
          ApiResult transactionJournalResult = getOrderDepositService().upsertOrderDeposit(reqData);
          if (transactionJournalResult.data.containsKey('CancelPointList')) {
            resData.put('CancelPointList', transactionJournalResult.data.get('CancelPointList'));
          }
          if (transactionJournalResult.data.containsKey('DebitPointList')) {
            resData.put('DebitPointList', transactionJournalResult.data.get('DebitPointList'));
          }
        }
      }

      ApiResult result = ApiResult.ok(200, '주문 수정 완료', reqData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
  }

  // /**
  //  * ! 사용 x
  //  * 주문 취소
  //  * Order update
  //  * OrderItem update
  //  */
  // @HttpPut
  // global static void cancelOrder() {
  //   RestRequest req = RestContext.request;
  //   Savepoint sp = Database.setSavepoint();
  //   try {
  //     String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
  //     if (String.isBlank(raw)) {
  //       throw new CustomException(400, '요청 본문이 비었습니다.');
  //     }

  //     Map<String, Object> reqData;
  //     try {
  //       reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //     } catch (Exception e) {
  //       throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
  //     }
  //     Map<String, Object> resData = reqData;

  //     {
  //       // Order update
  //       reqData.put('orderId', getOrderService().updateOrder(reqData).data.get('orderId'));
  //     }

  //     {
  //       // OrderItem upsert
  //       if (reqData.containsKey('OrderItem')) {
  //         getOrderItemService().upsertOrderItem(reqData);
  //       }
  //     }

  //     {
  //       // TransactionJournal insert - 입금 내역
  //       getTransactionJournalService().createOrderDepositHistory(reqData);
  //     }

  //     ApiResult result = ApiResult.ok(200, '주문 취소 완료', resData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // /**
  //  * ! 이관 대상 -> 사용 x
  //  * 주문 입금 조회
  //  */
  // @HttpGet
  // global static void getOrderDepositList() {
  //   try {
  //     RestRequest req = RestContext.request;

  //     String orderNo = ValidationUtil.stringValidation(req.params.get('orderNo'), 'orderNo', true);

  //     ApiResult result = getTransactionJournalService().getOrderDepositList(orderNo);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (ValidationException ve) {
  //     RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, null, 500);
  //   }
  // }
}