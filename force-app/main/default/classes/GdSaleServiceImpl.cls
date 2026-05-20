/**
 * implements GdSaleDepositService
 * 판매 서비스 로직 구현
 */
public with sharing class GdSaleServiceImpl implements GdSaleService {
  private enum Status {
    Draft,
    saleSuccess
  }

  // [Sale Delete Validation Fix 2026-05-05] 반품 입금 삭제 재차감 보조 TJ 마커
  //   다른 클래스 정의: GdSaleDepositServiceImpl, GdReturnDepositServiceImpl, GdMemberHelpInfoServiceImpl, GdPointServiceImpl, GdReturnServiceImpl
  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

  // [Refunded Usage Exclusion 2026-05-08] 작업 1 검증 식 — Cancel Credit 환불 / 재사용 추적 SubType
  private static final Set<String> ACCRUAL_VALIDATION_SUBTYPE_NAMES = new Set<String>{
    'Purchase Accrual',
    'Promotion Point Accrual'
  };
  private static final String SUBTYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String ORIGIN_CREDIT_LL_TOKEN = 'ORIGIN_CREDIT_LL=';
  private static final Integer MAX_REFUND_USAGE_TRACE_DEPTH = 8;

  /**
   * [Refunded Usage Exclusion 2026-05-08] 적립처 판매(originalOrderId) 의 활성 사용 LLT 중
   *   "환불(Cancel Credit)으로 상쇄되지 않은 잔여 사용" 이 있는 사용처들을 식별.
   *
   * 식:
   *   unrefundedUsage = (a) A 적립 LL 의 활성 사용 LLT 합 (직접 사용)
   *                   - (b) A origin Cancel Credit Points 합 (환불받은 양)
   *                   + (c) A origin Cancel Credit 의 활성 사용 LLT 합 (재사용)
   *   unrefundedUsage > 0 → 차단 (해당 사용처 메시지 노출)
   *
   * 매칭 SubType: Purchase Accrual + Promotion Point Accrual
   *   에코/Cancel Purchase Accrual/Restore 등 무관 SubType 제외 → 부당 차단 방지.
   *
   * Cancel Credit origin 식별:
   *   같은 (SubType, ExpiryDate) 의 Purchase/Promotion Accrual LL 중 OrderId=originalOrderId 인 것을 origin 으로 매핑.
   *   회원도움창 buildRedeemCancelCreditOriginPortions (GdMemberHelpInfoServiceImpl.cls:480) 와 동일 패턴.
   *
   * 안전성:
   *   - Cancel Credit 의 LL.IsDeleted=false AND TJ.IsDeleted=false 만 활성으로 인정.
   *   - 활성 사용 LLT (a/c) 도 IsDeleted=false + RESTORE_NOTE 제외.
   *   - 다단 (Cancel-of-Cancel) 케이스는 보수적으로 차단 유지 (재귀 추적 안 함).
   */
  public static UnrefundedUsageResult calculateUnrefundedUsage(Id originalOrderId) {
    UnrefundedUsageResult result = new UnrefundedUsageResult();

    List<LoyaltyLedger> originalAccrualLLs = [
      SELECT Id, Points, LoyaltyPgmCrcySubtypeId, ExpiryDate, LoyaltyProgramMemberId, AdditionalNotes
      FROM LoyaltyLedger
      WHERE TransactionJournal.OrderId = :originalOrderId
        AND TransactionJournal.JournalSubType.Name IN :ACCRUAL_VALIDATION_SUBTYPE_NAMES
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
      LIMIT 200
    ];
    if (originalAccrualLLs.isEmpty()) {
      return result;
    }

    Set<Id> originalLLIds = new Set<Id>();
    Id memberId = null;
    for (LoyaltyLedger ll : originalAccrualLLs) {
      originalLLIds.add(ll.Id);
      memberId = ll.LoyaltyProgramMemberId;
    }

    Set<Id> activeCreditIds = new Set<Id>(originalLLIds);
    Set<Id> tracedCreditIds = new Set<Id>();
    // [Orphan 검증 narrow 보강 2026-05-15] 메인 loop 에서 환불 매칭에 사용된 Cancel Credit Id 누적.
    //   orphan 검증 단계에서 이들 CC 는 이미 처리됨으로 간주하여 over-block 방지 (CAR_515004 결함).
    Set<Id> matchedByMainLoopCancelCreditIds = new Set<Id>();

    for (Integer depth = 0; depth < MAX_REFUND_USAGE_TRACE_DEPTH && !activeCreditIds.isEmpty(); depth++) {
      Set<Id> currentCreditIds = new Set<Id>();
      for (Id creditId : activeCreditIds) {
        if (creditId != null && !tracedCreditIds.contains(creditId)) {
          currentCreditIds.add(creditId);
          tracedCreditIds.add(creditId);
        }
      }
      if (currentCreditIds.isEmpty()) {
        break;
      }

      List<UsageTracePortion> usagePortionList = new List<UsageTracePortion>();
      Set<Id> usageOrderIds = new Set<Id>();
      Set<Id> usageSubtypeIds = new Set<Id>();
      Set<Date> usageExpiryDates = new Set<Date>();

      for (LoyaltyLedgerTraceability llt : [
        SELECT Id, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId, Points,
               CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId,
               CreditLoyaltyLedger.ExpiryDate,
               CreditLoyaltyLedger.AdditionalNotes,
               DebitLoyaltyLedger.TransactionJournal.OrderId,
               DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
               DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
               DebitLoyaltyLedger.TransactionJournal.DepositNo__c
        FROM LoyaltyLedgerTraceability
        WHERE CreditLoyaltyLedgerId IN :currentCreditIds
          AND ActionType = 'Debit'
          AND IsDeleted = FALSE
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
          AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        LIMIT 50000
      ]) {
        UsageTracePortion usagePortion = buildUsageTracePortion(llt, originalLLIds);
        if (usagePortion == null || usagePortion.points <= 0 || usagePortion.originCreditLedgerId == null) {
          continue;
        }
        usagePortionList.add(usagePortion);
        if (usagePortion.orderId != null) usageOrderIds.add(usagePortion.orderId);
        if (usagePortion.subtypeId != null) usageSubtypeIds.add(usagePortion.subtypeId);
        if (usagePortion.expiryDate != null) usageExpiryDates.add(usagePortion.expiryDate);
      }

      if (usagePortionList.isEmpty()) {
        activeCreditIds.clear();
        continue;
      }

      Map<String, Decimal> cancelPointByUsageKey = new Map<String, Decimal>();
      Set<Id> nextCreditIds = new Set<Id>();
      if (!usageOrderIds.isEmpty()) {
        for (LoyaltyLedger cancelCredit : [
          SELECT Id, Points, AdditionalNotes, LoyaltyPgmCrcySubtypeId, ExpiryDate,
                 TransactionJournal.OrderId,
                 TransactionJournal.AdditionalNotes__c
          FROM LoyaltyLedger
          WHERE LoyaltyProgramMemberId = :memberId
            AND TransactionJournal.JournalSubType.Name = :SUBTYPE_NAME_POINT_REDEEM_CANCEL
            AND TransactionJournal.OrderId IN :usageOrderIds
            AND LoyaltyPgmCrcySubtypeId IN :usageSubtypeIds
            AND ExpiryDate IN :usageExpiryDates
            AND EventType = 'Credit'
            AND IsDeleted = FALSE
            AND TransactionJournal.IsDeleted__c = FALSE
          LIMIT 50000
        ]) {
          Id originCreditLedgerId = extractOriginCreditLedgerId(cancelCredit.AdditionalNotes);
          if (originCreditLedgerId == null && cancelCredit.TransactionJournal != null) {
            originCreditLedgerId = extractOriginCreditLedgerId(cancelCredit.TransactionJournal.AdditionalNotes__c);
          }
          if (originCreditLedgerId == null || !originalLLIds.contains(originCreditLedgerId)) {
            continue;
          }

          String usageKey = buildUsageTraceKey(
            originCreditLedgerId,
            cancelCredit.TransactionJournal == null ? null : cancelCredit.TransactionJournal.OrderId,
            cancelCredit.LoyaltyPgmCrcySubtypeId,
            cancelCredit.ExpiryDate
          );
          Decimal cancelPoints = cancelCredit.Points == null ? 0 : cancelCredit.Points.abs();
          cancelPointByUsageKey.put(
            usageKey,
            (cancelPointByUsageKey.containsKey(usageKey) ? cancelPointByUsageKey.get(usageKey) : 0) + cancelPoints
          );
          nextCreditIds.add(cancelCredit.Id);
          // [Orphan 검증 narrow 2026-05-15] 메인 loop 가 cancel 매칭으로 처리한 CC → orphan 검증에서 제외
          matchedByMainLoopCancelCreditIds.add(cancelCredit.Id);
        }
      }

      for (UsageTracePortion usagePortion : usagePortionList) {
        Decimal cancelPoints = cancelPointByUsageKey.containsKey(usagePortion.usageKey)
          ? cancelPointByUsageKey.get(usagePortion.usageKey)
          : 0;
        Decimal usedCancelPoints = cancelPoints < usagePortion.points ? cancelPoints : usagePortion.points;
        if (usedCancelPoints > 0) {
          cancelPointByUsageKey.put(usagePortion.usageKey, cancelPoints - usedCancelPoints);
        }
        if (usagePortion.points - usedCancelPoints > 0) {
          addBlockingUsage(result, usagePortion);
        }
      }

      activeCreditIds = nextCreditIds;
    }

    // [Orphan Cancel Credit 검증 2026-05-15, narrow 보강 2026-05-15-v2]
    //   배경: 메인 loop 는 직접 사용 LLT (TJ.IsDeleted__c=false) 만 추적함. upstream sale (예: C판매)
    //         이 삭제되어 사용 TJ 가 IsDel=true 가 되면 메인 loop 가 빈 결과로 조기 종료 → orphan
    //         Cancel Credit (ORIGIN=B의 적립) 의 존재를 인식 못함 → B 삭제 잘못 허용 (CAR_269254 결함).
    //   해결: originalLLIds 를 ORIGIN_CREDIT_LL 로 가리키는 활성 Point Redeem Cancel Credit 을
    //         직접 조회. RESTORE_NOTE Debit 으로 재소비된 것은 정상 복원이므로 제외.
    //         남는 outstanding Cancel Credit 은 B의 적립 가치가 회원 잔액에 변형되어 살아있는
    //         증거 → 삭제 차단.
    //   범위: ORIGIN 은 항상 ultimate (buildRestoreCreditAdditionalNotes chain follow 결과) 이므로
    //         multi-level chain 도 1회 query 로 충분.
    //   [narrow 보강] 메인 loop 가 환불 매칭으로 정상 처리한 CC 는 제외 (CAR_515004 over-block 결함 회피).
    //         일반 흐름 (사용→cancel→삭제 시도) 에서 use TJ.IsDel=false 인 경우 메인 loop 가 net 매칭
    //         으로 차단 사유를 정확히 산출함. 이 때 orphan 검증이 동일 CC 를 또 차단하면 over-block.
    //         메인 loop 매칭된 CC 누적 (matchedByMainLoopCancelCreditIds) → orphan 검증에서 skip.
    Set<Id> restoreConsumedCancelCreditIds = new Set<Id>();
    for (LoyaltyLedgerTraceability r : [
      SELECT CreditLoyaltyLedgerId
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
        AND ActionType = 'Debit'
        AND IsDeleted = FALSE
        AND DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE
        AND CreditLoyaltyLedgerId != NULL
      LIMIT 50000
    ]) {
      restoreConsumedCancelCreditIds.add(r.CreditLoyaltyLedgerId);
    }

    for (LoyaltyLedger cc : [
      SELECT Id, Points, AdditionalNotes,
             TransactionJournal.OrderId, TransactionJournal.DepositNo__c,
             TransactionJournal.Order.SaleNo__c, TransactionJournal.Order.OrderNo__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND TransactionJournal.JournalSubType.Name = :SUBTYPE_NAME_POINT_REDEEM_CANCEL
        AND EventType = 'Credit'
        AND Points > 0
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND AdditionalNotes LIKE '%ORIGIN_CREDIT_LL=%'
      LIMIT 50000
    ]) {
      // [narrow 보강] 메인 loop 가 cancel 매칭으로 처리한 CC 는 over-block 방지를 위해 제외
      if (matchedByMainLoopCancelCreditIds.contains(cc.Id)) continue;
      if (restoreConsumedCancelCreditIds.contains(cc.Id)) continue;
      Id originId = extractOriginCreditLedgerId(cc.AdditionalNotes);
      if (originId == null || !originalLLIds.contains(originId)) continue;

      TransactionJournal ccTj = cc.TransactionJournal;
      UsageTracePortion blockingPortion = new UsageTracePortion();
      blockingPortion.saleNo = (ccTj != null && ccTj.Order != null) ? ccTj.Order.SaleNo__c : null;
      blockingPortion.orderNo = (ccTj != null && ccTj.Order != null) ? ccTj.Order.OrderNo__c : null;
      blockingPortion.depositNo = ccTj == null ? null : ccTj.DepositNo__c;
      addBlockingUsage(result, blockingPortion);
    }

    return result;
  }

  private class UsageTracePortion {
    Id originCreditLedgerId;
    Id orderId;
    Id subtypeId;
    Date expiryDate;
    Decimal points;
    String saleNo;
    String orderNo;
    String depositNo;
    String usageKey;
  }

  private static UsageTracePortion buildUsageTracePortion(LoyaltyLedgerTraceability llt, Set<Id> originalLLIds) {
    if (llt == null || llt.CreditLoyaltyLedgerId == null || llt.CreditLoyaltyLedger == null
        || llt.DebitLoyaltyLedger == null || llt.DebitLoyaltyLedger.TransactionJournal == null) {
      return null;
    }

    Id originCreditLedgerId = originalLLIds.contains(llt.CreditLoyaltyLedgerId)
      ? llt.CreditLoyaltyLedgerId
      : extractOriginCreditLedgerId(llt.CreditLoyaltyLedger.AdditionalNotes);
    if (originCreditLedgerId == null || !originalLLIds.contains(originCreditLedgerId)) {
      return null;
    }

    TransactionJournal debitTj = llt.DebitLoyaltyLedger.TransactionJournal;
    UsageTracePortion usagePortion = new UsageTracePortion();
    usagePortion.originCreditLedgerId = originCreditLedgerId;
    usagePortion.orderId = debitTj.OrderId;
    usagePortion.subtypeId = llt.CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId;
    usagePortion.expiryDate = llt.CreditLoyaltyLedger.ExpiryDate;
    usagePortion.points = llt.Points == null ? 0 : llt.Points;
    usagePortion.saleNo = debitTj.Order == null ? null : debitTj.Order.SaleNo__c;
    usagePortion.orderNo = debitTj.Order == null ? null : debitTj.Order.OrderNo__c;
    usagePortion.depositNo = debitTj.DepositNo__c;
    usagePortion.usageKey = buildUsageTraceKey(
      usagePortion.originCreditLedgerId,
      usagePortion.orderId,
      usagePortion.subtypeId,
      usagePortion.expiryDate
    );
    return usagePortion;
  }

  private static String buildUsageTraceKey(Id originCreditLedgerId, Id orderId, Id subtypeId, Date expiryDate) {
    return String.valueOf(originCreditLedgerId) + '::' +
      String.valueOf(orderId) + '::' +
      String.valueOf(subtypeId) + '::' +
      String.valueOf(expiryDate);
  }

  private static void addBlockingUsage(UnrefundedUsageResult result, UsageTracePortion usagePortion) {
    if (result == null || usagePortion == null) {
      return;
    }
    if (String.isNotBlank(usagePortion.saleNo)) {
      result.saleNumberSet.add(usagePortion.saleNo);
    } else if (String.isNotBlank(usagePortion.orderNo)) {
      result.orderNumberSet.add(usagePortion.orderNo);
    }
    if (String.isNotBlank(usagePortion.depositNo)) {
      result.depositNumberSet.add(usagePortion.depositNo);
    }
  }

  private static Id extractOriginCreditLedgerId(String additionalNotes) {
    if (String.isBlank(additionalNotes)) {
      return null;
    }

    Integer tokenIndex = additionalNotes.indexOf(ORIGIN_CREDIT_LL_TOKEN);
    if (tokenIndex < 0) {
      return null;
    }

    Integer valueStart = tokenIndex + ORIGIN_CREDIT_LL_TOKEN.length();
    Integer valueEnd = additionalNotes.indexOf(';', valueStart);
    String originIdText = valueEnd < 0
      ? additionalNotes.substring(valueStart)
      : additionalNotes.substring(valueStart, valueEnd);
    originIdText = originIdText == null ? null : originIdText.trim();

    if (String.isBlank(originIdText) || (originIdText.length() != 15 && originIdText.length() != 18)) {
      return null;
    }

    try {
      return (Id) originIdText;
    } catch (Exception e) {
      return null;
    }
  }

  private static void collectBlockingUsages(List<List<LoyaltyLedgerTraceability>> lltGroups, UnrefundedUsageResult result) {
    for (List<LoyaltyLedgerTraceability> lltGroup : lltGroups) {
      for (LoyaltyLedgerTraceability llt : lltGroup) {
        if (llt.DebitLoyaltyLedger == null || llt.DebitLoyaltyLedger.TransactionJournal == null) continue;
        if (llt.DebitLoyaltyLedger.TransactionJournal.Order != null
            && llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
          result.saleNumberSet.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c);
        } else if (llt.DebitLoyaltyLedger.TransactionJournal.Order != null
            && llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
          result.orderNumberSet.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c);
        }
        if (llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c != null) {
          result.depositNumberSet.add(llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c);
        }
      }
    }
  }

  public class UnrefundedUsageResult {
    public Set<String> saleNumberSet = new Set<String>();
    public Set<String> orderNumberSet = new Set<String>();
    public Set<String> depositNumberSet = new Set<String>();

    public Boolean shouldBlock() {
      return !saleNumberSet.isEmpty() || !orderNumberSet.isEmpty() || !depositNumberSet.isEmpty();
    }

    public String buildBlockMessage(String prefix) {
      List<String> saleSorted = new List<String>(saleNumberSet);
      saleSorted.sort();
      List<String> orderSorted = new List<String>(orderNumberSet);
      orderSorted.sort();
      List<String> depositSorted = new List<String>(depositNumberSet);
      depositSorted.sort();
      String saleList = String.join(saleSorted, ', ');
      String orderList = String.join(orderSorted, ', ');
      String depositList = String.join(depositSorted, ', ');

      String msg = prefix;
      if (String.isNotBlank(saleList)) msg += ' 판매번호: ' + saleList;
      if (String.isNotBlank(orderList)) {
        msg += (String.isNotBlank(saleList) ? ' / ' : ' ') + '주문번호: ' + orderList;
      }
      if (String.isNotBlank(depositList)) msg += ' / 입금번호: ' + depositList;
      return msg;
    }
  }

  /**
   * ! 보류
   * 판매 등록
   * Order insert
   */
  /*
  public ApiResult createSale(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String accountId = ValidationUtil.stringValidation(reqData.get('AccountId'), 'AccountId', true);
      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', true);
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', true);
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false);
      String saleStatus = ValidationUtil.stringValidation(reqData.get('SaleStatus__c'), 'SaleStatus__c', false);
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true); // 등록자

      // 판매번호(SaleNo__c) 중복 체크
      if ([SELECT COUNT() FROM Order WHERE SaleNo__c = :saleNo] > 0) {
        throw new CustomException(400, 'SaleNo__c already exists.');
      }

      List<Contact> contactList = [SELECT Id, MemberNo__c FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
      if (contactList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }
      Contact contact = contactList[0];

      // 회사 코드 체크
      List<Account> companyList = [SELECT Id FROM Account WHERE CompanyCode__c = :accountId LIMIT 1];
      if (companyList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회사 코드입니다. ' + accountId);
      }
      Account company = companyList[0];

      // 매장 코드 체크
      List<Account> storeList = [SELECT Id FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
      if (storeList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 매장 코드입니다. ' + storeCode);
      }
      Account store = storeList[0];

      // Standard Pricebook 조회
      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Order o = new Order();
      o.AccountId = company.Id;
      o.StoreCode__c = store.Id;
      o.Status = String.valueOf(Status.Draft);
      o.EffectiveDate = Date.today();
      o.MemberNo__c = contact.Id;
      o.SaleNo__c = saleNo;
      if (actualPaymentAmount != null) {
        o.ActualPaymentAmount__c = actualPaymentAmount;
      }
      if (saleStatus != null) {
        o.SaleStatus__c = saleStatus;
      }
      o.Pricebook2Id = standardPricebookId;
      o.InsertId__c = insertId;

      Database.SaveResult insertResult = Database.insert(o);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();

      reqData.put('orderId', o.Id);
      createSaleItem(reqData); // 판매 상세 등록

      o.Status = String.valueOf(Status.saleSuccess);
      Database.SaveResult updateResult = Database.update(o);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      return ApiResult.ok(200, '판매 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  */

  /**
   * ! 보류
   * 판매 상세 등록
   * OrderItem insert
   */
  /**
  public void createSaleItem(Map<String, Object> reqData) {
    try {
      List<Object> saleItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);

      List<OrderItem> oiList = new List<OrderItem>();

      for (Object v : saleItemList) {
        Map<String, Object> saleItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String saleSeqNo = ValidationUtil.stringValidation(saleItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', true); // 판매 일련 번호
        String orderNo = ValidationUtil.stringValidation(saleItem.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호
        String productCode = ValidationUtil.stringValidation(saleItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(saleItem.get('Quantity'), 'Quantity', true); // 수량

        // Product2 조회
        List<Product2> productList = [SELECT Id FROM Product2 WHERE Product2.ProductCode = :productCode LIMIT 1];
        if (productList.isEmpty()) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

        // Standard Pricebook 조회
        Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

        // PricebookEntry 조회
        List<PricebookEntry> pricebookEntryList = [
          SELECT Id, UnitPrice, Name
          FROM PricebookEntry
          WHERE ProductCode = :productCode AND Pricebook2Id = :standardPricebookId
          LIMIT 1
        ];
        if (pricebookEntryList.isEmpty()) {
          throw new CustomException(400, '해당 PricebookEntry 가 없습니다.');
        }

        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.PricebookEntryId = pricebookEntryList[0].Id;
        oi.Quantity = quantity;
        oi.UnitPrice = pricebookEntryList[0].UnitPrice;
        oi.SaleSeqNo__c = saleSeqNo;
        oi.SaleItemNo__c = orderId + '-' + saleSeqNo; // 판매 상세 번호 (외부 ID)

        if (orderNo != null) {
          List<Order> oList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
          if (oList.isEmpty()) {
            throw new CustomException(400, '해당 주문 건이 없습니다. ' + orderNo);
          }
          oi.OrderId__c = oList[0].Id;
        }

        oiList.add(oi);
      }

      List<Database.SaveResult> resultList = Database.insert(oiList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }
      return;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  */

  /**
   * 판매 전체 삭제
   * Order update
   */
  public ApiResult deleteSale(String saleNo) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Order> oList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 판매 번호입니다. ' + saleNo);
      }

      // [Refunded Usage Exclusion 2026-05-08] 새 검증 식 — Cancel Credit 환불/재사용 차감 후 잔여 사용량 기준.
      //   기존: 활성 사용 LLT 1건이라도 있으면 차단 → 환불된 사용도 차단 사유로 잡힘 (부당 차단).
      //   수정: unrefundedUsage = 직접 사용 - 환불 + 재사용 → > 0 인 경우만 차단.
      //   Cancel Credit 환불 발생한 사용 LLT 는 차단 사유에서 자동 제외 (B 반품 후 A 삭제 가능).
      UnrefundedUsageResult validationResult = calculateUnrefundedUsage(oList[0].Id);
      if (validationResult.shouldBlock()) {
        throw new CustomException(400,
          validationResult.buildBlockMessage('해당 판매 건은 삭제할 수 없습니다. 적립된 포인트가 다른 주문/판매에서 사용되었습니다.'));
      }

      oList[0].DeleteDateTime__c = System.now();
      oList[0].IsDeleted__c = true;

      Database.SaveResult result = Database.update(oList[0]);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      data.put('orderId', oList[0].Id);

      return ApiResult.ok(200, '판매 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}