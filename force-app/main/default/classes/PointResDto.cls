public with sharing class PointResDto {
  private static final Map<String, String> POINT_JOURNAL_SUB_TYPE_MAP = new Map<String, String>{
    'Tier Qualifying Accrue' => '승급 포인트 지급',
    'Purchase Accrual' => '구매 시 포인트 지급',
    'Manual Points Credit' => '포인트 수동 지급'
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

    public CreditPointResponse(LoyaltyLedger ll) {
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
      this.NM_TYPE_POINT = (ll != null && ll.LoyaltyPgmCrcySubtypeId != null) ? ll.LoyaltyPgmCrcySubtype.Name : '';

      // 적립예정
      this.DT_SAVE_PLAN = (ll != null && ll.EscrowPointsCreditDate != null) ? String.valueOf(ll.EscrowPointsCreditDate).replaceAll('-', '') : '';
      this.PT_SAVE_PLAN = (ll != null && ll.EscrowPointsCreditDate != null && ll.Points != null) ? ll.Points.intValue() : 0;

      // 적립확정
      this.DT_SAVE = (ll != null && ll.ActivityDate != null) ? ll.ActivityDate.format('yyyyMMdd') : '';
      this.PT_SAVE = (ll != null && ll.Points != null) ? ll.Points.intValue() : 0;

      // 사용/소멸
      this.PT_USE = 0;
      this.PT_DESTROY = 0;

      // 유효기간
      this.DT_LIMIT_START = (ll != null && ll.ActivityDate != null) ? ll.ActivityDate.format('yyyyMMdd') : '';
      this.DT_LIMIT_END = (ll != null && ll.ExpiryDate != null) ? String.valueOf(ll.ExpiryDate.addDays(-1)).replaceAll('-', '') : '';
      this.DT_DESTROY_PLAN = (ll != null && ll.ExpiryDate != null) ? String.valueOf(ll.ExpiryDate).replaceAll('-', '') : '';
      this.DT_DESTROY_DEL_SALE = '';

      // 판매정보
      this.NO_SAL = (ll != null &&
        ll.TransactionJournalId != null &&
        ll.TransactionJournal.OrderId != null)
        ? ll.TransactionJournal.Order.SaleNo__c
        : '';

      Decimal amt = (ll != null &&
        ll.TransactionJournal != null &&
        ll.TransactionJournal.OrderId != null)
        ? ll.TransactionJournal.Order.ActualPaymentAmount__c
        : null;
      this.AM_SAL = (amt == null) ? 0 : Integer.valueOf(amt);

      this.PT_TARGET = 0;
      this.PT_USE_SALE = 0;
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

    // 적립일
    public String DT_SAVE;

    // 판매반품번호
    public String NO_SAL_RTN;

    public DebitPointResponse(LoyaltyLedgerTraceability llt) {
      this.YM_CREATE = llt.CreatedDate.format('yyyyMM');

      System.debug(llt != null);
      System.debug(llt.LoyaltyPgmCurrencySubtypeId != null);
      this.NM_TYPE_POINT = (llt != null && llt.LoyaltyPgmCurrencySubtypeId != null) ? llt.LoyaltyPgmCurrencySubtype.Name : null;

      this.NM_PERSON = POINT_DEBIT_MAP.containsKey(llt.ActionType)
        ? POINT_DEBIT_MAP.get(llt.ActionType)
        : (llt.ActionType == null ? '' : llt.ActionType);

      this.DT_USE = llt.DebitLoyaltyLedger.ActivityDate.format('yyyyMMdd');
      this.PT_USE = (Integer) llt.DebitLoyaltyLedger.Points;
      this.NO_SAL = llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c;
      this.AM_SAL = Integer.valueOf(llt.DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c);
      this.NO_SAL_SAVE = llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c;
      this.DT_SAVE = llt.CreditLoyaltyLedger.ActivityDate.format('yyyyMMdd');
      this.NO_SAL_RTN = llt.CreditLoyaltyLedger.TransactionJournal.Order.IsReductionOrder
        ? llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c
        : '';
    }
  }
}