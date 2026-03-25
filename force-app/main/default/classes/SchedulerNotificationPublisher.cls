/**
 * 범용 스케줄러/배치 결과 알림 Publisher
 * - Platform Event(ErpAsyncFailure__e)를 발행하여 Custom Notification 트리거(ErpAsyncFailureTriggerHandler)로 연결
 * - 성공/부분성공/실패 결과를 공통 포맷으로 발행할 수 있도록 구성
 *
 * 사용 전제:
 * - ErpAsyncFailure__e 필드: ApiName__c, ErrorMessage__c, TargetRecordId__c
 * - ErpAsyncFailureTriggerHandler 가 알림 타입/그룹을 이용해 Custom Notification 발송
 */
public with sharing class SchedulerNotificationPublisher {
  // 메시지 길이(TriggerHandler에서 140자 제한을 두고 있어도, 여기서도 2차 방어)
  private static final Integer DEFAULT_MAX_LEN = 140;

  /**
   * 결과 상태(표준화)
   * - 기존 Status__c 픽리스트와 맞추기 위해 SUCCESS / PARTIAL / ERROR 를 사용
   */
  public enum ResultStatus {
    SUCCESS,
    PARTIAL,
    ERROR
  }

  /**
   * 발행 옵션
   * - notifyOnSuccess: SUCCESS도 알림 보낼지 여부(기본 false)
   * - maxBodyLen: 알림 본문 최대 길이(기본 140)
   * - titlePrefix: 알림 제목 prefix(기본 '⚠️ ')
   */
  public class PublishOption {
    public Boolean notifyOnSuccess = false;
    public Integer maxBodyLen = DEFAULT_MAX_LEN;
    public String titlePrefix = '⚠️ ';
  }

  /**
   * 스케줄러/배치 결과 알림 발행 (단건)
   *
   * @param sourceName  알림에 표시할 소스명(예: 'BirthdayCouponIssueScheduler' 또는 'BirthdayCouponIssueBatch')
   * @param status      SUCCESS / PARTIAL / ERROR
   * @param summary     본문 요약(필수 권장)
   * @param targetId    알림 클릭 시 이동할 레코드(선택)
   * @param opt         옵션(선택, null 가능)
   */
  public static void publishResult(String sourceName, ResultStatus status, String summary, Id targetId, PublishOption opt) {
    System.debug('publishResult 진입');
    if (opt == null) {
      opt = new PublishOption();
    }

    // SUCCESS 알림은 기본적으로 발행하지 않음(노이즈 방지)
    if (status == ResultStatus.SUCCESS && !opt.notifyOnSuccess) {
      return;
    }

    String safeSource = String.isBlank(sourceName) ? 'Scheduler/Batch' : sourceName.trim();
    String safeSummary = String.isBlank(summary) ? '작업 결과 요약이 없습니다.' : summary.trim();

    // 제목: 상태에 따라 prefix 조정(성공이면 체크, 나머지는 경고)
    String title;
    if (status == ResultStatus.SUCCESS) {
      title = '✅ ' + safeSource + ' - SUCCESS';
    } else if (status == ResultStatus.PARTIAL) {
      title = opt.titlePrefix + safeSource + ' - PARTIAL';
    } else {
      title = opt.titlePrefix + safeSource + ' - ERROR';
    }

    String body = shorten(safeSummary, opt.maxBodyLen);

    publishEvent(safeSource, body, targetId);
  }

  /**
   * 스케줄러 실행 시작 알림(선택)
   * - 보통은 시작 알림은 노이즈가 될 수 있으므로 필요할 때만 사용
   */
  public static void publishStarted(String sourceName, String extra, Id targetId) {
    String safeSource = String.isBlank(sourceName) ? 'Scheduler' : sourceName.trim();
    String msg = '작업이 시작되었습니다.';
    if (!String.isBlank(extra)) {
      msg += '\n' + extra.trim();
    }

    // 시작 알림은 보통 WARNING가 아니라 INFO 성격이지만,
    // 현재 파이프라인이 ErpAsyncFailure__e 기반이므로 동일 이벤트를 재사용
    publishEvent(safeSource + ' (START)', shorten(msg, DEFAULT_MAX_LEN), targetId);
  }

  /**
   * 실패 알림(예외 메시지 기반)
   */
  public static void publishFailure(String sourceName, Exception e, Id targetId) {
    String safeSource = String.isBlank(sourceName) ? 'Scheduler/Batch' : sourceName.trim();
    String msg = (e == null || String.isBlank(e.getMessage())) ? '알 수 없는 오류가 발생했습니다.' : e.getMessage();
    publishEvent(safeSource, shorten(msg, DEFAULT_MAX_LEN), targetId);
  }

  // ======================================================================
  // Internal

  /**
   * Platform Event 발행 (ErpAsyncFailure__e 재사용)
   */
  private static void publishEvent(String apiName, String errorMessage, Id targetId) {
    System.debug('publishEvent 진입');
    try {
      ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
      evt.ApiName__c = apiName;
      evt.ErrorMessage__c = errorMessage;
      evt.TargetRecordId__c = (targetId == null ? null : String.valueOf(targetId));
      System.debug('apiName : ' + apiName);
      System.debug('errorMessage : ' + errorMessage);
      System.debug('targetId : ' + targetId);

      //   EventBus.publish(evt);
      Database.SaveResult sr = EventBus.publish(evt);
      System.debug('PE publish success=' + sr.isSuccess());

      if (!sr.isSuccess()) {
        for (Database.Error err : sr.getErrors()) {
          System.debug('PE publish error: ' + err.getStatusCode() + ' / ' + err.getMessage());
        }
      }

      System.debug('EventBus.publish 발송 완료');
    } catch (Exception ex) {
      // 알림 실패로 본 로직이 실패하지 않도록 방어
      System.debug('[SchedulerNotificationPublisher] publish failed: ' + ex.getMessage());
    }
  }

  /**
   * 문자열 길이 제한
   */
  private static String shorten(String s, Integer maxLen) {
    if (s == null) {
      return null;
    }
    if (maxLen == null || maxLen <= 0) {
      return s;
    }
    return (s.length() > maxLen) ? s.substring(0, maxLen) : s;
  }
}