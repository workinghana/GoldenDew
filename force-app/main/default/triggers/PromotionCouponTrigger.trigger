trigger PromotionCouponTrigger on VoucherLimit__c(after insert, after delete, after update) {
  new PromotionCouponTriggerHandler().run();
}
