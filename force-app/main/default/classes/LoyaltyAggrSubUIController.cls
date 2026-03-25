public with sharing class LoyaltyAggrSubUIController {
  @AuraEnabled(cacheable=true)
  public static PointDetailResult getPointDetails(Id loyaltyProgramMemberId) {
    List<LoyaltyLedger> ledgers = [
      SELECT Id, Points, EventType, ExpiryDate, LoyaltyPgmCrcySubtypeId, LoyaltyPgmCrcySubtype.Name
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId
      ORDER BY ExpiryDate
    ];

    Map<String, PointDetailDTO> mapResult = new Map<String, PointDetailDTO>();

    for (LoyaltyLedger l : ledgers) {
      String pointTypeName = l.LoyaltyPgmCrcySubtype != null ? l.LoyaltyPgmCrcySubtype.Name : '기타';
      String expirationDate = l.ExpiryDate != null ? String.valueOf(l.ExpiryDate) : null;
      String key = pointTypeName + '_' + expirationDate;

      if (!mapResult.containsKey(key)) {
        PointDetailDTO dto = new PointDetailDTO();
        dto.pointTypeName = pointTypeName;
        dto.accruedPoints = 0;
        dto.usedPoints = 0;
        dto.expiredPoints = 0;
        dto.expirationDate = expirationDate;
        mapResult.put(key, dto);
      }

      PointDetailDTO dto = mapResult.get(key);

      Integer point = 0;
      if (l.Points != null) {
        point = Integer.valueOf(l.Points);
      }

      if (l.EventType == 'Credit') {
        dto.accruedPoints += point;
      } else if (l.EventType == 'Debit') {
        dto.usedPoints += (point < 0 ? -point : point);
      }
    }

    List<PointDetailDTO> result = new List<PointDetailDTO>();
    Integer totalAccrued = 0;
    Integer totalUsed = 0;

    for (PointDetailDTO dto : mapResult.values()) {
      dto.remainingPoints = dto.accruedPoints - dto.usedPoints - dto.expiredPoints;
      result.add(dto);

      totalAccrued += dto.accruedPoints;
      totalUsed += dto.usedPoints;
    }

    PointDetailResult wrapper = new PointDetailResult();
    wrapper.details = result;
    wrapper.totalAccrued = totalAccrued;
    wrapper.totalUsed = totalUsed;
    wrapper.totalRemaining = totalAccrued - totalUsed;

    return wrapper;
  }

  public class PointDetailResult {
    @AuraEnabled
    public List<PointDetailDTO> details;

    @AuraEnabled
    public Integer totalAccrued;

    @AuraEnabled
    public Integer totalUsed;

    @AuraEnabled
    public Integer totalRemaining;
  }

  public class PointDetailDTO {
    @AuraEnabled
    public String pointTypeName;

    @AuraEnabled
    public Integer accruedPoints;

    @AuraEnabled
    public Integer usedPoints;

    @AuraEnabled
    public Integer expiredPoints;

    @AuraEnabled
    public Integer remainingPoints;

    @AuraEnabled
    public String expirationDate;
  }
}