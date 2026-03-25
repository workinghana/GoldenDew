/**
 * ! 사용 x
 * 판매/교환 반품 관련 API 컨트롤러
 */
// @RestResource(urlMapping='/gd/return/*')
global with sharing class GdReturnApiController {
  // private static GdReturnService returnService;
  // private static GdReturnItemService returnItemService;
  // private static GdTransactionJournalService transactionJournalService;
  // private static GdReturnDepositService returnDepositService;

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setReturnService(GdReturnService mock) {
  //   returnService = mock;
  // }

  // private static GdReturnService getReturnService() {
  //   if (returnService == null)
  //     returnService = new GdReturnServiceImpl();
  //   return returnService;
  // }

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setReturnItemService(GdReturnItemService mock) {
  //   returnItemService = mock;
  // }

  // private static GdReturnItemService getReturnItemService() {
  //   if (returnItemService == null)
  //     returnItemService = new GdReturnItemServiceImpl();
  //   return returnItemService;
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
  // private static void setReturnDepositService(GdReturnDepositService mock) {
  //   returnDepositService = mock;
  // }

  // private static GdReturnDepositService getReturnDepositService() {
  //   if (returnDepositService == null)
  //     returnDepositService = new GdReturnDepositServiceImpl();
  //   return returnDepositService;
  // }

  // /**
  //  * [판매반품, 교환반품] 반품 등록 API
  //  */
  // @HttpPost
  // global static void createReturn() {
  //   RestRequest req = RestContext.request;
  //   Savepoint sp = Database.setSavepoint();
  //   try {
  //     String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
  //     if (String.isBlank(raw)) {
  //       throw new CustomException(400, '요청 본문이 비었습니다.');
  //     }

  //     Map<String, Object> reqData;
  //     Map<String, Object> resData = new Map<String, Object>();
  //     try {
  //       reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //       resData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //     } catch (Exception e) {
  //       throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
  //     }

  //     {
  //       // Order insert
  //       ApiResult orderResult = getReturnService().createReturn(reqData);
  //       reqData.put('orderId', orderResult.data.get('orderId'));
  //       reqData.put('originalOrderId', orderResult.data.get('originalOrderId'));
  //     }

  //     {
  //       // OrderItem upsert
  //       if (reqData.containsKey('OrderItem')) {
  //         ApiResult orderItemResult = getReturnItemService().createReturnItem(reqData);
  //       }
  //     }

  //     {
  //       // TransactionJournal insert
  //       if (reqData.containsKey('TransactionJournal')) {
  //         ApiResult transactionJournalResult = getReturnDepositService().insertSaleDepositHistoryByUpdate(reqData);
  //         if (transactionJournalResult.data.containsKey('CancelPointList')) {
  //           resData.put('CancelPointList', transactionJournalResult.data.get('CancelPointList'));
  //         }
  //         if (transactionJournalResult.data.containsKey('DebitPointList')) {
  //           resData.put('DebitPointList', transactionJournalResult.data.get('DebitPointList'));
  //         }
  //         if (transactionJournalResult.data.containsKey('CreditPointList')) {
  //           resData.put('CreditPointList', transactionJournalResult.data.get('CreditPointList'));
  //         }
  //       }
  //     }

  //     Id orderId = (Id) reqData.get('orderId');
  //     List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
  //     if (oList.isEmpty()) {
  //       throw new CustomException(400, 'order is not found');
  //     }
  //     oList[0].Status = 'returnSuccess';
  //     Database.SaveResult updateResult = Database.update(oList[0]);

  //     if (!updateResult.isSuccess()) {
  //       Database.Error err = updateResult.getErrors()[0];
  //       throw new CustomException(400, err.getMessage());
  //     }

  //     ApiResult result = ApiResult.ok(200, '반품 등록 완료', reqData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // @HttpGet
  // global static void doGet() {
  //   RestRequest req = RestContext.request;
  //   try {
  //     String subPath = req.requestURI.substringAfter('/gd/return/');
  //     String saleNo = ValidationUtil.stringValidationEx(req.params.get('SaleNo__c'), 'SaleNo__c', true, false); // 반품 번호

  //     if ('coupon'.equals(subPath)) {
  //       ApiResult result = ApiResult.ok(200, '반품 쿠폰 조회 성공', null);

  //       RestResponseUtil.handleSuccess(result);
  //     } else if ('point'.equals(subPath)) {
  //       ApiResult result = ApiResult.ok(200, '반품 포인트 조회 성공', null);

  //       RestResponseUtil.handleSuccess(result);
  //     } else {
  //       throw new CustomException(500, 'subPath is not found');
  //     }
  //   } catch (ValidationException ve) {
  //     RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, null, 500);
  //   }
  // }
}