public with sharing class PointResDto {
  private static final Map<String, String> POINT_JOURNAL_SUB_TYPE_MAP = new Map<String, String>{
    'Tier Qualifying Accrue' => '승급 포인트 지급',
    'Purchase Accrual' => '구매 시 포인트 지급',
    'Manual Points Credit' => '포인트 수동 지급',
    'Point Redeem Cancel' => '사용 취소 재적립'
  };

  private static final Map<String, String> POINT_DEBIT_MAP = new Map<String, String>{
    'Debit' => '사용',
    'DebitCancellation' => '사용취소',
    'CreditCancellation' => '포인트 지급 취소',
    'Expiry' => '소멸'
  };

  /**
   * 사용 가능한 포인트 조회 응답
   * pointList 배열의 각 요소
   */
  public class AvailablePointResponse {
    public String CD_TYPE_POINT; // 포인트 구분 코드
    public Integer points; // 사용 가능 포인트 잔액

    public AvailablePointResponse(AggregateResult ar) {
      this.CD_TYPE_POINT = (String) ar.get('pointTypeCode');

      Decimal total = (Decimal) ar.get('totalPoints');
      this.points = (total == null) ? 0 : total.intValue();
    }
  }

  public class CreditPointResponse {
    // 적립일
    public String YM_CREATE;

    // 포인트 구분 / 적립 구분
    public String NM_TYPE_POINT;
    public String NM_TYPE_SAVE;

    // 적립예정
    public String DT_SAVE_PLAN;
    public Integer PT_SAVE_PLAN;

    // 적립확정
    public String DT_SAVE;
    public Integer PT_SAVE;

    // 사용/소멸
    public Integer PT_USE;
    public Integer PT_DESTROY;

    // 유효기간
    public String DT_LIMIT_START;
    public String DT_LIMIT_END;

    // 소멸일
    public String DT_DESTROY_PLAN; // 소멸예정일
    public String DT_DESTROY_DEL_SALE; // 판매취소일

    // 판매정보
    public String NO_SAL; // 판매번호
    public Integer AM_SAL; // 판매금액
    public Integer PT_TARGET; // 적립대상포인트
    public Integer PT_USE_SALE; // 입금포인트
    public Integer PT_USE_SALE_COUPON; // 쿠폰 입금 금액
    public String NO_PROM_MBR; // 프로모션 번호

    public CreditPointResponse(LoyaltyLedger ll) {
      this(ll, 0, 0, 0, 0);
    }

    public CreditPointResponse(LoyaltyLedger ll, Integer usedPoints, Integer destroyedPoints, Integer usedSalePoints) {
      this(ll, usedPoints, destroyedPoints, usedSalePoints, 0);
    }

    public CreditPointResponse(LoyaltyLedger ll, Integer usedPoints, Integer destroyedPoints, Integer usedSalePoints, Integer usedSaleCouponAmount) {
      // subtypeName 안전 추출
      String subTypeName = (ll != null &&
        ll.TransactionJournalId != null &&
        ll.TransactionJournal.JournalSubTypeId != null)
        ? ll.TransactionJournal.JournalSubType.Name
        : null;

      // 맵 적용(없으면 원본)
      this.NM_TYPE_SAVE = (subTypeName != null && POINT_JOURNAL_SUB_TYPE_MAP.containsKey(subTypeName))
        ? POINT_JOURNAL_SUB_TYPE_MAP.get(subTypeName)
        : (subTypeName == null ? '' : subTypeName);

      // 날짜/기본
      this.YM_CREATE = (ll != null && ll.ActivityDate != null) ? ll.ActivityDate.format('yyyyMM') : '';
      this.NM_TYPE_POINT = (ll != null &&
        ll.LoyaltyPgmCrcySubtypeId != null &&
        ll.LoyaltyPgmCrcySubtype != null)
        ? ll.LoyaltyPgmCrcySubtype.Name
        : '';

      // [Plan Field Fix 2026-04-29] PT_SAVE_PLAN / DT_SAVE_PLAN = 최초 적립 시점 값 (불변)
      //   - LL 은 insert 후 Points / ActivityDate 가 update 되지 않으므로 원본값 유지
      //   - 적립 취소/사용/소멸과 무관하게 PT_SAVE_PLAN 은 원본 적립액 그대로 표시
      //   - 기존: EscrowPointsCreditDate 기반 (escrow 케이스에만 채워져 일반 적립은 항상 0/'') → 사용성 부재
      this.DT_SAVE_PLAN = (ll != null && ll.ActivityDate != null) ? ll.ActivityDate.format('yyyyMMdd') : '';
      this.PT_SAVE_PLAN = (ll != null && ll.Points != null) ? ll.Points.intValue() : 0;

      // 적립확정
      this.DT_SAVE = (ll != null && ll.ActivityDate != null) ? ll.ActivityDate.format('yyyyMMdd') : '';
      this.PT_SAVE = (ll != null && ll.Points != null) ? ll.Points.intValue() : 0;

      // 사용/소멸
      this.PT_USE = usedPoints == null ? 0 : usedPoints;
      this.PT_DESTROY = destroyedPoints == null ? 0 : destroyedPoints;

      // 유효기간
      this.DT_LIMIT_START = (ll != null && ll.ActivityDate != null) ? ll.ActivityDate.format('yyyyMMdd') : '';
      this.DT_LIMIT_END = (ll != null && ll.ExpiryDate != null) ? String.valueOf(ll.ExpiryDate).replaceAll('-', '') : '';
      this.DT_DESTROY_PLAN = (ll != null && ll.ExpiryDate != null) ? String.valueOf(ll.ExpiryDate.addDays(1)).replaceAll('-', '') : '';
      this.DT_DESTROY_DEL_SALE = '';

      // 판매정보
      // 신규 로직 (26.05.08 CS)
      String orderSaleNo = (ll != null &&
        ll.TransactionJournal != null &&
        ll.TransactionJournal.Order != null)
        ? ll.TransactionJournal.Order.SaleNo__c
        : null;

      String saleSaleNo = (ll != null &&
        ll.TransactionJournal != null &&
        ll.TransactionJournal.SaleId__r != null)
        ? ll.TransactionJournal.SaleId__r.SaleNo__c
        : null;

      this.NO_SAL = String.isNotBlank(orderSaleNo)
        ? orderSaleNo
        : (String.isNotBlank(saleSaleNo) ? saleSaleNo : '');
      // 기존 로직
      // this.NO_SAL = (ll != null &&
      //   ll.TransactionJournalId != null &&
      //   ll.TransactionJournal.OrderId != null &&
      //   ll.TransactionJournal.Order != null &&
      //   String.isNotBlank(ll.TransactionJournal.Order.SaleNo__c))
      //   ? ll.TransactionJournal.Order.SaleNo__c
      //   : '';

      Decimal amt = (ll != null &&
        ll.TransactionJournal != null &&
        ll.TransactionJournal.OrderId != null)
        ? ll.TransactionJournal.Order.ActualPaymentAmount__c
        : null;
      this.AM_SAL = (amt == null) ? 0 : Integer.valueOf(amt);

      // this.PT_TARGET = 0;  // 기존
      this.PT_TARGET = (ll != null && ll.Points != null) ? ll.Points.intValue() : 0;  // 신규 로직 (26.05.04 CS)
      this.PT_USE_SALE = usedSalePoints == null ? 0 : usedSalePoints;
      this.PT_USE_SALE_COUPON = usedSaleCouponAmount == null ? 0 : usedSaleCouponAmount;

      this.NO_PROM_MBR = (ll != null &&
        ll.TransactionJournalId != null &&
        ll.TransactionJournal.Promotion != null &&
        String.isNotBlank(ll.TransactionJournal.Promotion.PromotionNo__c))
        ? ll.TransactionJournal.Promotion.PromotionNo__c
        : '';
    }
  }

  public class DebitPointResponse {
    // 발생일
    public String YM_CREATE;

    // 포인트 구분
    public String NM_TYPE_POINT;

    // 소지 구분
    public String NM_PERSON;

    // 사용/소멸일
    public String DT_USE;

    // 사용/소멸 포인트
    public Integer PT_USE;

    // 판매정보
    public String NO_SAL; // 판매번호
    public Integer AM_SAL; // 판매금액

    // 적립된 판매번호
    public String NO_SAL_SAVE; // 적립된 판매번호
    public String NO_SAL_ORD; // 사용한 주문번호

    // 적립일
    public String DT_SAVE;

    // 판매반품번호
    public String NO_SAL_RTN;

    private String getSaleNoFromOrder(Order orderRecord) {
      return (orderRecord != null && String.isNotBlank(orderRecord.SaleNo__c)) ? orderRecord.SaleNo__c : '';
    }

    private String getSaleNoFromDebitContext(LoyaltyLedgerTraceability llt, Order debitOrder) {
      String orderSaleNo = getSaleNoFromOrder(debitOrder);
      if (String.isNotBlank(orderSaleNo)) {
        return orderSaleNo;
      }

      return (llt != null &&
        llt.DebitLoyaltyLedger != null &&
        llt.DebitLoyaltyLedger.TransactionJournal != null &&
        llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r != null &&
        String.isNotBlank(llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c))
        ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c
        : '';
    }

    private Integer getSaleAmountFromOrder(Order orderRecord) {
      Decimal amount = orderRecord != null ? orderRecord.ActualPaymentAmount__c : null;
      return amount == null ? 0 : Integer.valueOf(amount);
    }

    private String getOrderNoFromOrder(Order orderRecord) {
      return (orderRecord != null && String.isNotBlank(orderRecord.OrderNo__c)) ? orderRecord.OrderNo__c : '';
    }

    // [정책 변경 2026-05-03] 기본 생성자 추가
    //   배경: "포인트 사용 취소" 행은 LoyaltyLedgerTraceability 가 아닌 LoyaltyLedger 에서
    //         직접 합성되므로 기존 LLT 인자 생성자를 사용할 수 없음.
    //   해결: 빈 기본 생성자 추가 — 필드는 호출자가 직접 set.
    //   영향: 기존 LLT 인자 생성자는 그대로 유지되어 기존 호출부 영향 없음.
    public DebitPointResponse() {}

    public DebitPointResponse(LoyaltyLedgerTraceability llt) {
      Order debitOrder = (llt != null &&
        llt.DebitLoyaltyLedger != null &&
        llt.DebitLoyaltyLedger.TransactionJournal != null)
        ? llt.DebitLoyaltyLedger.TransactionJournal.Order
        : null;
      Order creditOrder = (llt != null &&
        llt.CreditLoyaltyLedger != null &&
        llt.CreditLoyaltyLedger.TransactionJournal != null)
        ? llt.CreditLoyaltyLedger.TransactionJournal.Order
        : null;

      this.YM_CREATE = (llt != null && llt.CreatedDate != null) ? llt.CreatedDate.format('yyyyMM') : '';
      this.NM_TYPE_POINT = (llt != null &&
        llt.LoyaltyPgmCurrencySubtypeId != null &&
        llt.LoyaltyPgmCurrencySubtype != null)
        ? llt.LoyaltyPgmCurrencySubtype.Name
        : '';

      this.NM_PERSON = (llt != null && POINT_DEBIT_MAP.containsKey(llt.ActionType))
        ? POINT_DEBIT_MAP.get(llt.ActionType)
        : (llt == null || llt.ActionType == null ? '' : llt.ActionType);

      this.DT_USE = (llt != null &&
        llt.DebitLoyaltyLedger != null &&
        llt.DebitLoyaltyLedger.TransactionJournal != null)
        ? llt.DebitLoyaltyLedger.TransactionJournal.JournalDate.format('yyyyMMdd')
        : '';
      // [Bug 1 fix 2026-04-24] 기존: llt.DebitLoyaltyLedger.Points (Debit Ledger 총액)
      //                         수정: llt.Points (개별 Traceability 금액)
      //   Multi-Traceability 케이스에서 각 행의 PT_USE 가 Debit Ledger 총액으로
      //   잘못 표시되어 합계가 N배로 뻥튀기되던 버그. 이제 각 Traceability 의
      //   실제 사용 포인트만 표시하여 합계도 정확해짐.
      Integer ptUse = (llt != null && llt.Points != null)
        ? Integer.valueOf(llt.Points.abs())
        : 0;
      if (llt != null && llt.ActionType == 'DebitCancellation') {
        ptUse *= -1;
      }
      this.PT_USE = ptUse;

      // 반품 포인트 여부: DebitLoyaltyLedger의 TJ에 SaleId__c가 반품 건이면 반품 포인트
      Boolean isReturnPoint =
        debitOrder != null &&
        llt != null &&
        llt.DebitLoyaltyLedger != null &&
        llt.DebitLoyaltyLedger.TransactionJournal != null &&
        llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r != null &&
        llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c == true;

      // NO_SAL: 반품 포인트면 빈값, 일반 사용이면 판매번호
      // this.NO_SAL = isReturnPoint ? '' : getSaleNoFromDebitContext(llt, debitOrder); // 기존
      this.NO_SAL = isReturnPoint ? getSaleNoFromOrder(creditOrder) : getSaleNoFromDebitContext(llt, debitOrder);  // 신규

      this.AM_SAL = getSaleAmountFromOrder(debitOrder);
      this.NO_SAL_SAVE = getSaleNoFromOrder(creditOrder);
      this.NO_SAL_ORD = getOrderNoFromOrder(debitOrder);
      this.DT_SAVE = (llt != null &&
        llt.CreditLoyaltyLedger != null &&
        llt.CreditLoyaltyLedger.ActivityDate != null)
        ? llt.CreditLoyaltyLedger.ActivityDate.format('yyyyMMdd')
        : '';

      this.NO_SAL_RTN = isReturnPoint &&
        llt != null &&
        llt.DebitLoyaltyLedger != null &&
        llt.DebitLoyaltyLedger.TransactionJournal != null &&
        llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r != null
        ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c
        : '';
    }
  }
}