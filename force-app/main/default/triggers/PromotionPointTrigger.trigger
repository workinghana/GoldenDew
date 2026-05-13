trigger PromotionPointTrigger on PromotionPointLimit__c(after insert, after delete, after update) {
  // 공통 TriggerHandler 패턴 사용
  new PromotionPointTriggerHandler().run();
}