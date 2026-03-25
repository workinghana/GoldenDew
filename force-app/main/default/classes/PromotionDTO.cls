public with sharing class PromotionDTO {
  public String Name; // 이름
  public String PromotionNo; // 프로모션 번호
  public Boolean IsActive; // 활성 여부
  public Date StartDate; // 시작 일자
  public Date EndDate; // 종료 일자

  public PromotionDTO(Promotion p) {
    this.Name = p.Name;
    this.PromotionNo = p.PromotionNo__c;
    this.IsActive = p.IsActive;
    this.StartDate = p.StartDate;
    this.EndDate = p.EndDate;
  }
}