// ! 사용 x
// 교환 반품 API 컨트롤러
// @RestResource(urlMapping='/gd/exchangeReturn')
global with sharing class GdExchangeReturnApiController {
  // private static GdOrderService orderService;
  // private static GdOrderItemService orderItemService;
  // private static GdTransactionJournalService transactionJournalService;
  // private static GdVoucherService voucherService;

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setOrderService(GdOrderService mock) {
  //   orderService = mock;
  // }

  // private static GdOrderService getOrderService() {
  //   if (orderService == null)
  //     orderService = new GdOrderServiceImpl();
  //   return orderService;
  // }

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setOrderItemService(GdOrderItemService mock) {
  //   orderItemService = mock;
  // }

  // private static GdOrderItemService getOrderItemService() {
  //   if (orderItemService == null)
  //     orderItemService = new GdOrderItemServiceImpl();
  //   return orderItemService;
  // }

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setTransactionJournalService(GdTransactionJournalService mock) {
  //   transactionJournalService = mock;
  // }

  // private static GdTransactionJournalService getTransactionJournalService() {
  //   if (transactionJournalService == null)
  //     transactionJournalService = new GdTransactionJournalServiceImpl();
  //   return transactionJournalService;
  // }

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setVoucherService(GdVoucherService mock) {
  //   voucherService = mock;
  // }

  // private static GdVoucherService getVoucherService() {
  //   if (voucherService == null)
  //     voucherService = new GdVoucherServiceImpl();
  //   return voucherService;
  // }

  // /**
  //  * 주문 등록
  //  * Order insert
  //  * OrderItem insert
  //  * TransactionJournal insert
  //  */
  // @HttpPost
  // global static void createOrder() {
  //   RestRequest req = RestContext.request;
  //   Savepoint sp = Database.setSavepoint();
  //   try {
  //     String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
  //     if (String.isBlank(raw)) {
  //       throw new CustomException(400, '요청 본문이 비었습니다.');
  //     }

  //     Map<String, Object> reqData;
  //     Map<String, Object> resData;
  //     try {
  //       reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //       resData = reqData;
  //     } catch (Exception e) {
  //       throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
  //     }

  //     {
  //       // Order insert
  //       ApiResult orderResult = getOrderService().createOrder(reqData);
  //       reqData.put('orderId', orderResult.data.get('orderId'));
  //     }

  //     {
  //       // OrderItem insert
  //       getOrderItemService().createOrderItem(reqData);
  //     }

  //     {
  //       // TransactionJournal insert - 입금 내역
  //       resData.put('DebitPointList', getTransactionJournalService().createOrderDepositHistory(reqData).data.get('DebitPointList'));
  //     }

  //     ApiResult result = ApiResult.ok(200, '주문 등록 완료', resData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // /**
  //  * 주문 수정
  //  * Order update
  //  * OrderItem update
  //  * TransactionJournal upsert
  //  */
  // @HttpPatch
  // global static void updateOrder() {
  //   RestRequest req = RestContext.request;
  //   Savepoint sp = Database.setSavepoint();
  //   try {
  //     String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
  //     if (String.isBlank(raw)) {
  //       throw new CustomException(400, '요청 본문이 비었습니다.');
  //     }

  //     Map<String, Object> reqData;
  //     Map<String, Object> resData;
  //     try {
  //       reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //       resData = reqData;
  //     } catch (Exception e) {
  //       throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
  //     }

  //     {
  //       // Order update
  //       ApiResult orderResult = getOrderService().updateOrder(reqData);
  //       reqData.put('orderId', orderResult.data.get('orderId'));
  //     }

  //     {
  //       // OrderItem upsert
  //       if (reqData.containsKey('OrderItem')) {
  //         ApiResult orderItemResult = getOrderItemService().upsertOrderItem(reqData);
  //       }
  //     }

  //     {
  //       // TransactionJournal insert
  //       if (reqData.containsKey('TransactionJournal')) {
  //         ApiResult transactionJournalResult = getTransactionJournalService().insertOrderDepositHistoryByUpdate(reqData);
  //         if (transactionJournalResult.data.containsKey('CancelPointList')) {
  //           resData.put('CancelPointList', transactionJournalResult.data.get('CancelPointList'));
  //         }
  //         if (transactionJournalResult.data.containsKey('DebitPointList')) {
  //           resData.put('DebitPointList', transactionJournalResult.data.get('DebitPointList'));
  //         }
  //       }
  //     }

  //     ApiResult result = ApiResult.ok(200, '주문 수정 완료', reqData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // /**
  //  * ! 보류
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