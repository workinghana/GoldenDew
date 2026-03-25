// ! 사용 x
/**
 * 주문 입금 관련 API 컨트롤러
 */
// @RestResource(urlMapping='/gd/order/deposit')
global with sharing class GdOrderDepositApiController {
  // private static GdOrderDepositService orderDepositService;

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setOrderDepositService(GdOrderDepositService mock) {
  //   orderDepositService = mock;
  // }

  // private static GdOrderDepositService getOrderDepositService() {
  //   if (orderDepositService == null)
  //     orderDepositService = new GdOrderDepositServiceImpl();
  //   return orderDepositService;
  // }

  // /**
  //  * ! 검토 필요
  //  * 주문 입금 등록
  //  */
  // @HttpPost
  // global static void createOrderDeposit() {
  //   // RestRequest req = RestContext.request;
  //   // Savepoint sp = Database.setSavepoint();
  //   // try {
  //   //   String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
  //   //   if (String.isBlank(raw)) {
  //   //     throw new CustomException(400, '요청 본문이 비었습니다.');
  //   //   }

  //   //   Map<String, Object> reqData;
  //   //   Map<String, Object> resData;
  //   //   try {
  //   //     reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //   //     resData = reqData;
  //   //   } catch (Exception e) {
  //   //     throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
  //   //   }

  //   //   {
  //   //     // Order insert
  //   //     ApiResult orderResult = getOrderService().createOrder(reqData);
  //   //     reqData.put('orderId', orderResult.data.get('orderId'));
  //   //   }

  //   //   {
  //   //     // OrderItem insert
  //   //     getOrderItemService().createOrderItem(reqData);
  //   //   }

  //   //   {
  //   //     // TransactionJournal insert - 입금 내역
  //   //     resData.put('DebitPointList', getTransactionJournalService().createOrderDepositHistory(reqData).data.get('DebitPointList'));
  //   //   }

  //   //   ApiResult result = ApiResult.ok(200, '주문 등록 완료', resData);

  //   //   RestResponseUtil.handleSuccess(result);
  //   // } catch (CustomException ce) {
  //   //   RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   // } catch (Exception e) {
  //   //   RestResponseUtil.handleException(e, sp, 500);
  //   // }
  // }

  // /**
  //  * * 개발 완료
  //  * 주문 입금 조회
  //  */
  // @HttpGet
  // global static void getOrderDepositList() {
  //   try {
  //     RestRequest req = RestContext.request;

  //     String orderNo = ValidationUtil.stringValidation(req.params.get('orderNo'), 'orderNo', true);

  //     ApiResult result = getOrderDepositService().getOrderDepositList(orderNo);

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
  //  * todo : 개발 필요
  //  * 주문 입금 수정
  //  */
  // @HttpPatch
  // global static void updateOrderDeposit() {
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

  //     ApiResult result = getOrderDepositService().createOrderDepositHistory(reqData);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, sp, 500);
  //   }
  // }

  // /**
  //  * ! 검토 필요
  //  * 주문 입금 삭제
  //  */
  // @HttpDelete
  // global static void deleteOrderDeposit() {
  //   // RestRequest req = RestContext.request;
  //   // Savepoint sp = Database.setSavepoint();
  //   // try {
  //   //   String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
  //   //   if (String.isBlank(raw)) {
  //   //     throw new CustomException(400, '요청 본문이 비었습니다.');
  //   //   }

  //   //   Map<String, Object> reqData;
  //   //   Map<String, Object> resData;
  //   //   try {
  //   //     reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //   //     resData = reqData;
  //   //   } catch (Exception e) {
  //   //     throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
  //   //   }

  //   //   {
  //   //     // Order update
  //   //     ApiResult orderResult = getOrderService().updateOrder(reqData);
  //   //     reqData.put('orderId', orderResult.data.get('orderId'));
  //   //   }

  //   //   {
  //   //     // OrderItem upsert
  //   //     if (reqData.containsKey('OrderItem')) {
  //   //       ApiResult orderItemResult = getOrderItemService().upsertOrderItem(reqData);
  //   //     }
  //   //   }

  //   //   {
  //   //     // TransactionJournal insert
  //   //     if (reqData.containsKey('TransactionJournal')) {
  //   //       ApiResult transactionJournalResult = getTransactionJournalService().insertOrderDepositHistoryByUpdate(reqData);
  //   //       if (transactionJournalResult.data.containsKey('CancelPointList')) {
  //   //         resData.put('CancelPointList', transactionJournalResult.data.get('CancelPointList'));
  //   //       }
  //   //       if (transactionJournalResult.data.containsKey('DebitPointList')) {
  //   //         resData.put('DebitPointList', transactionJournalResult.data.get('DebitPointList'));
  //   //       }
  //   //     }
  //   //   }

  //   //   ApiResult result = ApiResult.ok(200, '주문 수정 완료', reqData);

  //   //   RestResponseUtil.handleSuccess(result);
  //   // } catch (CustomException ce) {
  //   //   RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //   // } catch (Exception e) {
  //   //   RestResponseUtil.handleException(e, sp, 500);
  //   // }
  // }

  // public class DepositResponseDTO {
  //   public String CD_TYPE_APPR; // 결제 구분
  //   public Decimal AM_DEPOSIT; // 금액
  //   public String NO_COUPON_ALL; // 쿠폰 코드
  //   public String NM_COUPON; // 쿠폰명
  //   public Date DT_EXP; // 만료 날짜
  //   public Integer RT_DISC; // 할인율
  //   public Decimal AM_DISC; // 할인 금액
  //   public String TX_REMARK; // 비고
  // }
}