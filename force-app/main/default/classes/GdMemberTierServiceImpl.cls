public with sharing class GdMemberTierServiceImpl implements GdMemberTierService {
  /**
   * 요청 일자를 기준으로 회원 등급 조회
   */
  public String resolveAccrualGrade(Id lpmId, Date reqDate) {
    try {
      if (lpmId == null || reqDate == null) {
        throw new CustomException(400, 'lpmId or reqDate is null');
      }

      // 회원 등급 조회
      List<LoyaltyMemberTier> lmtList = [
        SELECT Id, LastModifiedDate, LoyaltyMember.Contact.Grade__c, LoyaltyMember.Contact.PreviousGrade__c
        FROM LoyaltyMemberTier
        WHERE LoyaltyMemberId = :lpmId
        ORDER BY LastModifiedDate DESC
        LIMIT 1
      ];
      if (lmtList.isEmpty()) {
        throw new CustomException(400, '회원 등급이 존재하지 않습니다. ' + lpmId);
      }

      if (reqDate < lmtList[0].LastModifiedDate.date()) {
        if (lmtList[0].LoyaltyMember.Contact.PreviousGrade__c == null) {
          throw new CustomException(400, '회원의 이전 등급이 없습니다. ' + lpmId);
        }
        return lmtList[0].LoyaltyMember.Contact.PreviousGrade__c; // 이전 등급 반환
      } else {
        return lmtList[0].LoyaltyMember.Contact.Grade__c; // 현재 등급 반환
      }
    } catch (Exception e) {
      throw e;
    }
  }
}