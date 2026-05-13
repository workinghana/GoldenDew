trigger ErpAsyncFailureTrigger on ErpAsyncFailure__e(after insert) {
  ErpAsyncFailureTriggerHandler handler = new ErpAsyncFailureTriggerHandler();
  System.debug('ErpAsyncFailureTrigger 발동');
  handler.run();
}