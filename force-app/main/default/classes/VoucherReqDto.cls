public with sharing class VoucherReqDto {
  /**
   * 사용 가능한 쿠폰 조회 요청
   */
  public class AvailableVoucherRequest extends BaseReqDto {
    public AvailableVoucherRequest(Map<String, Object> raw) {
      super(raw);
    }

    // =========================
    // 기본 정보
    // =========================

    /** 매장 코드 */
    public String storeCode() {
      return s('StoreCode__c', 'StoreCode__c', false);
    }

    /** 회원번호  */
    public String memberNo() {
      return sEx('MemberNo__c', 'MemberNo__c', true, false);
    }

    /** 주문 상태 코드 */
    public String orderStatus() {
      return s('OrderStatus__c', 'OrderStatus__c', false);
    }

    /** 주문 구분 코드 */
    public String type() {
      return s('Type', 'Type', false);
    }

    /** 프로모션 번호 */
    public String promotionNo() {
      return s('PromotionNo__c', 'PromotionNo__c', false);
    }

    /** 쿠폰관리번호 */
    public String noManCoupon() {
      return s('NO_MAN_COUPON', 'NO_MAN_COUPON', false);
    }

    /** 쿠폰번호 */
    public String noCoupon() {
      return s('NO_COUPON', 'NO_COUPON', false);
    }

    /** 발급시작일자 */
    public Date dtStrExp() {
      // ValidationUtil.dateValidation 은 YYYY-MM-DD / YYYYMMDD 지원
      return dt('DT_STR_EXP', 'DT_STR_EXP', false);
    }

    /** 발급종료일자 */
    public Date dtEndExp() {
      return dt('DT_END_EXP', 'DT_END_EXP', false);
    }

    // =========================
    // 주문 상세 리스트 (선택)
    // =========================
    public List<OrderItemReq> orderItems() {
      List<Object> items = l('OrderItem', 'OrderItem', false);
      if (items == null) {
        return null;
      }

      List<OrderItemReq> res = new List<OrderItemReq>();
      for (Object o : items) {
        res.add(new OrderItemReq(asMap(o, 'OrderItem[]', true)));
      }
      return res;
    }

    // =========================
    // 입금 리스트 (선택)
    // =========================
    public List<TransactionJournalReq> transactionJournals() {
      List<Object> tjList = l('TransactionJournal', 'TransactionJournal', false);
      if (tjList == null) {
        return null;
      }

      List<TransactionJournalReq> res = new List<TransactionJournalReq>();
      for (Object o : tjList) {
        res.add(new TransactionJournalReq(asMap(o, 'TransactionJournal[]', true)));
      }
      return res;
    }
  }

  /**
   * 주문 상세 DTO
   */
  public class OrderItemReq extends BaseReqDto {
    public OrderItemReq(Map<String, Object> raw) {
      super(raw);
    }

    /** 상품 코드 */
    public String productCode() {
      return s('ProductCode', 'ProductCode', true);
    }

    /** 수량 */
    public Integer quantity() {
      return i('Quantity', 'Quantity', true);
    }
  }

  /**
   * 입금 정보 DTO
   */
  public class TransactionJournalReq extends BaseReqDto {
    public TransactionJournalReq(Map<String, Object> raw) {
      super(raw);
    }

    /** 결제 구분 코드 */
    public String paymentMethod() {
      return s('PaymentMethod', 'PaymentMethod', true);
    }

    /** 입금 구분 코드 */
    public String depositType() {
      // JSON 키가 DepositType__c 로 오니까 그걸 그대로 사용
      return s('DepositType__c', 'DepositType__c', true);
    }

    /** 입금 금액 */
    public Decimal transactionAmount() {
      return d('TransactionAmount', 'TransactionAmount', true);
    }

    /** 쿠폰 번호 */
    public String couponNo() {
      return s('CouponNo', 'CouponNo', false);
    }
  }
}