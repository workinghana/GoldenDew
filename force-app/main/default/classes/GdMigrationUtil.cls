/**
 * 옵션 C 마이그레이션 분기 처리 유틸리티
 *
 * Phase 1 — 기반 구축 단계
 *   - 분기 처리 활성화 여부 / 기준 일자 조회 (Custom Setting 기반)
 *   - 옛 거래 여부 판단 (입금 번호 / 판매 번호 / 주문 Id 기준)
 *   - Phase 2+ 에서 분기 핸들러가 이 유틸 호출
 *
 * 안전 장치
 *   - shouldApplyOptionCBranch* 는 IsEnabled__c=false 또는 Custom Setting 미존재 시 항상 false 반환
 *     → 분기 처리 비활성화 시 100% 표준 로직 통과 보장
 *   - 모든 SOQL 은 LIMIT 1 + 빈 리스트 가드 적용
 *   - Custom Setting 기준 일자 미설정 시 하드코딩 기본값 (2026-05-15) 으로 fallback
 *
 * Custom Setting: OptionCBranchSetting__c (Hierarchy)
 *   - IsEnabled__c (Checkbox) : 분기 처리 활성화 여부
 *   - OpenDate__c (Date)      : 운영 오픈 기준 일자
 */
public with sharing class GdMigrationUtil {

  // 기본 기준 일자 (Custom Setting 미설정 시 fallback)
  private static final Date DEFAULT_OPEN_DATE = Date.newInstance(2026, 5, 15);

  // 마이그레이션 TJ InsertId 마커 (옵션 C 적재 시 사용된 값)
  private static final Set<String> MIG_INSERT_IDS = new Set<String>{
    'MIG_OPTC_CREDIT',
    'MIG_OPTC_CANCEL'
  };

  // ============================================================
  // Section 1: Custom Setting 조회
  // ============================================================

  /**
   * 분기 처리 활성화 여부.
   * Custom Setting 미존재 또는 IsEnabled__c=false 시 false 반환.
   */
  public static Boolean isOptionCBranchEnabled() {
    OptionCBranchSetting__c setting = OptionCBranchSetting__c.getInstance();
    if (setting == null) {
      return false;
    }
    return setting.IsEnabled__c == true;
  }

  /**
   * 운영 오픈 기준 일자.
   * Custom Setting OpenDate__c 우선, 미설정 시 DEFAULT_OPEN_DATE (2026-05-15) 반환.
   */
  public static Date getOpenDate() {
    OptionCBranchSetting__c setting = OptionCBranchSetting__c.getInstance();
    if (setting != null && setting.OpenDate__c != null) {
      return setting.OpenDate__c;
    }
    return DEFAULT_OPEN_DATE;
  }

  // ============================================================
  // Section 2: 분기 발동 조건 — 입금 번호 기준
  // DELETE /gd/v1/return/deposit, DELETE /gd/v1/sale/deposit 용
  // ============================================================

  /**
   * 입금 번호 기준 분기 발동 여부.
   * @param depositNo 입금 번호 (예: 'DEP202507020191-1')
   * @return Feature Flag ON + 옛 거래 매칭 시 true
   */
  public static Boolean shouldApplyOptionCBranchByDepositNo(String depositNo) {
    if (!isOptionCBranchEnabled()) {
      return false;
    }
    if (String.isBlank(depositNo)) {
      return false;
    }

    List<TransactionJournal> tjList = [
      SELECT Id, ActivityDate, InsertId__c, OrderId, Order.EffectiveDate
      FROM TransactionJournal
      WHERE DepositNo__c = :depositNo
      LIMIT 1
    ];
    if (tjList.isEmpty()) {
      return false;
    }
    return isPreOpenTransaction(tjList[0]);
  }

  // ============================================================
  // Section 3: 분기 발동 조건 — 판매 번호 기준
  // POST /gd/v1/return (OriginalOrderId), DELETE/PATCH /gd/v1/sale (SaleNo__c) 용
  // ============================================================

  /**
   * 판매 번호 기준 분기 발동 여부.
   * @param saleNo 판매 번호 (Order.SaleNo__c)
   * @return Feature Flag ON + Order.EffectiveDate < OpenDate 시 true
   */
  public static Boolean shouldApplyOptionCBranchBySaleNo(String saleNo) {
    if (!isOptionCBranchEnabled()) {
      return false;
    }
    if (String.isBlank(saleNo)) {
      return false;
    }

    List<Order> oList = [
      SELECT Id, EffectiveDate FROM Order WHERE SaleNo__c = :saleNo LIMIT 1
    ];
    if (oList.isEmpty()) {
      return false;
    }
    if (oList[0].EffectiveDate == null) {
      return false;
    }
    return oList[0].EffectiveDate < getOpenDate();
  }

  // ============================================================
  // Section 4: 분기 발동 조건 — Order Id 기준 (내부 호출용)
  // ============================================================

  /**
   * Order Id 기준 분기 발동 여부.
   * 분기 핸들러가 이미 orderId 를 알고 있을 때 사용.
   */
  public static Boolean shouldApplyOptionCBranchByOrderId(Id orderId) {
    if (!isOptionCBranchEnabled()) {
      return false;
    }
    if (orderId == null) {
      return false;
    }

    List<Order> oList = [
      SELECT Id, EffectiveDate FROM Order WHERE Id = :orderId LIMIT 1
    ];
    if (oList.isEmpty() || oList[0].EffectiveDate == null) {
      return false;
    }
    return oList[0].EffectiveDate < getOpenDate();
  }

  // ============================================================
  // Section 5: 옛 거래 판단 (private helper)
  // ============================================================

  /**
   * TJ 가 옛 거래인지 판단.
   * 우선순위:
   *   1. 마이그레이션 TJ 마커 (InsertId__c IN ('MIG_OPTC_CREDIT', 'MIG_OPTC_CANCEL'))
   *   2. 부모 Order.EffectiveDate < OpenDate
   *   3. TJ.ActivityDate < OpenDate (Order 가 없을 때 fallback)
   */
  private static Boolean isPreOpenTransaction(TransactionJournal tj) {
    if (tj == null) {
      return false;
    }

    // 1. 마이그레이션 TJ 직접 식별
    if (String.isNotBlank(tj.InsertId__c) && MIG_INSERT_IDS.contains(tj.InsertId__c)) {
      return true;
    }

    Date openDate = getOpenDate();

    // 2. Order.EffectiveDate 우선
    if (tj.Order != null && tj.Order.EffectiveDate != null) {
      return tj.Order.EffectiveDate < openDate;
    }

    // 3. TJ.ActivityDate fallback
    if (tj.ActivityDate != null) {
      return tj.ActivityDate.date() < openDate;
    }

    return false;
  }

  // ============================================================
  // Section 6: 손실 추적 / 강제 처리 헬퍼 (Phase 6.1)
  //
  // 보수 설계:
  //   - recordAdjustmentLog 만 우선 추가 (DML 안전, 영향 0)
  //   - forceDebit/Credit 은 추후 sub-phase 에서 호출자 추가 시 동작
  //   - 모든 DML 은 try/catch + Database.SaveResult 검사
  //   - 실패해도 호출 컨텍스트 (분기 처리 자체) 에 영향 안 주도록
  // ============================================================

  /**
   * 분기 처리 이력 1건 기록.
   *
   * @param memberId    LoyaltyProgramMember.Id (없으면 null)
   * @param memberNo    회원 번호 (Contact.MemberNo__c, 운영자 조회용)
   * @param adjustType  처리 유형 (예: 'ACCRUAL_REVERSAL', 'USE_REVERSAL', 'SALE_MODIFY')
   * @param sourceApi   호출 API (예: 'POST /gd/v1/return')
   * @param originalSaleOrDepositNo 원거래 식별자
   * @param requested   요청 처리 금액
   * @param actual      실제 처리 금액 (잔액 부족 시 < requested)
   * @param reason      추가 audit 메모 (LongTextArea)
   * @return            생성된 MigrationAdjustmentLog__c.Id (실패 시 null)
   *
   * 안전성:
   *   - 모든 인자 null 안전
   *   - DML 실패 시 null 반환, 호출자에 throw X (분기 흐름 깨면 안 됨)
   *   - System.debug 로 흔적만 남김
   */
  public static Id recordAdjustmentLog(
    Id memberId,
    String memberNo,
    String adjustType,
    String sourceApi,
    String originalSaleOrDepositNo,
    Decimal requested,
    Decimal actual,
    String reason
  ) {
    if (String.isBlank(adjustType)) {
      System.debug('GdMigrationUtil.recordAdjustmentLog skipped: adjustType blank');
      return null;
    }

    Decimal req = (requested == null) ? 0 : requested;
    Decimal act = (actual == null) ? 0 : actual;
    Decimal loss = req - act;
    if (loss < 0) {
      loss = 0;
    }

    MigrationAdjustmentLog__c log = new MigrationAdjustmentLog__c();
    if (memberId != null) {
      log.MemberId__c = String.valueOf(memberId);
    }
    if (String.isNotBlank(memberNo)) {
      log.MemberNo__c = memberNo;
    }
    log.AdjustType__c = adjustType;
    if (String.isNotBlank(sourceApi)) {
      log.SourceApi__c = sourceApi;
    }
    if (String.isNotBlank(originalSaleOrDepositNo)) {
      log.OriginalSaleNo__c = originalSaleOrDepositNo;
    }
    log.RequestedPoints__c = req;
    log.ActualPoints__c = act;
    log.CustomerLoss__c = loss;
    if (String.isNotBlank(reason)) {
      // 32k 안전 truncate
      String safeReason = reason.length() > 30000 ? reason.substring(0, 30000) : reason;
      log.Reason__c = safeReason;
    }

    try {
      Database.SaveResult sr = Database.insert(log, false);
      if (sr.isSuccess()) {
        return sr.getId();
      } else {
        Database.Error err = sr.getErrors().isEmpty() ? null : sr.getErrors()[0];
        System.debug('GdMigrationUtil.recordAdjustmentLog insert failed: ' +
          (err == null ? '(no error)' : err.getMessage()));
        return null;
      }
    } catch (Exception e) {
      System.debug('GdMigrationUtil.recordAdjustmentLog exception: ' + e.getMessage());
      return null;
    }
  }

  // ============================================================
  // Section 7: 적립 계산 (Phase 6.3) — DML 없는 calculation-only
  //
  // 표준 GdPointServiceImpl.creditPointsOnPurchaseV2 의 핵심 계산 로직만 추출.
  // 옛 거래 (옵션 C 마이그) 시나리오 처리 시 force-debit/credit 의 기준값 산출.
  //
  // 안전성
  //   - DML 0 건 (read SOQL 만)
  //   - 표준 함수 호출 안 함 (의존성 격리)
  //   - 표준 코드 0 줄 수정
  //   - 실패 시 빈 list 반환 (throw X) — 호출자 흐름 보호
  //
  // 한계 (사용자 인지 필요)
  //   - 회원 현재 등급 기준 (옛 거래 당시 등급과 다를 수 있음)
  //   - 옛 프로모션 종료 시 보너스 적립률 미반영
  //   - 적립률 정책 변경 시 옛 거래에 현재 정책 적용
  // ============================================================

  // 적립 불가 결제 수단 (표준 calculateEligibleAccrualAmount 와 동일)
  private static final Set<String> PAYMENT_METHODS_NOT_ACCRUAL_ELIGIBLE = new Set<String>{
    '20', '81', '90', '93'
  };

  /**
   * 적립 예상 결과 — Subtype 별로 1 건씩 반환.
   */
  public class AccrualEstimate {
    public Id subtypeId;             // LoyaltyProgramCurrencySubtype Id
    public String subtypeName;       // 예: '구매포인트', '사은포인트'
    public String pointTypeCode;     // 예: '01' (구매), '06' (사은)
    public Decimal pointRate;        // 적립률 % (예: 1.00 = 1%)
    public Decimal points;           // 계산된 적립 포인트
  }

  /**
   * 옛 거래 적립 계산 (DML 없음).
   *
   * 표준 동작 모방:
   *   1. 회원의 LoyaltyMemberTier → LoyaltyTierBenefit 조회 (현재 등급 기반)
   *   2. promotionId 있으면 Promotion.PointTypeCode__c 추출 → 제외 SubType set
   *   3. 각 LoyaltyTierBenefit 별로 points = eligibleAmount × (rate / 100)
   *
   * @param memberId        LoyaltyProgramMember.Id (필수)
   * @param eligibleAmount  적립 가능 결제 금액 (WON)
   * @param promotionId     프로모션 Id (없으면 null)
   * @return                List<AccrualEstimate> (계산 실패 시 빈 list)
   *
   * 안전성:
   *   - SOQL 만 (read-only)
   *   - 모든 예외 catch → 빈 list 반환
   *   - 입력 검증
   */
  public static List<AccrualEstimate> calculateAccrualForOldOrder(
    Id memberId,
    Decimal eligibleAmount,
    Id promotionId
  ) {
    List<AccrualEstimate> result = new List<AccrualEstimate>();

    if (memberId == null || eligibleAmount == null || eligibleAmount <= 0) {
      return result;
    }

    try {
      // 1. Promotion PointTypeCode 제외 set
      Set<String> excludedPointTypeCodes = extractExcludedPointTypeCodes(promotionId);

      // 2. 회원 등급별 적립 보상 조회 (현재 등급 기반)
      List<LoyaltyTierBenefit> ltbList = [
        SELECT
          Benefit.PurchasePointRate__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.Name,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (
          SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :memberId
        )
      ];

      if (ltbList.isEmpty()) {
        return result;
      }

      // 3. 각 등급별 보상 적용
      for (LoyaltyTierBenefit ltb : ltbList) {
        if (ltb.Benefit == null || ltb.Benefit.PurchasePointRate__c == null) {
          continue;
        }
        if (ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c == null) {
          continue;
        }

        // 프로모션 제외 PointTypeCode 필터
        String benefitPointTypeCode = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r != null
          ? ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
          : null;
        if (
          String.isNotBlank(benefitPointTypeCode) &&
          excludedPointTypeCodes.contains(benefitPointTypeCode.trim())
        ) {
          continue;
        }

        Decimal rate = ltb.Benefit.PurchasePointRate__c;
        // 표준과 동일한 반올림 정책 (HALF_UP, scale 0)
        Decimal points = (eligibleAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);

        AccrualEstimate est = new AccrualEstimate();
        est.subtypeId = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c;
        est.subtypeName = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r != null
          ? ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name
          : null;
        est.pointTypeCode = benefitPointTypeCode;
        est.pointRate = rate;
        est.points = points;

        result.add(est);
      }

      return result;
    } catch (Exception e) {
      System.debug('GdMigrationUtil.calculateAccrualForOldOrder exception: ' + e.getMessage());
      return result;
    }
  }

  /**
   * 적립 가능 결제 금액 산출 (표준 calculateEligibleAccrualAmount 와 동일 로직).
   * TJ 리스트 + excludeAmount 받아서 적립 가능 금액 계산 (WON).
   *
   * 호출자가 deposit TJ 리스트를 알고 있을 때 활용.
   *
   * @param tjList         deposit TJ 리스트
   * @param excludeAmount  반품 제외 항목 등 차감 금액
   * @return               적립 가능 금액 (WON)
   */
  public static Decimal calculateEligibleAccrualAmount(
    List<TransactionJournal> tjList,
    Decimal excludeAmount
  ) {
    if (tjList == null || tjList.isEmpty()) {
      return 0;
    }

    Decimal totalAmount = 0;
    for (TransactionJournal tj : tjList) {
      if (tj == null) {
        continue;
      }
      // 적립 불가 결제 수단 스킵 (표준과 동일)
      if (
        tj.PaymentMethod != null &&
        PAYMENT_METHODS_NOT_ACCRUAL_ELIGIBLE.contains(tj.PaymentMethod)
      ) {
        continue;
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
        continue;
      }
      totalAmount += tj.TransactionAmount;
    }

    if (excludeAmount != null) {
      totalAmount -= excludeAmount;
    }

    return totalAmount;
  }

  /**
   * Promotion 의 적립 제외 PointTypeCode 추출.
   * Promotion.PointTypeCode__c = '01;05' 같은 ; 구분 문자열.
   */
  private static Set<String> extractExcludedPointTypeCodes(Id promotionId) {
    Set<String> result = new Set<String>();
    if (promotionId == null) {
      return result;
    }
    try {
      List<Promotion> pList = [
        SELECT Id, PointTypeCode__c FROM Promotion WHERE Id = :promotionId LIMIT 1
      ];
      if (pList.isEmpty() || String.isBlank(pList[0].PointTypeCode__c)) {
        return result;
      }
      for (String code : pList[0].PointTypeCode__c.split(';')) {
        if (String.isNotBlank(code)) {
          result.add(code.trim());
        }
      }
    } catch (Exception e) {
      System.debug('GdMigrationUtil.extractExcludedPointTypeCodes exception: ' + e.getMessage());
    }
    return result;
  }

  // ============================================================
  // Section 8: 강제 차감 (Phase 6.4) — 회원 잔액 force debit + 손실 기록
  //
  // 표준 GdPointServiceImpl.debitPoint 의 분배 패턴 그대로 사용:
  //   1. LoyaltyAggrSubPointExprLedger (LASEL) 우선순위 조회
  //   2. 가용 잔액 확인
  //   3. SubType 별 차감액 분배 (FIFO ExpiryDate, UsagePriority)
  //   4. LoyaltyPointService.debitPoints 호출
  //
  // 안전성 강화 (표준과 차이):
  //   - 표준: 잔액 부족 시 throw → 우리: 가능한 만큼만 차감 + 손실 기록
  //   - 표준: 예외 시 호출자가 감당 → 우리: try/catch + 결과 객체 반환
  //   - 호출자 흐름 보호 (분기 처리 자체 깨지면 안 됨)
  // ============================================================

  /**
   * 강제 차감 결과.
   */
  public class ForceDebitResult {
    public Decimal requestedPoints;   // 요청 차감 금액
    public Decimal actualPoints;      // 실제 차감 금액
    public Decimal loss;              // 손실 (회사 부담)
    public Boolean success;           // 차감 성공 여부 (DML 성공)
    public Id debitTjId;              // 생성된 차감 TJ Id
    public String error;              // 에러 메시지 (있는 경우)
  }

  /**
   * 회원 잔액에서 강제 차감 (잔액 부족 시 부분 차감 + 손실 기록).
   *
   * @param memberId            LoyaltyProgramMember.Id
   * @param loyaltyProgramId    LoyaltyProgram.Id
   * @param orderId             연관 Order.Id (없으면 null)
   * @param requestedPoints     요청 차감 포인트
   * @param reason              audit 메모
   * @return                    ForceDebitResult
   *
   * 동작:
   *   1. LASEL 으로 가용 잔액 조회
   *   2. actualPoints = min(requested, available)
   *   3. loss = requested - actual
   *   4. actualPoints > 0 시 force debit TJ + LoyaltyPointService.debitPoints
   *
   * 안전성:
   *   - 모든 DML try/catch
   *   - 실패 시 result.success=false, 호출자에게 throw 안 함
   */
  public static ForceDebitResult forceDebitPointsSafe(
    Id memberId,
    Id loyaltyProgramId,
    Id orderId,
    Decimal requestedPoints,
    String reason
  ) {
    ForceDebitResult result = new ForceDebitResult();
    result.requestedPoints = (requestedPoints == null) ? 0 : requestedPoints;
    result.actualPoints = 0;
    result.loss = result.requestedPoints;
    result.success = false;

    if (memberId == null || result.requestedPoints <= 0) {
      result.error = 'invalid input';
      return result;
    }

    try {
      // 1. LASEL 으로 SubType 별 가용 잔액 조회 (만료일 → 우선순위 순)
      //    안전 정책: 이관된 묶음 잔액 (PointTypeCode='04', 기타포인트) 만 차감 대상.
      //    회원이 마이그 후 신규로 적립한 포인트 (구매/사은/에코 등) 는 보호.
      List<LoyaltyAggrSubPointExprLedger__c> aggrList = [
        SELECT AvailablePoints__c, CurrencySubTypeId__r.Name,
               CurrencySubTypeId__r.UsagePriorityNumber, ExpiryDate__c
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE LoyaltyProgramMemberId__c = :memberId
          AND AvailablePoints__c > 0
          AND ExpiryDate__c >= TODAY
          AND CurrencySubTypeId__r.PointTypeCode__c = '04'
        ORDER BY ExpiryDate__c ASC, CurrencySubTypeId__r.UsagePriorityNumber ASC
      ];

      // 2. 총 가용 잔액
      Decimal totalAvailable = 0;
      for (LoyaltyAggrSubPointExprLedger__c aggr : aggrList) {
        totalAvailable += aggr.AvailablePoints__c;
      }

      // 3. 실제 차감 금액 결정 (잔액 부족 시 부분 차감)
      Decimal actual = (result.requestedPoints <= totalAvailable)
        ? result.requestedPoints
        : totalAvailable;

      if (actual <= 0) {
        // 잔액 0 → 모두 손실
        result.actualPoints = 0;
        result.loss = result.requestedPoints;
        result.success = false;
        result.error = 'no available balance';
        return result;
      }

      // 4. SubType 별 차감액 분배 (testable helper)
      Map<String, Decimal> subtypeDebitMap = distributeDebitBySubtype(aggrList, actual);

      // 5. force debit TJ insert
      Id redemptionJtId = SObjectUtil.findIdByName(JournalType.SObjectType, 'Redemption', true);
      Id apiForcedDebitJstId = SObjectUtil.findIdByConditions(
        JournalSubType.SObjectType,
        new Map<String, Object>{ 'Name' => 'Api Forced Debit', 'JournalTypeId' => redemptionJtId },
        true
      );

      TransactionJournal forceTj = buildForceDebitTJ(
        memberId, loyaltyProgramId, orderId, actual, reason, redemptionJtId, apiForcedDebitJstId
      );

      insert forceTj;
      result.debitTjId = forceTj.Id;

      // 6. LoyaltyPointService.debitPoints 호출 (SubType 별)
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      for (String subtypeName : subtypeDebitMap.keySet()) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', memberId);
        req.put('points', subtypeDebitMap.get(subtypeName));
        req.put('journalId', forceTj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', subtypeName);
        reqList.add(req);
      }

      LoyaltyPointService.debitPoints(reqList);

      // 성공
      result.actualPoints = actual;
      result.loss = result.requestedPoints - actual;
      result.success = true;
      return result;
    } catch (Exception e) {
      // 모든 예외 catch — 호출자 흐름 보호
      System.debug('GdMigrationUtil.forceDebitPointsSafe exception: ' + e.getMessage());
      result.actualPoints = 0;
      result.loss = result.requestedPoints;
      result.success = false;
      result.error = e.getMessage();
      return result;
    }
  }

  /**
   * SubType 별 차감액 분배 (FIFO ExpiryDate, UsagePriority).
   * aggrList 는 호출자가 정렬하여 전달.
   * 동일 SubType 의 여러 aggr 는 합산.
   *
   * 순수 함수 (DML/SOQL 없음) → @TestVisible 로 단위 테스트.
   */
  @TestVisible
  private static Map<String, Decimal> distributeDebitBySubtype(
    List<LoyaltyAggrSubPointExprLedger__c> aggrList,
    Decimal totalToDebit
  ) {
    Map<String, Decimal> subtypeDebitMap = new Map<String, Decimal>();
    if (aggrList == null || aggrList.isEmpty() || totalToDebit == null || totalToDebit <= 0) {
      return subtypeDebitMap;
    }
    Decimal remaining = totalToDebit;
    for (LoyaltyAggrSubPointExprLedger__c aggr : aggrList) {
      if (remaining <= 0) {
        break;
      }
      Decimal avail = (aggr.AvailablePoints__c == null) ? 0 : aggr.AvailablePoints__c;
      if (avail <= 0 || aggr.CurrencySubTypeId__r == null) {
        continue;
      }
      String subtypeName = aggr.CurrencySubTypeId__r.Name;
      if (String.isBlank(subtypeName)) {
        continue;
      }
      Decimal amt = (avail < remaining) ? avail : remaining;
      if (subtypeDebitMap.containsKey(subtypeName)) {
        subtypeDebitMap.put(subtypeName, subtypeDebitMap.get(subtypeName) + amt);
      } else {
        subtypeDebitMap.put(subtypeName, amt);
      }
      remaining -= amt;
    }
    return subtypeDebitMap;
  }

  /**
   * Force-Debit TJ 객체 빌드 (insert 전).
   * DML/SOQL 없음 → @TestVisible 로 단위 테스트.
   */
  @TestVisible
  private static TransactionJournal buildForceDebitTJ(
    Id memberId, Id loyaltyProgramId, Id orderId,
    Decimal amount, String reason,
    Id journalTypeId, Id journalSubTypeId
  ) {
    TransactionJournal forceTj = new TransactionJournal();
    forceTj.MemberId = memberId;
    forceTj.LoyaltyProgramId = loyaltyProgramId;
    if (orderId != null) {
      forceTj.OrderId = orderId;
    }
    forceTj.JournalDate = Datetime.now();
    forceTj.ActivityDate = Datetime.now();
    forceTj.JournalTypeId = journalTypeId;
    forceTj.JournalSubTypeId = journalSubTypeId;
    forceTj.JournalReason__c = '1';
    forceTj.TransactionAmount = amount;
    forceTj.Status = 'Pending';
    String safeReason = String.isBlank(reason) ? '' : reason;
    if (safeReason.length() > 30000) {
      safeReason = safeReason.substring(0, 30000);
    }
    forceTj.AdditionalNotes__c = 'OPTC_FORCE_DEBIT: ' + safeReason;
    return forceTj;
  }

  /**
   * 회원의 현재 가용 포인트 잔액 조회 (LASEL 합).
   * 호출자가 사전 잔액 확인 시 활용.
   */
  public static Decimal getAvailableBalance(Id memberId) {
    if (memberId == null) {
      return 0;
    }
    Decimal total = 0;
    try {
      for (LoyaltyAggrSubPointExprLedger__c aggr : [
        SELECT AvailablePoints__c
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE LoyaltyProgramMemberId__c = :memberId
          AND AvailablePoints__c > 0
          AND ExpiryDate__c >= TODAY
      ]) {
        total += (aggr.AvailablePoints__c == null) ? 0 : aggr.AvailablePoints__c;
      }
    } catch (Exception e) {
      System.debug('getAvailableBalance exception: ' + e.getMessage());
    }
    return total;
  }

  // ============================================================
  // Section 8.5: 강제 적립 (Phase 6.6) — 회원의 이관된 묶음 잔액에 추가 적립
  //
  // 표준 GdPointServiceImpl.creditPoint 의 패턴을 따름:
  //   1. 회원의 기타포인트 (PointTypeCode='04') SubType 확인
  //   2. force credit TJ 생성 (Accrual / Api Forced Credit)
  //   3. LoyaltyPointService.creditPoints 호출
  //
  // 안전성:
  //   - 회원의 묶음 잔액 SubType / 만료일 그대로 사용 (정합성)
  //   - 회원에게 활성 묶음 잔액 없으면 적립 안 함 (안전)
  //   - 모든 DML try/catch + 실패 시 호출자에게 throw 안 함
  // ============================================================

  /**
   * 강제 적립 결과.
   */
  public class ForceCreditResult {
    public Decimal requestedPoints;   // 요청 적립 금액
    public Decimal actualPoints;      // 실제 적립 금액
    public Decimal unprocessed;       // 적립 못한 부분 (회원 보호)
    public Boolean success;           // 적립 성공 여부
    public Id creditTjId;             // 생성된 적립 TJ Id
    public String error;              // 에러 메시지
  }

  /**
   * 회원의 이관된 묶음 잔액 (PointTypeCode='04') 에 추가 적립.
   *
   * @param memberId            LoyaltyProgramMember.Id
   * @param loyaltyProgramId    LoyaltyProgram.Id
   * @param orderId             연관 Order.Id (없으면 null)
   * @param requestedPoints     요청 적립 포인트
   * @param reason              audit 메모
   * @return                    ForceCreditResult
   *
   * 동작:
   *   1. 회원의 기타포인트 (만료 안 된) 묶음 잔액 SubType / 만료일 조회
   *   2. 묶음 잔액 미존재/만료 → 적립 skip + 미처리 기록
   *   3. force credit TJ insert + LoyaltyPointService.creditPoints
   *
   * 안전성:
   *   - 모든 DML try/catch
   *   - 실패 시 result.success=false, 호출자에게 throw 안 함
   */
  public static ForceCreditResult forceCreditPointsSafe(
    Id memberId,
    Id loyaltyProgramId,
    Id orderId,
    Decimal requestedPoints,
    String reason
  ) {
    ForceCreditResult result = new ForceCreditResult();
    result.requestedPoints = (requestedPoints == null) ? 0 : requestedPoints;
    result.actualPoints = 0;
    result.unprocessed = result.requestedPoints;
    result.success = false;

    if (memberId == null || result.requestedPoints <= 0) {
      result.error = 'invalid input';
      return result;
    }

    try {
      // 1. 회원의 활성 기타포인트 묶음 잔액 (만료 안 된) 조회
      List<LoyaltyAggrSubPointExprLedger__c> aggrList = [
        SELECT CurrencySubTypeId__c, CurrencySubTypeId__r.Name,
               ExpiryDate__c
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE LoyaltyProgramMemberId__c = :memberId
          AND CurrencySubTypeId__r.PointTypeCode__c = '04'
          AND ExpiryDate__c >= TODAY
        ORDER BY ExpiryDate__c DESC
        LIMIT 1
      ];

      if (aggrList.isEmpty()) {
        result.error = 'no active migrated lump for member (PointTypeCode=04)';
        return result;
      }

      String subtypeName = aggrList[0].CurrencySubTypeId__r.Name;
      Date expiryDate = aggrList[0].ExpiryDate__c;

      // 2. force credit TJ insert
      Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, 'Accrual', true);
      Id apiForcedCreditJstId = SObjectUtil.findIdByConditions(
        JournalSubType.SObjectType,
        new Map<String, Object>{ 'Name' => 'Api Forced Credit', 'JournalTypeId' => accrualJtId },
        true
      );

      TransactionJournal forceTj = buildForceCreditTJ(
        memberId, loyaltyProgramId, orderId, result.requestedPoints, reason,
        accrualJtId, apiForcedCreditJstId
      );

      insert forceTj;
      result.creditTjId = forceTj.Id;

      // 3. LoyaltyPointService.creditPoints 호출
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', memberId);
      req.put('journalId', forceTj.Id);
      req.put('loyaltyProgramCurrencySubtypeName', subtypeName);
      req.put('points', result.requestedPoints);
      if (expiryDate != null) {
        req.put('pointsExpirationDate', String.valueOf(expiryDate));
      }
      reqList.add(req);

      LoyaltyPointService.creditPoints(reqList);

      // 성공
      result.actualPoints = result.requestedPoints;
      result.unprocessed = 0;
      result.success = true;
      return result;
    } catch (Exception e) {
      System.debug('GdMigrationUtil.forceCreditPointsSafe exception: ' + e.getMessage());
      result.actualPoints = 0;
      result.unprocessed = result.requestedPoints;
      result.success = false;
      result.error = e.getMessage();
      return result;
    }
  }

  /**
   * Force-Credit TJ 객체 빌드 (insert 전).
   * DML/SOQL 없음 → @TestVisible 로 단위 테스트.
   */
  @TestVisible
  private static TransactionJournal buildForceCreditTJ(
    Id memberId, Id loyaltyProgramId, Id orderId,
    Decimal amount, String reason,
    Id journalTypeId, Id journalSubTypeId
  ) {
    TransactionJournal forceTj = new TransactionJournal();
    forceTj.MemberId = memberId;
    forceTj.LoyaltyProgramId = loyaltyProgramId;
    if (orderId != null) {
      forceTj.OrderId = orderId;
    }
    forceTj.JournalDate = Datetime.now();
    forceTj.ActivityDate = Datetime.now();
    forceTj.JournalTypeId = journalTypeId;
    forceTj.JournalSubTypeId = journalSubTypeId;
    forceTj.TransactionAmount = amount;
    forceTj.Status = 'Pending';
    String safeReason = String.isBlank(reason) ? '' : reason;
    if (safeReason.length() > 30000) {
      safeReason = safeReason.substring(0, 30000);
    }
    forceTj.AdditionalNotes__c = 'OPTC_FORCE_CREDIT: ' + safeReason;
    return forceTj;
  }

  // ============================================================
  // Section 9: TestVisible — 테스트에서 fallback 확인용
  // ============================================================

  @TestVisible
  private static Date getDefaultOpenDate() {
    return DEFAULT_OPEN_DATE;
  }

  @TestVisible
  private static Set<String> getMigrationInsertIds() {
    return MIG_INSERT_IDS;
  }

  @TestVisible
  private static Set<String> getPaymentMethodsNotAccrualEligible() {
    return PAYMENT_METHODS_NOT_ACCRUAL_ELIGIBLE;
  }
}