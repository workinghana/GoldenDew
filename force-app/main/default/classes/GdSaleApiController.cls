// ! 사용 x
// @RestResource(urlMapping='/gd/sale')
global with sharing class GdSaleApiController {
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
  //  * 판매 등록
  //  * Order, OrderItem 생성
  //  */
  // @HttpPost
  // global static void createSale() {
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
  //       // Order 생성
  //       reqData.put('orderId', getOrderService().createSale(reqData).data.get('orderId'));
  //     }

  //     {
  //       // OrderItem 생성
  //       getOrderItemService().createSaleItem(reqData);
  //     }

  //     {
  //       // TransactionJournal 생성 - 입금 내역
  //       ApiResult transactionJournalResult = getTransactionJournalService().createSaleDepositHistory(reqData);
  //       if (transactionJournalResult.data.containsKey('DebitPointList')) {
  //         resData.put('DebitPointList', transactionJournalResult.data.get('DebitPointList'));
  //       }
  //       if (transactionJournalResult.data.containsKey('CreditPointList')) {
  //         resData.put('CreditPointList', transactionJournalResult.data.get('CreditPointList'));
  //       }
  //     }

  //     Id orderId = (Id) reqData.get('orderId');
  //     List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
  //     if (oList.isEmpty()) {
  //       throw new CustomException(400, 'order is not found');
  //     }
  //     oList[0].Status = 'saleSuccess';
  //     Database.SaveResult updateResult = Database.update(oList[0]);

  //     if (!updateResult.isSuccess()) {
  //       Database.Error err = updateResult.getErrors()[0];
  //       throw new CustomException(400, err.getMessage());
  //     }

  //     ApiResult result = ApiResult.ok(200, '판매 등록 완료', resData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // /**
  //  * 판매 수정
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
  //       ApiResult orderResult = getOrderService().updateSale(reqData);
  //       reqData.put('orderId', orderResult.data.get('orderId'));
  //     }

  //     {
  //       // OrderItem upsert
  //       if (reqData.containsKey('OrderItem')) {
  //         ApiResult orderItemResult = getOrderItemService().upsertSaleItem(reqData);
  //       }
  //     }

  //     {
  //       // TransactionJournal insert
  //       if (reqData.containsKey('TransactionJournal')) {
  //         ApiResult transactionJournalResult = getTransactionJournalService().insertSaleDepositHistoryByUpdate(reqData);
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

  //     ApiResult result = ApiResult.ok(200, '판매 수정 완료', reqData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // /**
  //  * ! 보류
  //  * 판매 삭제
  //  * Order update
  //  */
  // @HttpPut
  // global static void deleteSale() {
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

  //     // {
  //     //   // Order update
  //     //   reqData.put('orderId', getOrderService().deleteSale(reqData).data.get('orderId'));
  //     // }

  //     // {
  //     //   // OrderItem update
  //     //   getOrderItemService().deleteSaleItem(reqData);
  //     // }

  //     // {
  //     //   // TransactionJournal 생성 - 입금 내역
  //     //   getTransactionJournalService().deleteSaleDepositHistory(reqData);
  //     // }

  //     ApiResult result = ApiResult.ok(200, '판매 삭제 완료', resData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // /**
  //  * 판매 입금 조회
  //  */
  // @HttpGet
  // global static void getSaleDepositList() {
  //   try {
  //     RestRequest req = RestContext.request;

  //     String saleNo = ValidationUtil.stringValidation(req.params.get('saleNo'), 'saleNo', true);

  //     ApiResult result = getTransactionJournalService().getSaleDepositList(saleNo);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (ValidationException ve) {
  //     RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, null, 500);
  //   }
  // }

  // /**
  //  * ERP 포인트 적립 DTO
  //  */
  // public class PointCreditDTO {
  //   public String CD_JOURNAL; // 로열티 생성 키값
  //   public String CD_TYPE_POINT; // 포인트 구분
  //   public String NO_MBR; // 회원번호
  //   public String NO_SAL; // 판매번호
  //   public Decimal AM_SAL; // 판매 금액
  //   public Decimal PT_TARGET; // 적립 포인트
  //   public String DT_SAVE_PLAN; // 해당 포인트 적립 예정일
  //   public String DT_LIMIT_START; // 포인트 유효기간 시작일
  //   public String DT_LIMIT_END; // 포인트 유효기간 종료일
  //   public String DT_DESTROY_PLAN; // 소멸 예정일
  //   public String DTS_INSERT; // 등록일자
  //   public String ID_INSERT; // 등록자
  //   public String CD_TYPE_SAVE; // 적립구분
  //   public String NO_PROM_MBR; // 프로모션 번호
  //   public String TX_REMARK; // 비고
  //   public String NO_GRADE_ADVAN; // 승급번호
  // }

  // # 사용 중
  // /**
  //  * ERP 포인트 사용/소멸 DTO
  //  */
  public class PointDebitDTO {
    public String CD_LEDGER; // 로열티 소멸 키값
    public String CD_JOURNAL; // 로열티 생성 키값
    public String CD_TYPE_POINT; // 포인트 구분
    public String CD_RESON; // 회원포인트소진구분
    public String NO_MBR; // 회원번호
    public String NO_SAL; // 판매처리된 번호
    public Decimal AM_SAL; // 판매처리된 판매의 금액
    public Decimal PT_USE; // 사용처리된 금액
    public String DTS_INSERT; // 등록일자
    public String ID_INSERT; // 등록자
    public String NO_SAL_RTN; //  판매 반품번호
  }
}