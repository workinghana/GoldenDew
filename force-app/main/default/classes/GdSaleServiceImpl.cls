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

    // [SOQL Optimization 2026-05-08 + Origin Accuracy Fix] 4 SOQL — Phase A 합계 + Phase B 사용처 collect.
    //   배경:
    //     - 기존 6 SOQL → governor limit 초과로 운영 에러
    //     - 1차 최적화 (3 SOQL) 의 origin 매칭 누락으로 부당 통과 결함 발견
    //     - 회원이 같은 (SubType, ExpiryDate) 의 다른 판매 적립을 가지면 그쪽 Cancel Credit 까지 refund 로 잘못 잡힘
    //   해결:
    //     - SOQL #1: 자기 판매 적립 LL + 회원 식별
    //     - SOQL #2: 자기 적립 LL 의 직접 사용 LLT — directUsage 계산 + 사용 OrderId 셋 추출 (origin 매핑 핵심)
    //     - SOQL #3: refund 매칭 — 사용 OrderId 와 같은 OrderId 의 Cancel Credit (= 진짜 origin=A 적립)
    //     - SOQL #4: reuse 합 — 매칭된 Cancel Credit 의 활성 사용 LLT
    //   효과: governor 한도 여유 + 정합 정확도 100% (다른 origin Cancel 오염 제거).

    // SOQL #1: A판매 적립 Credit LL + 회원 식별
    List<LoyaltyLedger> originalAccrualLLs = [
      SELECT Id, Points, LoyaltyPgmCrcySubtypeId, ExpiryDate, LoyaltyProgramMemberId
      FROM LoyaltyLedger
      WHERE TransactionJournal.OrderId = :originalOrderId
        AND TransactionJournal.JournalSubType.Name IN :ACCRUAL_VALIDATION_SUBTYPE_NAMES
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
      LIMIT 200
    ];
    if (originalAccrualLLs.isEmpty()) {
      return result;   // 적립 없음 → 통과
    }

    Set<Id> originalLLIds = new Set<Id>();
    Set<Id> subtypeIdSet = new Set<Id>();
    Set<Date> expiryDateSet = new Set<Date>();
    Id memberId = null;
    for (LoyaltyLedger ll : originalAccrualLLs) {
      originalLLIds.add(ll.Id);
      subtypeIdSet.add(ll.LoyaltyPgmCrcySubtypeId);
      expiryDateSet.add(ll.ExpiryDate);
      memberId = ll.LoyaltyProgramMemberId;
    }

    // SOQL #2: 자기 적립 LL 의 직접 사용 LLT (a) + 사용 발생 OrderId 셋 (origin 매핑 키)
    //   사용 발생 OrderId 와 같은 OrderId 의 Cancel Credit 만 origin=A 적립의 환불.
    Decimal totalDirectUsage = 0;
    Set<Id> usedOrderIds = new Set<Id>();
    Set<String> directUsageSaleNos = new Set<String>();
    Set<String> directUsageOrderNos = new Set<String>();
    Set<String> directUsageDepositNos = new Set<String>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT Id, CreditLoyaltyLedgerId, Points,
             DebitLoyaltyLedger.TransactionJournal.OrderId,
             DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
             DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
             DebitLoyaltyLedger.TransactionJournal.DepositNo__c
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :originalLLIds
        AND ActionType = 'Debit'
        AND IsDeleted = FALSE
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
      LIMIT 50000
    ]) {
      totalDirectUsage += (llt.Points == null ? 0 : llt.Points);
      if (llt.DebitLoyaltyLedger != null && llt.DebitLoyaltyLedger.TransactionJournal != null) {
        if (llt.DebitLoyaltyLedger.TransactionJournal.OrderId != null) {
          usedOrderIds.add(llt.DebitLoyaltyLedger.TransactionJournal.OrderId);
        }
        if (llt.DebitLoyaltyLedger.TransactionJournal.Order != null
            && llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
          directUsageSaleNos.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c);
        } else if (llt.DebitLoyaltyLedger.TransactionJournal.Order != null
            && llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
          directUsageOrderNos.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c);
        }
        if (llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c != null) {
          directUsageDepositNos.add(llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c);
        }
      }
    }

    // SOQL #3: refund 매칭 — 자기 적립 LL 사용 OrderId 와 같은 OrderId 의 Cancel Credit
    //   = origin=A 적립의 환불. 다른 판매 적립의 Cancel 은 OrderId 다르므로 자동 제외.
    Decimal totalRefund = 0;
    Set<Id> activeCancelLLIds = new Set<Id>();
    if (!usedOrderIds.isEmpty()) {
      for (LoyaltyLedger c : [
        SELECT Id, Points
        FROM LoyaltyLedger
        WHERE LoyaltyProgramMemberId = :memberId
          AND TransactionJournal.JournalSubType.Name = :SUBTYPE_NAME_POINT_REDEEM_CANCEL
          AND TransactionJournal.OrderId IN :usedOrderIds
          AND LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
          AND ExpiryDate IN :expiryDateSet
          AND EventType = 'Credit'
          AND IsDeleted = FALSE
          AND TransactionJournal.IsDeleted__c = FALSE
        LIMIT 1000
      ]) {
        totalRefund += (c.Points == null ? 0 : c.Points.abs());
        activeCancelLLIds.add(c.Id);
      }
    }

    // SOQL #4: reuse 합 — Cancel Credit 의 활성 사용 LLT (재사용)
    Decimal totalReuse = 0;
    Set<String> reuseSaleNos = new Set<String>();
    Set<String> reuseOrderNos = new Set<String>();
    Set<String> reuseDepositNos = new Set<String>();
    if (!activeCancelLLIds.isEmpty()) {
      for (LoyaltyLedgerTraceability llt : [
        SELECT Id, Points,
               DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
               DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
               DebitLoyaltyLedger.TransactionJournal.DepositNo__c
        FROM LoyaltyLedgerTraceability
        WHERE CreditLoyaltyLedgerId IN :activeCancelLLIds
          AND ActionType = 'Debit'
          AND IsDeleted = FALSE
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
          AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        LIMIT 50000
      ]) {
        totalReuse += (llt.Points == null ? 0 : llt.Points);
        if (llt.DebitLoyaltyLedger != null && llt.DebitLoyaltyLedger.TransactionJournal != null) {
          if (llt.DebitLoyaltyLedger.TransactionJournal.Order != null
              && llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
            reuseSaleNos.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c);
          } else if (llt.DebitLoyaltyLedger.TransactionJournal.Order != null
              && llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
            reuseOrderNos.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c);
          }
          if (llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c != null) {
            reuseDepositNos.add(llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c);
          }
        }
      }
    }

    Decimal unrefundedUsage = totalDirectUsage - totalRefund + totalReuse;
    if (unrefundedUsage <= 0) {
      return result;   // 통과
    }

    // 차단 — 사용처 collect (이미 SOQL 결과에서 추출한 정보 활용, 추가 SOQL 없음)
    result.saleNumberSet.addAll(directUsageSaleNos);
    result.saleNumberSet.addAll(reuseSaleNos);
    result.orderNumberSet.addAll(directUsageOrderNos);
    result.orderNumberSet.addAll(reuseOrderNos);
    result.depositNumberSet.addAll(directUsageDepositNos);
    result.depositNumberSet.addAll(reuseDepositNos);
    return result;
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