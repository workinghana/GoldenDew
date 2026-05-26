public without sharing class LoyaltyActivityCounter {
  private static final Set<String> IMMEDIATE_ALERT_ACTIVITY_TYPES = new Set<String>{ 'SaleDelete', 'ReturnCreate', 'ReturnDelete' };

  @future(callout=true)
  public static void processMonitoringAsync(String payloadJson) {
    try {
      if (String.isBlank(payloadJson)) {
        return;
      }

      Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
      Set<Id> allContactIds = new Set<Id>();
      Map<String, Set<Id>> contactIdsByType = new Map<String, Set<Id>>();

      for (String type : raw.keySet()) {
        List<Object> ids = (List<Object>) raw.get(type);
        Set<Id> idSet = new Set<Id>();
        for (Object value : ids) {
          if (value != null) {
            idSet.add((Id) String.valueOf(value));
          }
        }
        if (!idSet.isEmpty()) {
          contactIdsByType.put(type, idSet);
          allContactIds.addAll(idSet);
        }
      }

      if (allContactIds.isEmpty()) {
        return;
      }

      Map<Id, LoyaltyProgramMember> memberByContactId = new Map<Id, LoyaltyProgramMember>();
      for (LoyaltyProgramMember member : [
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
        memberByContactId.put(member.ContactId, member);
      }

      if (memberByContactId.isEmpty()) {
        System.debug('[골든듀 모니터링] 활성 회원 없음. ContactIds=' + allContactIds.size());
        return;
      }

      Map<String, Activity_Threshold__mdt> thresholdByType = new Map<String, Activity_Threshold__mdt>();
      for (String type : contactIdsByType.keySet()) {
        Activity_Threshold__mdt threshold = getThreshold(type);
        if (threshold != null) {
          thresholdByType.put(type, threshold);
        }
      }

      Date today = Date.today();
      Map<Id, LoyaltyProgramMember> membersToUpdate = new Map<Id, LoyaltyProgramMember>();
      List<SlackNotifier.AlertPayload> thresholdAlertsToSend = new List<SlackNotifier.AlertPayload>();
      List<SlackNotifier.AlertPayload> negativeAggrAlertsToSend = new List<SlackNotifier.AlertPayload>();
      appendNegativeAggrAlerts(memberByContactId.values(), negativeAggrAlertsToSend);

      if (thresholdByType.isEmpty()) {
        System.debug('[골든듀 모니터링] 활성화된 임계치 룰이 없습니다.');
      }

      for (String activityType : contactIdsByType.keySet()) {
        Activity_Threshold__mdt threshold = thresholdByType.get(activityType);
        Boolean isImmediateAlert = IMMEDIATE_ALERT_ACTIVITY_TYPES.contains(activityType);
        if (threshold == null && !isImmediateAlert) {
          continue;
        }

        for (Id contactId : contactIdsByType.get(activityType)) {
          LoyaltyProgramMember member = memberByContactId.get(contactId);
          if (member == null) {
            continue;
          }

          if (membersToUpdate.containsKey(member.Id)) {
            member = membersToUpdate.get(member.Id);
          }

          if (member.Last_Activity_Date__c == today) {
            member.Daily_Activity_Count__c = (member.Daily_Activity_Count__c == null ? 0 : member.Daily_Activity_Count__c) + 1;
          } else {
            member.Last_Activity_Date__c = today;
            member.Daily_Activity_Count__c = 1;
          }

          Boolean shouldSendThresholdAlert = false;
          if (threshold != null) {
            Boolean isOverThreshold = member.Daily_Activity_Count__c >= threshold.Daily_Threshold__c;
            Boolean isNotAlertedToday = member.Last_Alert_Date__c != today;
            shouldSendThresholdAlert = isOverThreshold && isNotAlertedToday;
          }

          if (isImmediateAlert || shouldSendThresholdAlert) {
            SlackNotifier.AlertPayload payload = new SlackNotifier.AlertPayload();
            payload.memberId = String.valueOf(member.Id);
            payload.memberName = getMemberName(member);
            payload.memberNo = member.Contact == null ? member.MembershipNumber : member.Contact.MemberNo__c;
            payload.count = Integer.valueOf(member.Daily_Activity_Count__c);
            payload.threshold = threshold == null ? null : Integer.valueOf(threshold.Daily_Threshold__c);
            payload.activityType = activityType;
            payload.riskLevel = threshold == null ? 'Medium' : threshold.Risk_Level__c;

            thresholdAlertsToSend.add(payload);
            if (!isImmediateAlert) {
              member.Last_Alert_Date__c = today;
            }
          }

          membersToUpdate.put(member.Id, member);
        }
      }

      Set<Id> failedAlertMemberIds = new Set<Id>();
      if (!negativeAggrAlertsToSend.isEmpty()) {
        sendAlertsInline(negativeAggrAlertsToSend);
      }
      if (!thresholdAlertsToSend.isEmpty()) {
        failedAlertMemberIds = sendAlertsInline(thresholdAlertsToSend);
      }

      if (!failedAlertMemberIds.isEmpty()) {
        rollbackFailedAlerts(membersToUpdate, failedAlertMemberIds);
      }

      if (!membersToUpdate.isEmpty()) {
        update membersToUpdate.values();
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] 비동기 처리 실패: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
  }

  private static Set<Id> sendAlertsInline(List<SlackNotifier.AlertPayload> payloads) {
    Set<Id> failedMemberIds = new Set<Id>();
    for (SlackNotifier.AlertPayload payload : payloads) {
      if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
        failedMemberIds.add((Id) payload.memberId);
        System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] Slack Callout 한도 도달로 알림 중단: ' + payload.memberName);
        continue;
      }

      Boolean success = false;
      try {
        success = SlackNotifier.sendAlertSync(payload);
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] Slack 발송 예외 (' + payload.memberName + '): ' + e.getMessage());
      }

      if (!success) {
        failedMemberIds.add((Id) payload.memberId);
        System.debug(LoggingLevel.WARN, '[골든듀 모니터링] Slack 발송 실패로 Last_Alert_Date 롤백 예정: ' + payload.memberName);
      }
    }
    return failedMemberIds;
  }

  private static void appendNegativeAggrAlerts(List<LoyaltyProgramMember> members, List<SlackNotifier.AlertPayload> alertsToSend) {
    if (members == null || members.isEmpty() || alertsToSend == null) {
      return;
    }

    Map<Id, LoyaltyProgramMember> memberById = new Map<Id, LoyaltyProgramMember>();
    for (LoyaltyProgramMember member : members) {
      if (member != null && member.Id != null) {
        memberById.put(member.Id, member);
      }
    }
    if (memberById.isEmpty()) {
      return;
    }

    for (AggregateResult row : [
      SELECT LoyaltyProgramMemberId__c memberId, COUNT(Id) cnt, SUM(AvailablePoints__c) total
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c IN :memberById.keySet() AND AvailablePoints__c < 0
      GROUP BY LoyaltyProgramMemberId__c
    ]) {
      Id memberId = (Id) row.get('memberId');
      LoyaltyProgramMember member = memberById.get(memberId);
      if (member == null) {
        continue;
      }

      Integer negativeCount = (Integer) row.get('cnt');
      Decimal negativeTotal = row.get('total') == null ? 0 : (Decimal) row.get('total');
      SlackNotifier.AlertPayload payload = new SlackNotifier.AlertPayload();
      payload.memberId = String.valueOf(member.Id);
      payload.memberName = getMemberName(member);
      payload.memberNo = member.Contact == null ? member.MembershipNumber : member.Contact.MemberNo__c;
      payload.count = negativeCount;
      payload.threshold = null;
      payload.activityType = '포인트 집계 음수 발생';
      payload.riskLevel = 'High';
      payload.detailMessage = '사용 가능 포인트 집계가 음수입니다. 음수 합계: ' + String.valueOf(negativeTotal.setScale(0)) + 'P';
      alertsToSend.add(payload);
    }
  }

  private static void rollbackFailedAlerts(Map<Id, LoyaltyProgramMember> membersToUpdate, Set<Id> failedMemberIds) {
    for (Id memberId : failedMemberIds) {
      LoyaltyProgramMember member = membersToUpdate.get(memberId);
      if (member != null) {
        member.Last_Alert_Date__c = null;
      }
    }
  }

  private static Activity_Threshold__mdt getThreshold(String activityType) {
    for (Activity_Threshold__mdt threshold : Activity_Threshold__mdt.getAll().values()) {
      if (threshold.Is_Active__c && threshold.Activity_Type__c == activityType) {
        return threshold;
      }
    }
    return null;
  }

  private static String getMemberName(LoyaltyProgramMember member) {
    if (member.Contact != null && String.isNotBlank(member.Contact.Name)) {
      return member.Contact.Name;
    }
    if (member.Account != null && String.isNotBlank(member.Account.Name)) {
      return member.Account.Name;
    }
    return member.MembershipNumber != null ? member.MembershipNumber : '(이름 없음)';
  }
}