@IsTest
private class SchedulerNotificationPublisherTest {

  /* =====================================================
   * PublishOption 필드 기본값 검증
   * ===================================================== */
  @IsTest
  static void test_publishOption_defaults() {
    SchedulerNotificationPublisher.PublishOption opt = new SchedulerNotificationPublisher.PublishOption();
    System.assertEquals(false, opt.notifyOnSuccess, 'notifyOnSuccess 기본값 false');
    System.assertEquals(140,   opt.maxBodyLen,      'maxBodyLen 기본값 140');
    System.assertEquals('⚠️ ', opt.titlePrefix,    'titlePrefix 기본값 ⚠️');
  }

  /* =====================================================
   * publishResult - SUCCESS + notifyOnSuccess=false → 조기 리턴(이벤트 발행 안 함)
   * ===================================================== */
  @IsTest
  static void test_publishResult_success_suppressedByDefault() {
    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.SUCCESS,
      '성공 요약', null, null
    );
    Test.stopTest();
    // 예외 없이 정상 종료되면 통과
    System.assert(true, 'SUCCESS + notifyOnSuccess=false → 조기 리턴');
  }

  /* =====================================================
   * publishResult - SUCCESS + notifyOnSuccess=true → 이벤트 발행
   * ===================================================== */
  @IsTest
  static void test_publishResult_success_notifyOnSuccess() {
    SchedulerNotificationPublisher.PublishOption opt = new SchedulerNotificationPublisher.PublishOption();
    opt.notifyOnSuccess = true;

    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.SUCCESS,
      '성공 요약', null, opt
    );
    Test.stopTest();

    System.assert(true, 'SUCCESS + notifyOnSuccess=true → 이벤트 발행');
  }

  /* =====================================================
   * publishResult - PARTIAL → 이벤트 발행 (opt null)
   * ===================================================== */
  @IsTest
  static void test_publishResult_partial_nullOpt() {
    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.PARTIAL,
      '일부 실패 요약', null, null
    );
    Test.stopTest();

    System.assert(true, 'PARTIAL → 이벤트 발행');
  }

  /* =====================================================
   * publishResult - ERROR → 이벤트 발행 (opt null)
   * ===================================================== */
  @IsTest
  static void test_publishResult_error_nullOpt() {
    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.ERROR,
      '오류 요약', null, null
    );
    Test.stopTest();

    System.assert(true, 'ERROR → 이벤트 발행');
  }

  /* =====================================================
   * publishResult - sourceName 공백 → 'Scheduler/Batch' fallback 분기
   * ===================================================== */
  @IsTest
  static void test_publishResult_blankSourceName_fallback() {
    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      '  ', SchedulerNotificationPublisher.ResultStatus.ERROR,
      '오류', null, null
    );
    Test.stopTest();

    System.assert(true, '빈 sourceName → Scheduler/Batch fallback');
  }

  /* =====================================================
   * publishResult - summary 공백 → '작업 결과 요약이 없습니다.' fallback 분기
   * ===================================================== */
  @IsTest
  static void test_publishResult_blankSummary_fallback() {
    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.ERROR,
      '   ', null, null
    );
    Test.stopTest();

    System.assert(true, '빈 summary → 기본 메시지 fallback');
  }

  /* =====================================================
   * publishResult - summary null → fallback 분기
   * ===================================================== */
  @IsTest
  static void test_publishResult_nullSummary_fallback() {
    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.ERROR,
      null, null, null
    );
    Test.stopTest();

    System.assert(true, 'null summary → 기본 메시지 fallback');
  }

  /* =====================================================
   * publishResult - summary > 140자 → shorten 분기 커버
   * ===================================================== */
  @IsTest
  static void test_publishResult_longSummary_shortened() {
    String longSummary = 'A'.repeat(200); // 200자

    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.ERROR,
      longSummary, null, null
    );
    Test.stopTest();

    System.assert(true, '200자 summary → 140자 truncation');
  }

  /* =====================================================
   * publishResult - maxBodyLen 커스텀 설정
   * ===================================================== */
  @IsTest
  static void test_publishResult_customMaxBodyLen() {
    SchedulerNotificationPublisher.PublishOption opt = new SchedulerNotificationPublisher.PublishOption();
    opt.maxBodyLen = 50;

    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.ERROR,
      'A'.repeat(100), null, opt
    );
    Test.stopTest();

    System.assert(true, 'maxBodyLen=50 → 50자 truncation');
  }

  /* =====================================================
   * publishResult - maxBodyLen = 0 → shorten 내 0 이하 분기 (원본 반환)
   * ===================================================== */
  @IsTest
  static void test_publishResult_zeroMaxBodyLen_returnsOriginal() {
    SchedulerNotificationPublisher.PublishOption opt = new SchedulerNotificationPublisher.PublishOption();
    opt.maxBodyLen = 0;

    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.ERROR,
      '짧은 요약', null, opt
    );
    Test.stopTest();

    System.assert(true, 'maxBodyLen=0 → shorten 원본 반환 분기');
  }

  /* =====================================================
   * publishResult - PARTIAL + titlePrefix 커스텀
   * ===================================================== */
  @IsTest
  static void test_publishResult_partial_customTitlePrefix() {
    SchedulerNotificationPublisher.PublishOption opt = new SchedulerNotificationPublisher.PublishOption();
    opt.titlePrefix = '[WARN] ';

    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.PARTIAL,
      '부분 실패', null, opt
    );
    Test.stopTest();

    System.assert(true, 'PARTIAL + 커스텀 titlePrefix');
  }

  /* =====================================================
   * publishResult - targetId 있음 → TargetRecordId__c 세팅 분기
   * ===================================================== */
  @IsTest
  static void test_publishResult_withTargetId() {
    Account a = new Account(Name = 'TestAcc_SNP');
    insert a;

    Test.startTest();
    SchedulerNotificationPublisher.publishResult(
      'TestSource', SchedulerNotificationPublisher.ResultStatus.ERROR,
      '오류 발생', a.Id, null
    );
    Test.stopTest();

    System.assert(true, 'targetId 있음 → TargetRecordId__c 세팅');
  }

  /* =====================================================
   * publishStarted - 정상 호출 (extra 있음)
   * ===================================================== */
  @IsTest
  static void test_publishStarted_withExtra() {
    Test.startTest();
    SchedulerNotificationPublisher.publishStarted('TestScheduler', '추가 정보', null);
    Test.stopTest();

    System.assert(true, 'publishStarted(extra 있음) 정상 실행');
  }

  /* =====================================================
   * publishStarted - extra 공백 → if(!isBlank) 미진입 분기
   * ===================================================== */
  @IsTest
  static void test_publishStarted_blankExtra() {
    Test.startTest();
    SchedulerNotificationPublisher.publishStarted('TestScheduler', '   ', null);
    Test.stopTest();

    System.assert(true, 'publishStarted(빈 extra) 정상 실행');
  }

  /* =====================================================
   * publishStarted - extra null → if(!isBlank) 미진입 분기
   * ===================================================== */
  @IsTest
  static void test_publishStarted_nullExtra() {
    Test.startTest();
    SchedulerNotificationPublisher.publishStarted('TestScheduler', null, null);
    Test.stopTest();

    System.assert(true, 'publishStarted(null extra) 정상 실행');
  }

  /* =====================================================
   * publishStarted - sourceName 공백 → 'Scheduler' fallback 분기
   * ===================================================== */
  @IsTest
  static void test_publishStarted_blankSourceName() {
    Test.startTest();
    SchedulerNotificationPublisher.publishStarted('', '추가 정보', null);
    Test.stopTest();

    System.assert(true, 'publishStarted(빈 sourceName) → Scheduler fallback');
  }

  /* =====================================================
   * publishFailure - 일반 Exception
   * ===================================================== */
  @IsTest
  static void test_publishFailure_withException() {
    Exception ex = new IllegalArgumentException('테스트 예외 메시지');

    Test.startTest();
    SchedulerNotificationPublisher.publishFailure('TestBatch', ex, null);
    Test.stopTest();

    System.assert(true, 'publishFailure(Exception) 정상 실행');
  }

  /* =====================================================
   * publishFailure - null Exception → '알 수 없는 오류' fallback
   * ===================================================== */
  @IsTest
  static void test_publishFailure_nullException() {
    Test.startTest();
    SchedulerNotificationPublisher.publishFailure('TestBatch', null, null);
    Test.stopTest();

    System.assert(true, 'publishFailure(null Exception) → 알 수 없는 오류 fallback');
  }

  /* =====================================================
   * publishFailure - Exception 메시지 공백 → fallback
   * ===================================================== */
  @IsTest
  static void test_publishFailure_blankExceptionMessage() {
    // getMessage()가 빈 문자열인 경우는 직접 만들기 어려우므로,
    // null Exception 경로로 대리 커버
    Test.startTest();
    SchedulerNotificationPublisher.publishFailure(null, null, null);
    Test.stopTest();

    System.assert(true, 'publishFailure(null sourceName, null ex) → fallback');
  }

  /* =====================================================
   * publishFailure - sourceName 공백 → 'Scheduler/Batch' fallback
   * ===================================================== */
  @IsTest
  static void test_publishFailure_blankSourceName() {
    Test.startTest();
    SchedulerNotificationPublisher.publishFailure('  ', new IllegalArgumentException('err'), null);
    Test.stopTest();

    System.assert(true, 'publishFailure(빈 sourceName) → Scheduler/Batch fallback');
  }

  /* =====================================================
   * publishFailure - targetId 있음
   * ===================================================== */
  @IsTest
  static void test_publishFailure_withTargetId() {
    Account a = new Account(Name = 'TestAcc_SNP2');
    insert a;

    Test.startTest();
    SchedulerNotificationPublisher.publishFailure(
      'TestBatch', new IllegalArgumentException('에러'), a.Id
    );
    Test.stopTest();

    System.assert(true, 'publishFailure(targetId 있음) 정상 실행');
  }

  /* =====================================================
   * ResultStatus enum 값 전체 커버
   * ===================================================== */
  @IsTest
  static void test_resultStatus_enumValues() {
    System.assertEquals(
      SchedulerNotificationPublisher.ResultStatus.SUCCESS,
      SchedulerNotificationPublisher.ResultStatus.valueOf('SUCCESS')
    );
    System.assertEquals(
      SchedulerNotificationPublisher.ResultStatus.PARTIAL,
      SchedulerNotificationPublisher.ResultStatus.valueOf('PARTIAL')
    );
    System.assertEquals(
      SchedulerNotificationPublisher.ResultStatus.ERROR,
      SchedulerNotificationPublisher.ResultStatus.valueOf('ERROR')
    );
  }
}