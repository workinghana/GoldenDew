public with sharing class GdLoyaltyAggrSubUIController {
  @AuraEnabled(cacheable=true)
  public static List<PointDetailDTO> getPointDetails(Id loyaltyProgramMemberId) {
    List<LoyaltyAggrSubPointExprLedger__c> ledgers = [
      SELECT Id, CurrencySubTypeName__c, AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c, ExpiryDate__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :loyaltyProgramMemberId
      ORDER BY ExpiryDate__c
    ];

    List<PointDetailDTO> result = new List<PointDetailDTO>();

    for (LoyaltyAggrSubPointExprLedger__c l : ledgers) {
      PointDetailDTO dto = new PointDetailDTO();
      dto.ledgerId = l.Id;
      dto.pointTypeName = l.CurrencySubTypeName__c;
      dto.accruedPoints = (Integer) l.AccruedPoints__c;
      dto.usedPoints = (Integer) l.RedeemedPoints__c;
      dto.expiredPoints = (Integer) l.ExpiredPoints__c;
      dto.ledgerId = l.Id;

      dto.remainingPoints = dto.accruedPoints - dto.usedPoints - dto.expiredPoints;

      dto.expirationDate = l.ExpiryDate__c;
      result.add(dto);
    }

    return result;
  }

  public class PointDetailDTO {
    @AuraEnabled
    public Id ledgerId;
    @AuraEnabled
    public String pointTypeName; // 하위 포인트 유형
    @AuraEnabled
    public Integer accruedPoints; // 적립
    @AuraEnabled
    public Integer usedPoints; // 사용
    @AuraEnabled
    public Integer expiredPoints; // 만료
    @AuraEnabled
    public Integer remainingPoints; // 잔여
    @AuraEnabled
    public Date expirationDate; // 만료일
  }
}