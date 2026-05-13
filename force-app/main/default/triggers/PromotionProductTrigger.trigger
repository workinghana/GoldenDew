trigger PromotionProductTrigger on PromotionProduct(after insert, after update, after delete) {
  new PromotionProductTriggerHandler().run();
}