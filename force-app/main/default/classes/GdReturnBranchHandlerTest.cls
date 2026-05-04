/**
 * GdReturnBranchHandler Test
 *
 * 검증 영역
 *   A. validateReturnAmountWithinPolicy — 통과 케이스
 *   B. validateReturnAmountWithinPolicy — 차단 케이스 (정책 위반)
 *   C. validateReturnAmountWithinPolicy — skip 케이스 (표준에 위임)
 *   D. wrapResponseIfSilentFail — silent fail 감지 + enrich
 *   E. wrapResponseIfSilentFail — 정상 동작 시 wrap 안 함
 *   F. wrapResponseIfSilentFail — 안전성 (null 처리)
 */
@IsTest
private class GdReturnBranchHandlerTest {

  // 테스트 상수
  private static final Decimal ORIGINAL_AMOUNT = 100000;

  // ============================================================
  // @TestSetup
  // ============================================================
  @TestSetup
  static void setupData() {
    Id stdPbId = Test.getStandardPricebookId();

    Account company = new Account(Name = 'Co_RB', CompanyCode__c = 'CMP-RB');
    insert company;

    Account store = new Account(Name = 'Store_RB', StoreCode__c = 'STR-RB');
    insert store;

    Contact c = new Contact(LastName = 'RBTester', MemberNo__c = 'M-RB-TEST', AccountId = company.Id);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP_RB', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-RB-TEST',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    // 원판매 (100,000원)
    Order originalOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SALE-RB-ORIG',
      ActualPaymentAmount__c = ORIGINAL_AMOUNT,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert originalOrder;

    // 원판매 — ActualPaymentAmount__c = NULL (한도 검증 불가 케이스)
    Order originalOrderNullAmount = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SALE-RB-NULLAMT',
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert originalOrderNullAmount;

    // 기존 부분 반품 1: 30,000원, returnSuccess (누계 카운트 대상)
    Order existingReturn1 = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 6, 1),
      Status = 'returnSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'RET-RB-EXIST-30K',
      ActualPaymentAmount__c = 30000,
      Type = 'Standard',
      SaleStatus__c = '03',
      IsReductionOrder__c = true,
      OriginalOrderId__c = originalOrder.Id,
      InsertId__c = 'tester'
    );
    insert existingReturn1;

    // 기존 부분 반품 2: 30,000원, returnSuccess (누계 카운트 대상)
    Order existingReturn2 = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 6, 5),
      Status = 'returnSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'RET-RB-EXIST-30K-2',
      ActualPaymentAmount__c = 30000,
      Type = 'Standard',
      SaleStatus__c = '03',
      IsReductionOrder__c = true,
      OriginalOrderId__c = originalOrder.Id,
      InsertId__c = 'tester'
    );
    insert existingReturn2;

    // 기존 반품 (returnDeleted Status) — 누계 카운트 제외 대상
    Order existingReturnDeleted = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 6, 10),
      Status = 'returnDeleted',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'RET-RB-DELETED',
      ActualPaymentAmount__c = 50000,
      Type = 'Standard',
      SaleStatus__c = '03',
      IsReductionOrder__c = true,
      OriginalOrderId__c = originalOrder.Id,
      InsertId__c = 'tester'
    );
    insert existingReturnDeleted;
  }

  // ============================================================
  // A. validateReturnAmountWithinPolicy — 통과 케이스
  // ============================================================

  @IsTest
  static void validate_partialReturnWithinLimit_passes() {
    // 누계 60,000 (30,000 + 30,000) + 이번 30,000 = 90,000 ≤ 100,000 → 통과
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 30000
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, '예외 없이 통과해야 함');
  }

  @IsTest
  static void validate_exactlyAtLimit_passes() {
    // 누계 60,000 + 이번 40,000 = 100,000 = 원판매 → 통과 (≤ 비교)
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 40000
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, '잔여 가능과 정확히 일치 시 통과');
  }

  @IsTest
  static void validate_returnDeletedExcludedFromTotal_passes() {
    // 누계는 60,000 만 (returnDeleted 50,000 은 제외) + 이번 35,000 = 95,000 ≤ 100,000 → 통과
    // returnDeleted 가 카운트되면 110,000 > 100,000 으로 차단되었을 것
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 35000
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, 'returnDeleted Status 는 누계에서 제외');
  }

  // ============================================================
  // B. validateReturnAmountWithinPolicy — 차단 케이스
  // ============================================================

  @IsTest
  static void validate_overLimit_throws400() {
    // 누계 60,000 + 이번 50,000 = 110,000 > 100,000 → 차단
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 50000
    };

    Test.startTest();
    Boolean thrown = false;
    Integer caughtCode = -1;
    String caughtMsg = '';
    try {
      GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    } catch (CustomException ce) {
      thrown = true;
      caughtCode = ce.code;
      caughtMsg = ce.message;
    }
    Test.stopTest();

    System.assertEquals(true, thrown, '한도 초과 → CustomException');
    System.assertEquals(400, caughtCode);
    System.assert(caughtMsg.contains('원판매 금액 초과'), 'message 에 원판매 금액 초과 표현 포함');
    System.assert(caughtMsg.contains('잔여 환불 가능'), 'message 에 잔여 환불 가능 표현 포함');
  }

  @IsTest
  static void validate_negativeAmount_throws400() {
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => -1000
    };

    Test.startTest();
    Boolean thrown = false;
    try {
      GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    } catch (CustomException ce) {
      thrown = (ce.code == 400);
    }
    Test.stopTest();

    System.assertEquals(true, thrown, '음수 환불 금액 차단');
  }

  @IsTest
  static void validate_zeroAmount_throws400() {
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 0
    };

    Test.startTest();
    Boolean thrown = false;
    try {
      GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    } catch (CustomException ce) {
      thrown = (ce.code == 400);
    }
    Test.stopTest();

    System.assertEquals(true, thrown, '0 환불 금액 차단');
  }

  @IsTest
  static void validate_originalAmountNull_throws400() {
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-NULLAMT',
      'ActualPaymentAmount__c' => 50000
    };

    Test.startTest();
    Boolean thrown = false;
    String caughtMsg = '';
    try {
      GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    } catch (CustomException ce) {
      thrown = (ce.code == 400);
      caughtMsg = ce.message;
    }
    Test.stopTest();

    System.assertEquals(true, thrown, '원판매 금액 NULL 차단');
    System.assert(caughtMsg.contains('원판매 금액 정보 없음'), 'message 에 명시');
  }

  // ============================================================
  // C. validateReturnAmountWithinPolicy — skip 케이스
  // ============================================================

  @IsTest
  static void validate_nullReqData_skipsSilently() {
    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(null);
    Test.stopTest();

    System.assert(true, 'null reqData 는 표준 검증으로 위임');
  }

  @IsTest
  static void validate_blankOriginalSaleNo_skipsSilently() {
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => '',
      'ActualPaymentAmount__c' => 50000
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, 'blank OriginalOrderId → 표준에 위임');
  }

  @IsTest
  static void validate_missingAmount_skipsSilently() {
    // ActualPaymentAmount__c 누락 — 표준이 처리할 것이라 skip
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG'
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, '환불 금액 missing → skip');
  }

  @IsTest
  static void validate_originalOrderNotFound_skipsSilently() {
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'NON-EXISTENT-SALE',
      'ActualPaymentAmount__c' => 50000
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, '원판매 미존재 → 표준 createReturn 이 throw 함');
  }

  // ============================================================
  // D. wrapResponseIfSilentFail — silent fail 감지 + enrich
  // ============================================================

  @IsTest
  static void wrap_silentFailDetected_enrichesResponse() {
    Map<String, Object> standardData = new Map<String, Object>{
      'orderId' => '801XXXXXXXXXXXXXXX',
      'CancelPointsCreditedList' => null  // ← silent fail 신호
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'orderId' => null,  // 마커 update 는 skip 됨 (안전)
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assert(
      result.message.contains(GdReturnBranchHandler.WRAP_MESSAGE_SUFFIX),
      'message 에 WRAP_MESSAGE_SUFFIX 추가'
    );
    System.assertEquals(true, result.data.get('option_c_branch'), 'option_c_branch=true');
    System.assertEquals('skipped_due_to_migration', result.data.get('point_processing'));
    System.assertEquals(GdReturnBranchHandler.WRAP_REASON, result.data.get('reason'));
  }

  @IsTest
  static void wrap_cancelPointsCreditedListMissing_enrichesResponse() {
    // key 자체가 없는 경우 — 동일하게 silent fail 로 간주
    Map<String, Object> standardData = new Map<String, Object>{
      'orderId' => '801XXXXXXXXXXXXXXX'
      // CancelPointsCreditedList key 자체가 없음
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'), 'key missing 도 silent fail 로 처리');
  }

  // ============================================================
  // E. wrapResponseIfSilentFail — 정상 동작 시 wrap 안 함
  // ============================================================

  @IsTest
  static void wrap_cancelPointsCreditedListPresent_doesNotWrap() {
    // 정상 처리 — CancelPointsCreditedList 에 값 있음
    Map<String, Object> standardData = new Map<String, Object>{
      'orderId' => '801XXXXXXXXXXXXXXX',
      'CancelPointsCreditedList' => new List<Object>{ new Map<String, Object>{ 'pt' => 100 } }
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals('반품 등록 완료', result.message, 'message 변경 안 됨');
    System.assertEquals(null, result.data.get('option_c_branch'), 'option_c_branch 추가 안 됨');
  }

  @IsTest
  static void wrap_noTransactionJournalInRequest_doesNotWrap() {
    // 운영자가 포인트 처리 미요청 (TJ 없음) → silent fail 무관
    Map<String, Object> standardData = new Map<String, Object>{
      'orderId' => '801XXXXXXXXXXXXXXX'
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG'
      // TransactionJournal 없음
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals(null, result.data.get('option_c_branch'), 'TJ 없으면 wrap 안 함');
  }

  // ============================================================
  // F. wrapResponseIfSilentFail — 안전성 (null 처리)
  // ============================================================

  @IsTest
  static void wrap_standardResultNull_returnsNullSafely() {
    Map<String, Object> reqData = new Map<String, Object>();

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(null, reqData, null);
    Test.stopTest();

    System.assertEquals(null, result, 'standardResult null → null 반환');
  }

  @IsTest
  static void wrap_standardDataNull_returnsAsIs() {
    ApiResult standardResult = new ApiResult(true, 200, 'msg', null);
    Map<String, Object> reqData = new Map<String, Object>();

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals(null, result.data, 'data null → 그대로 반환');
  }

  @IsTest
  static void wrap_reqDataNull_returnsAsIs() {
    Map<String, Object> standardData = new Map<String, Object>{
      'CancelPointsCreditedList' => null
    };
    ApiResult standardResult = ApiResult.ok(200, 'msg', standardData);

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, null, null);
    Test.stopTest();

    System.assertEquals(null, result.data.get('option_c_branch'), 'reqData null → wrap 안 함');
  }

  @IsTest
  static void wrap_loggerNull_doesNotThrow() {
    // logger=null 이어도 NPE 안 나야 함
    Map<String, Object> standardData = new Map<String, Object>{
      'CancelPointsCreditedList' => null
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'), 'logger null 이어도 정상 동작');
  }

  // ============================================================
  // G. wrapResponseIfSilentFail — TJ 마커 추가 + logger 동작
  // ============================================================

  @IsTest
  static void wrap_silentFailWithDepositNos_runsMarkerSoqlAndLogger() {
    // wrap 함수가 TransactionJournal 배열과 logger 받았을 때:
    //   - extractDepositNosFromRequest 추출 경로 커버
    //   - addMarkerToReturnDepositTjsByDepositNo SOQL 실행 경로 커버
    //   - logger.setStatus / setDescription 호출 경로 커버
    //   - TJ 미존재 시 SOQL 결과 비어 update 안 함 (정상)

    Map<String, Object> standardData = new Map<String, Object>{
      'CancelPointsCreditedList' => null
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'DEP-NONEXIST-RB',
          'DeposiSeqNo__c' => '1'
        }
      }
    };

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging('GdReturnBranchHandlerTest');

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, logger);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'), 'enrich 정상 동작');
    System.assert(
      result.message.contains(GdReturnBranchHandler.WRAP_MESSAGE_SUFFIX),
      'message suffix 추가됨'
    );
  }

  @IsTest
  static void wrap_extractDepositNos_handlesEmptyAndInvalid() {
    // extractDepositNosFromRequest 의 다양한 케이스 커버
    Set<String> r1 = GdReturnBranchHandler.extractDepositNosFromRequest(null);
    System.assertEquals(0, r1.size(), 'null reqData → empty set');

    Set<String> r2 = GdReturnBranchHandler.extractDepositNosFromRequest(new Map<String, Object>());
    System.assertEquals(0, r2.size(), 'TJ 키 없음 → empty set');

    // TJ 가 List 가 아닌 경우
    Set<String> r3 = GdReturnBranchHandler.extractDepositNosFromRequest(
      new Map<String, Object>{ 'TransactionJournal' => 'not-a-list' }
    );
    System.assertEquals(0, r3.size(), 'TJ 가 List 아님 → empty set');

    // TJ 안에 Map 이 아닌 element
    Set<String> r4 = GdReturnBranchHandler.extractDepositNosFromRequest(
      new Map<String, Object>{ 'TransactionJournal' => new List<Object>{ 'not-a-map' } }
    );
    System.assertEquals(0, r4.size(), 'TJ element 가 Map 아님 → 무시');

    // 정상 케이스
    Set<String> r5 = GdReturnBranchHandler.extractDepositNosFromRequest(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{ 'DepositNo__c' => 'DEP-A', 'DeposiSeqNo__c' => '1' },
          new Map<String, Object>{ 'DepositNo__c' => 'DEP-B', 'DeposiSeqNo__c' => '2' },
          new Map<String, Object>{ 'DepositNo__c' => null, 'DeposiSeqNo__c' => '3' }  // skip
        }
      }
    );
    System.assertEquals(2, r5.size(), '유효한 2건만 추출');
    System.assert(r5.contains('DEP-A-1'));
    System.assert(r5.contains('DEP-B-2'));
  }

  // ============================================================
  // H. validateReturnAmountWithinPolicy — toDecimal 변환 경로
  // ============================================================

  @IsTest
  static void validate_amountAsString_handlesCorrectly() {
    // ActualPaymentAmount__c 가 String 으로 전달 — 정상 변환되어 검증
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => '50000'
    };

    Test.startTest();
    Boolean thrown = false;
    try {
      GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    } catch (CustomException ce) {
      thrown = true;
    }
    Test.stopTest();

    System.assertEquals(true, thrown, 'String "50000" 정상 변환되어 한도 초과 차단');
  }

  @IsTest
  static void validate_amountAsDouble_handlesCorrectly() {
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 30000.0  // Double
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, 'Double 정상 변환되어 한도 내 통과');
  }

  @IsTest
  static void validate_amountInvalidString_skipsSilently() {
    // 파싱 불가 String 은 null 로 변환 → skip
    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 'not-a-number'
    };

    Test.startTest();
    GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);
    Test.stopTest();

    System.assert(true, '잘못된 String → null 변환 → skip');
  }

  // ============================================================
  // I. Phase 6.4 — wrap + force-debit 경로
  //   (LASEL 데이터 없음 → forceDebitPointsSafe 가 'no available balance' 반환)
  //   (LoyaltyTierBenefit 데이터 없음 → calculateAccrualForOldOrder 빈 list)
  //   → no accrual estimate path 또는 no balance path 둘 다 cover
  // ============================================================

  @IsTest
  static void wrap_validRefundAmount_invokesForceDebitPath() {
    // 환불 금액 유효 + 원판매 존재 + 회원 존재
    // → computeAndForceDebitForReturn 진입
    // → Tier benefit 없으므로 totalRequested=0 → 'no accrual estimate' 반환
    Map<String, Object> standardData = new Map<String, Object>{
      'orderId' => '801XXXXXXXXXXXXXXX',
      'CancelPointsCreditedList' => null
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'orderId' => '801xxxx',
      'ActualPaymentAmount__c' => 30000,
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    // wrap 자체는 성공
    System.assertEquals(true, result.data.get('option_c_branch'));
    // force debit 결과 필드 추가됨
    System.assert(result.data.containsKey('option_c_force_debit_requested'));
    System.assert(result.data.containsKey('option_c_force_debit_actual'));
    System.assert(result.data.containsKey('option_c_force_debit_loss'));
    // adjustment_log_id 도 기록됨
    System.assertNotEquals(null, result.data.get('adjustment_log_id'));
  }

  @IsTest
  static void wrap_originalSaleNotFound_recordsLogWithError() {
    // SALE-RB-NOTFOUND 라는 SaleNo 는 존재하지 않음
    Map<String, Object> standardData = new Map<String, Object>{
      'CancelPointsCreditedList' => null
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-NOTFOUND',
      'orderId' => '801xxxx',
      'ActualPaymentAmount__c' => 10000,
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(0, result.data.get('option_c_force_debit_actual'));
  }

  @IsTest
  static void wrap_blankOriginalOrderId_skipsForceDebit() {
    // OriginalOrderId 비어있음 → invalid input 반환
    Map<String, Object> standardData = new Map<String, Object>{
      'CancelPointsCreditedList' => null
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => '',
      'ActualPaymentAmount__c' => 30000,
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(0, result.data.get('option_c_force_debit_requested'));
  }

  @IsTest
  static void wrap_zeroRefundAmount_skipsForceDebit() {
    Map<String, Object> standardData = new Map<String, Object>{
      'CancelPointsCreditedList' => null
    };
    ApiResult standardResult = ApiResult.ok(200, '반품 등록 완료', standardData);

    Map<String, Object> reqData = new Map<String, Object>{
      'OriginalOrderId' => 'SALE-RB-ORIG',
      'ActualPaymentAmount__c' => 0,
      'TransactionJournal' => new List<Object>{ new Map<String, Object>() }
    };

    Test.startTest();
    ApiResult result = GdReturnBranchHandler.wrapResponseIfSilentFail(standardResult, reqData, null);
    Test.stopTest();

    System.assertEquals(0, result.data.get('option_c_force_debit_requested'));
  }

  @IsTest
  static void findPromotionIdForOriginalOrder_returnsNullWhenNoTj() {
    // 신규 Order, TJ 미존재 → null
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-RB-ORIG' LIMIT 1];

    Test.startTest();
    Id promId = GdReturnBranchHandler.findPromotionIdForOriginalOrder(o.Id);
    Test.stopTest();

    System.assertEquals(null, promId, 'PromotionId TJ 없음 → null');
  }

  @IsTest
  static void findPromotionIdForOriginalOrder_nullInput_returnsNull() {
    Test.startTest();
    Id promId = GdReturnBranchHandler.findPromotionIdForOriginalOrder(null);
    Test.stopTest();
    System.assertEquals(null, promId);
  }

}