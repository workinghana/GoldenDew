/**
 * 주문/판매/반품 등록 테스트용 LWC 컨트롤러
 *
 * 본 비즈니스 로직(GdOrderServiceImpl / GdOrderItemServiceImpl / GdOrderDepositServiceImpl) 은
 * 수정하지 않고, REST 컨트롤러(GdOrderApiControllerV1.createOrder) 와 동일한 흐름으로 호출.
 */
public with sharing class Order_Sale_Return_View_ControllerV1 {
  // 주문 등록 결과 (성공/실패만 LWC 로 전달)
  public class OrderResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public Integer code;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public String orderId;
  }

  /**
   * 주문 등록 — 본 로직 수정 없이 GdOrder / GdOrderItem / GdOrderDeposit 서비스 흐름만 호출.
   * 참고: GdOrderApiControllerV1.createOrder (REST: /services/apexrest/gd/v1/order POST)
   */
  @AuraEnabled(cacheable=false)
  public static OrderResult createOrder(String jsonBody) {
    OrderResult res = new OrderResult();

    if (String.isBlank(jsonBody)) {
      res.success = false;
      res.code = 400;
      res.message = '요청 JSON이 비었습니다.';
      return res;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      res.success = false;
      res.code = 400;
      res.message = 'JSON 파싱 실패: ' + e.getMessage();
      return res;
    }

    Savepoint sp = Database.setSavepoint();
    try {
      // 1) Order insert
      ApiResult orderResult = new GdOrderServiceImpl().createOrder(reqData);
      reqData.put('orderId', orderResult.data.get('orderId'));
      reqData.put('storeTypeFour', orderResult.data.get('storeTypeFour'));
      reqData.put('storeType', orderResult.data.get('storeType'));

      // 2) OrderItem insert
      ApiResult orderItemResult = new GdOrderItemServiceImpl().createOrderItem(reqData);
      reqData.put('oiList', orderItemResult.data.get('oiList'));
      reqData.put('isGoldenBar', orderItemResult.data.get('isGoldenBar'));

      // 3) TransactionJournal insert (입금 내역)
      new GdOrderDepositServiceImpl().createOrderDepositHistory(reqData);

      // 4) Order.Status = 'orderSuccess'
      Id orderId = (Id) reqData.get('orderId');
      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        Database.rollback(sp);
        res.success = false;
        res.code = 400;
        res.message = 'order is not found';
        return res;
      }
      oList[0].Status = 'orderSuccess';
      Database.SaveResult updateResult = Database.update(oList[0]);
      if (!updateResult.isSuccess()) {
        Database.rollback(sp);
        Database.Error err = updateResult.getErrors()[0];
        res.success = false;
        res.code = 400;
        res.message = err.getMessage();
        return res;
      }

      res.success = true;
      res.code = 200;
      res.message = '주문 등록 완료';
      res.orderId = String.valueOf(orderId);
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  /**
   * 주문 수정 — 본 로직 수정 없이 GdOrder / GdOrderItem / GdOrderDeposit 흐름만 호출.
   * 참고: GdOrderApiControllerV1.updateOrder (REST: /services/apexrest/gd/v1/order PATCH)
   */
  @AuraEnabled(cacheable=false)
  public static OrderResult updateOrder(String jsonBody) {
    OrderResult res = new OrderResult();

    if (String.isBlank(jsonBody)) {
      res.success = false;
      res.code = 400;
      res.message = '요청 JSON이 비었습니다.';
      return res;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      res.success = false;
      res.code = 400;
      res.message = 'JSON 파싱 실패: ' + e.getMessage();
      return res;
    }

    Savepoint sp = Database.setSavepoint();
    try {
      // 1) Order update
      ApiResult orderResult = new GdOrderServiceImpl().updateOrder(reqData);
      reqData.put('orderId', orderResult.data.get('orderId'));

      // 2) OrderItem upsert (요청에 포함된 경우만)
      if (reqData.containsKey('OrderItem')) {
        new GdOrderItemServiceImpl().upsertOrderItem(reqData);
      }

      // 3) TransactionJournal upsert (요청에 포함된 경우만) — 입금/취소/환불 등 처리
      if (reqData.containsKey('TransactionJournal')) {
        new GdOrderDepositServiceImpl().upsertOrderDeposit(reqData);
      }

      res.success = true;
      res.code = 200;
      res.message = '주문 수정 완료';
      Object oid = reqData.get('orderId');
      res.orderId = oid == null ? null : String.valueOf(oid);
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  /**
   * 판매 등록 — 본 로직 수정 없이 GdOrder/GdOrderItem/GdSaleDeposit 흐름 호출.
   * 참고: GdSaleApiControllerV1.createSale (REST: /services/apexrest/gd/v1/sale POST)
   */
  @AuraEnabled(cacheable=false)
  public static OrderResult createSale(String jsonBody) {
    OrderResult res = new OrderResult();

    if (String.isBlank(jsonBody)) {
      res.success = false;
      res.code = 400;
      res.message = '요청 JSON이 비었습니다.';
      return res;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      res.success = false;
      res.code = 400;
      res.message = 'JSON 파싱 실패: ' + e.getMessage();
      return res;
    }

    Savepoint sp = Database.setSavepoint();
    try {
      // 1) Order 생성 (판매)
      ApiResult orderResult = new GdOrderServiceImpl().createSale(reqData);
      reqData.put('orderId', orderResult.data.get('orderId'));
      reqData.put('storeTypeFour', orderResult.data.get('storeTypeFour'));
      reqData.put('storeType', orderResult.data.get('storeType'));

      // 2) OrderItem 생성 (판매 상세)
      ApiResult orderItemResult = new GdOrderItemServiceImpl().createSaleItem(reqData);
      reqData.put('oiList', orderItemResult.data.get('oiList'));

      // 3) TransactionJournal 생성 (입금 내역)
      new GdSaleDepositServiceImpl().createSaleDepositHistory(reqData);

      // 4) Order.Status = 'saleSuccess'
      Id orderId = (Id) reqData.get('orderId');
      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        Database.rollback(sp);
        res.success = false;
        res.code = 400;
        res.message = 'order is not found';
        return res;
      }
      oList[0].Status = 'saleSuccess';
      Database.SaveResult updateResult = Database.update(oList[0]);
      if (!updateResult.isSuccess()) {
        Database.rollback(sp);
        Database.Error err = updateResult.getErrors()[0];
        res.success = false;
        res.code = 400;
        res.message = err.getMessage();
        return res;
      }

      res.success = true;
      res.code = 200;
      res.message = '판매 등록 완료';
      res.orderId = String.valueOf(orderId);
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  /**
   * 판매 수정 — 본 로직 수정 없이 GdOrder/GdOrderItem/GdSaleDeposit 흐름 호출.
   * 참고: GdSaleApiControllerV1.updateSale (REST: /services/apexrest/gd/v1/sale PATCH)
   */
  @AuraEnabled(cacheable=false)
  public static OrderResult updateSale(String jsonBody) {
    OrderResult res = new OrderResult();

    if (String.isBlank(jsonBody)) {
      res.success = false;
      res.code = 400;
      res.message = '요청 JSON이 비었습니다.';
      return res;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      res.success = false;
      res.code = 400;
      res.message = 'JSON 파싱 실패: ' + e.getMessage();
      return res;
    }

    Savepoint sp = Database.setSavepoint();
    try {
      // 1) Order update (판매)
      ApiResult orderResult = new GdOrderServiceImpl().updateSale(reqData);
      reqData.put('orderId', orderResult.data.get('orderId'));

      // 2) OrderItem upsert (판매 상세)
      if (reqData.containsKey('OrderItem')) {
        new GdOrderItemServiceImpl().upsertSaleItem(reqData);
      }

      // 3) TransactionJournal upsert (V2)
      if (reqData.containsKey('TransactionJournal')) {
        new GdSaleDepositServiceImpl().upsertSaleDepositV2(reqData);
      }

      res.success = true;
      res.code = 200;
      res.message = '판매 수정 완료';
      Object oid = reqData.get('orderId');
      res.orderId = oid == null ? null : String.valueOf(oid);
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  /**
   * 판매 전체 삭제 — SaleNo__c 로 Order + OrderItem 삭제.
   * 참고: GdSaleApiControllerV1.deleteSale (REST: /services/apexrest/gd/v1/sale DELETE)
   */
  @AuraEnabled(cacheable=false)
  public static OrderResult deleteSale(String saleNo) {
    OrderResult res = new OrderResult();

    if (String.isBlank(saleNo)) {
      res.success = false;
      res.code = 400;
      res.message = '판매 번호를 입력하세요.';
      return res;
    }

    Savepoint sp = Database.setSavepoint();
    try {
      // 1) Order update (deleteSale)
      ApiResult saleResult = new GdSaleServiceImpl().deleteSale(saleNo);
      Object orderIdObj = saleResult.data.get('orderId');
      Id orderId = orderIdObj == null ? null : (Id) orderIdObj;

      // 2) OrderItem update (deleteSaleItem)
      if (orderId != null) {
        new GdSaleItemServiceImpl().deleteSaleItem(orderId);
      }

      res.success = true;
      res.code = 200;
      res.message = '판매 전체 삭제 완료';
      res.orderId = orderId == null ? null : String.valueOf(orderId);
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  /**
   * 판매 입금 삭제 — DepositNo__c + '-' + DeposiSeqNo__c 조합으로 단일 입금 항목 삭제.
   * 참고: GdSaleDepositApiControllerV1.deleteSaleDeposit (REST: /services/apexrest/gd/v1/sale/deposit DELETE)
   */
  @AuraEnabled(cacheable=false)
  public static OrderResult deleteSaleDeposit(String depositNo, String deposiSeqNo) {
    OrderResult res = new OrderResult();

    if (String.isBlank(depositNo)) {
      res.success = false;
      res.code = 400;
      res.message = '입금 번호를 입력하세요.';
      return res;
    }
    if (String.isBlank(deposiSeqNo)) {
      res.success = false;
      res.code = 400;
      res.message = '입금 일련 번호를 입력하세요.';
      return res;
    }

    Savepoint sp = Database.setSavepoint();
    try {
      String combined = depositNo + '-' + deposiSeqNo;
      new GdSaleDepositServiceImpl().deleteSaleDeposit(combined);

      res.success = true;
      res.code = 200;
      res.message = '판매 입금 삭제 완료';
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  /**
   * 반품 등록 — 본 로직 수정 없이 GdReturn / GdReturnItem / GdReturnDeposit 흐름 호출.
   * 참고: GdReturnApiControllerV1.createReturn (REST: /services/apexrest/gd/v1/return POST)
   */
  @AuraEnabled(cacheable=false)
  public static OrderResult createReturn(String jsonBody) {
    OrderResult res = new OrderResult();

    if (String.isBlank(jsonBody)) {
      res.success = false;
      res.code = 400;
      res.message = '요청 JSON이 비었습니다.';
      return res;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      res.success = false;
      res.code = 400;
      res.message = 'JSON 파싱 실패: ' + e.getMessage();
      return res;
    }

    Savepoint sp = Database.setSavepoint();
    try {
      // 1) 반품 처리
      ApiResult orderResult = new GdReturnServiceImpl().createReturn(reqData);
      reqData.put('orderId', orderResult.data.get('orderId'));
      reqData.put('originalOrderId', orderResult.data.get('originalOrderId'));

      // 2) 반품 상세 처리
      if (reqData.containsKey('OrderItem')) {
        new GdReturnItemServiceImpl().createReturnItem(reqData);
      }

      // 3) 반품 입금 처리
      if (reqData.containsKey('TransactionJournal')) {
        new GdReturnDepositServiceImpl().insertSaleDepositHistoryByUpdate(reqData);
      }

      // 4) Order.Status = 'returnSuccess'
      Id orderId = (Id) reqData.get('orderId');
      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        Database.rollback(sp);
        res.success = false;
        res.code = 400;
        res.message = 'order is not found';
        return res;
      }
      oList[0].Status = 'returnSuccess';
      Database.SaveResult updateResult = Database.update(oList[0]);
      if (!updateResult.isSuccess()) {
        Database.rollback(sp);
        Database.Error err = updateResult.getErrors()[0];
        res.success = false;
        res.code = 400;
        res.message = err.getMessage();
        return res;
      }

      res.success = true;
      res.code = 200;
      res.message = '반품 등록 완료';
      res.orderId = String.valueOf(orderId);
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  // 회원 등록 결과
  public class MemberRegisterResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public Integer code;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public String memberNo;
  }

  /**
   * 회원 등록 — 본 로직 수정 없이 GdContact / GdLoyaltyProgramMember / GdLoyaltyTier / GdVoucher 흐름 호출.
   * 참고: GdMemberApiControllerV1.createMember (REST: /services/apexrest/gd/v1/member POST)
   */
  @AuraEnabled(cacheable=false)
  public static MemberRegisterResult createMember(String jsonBody) {
    MemberRegisterResult res = new MemberRegisterResult();

    if (String.isBlank(jsonBody)) {
      res.success = false;
      res.code = 400;
      res.message = '요청 JSON이 비었습니다.';
      return res;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      res.success = false;
      res.code = 400;
      res.message = 'JSON 파싱 실패: ' + e.getMessage();
      return res;
    }

    // LastName 누락 시 MemberNo__c 로 자동 채움 (Contact.LastName 필수 대응)
    Object lastNameObj = reqData.get('Lastname');
    String lastNameStr = lastNameObj == null ? '' : String.valueOf(lastNameObj);
    if (String.isBlank(lastNameStr)) {
      reqData.put('Lastname', reqData.get('MemberNo__c'));
    }

    Savepoint sp = Database.setSavepoint();
    try {
      // 1) Contact insert
      ApiResult contactResult = new GdContactServiceImpl().createContact(reqData);
      Contact c = (Contact) contactResult.data.get('Contact');
      reqData.put('TargetTierName', contactResult.data.get('TargetTierName'));

      // 2) LoyaltyProgramMember insert
      ApiResult loyaltyMemberResult = new GdLoyaltyProgramMemberServiceImpl().createLoyaltyProgramMember(c);
      reqData.put('LoyaltyProgramMemberId', loyaltyMemberResult.data.get('LoyaltyProgramMemberId'));
      reqData.put('ChangeReason', '회원 등록');

      // 3) LoyaltyTier change
      new GdLoyaltyTierServiceImpl().changeTier(reqData);

      // 4) SMS 동의 시 신규 가입 쿠폰 발급
      if (c.IsSMSAgreed__c) {
        ApiResult voucherResult = new GdVoucherServiceImpl().issueSignupCoupon(reqData);
        if (voucherResult != null) {
          List<Voucher> couponList = (List<Voucher>) voucherResult.data.get('CouponList');
          if (couponList != null && !couponList.isEmpty()) {
            ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
            Set<Id> couponIds = new Set<Id>();
            for (Voucher coupon : couponList) {
              couponIssueReq.couponDetailModels.add(
                new ErpCouponReqDto.CouponDetailModel(coupon.VoucherDefinition.CouponManNo__c, coupon.VoucherCode, c.MemberNo__c, UserInfo.getName())
              );
              couponIds.add(coupon.Id);
            }
            System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), couponIds));
          }
        }
      }

      res.success = true;
      res.code = 200;
      res.message = '회원 등록 성공.';
      res.memberNo = c.MemberNo__c;
      return res;
    } catch (CustomException ce) {
      Database.rollback(sp);
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      Database.rollback(sp);
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }
}