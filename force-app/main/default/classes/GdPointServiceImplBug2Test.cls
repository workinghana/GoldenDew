/**
 * GdPointServiceImplBug2Test — Bug 2 (cancelPointRedemption UsageBucket 그룹화 결함) 단위 테스트.
 *
 * 목적:
 *   UsageBucketV2 의 핵심 동작(다중 Traceability 누적, FIFO 분배)을 직접 검증.
 *   기존 UsageBucket 로직은 그대로 유지되므로 이 테스트는 **v2 전용 안전망**.
 *
 * 커버리지 (Phase 1 TC-02, TC-03 + sanity):
 *   - TC-02: same bucket multi-Traceability full cancel
 *   - TC-03: same bucket multi-Traceability partial cancel (FIFO)
 *   - sanity: constructor, empty cancel, single entry, cancel exceeds total
 *   - sorter: UsageBucketV2CancelSorter 정렬 규칙
 *
 * 2026-04-24 Bug 2 Phase 5 Step B' 신규.
 */
@IsTest
private class GdPointServiceImplBug2Test {
  /**
   * Id 생성 헬퍼 (15-char, no checksum. Apex Id.valueOf 검증 통과용)
   */
  private static Id fakeId(String prefix, Integer suffix) {
    String padded = String.valueOf(suffix).leftPad(12, '0');
    return Id.valueOf(prefix + padded);
  }

  // ========================================================================
  // TC-02: 같은 bucket 에 Traceability 2건 있을 때 전액 취소
  // ========================================================================
  @IsTest
  static void bug2_tc02_multiTraceabilitySameBucket_fullCancel() {
    GdPointServiceImpl.UsageBucketV2 bucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12),
      '이벤트포인트',
      1,
      fakeId('11c', 1),
      String.valueOf(fakeId('05w', 1)),
      String.valueOf(fakeId('05w', 2))
    );

    Id lltA = fakeId('1Dt', 100);
    Id lltB = fakeId('1Dt', 101);
    bucket.addEntry(lltA, 85500);
    bucket.addEntry(lltB, 85500);

    System.assertEquals(171000, bucket.totalPoints, 'Bucket 총합 171,000 이어야 함');
    System.assertEquals(2, bucket.entries.size(), 'Traceability 2건 저장');

    // 전액 취소 (171,000)
    Map<Id, Decimal> allocated = bucket.allocateCancel(171000);

    System.assertEquals(2, allocated.size(), '두 Traceability 모두에 분배되어야 함');
    System.assertEquals(85500, allocated.get(lltA), 'A 전액 할당');
    System.assertEquals(85500, allocated.get(lltB), 'B 전액 할당');

    // 합계 검증
    Decimal sum = 0;
    for (Decimal v : allocated.values()) sum += v;
    System.assertEquals(171000, sum, '분배 합계가 cancel 금액과 일치');
  }

  // ========================================================================
  // TC-03: 같은 bucket 에 Traceability 2건 있을 때 부분 취소 (FIFO)
  // ========================================================================
  @IsTest
  static void bug2_tc03_multiTraceabilitySameBucket_partialCancel_FIFO() {
    GdPointServiceImpl.UsageBucketV2 bucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12),
      '이벤트포인트',
      1,
      fakeId('11c', 2),
      String.valueOf(fakeId('05w', 3)),
      String.valueOf(fakeId('05w', 4))
    );

    Id lltA = fakeId('1Dt', 200);
    Id lltB = fakeId('1Dt', 201);
    bucket.addEntry(lltA, 85500);
    bucket.addEntry(lltB, 85500);

    // 부분 취소 (100,000 — 전체 171,000 중 일부)
    Map<Id, Decimal> allocated = bucket.allocateCancel(100000);

    // FIFO: A 에 85,500 (전액), B 에 14,500 (부분)
    System.assertEquals(2, allocated.size(), '두 Traceability 모두 터치되어야 함');
    System.assertEquals(85500, allocated.get(lltA), 'A 가 FIFO 첫 번째로 전액 소비');
    System.assertEquals(14500, allocated.get(lltB), 'B 에서 남은 14,500 만 소비');

    Decimal sum = 0;
    for (Decimal v : allocated.values()) sum += v;
    System.assertEquals(100000, sum, '분배 합계 = cancel 금액');
  }

  // ========================================================================
  // Sanity: 단일 Traceability 전액 취소 (역호환성)
  // ========================================================================
  @IsTest
  static void bug2_sanity_singleTraceability_fullCancel() {
    GdPointServiceImpl.UsageBucketV2 bucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12),
      '구매포인트',
      7,
      fakeId('11c', 3),
      String.valueOf(fakeId('05w', 5)),
      String.valueOf(fakeId('05w', 6))
    );
    Id llt = fakeId('1Dt', 300);
    bucket.addEntry(llt, 100000);

    Map<Id, Decimal> allocated = bucket.allocateCancel(100000);

    System.assertEquals(1, allocated.size());
    System.assertEquals(100000, allocated.get(llt));
  }

  // ========================================================================
  // Sanity: cancel 금액 = 0 또는 null
  // ========================================================================
  @IsTest
  static void bug2_sanity_zeroOrNullCancel_returnsEmpty() {
    GdPointServiceImpl.UsageBucketV2 bucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '이벤트포인트', 1,
      fakeId('11c', 4),
      String.valueOf(fakeId('05w', 7)),
      String.valueOf(fakeId('05w', 8))
    );
    bucket.addEntry(fakeId('1Dt', 400), 50000);

    System.assertEquals(0, bucket.allocateCancel(0).size(), 'cancel=0 이면 빈 맵');
    System.assertEquals(0, bucket.allocateCancel(null).size(), 'cancel=null 이면 빈 맵');
  }

  // ========================================================================
  // Sanity: cancel 금액 > total 인 경우 (최대까지 분배)
  // ========================================================================
  @IsTest
  static void bug2_sanity_cancelExceedsTotal_allocatesMax() {
    GdPointServiceImpl.UsageBucketV2 bucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '이벤트포인트', 1,
      fakeId('11c', 5),
      String.valueOf(fakeId('05w', 9)),
      String.valueOf(fakeId('05w', 10))
    );
    bucket.addEntry(fakeId('1Dt', 500), 50000);
    bucket.addEntry(fakeId('1Dt', 501), 30000);

    // cancel 100,000 요청이지만 실제로는 80,000 분배 가능
    Map<Id, Decimal> allocated = bucket.allocateCancel(100000);
    Decimal sum = 0;
    for (Decimal v : allocated.values()) sum += v;
    System.assertEquals(80000, sum, '최대 총합만 분배됨 (나머지는 caller 가 처리)');
  }

  // ========================================================================
  // Sanity: 빈 bucket (entries 없음)
  // ========================================================================
  @IsTest
  static void bug2_sanity_emptyBucket_returnsEmpty() {
    GdPointServiceImpl.UsageBucketV2 bucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '이벤트포인트', 1,
      fakeId('11c', 6),
      String.valueOf(fakeId('05w', 11)),
      String.valueOf(fakeId('05w', 12))
    );
    // addEntry 호출 없이 비운 상태
    Map<Id, Decimal> allocated = bucket.allocateCancel(10000);
    System.assertEquals(0, allocated.size());
  }

  // ========================================================================
  // TC-09: V4-SCN03 상황 재현 — 3 buckets 걸침 + FIFO 분배
  // ========================================================================
  @IsTest
  static void bug2_tc09_crossBucket_FIFO_allocation() {
    // 이벤트 bucket (priority=1)
    GdPointServiceImpl.UsageBucketV2 eventBucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '이벤트포인트', 1,
      fakeId('11c', 7),
      String.valueOf(fakeId('05w', 20)),
      String.valueOf(fakeId('05w', 21))
    );
    Id ev1 = fakeId('1Dt', 900);
    Id ev2 = fakeId('1Dt', 901);
    eventBucket.addEntry(ev1, 85500);
    eventBucket.addEntry(ev2, 85500);

    // 사은 bucket (priority=5)
    GdPointServiceImpl.UsageBucketV2 giftBucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '사은포인트', 5,
      fakeId('11c', 8),
      String.valueOf(fakeId('05w', 22)),
      String.valueOf(fakeId('05w', 23))
    );
    giftBucket.addEntry(fakeId('1Dt', 902), 85500);

    // 구매 bucket (priority=7)
    GdPointServiceImpl.UsageBucketV2 purchaseBucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '구매포인트', 7,
      fakeId('11c', 9),
      String.valueOf(fakeId('05w', 24)),
      String.valueOf(fakeId('05w', 25))
    );
    purchaseBucket.addEntry(fakeId('1Dt', 903), 23500);

    // 정렬 — 만료일 동일 → 우선순위 DESC (높은 숫자 먼저)
    // UsageBucketV2CancelSorter 는 만료일 DESC, 우선순위 DESC, 이름 ASC
    List<GdPointServiceImpl.UsageBucketV2> ubList = new List<GdPointServiceImpl.UsageBucketV2>{
      eventBucket, giftBucket, purchaseBucket
    };
    ubList.sort(new GdPointServiceImpl.UsageBucketV2CancelSorter());

    // 정렬 후: 만료일 DESC → 모두 동일 → 우선순위 DESC → 구매(7) > 사은(5) > 이벤트(1)
    System.assertEquals('구매포인트', ubList[0].pointSubTypeName, '정렬 1: 구매 (priority 7)');
    System.assertEquals('사은포인트', ubList[1].pointSubTypeName, '정렬 2: 사은 (priority 5)');
    System.assertEquals('이벤트포인트', ubList[2].pointSubTypeName, '정렬 3: 이벤트 (priority 1)');

    // V4-SCN03 3-11 시나리오: 총 280,000 취소. 정렬된 순서대로 순회 가능성 검증.
    // (실제 순회 로직은 cancelPointRedemption_v2 내부에 있고 본 테스트는 UsageBucketV2 단독 검증)
    Map<Id, Decimal> evAlloc = eventBucket.allocateCancel(171000);
    System.assertEquals(2, evAlloc.size(), '이벤트 bucket 의 2건 모두 분배');
    System.assertEquals(85500, evAlloc.get(ev1), '이벤트 A (FIFO 1)');
    System.assertEquals(85500, evAlloc.get(ev2), '이벤트 B (FIFO 2)');
  }

  // ========================================================================
  // Sorter: 만료일 DESC 정렬
  // ========================================================================
  @IsTest
  static void bug2_sorter_expiryDateDesc() {
    GdPointServiceImpl.UsageBucketV2 earlier = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(6), '이벤트포인트', 1,
      fakeId('11c', 10),
      String.valueOf(fakeId('05w', 30)),
      String.valueOf(fakeId('05w', 31))
    );
    GdPointServiceImpl.UsageBucketV2 later = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '이벤트포인트', 1,
      fakeId('11c', 11),
      String.valueOf(fakeId('05w', 32)),
      String.valueOf(fakeId('05w', 33))
    );

    List<GdPointServiceImpl.UsageBucketV2> sortList = new List<GdPointServiceImpl.UsageBucketV2>{ earlier, later };
    sortList.sort(new GdPointServiceImpl.UsageBucketV2CancelSorter());
    System.assertEquals(later.expiryDate, sortList[0].expiryDate, '만료일 먼 것 먼저');
  }

  // ========================================================================
  // Constructor: TraceabilityEntry 기본 동작
  // ========================================================================
  @IsTest
  static void bug2_traceabilityEntry_construction() {
    Id id = fakeId('1Dt', 999);
    GdPointServiceImpl.TraceabilityEntry entry = new GdPointServiceImpl.TraceabilityEntry(id, 12345);
    System.assertEquals(id, entry.lltId);
    System.assertEquals(12345, entry.points);

    // null points → 0 으로 정규화
    GdPointServiceImpl.TraceabilityEntry entryNull = new GdPointServiceImpl.TraceabilityEntry(id, null);
    System.assertEquals(0, entryNull.points, 'null points 는 0 으로 정규화');
  }

  // ========================================================================
  // CancelPortionV2: UsageBucketV2 로부터 생성
  // ========================================================================
  @IsTest
  static void bug2_cancelPortionV2_construction() {
    GdPointServiceImpl.UsageBucketV2 bucket = new GdPointServiceImpl.UsageBucketV2(
      Date.today().addMonths(12), '이벤트포인트', 1,
      fakeId('11c', 12),
      String.valueOf(fakeId('05w', 40)),
      String.valueOf(fakeId('05w', 41))
    );
    bucket.addEntry(fakeId('1Dt', 1000), 50000);

    GdPointServiceImpl.CancelPortionV2 portion = new GdPointServiceImpl.CancelPortionV2(bucket, 30000);
    System.assertEquals(30000, portion.cancelPoints);
    System.assertEquals('이벤트포인트', portion.pointSubTypeName);
    System.assertEquals(1, portion.usagePriority);
  }

  // ========================================================================
  // GdFeatureFlag: Flag 헬퍼 기본 동작
  // ========================================================================
  @IsTest
  static void bug2_featureFlag_disabled_by_default() {
    GdFeatureFlag.clearCacheForTest();
    Boolean enabled = GdFeatureFlag.isEnabled('NonExistentFlagXYZ');
    System.assertEquals(false, enabled, '존재하지 않는 Flag 는 false');
  }

  @IsTest
  static void bug2_featureFlag_blankName_returnsFalse() {
    System.assertEquals(false, GdFeatureFlag.isEnabled(''), '빈 문자열 → false');
    System.assertEquals(false, GdFeatureFlag.isEnabled(null), 'null → false');
  }

  @IsTest
  static void bug2_featureFlag_setForTest_controlsReturn() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('TestFlagName', true);
    System.assertEquals(true, GdFeatureFlag.isEnabled('TestFlagName'));
    GdFeatureFlag.setForTest('TestFlagName', false);
    System.assertEquals(false, GdFeatureFlag.isEnabled('TestFlagName'));
  }
}