public without sharing class LoyaltyActivityCounter {
  /**
   * 🆕 비동기 진입점 - 통합 처리
   * - OrderTriggerHandler의 enqueueMonitoring()에서 호출됨
   * - 한 번의 @future로 모든 활동유형 처리
   *
   * 처리 순서:
   *   1) JSON 파싱
   *   2) SOQL - 활성 회원 조회
   *   3) 임계치 룰 로드
   *   4) 카운트 갱신 (메모리)
   *   5) Slack 알림 발송 (Callout, 실패 추적)
   *   6) 실패한 알림은 Last_Alert_Date 롤백
   *   7) DML - 회원 정보 업데이트
   *
   * @param payloadJson Map<String, List<Id>> 형식의 JSON
   */
  @future(callout=true)
  public static void processMonitoringAsync(String payloadJson) {
    try {
      if (String.isBlank(payloadJson)) {
        return;
      }

      // 1️⃣ JSON 파싱
      Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);

      Set<Id> allContactIds = new Set<Id>();
      Map<String, Set<Id>> contactIdsByType = new Map<String, Set<Id>>();

      for (String type : raw.keySet()) {
        List<Object> ids = (List<Object>) raw.get(type);
        Set<Id> idSet = new Set<Id>();
        for (Object o : ids) {
          idSet.add((Id) o);
        }
        if (!idSet.isEmpty()) {
          contactIdsByType.put(type, idSet);
          allContactIds.addAll(idSet);
        }
      }

      if (allContactIds.isEmpty()) {
        return;
      }

      // 2️⃣ SOQL 1회 - 모든 활성 회원 조회
      Map<Id, LoyaltyProgramMember> memberByContactId = new Map<Id, LoyaltyProgramMember>();
      for (LoyaltyProgramMember m : [
        SELECT
          Id,
          ContactId,
          MembershipNumber,
          Last_Activity_Date__c,
          Daily_Activity_Count__c,
          Last_Alert_Date__c,
          Contact.Name,
          Account.Name,
          Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE ContactId IN :allContactIds AND MemberStatus = 'Active'
      ]) {
        memberByContactId.put(m.ContactId, m);
      }

      if (memberByContactId.isEmpty()) {
        System.debug('[골든듀 모니터링] 활성 회원 없음. ContactIds=' + allContactIds.size());
        return;
      }

      // 3️⃣ 활동유형별 임계치 룰 미리 로드
      Map<String, Activity_Threshold__mdt> thresholdByType = new Map<String, Activity_Threshold__mdt>();
      for (String type : contactIdsByType.keySet()) {
        Activity_Threshold__mdt t = getThreshold(type);
        if (t != null) {
          thresholdByType.put(type, t);
        }
      }

      if (thresholdByType.isEmpty()) {
        System.debug('[골든듀 모니터링] 활성화된 임계치 룰이 없습니다.');
        return;
      }

      // 4️⃣ 카운트 갱신 + 임계치 체크 (메모리 작업만)
      Date today = Date.today();
      Map<Id, LoyaltyProgramMember> membersToUpdate = new Map<Id, LoyaltyProgramMember>();
      List<SlackNotifier.AlertPayload> alertsToSend = new List<SlackNotifier.AlertPayload>();

      for (String activityType : contactIdsByType.keySet()) {
        Activity_Threshold__mdt threshold = thresholdByType.get(activityType);
        if (threshold == null) {
          continue;
        }

        for (Id contactId : contactIdsByType.get(activityType)) {
          LoyaltyProgramMember m = memberByContactId.get(contactId);
          if (m == null) {
            continue;
          }

          // 이미 같은 트랜잭션에서 업데이트한 회원이면 갱신된 값 사용
          if (membersToUpdate.containsKey(m.Id)) {
            m = membersToUpdate.get(m.Id);
          }

          // 일자 비교 후 카운트 증가 또는 리셋
          if (m.Last_Activity_Date__c == today) {
            m.Daily_Activity_Count__c = (m.Daily_Activity_Count__c == null ? 0 : m.Daily_Activity_Count__c) + 1;
          } else {
            m.Last_Activity_Date__c = today;
            m.Daily_Activity_Count__c = 1;
          }

          // 임계치 초과 + 오늘 알림 미발송 시 → 알림 대상
          Boolean isOverThreshold = m.Daily_Activity_Count__c >= threshold.Daily_Threshold__c;
          Boolean isNotAlertedToday = m.Last_Alert_Date__c != today;

          if (isOverThreshold && isNotAlertedToday) {
            SlackNotifier.AlertPayload p = new SlackNotifier.AlertPayload();
            p.memberId = m.Id;
            p.memberName = getMemberName(m);
            p.memberNo = m.Contact.MemberNo__c;
            p.count = Integer.valueOf(m.Daily_Activity_Count__c);
            p.threshold = Integer.valueOf(threshold.Daily_Threshold__c);
            p.activityType = activityType;
            p.riskLevel = threshold.Risk_Level__c;

            alertsToSend.add(p);
            m.Last_Alert_Date__c = today; // 일단 임시로 세팅 (Slack 실패 시 롤백)
          }

          membersToUpdate.put(m.Id, m);
        }
      }

      // ⚡⚡ 순서 변경: Callout 먼저 → DML 나중 ⚡⚡

      // 5️⃣ Slack 알림 발송 (Callout, 실패한 회원 추적)
      Set<Id> failedAlertMemberIds = new Set<Id>();
      if (!alertsToSend.isEmpty()) {
        failedAlertMemberIds = sendAlertsInline(alertsToSend);
      }

      // 6️⃣ Slack 발송 실패한 회원은 Last_Alert_Date 롤백 (다음 트랜잭션에서 재시도)
      if (!failedAlertMemberIds.isEmpty()) {
        rollbackFailedAlerts(membersToUpdate, failedAlertMemberIds);
      }

      // 7️⃣ DML 1회 (모든 회원 한 번에 업데이트)
      if (!membersToUpdate.isEmpty()) {
        update membersToUpdate.values();
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] 비동기 처리 실패: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
  }

  /**
   * Slack 알림 발송 (실패한 회원 ID 반환)
   * - @future 내부이므로 SlackNotifier.sendAlertSync 사용
   * - 개별 실패는 다른 알림 발송에 영향 없음
   *
   * @return 발송 실패한 회원 Id 집합
   */
  private static Set<Id> sendAlertsInline(List<SlackNotifier.AlertPayload> payloads) {
    Set<Id> failedMemberIds = new Set<Id>();

    for (SlackNotifier.AlertPayload p : payloads) {
      Boolean success = false;
      try {
        success = SlackNotifier.sendAlertSync(p);
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] Slack 발송 예외 (' + p.memberName + '): ' + e.getMessage());
      }

      if (!success) {
        failedMemberIds.add((Id) p.memberId);
        System.debug(LoggingLevel.WARN, '[골든듀 모니터링] Slack 발송 실패로 Last_Alert_Date 롤백 예정: ' + p.memberName);
      }
    }

    return failedMemberIds;
  }

  /**
   * Slack 발송 실패한 회원의 Last_Alert_Date 롤백
   * - 카운트(Daily_Activity_Count__c, Last_Activity_Date__c)는 유지 (활동 자체는 발생했음)
   * - Last_Alert_Date만 원복 → 다음 활동 시 재시도 가능
   */
  private static void rollbackFailedAlerts(Map<Id, LoyaltyProgramMember> membersToUpdate, Set<Id> failedMemberIds) {
    for (Id memberId : failedMemberIds) {
      LoyaltyProgramMember m = membersToUpdate.get(memberId);
      if (m != null) {
        // null로 설정해서 다음 활동에서 알림 재시도 가능하게 함
        m.Last_Alert_Date__c = null;
      }
    }
  }

  /**
   * 활동유형에 해당하는 활성화된 임계치 룰 조회
   */
  private static Activity_Threshold__mdt getThreshold(String activityType) {
    for (Activity_Threshold__mdt t : Activity_Threshold__mdt.getAll().values()) {
      if (t.Is_Active__c && t.Activity_Type__c == activityType) {
        return t;
      }
    }
    return null;
  }

  /**
   * 회원의 표시 이름 (Contact 이름 → Account 이름 → 회원번호 순)
   */
  private static String getMemberName(LoyaltyProgramMember m) {
    if (m.Contact != null && String.isNotBlank(m.Contact.Name)) {
      return m.Contact.Name;
    }
    if (m.Account != null && String.isNotBlank(m.Account.Name)) {
      return m.Account.Name;
    }
    return m.MembershipNumber != null ? m.MembershipNumber : '(이름 없음)';
  }
}