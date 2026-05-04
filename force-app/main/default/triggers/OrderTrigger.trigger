trigger OrderTrigger on Order(after update) {
  ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
  logger.logging('OrderTrigger');
  logger.setRequestDatetime(Datetime.now());

  try {
    if (Trigger.new != null && !Trigger.new.isEmpty()) {
      logger.setScopedIds((List<SObject>) Trigger.new, 'Id');
    }

    System.debug('OrderTrigger 진입');
    OrderTriggerHandler handler = new OrderTriggerHandler();
    handler.run();

    logger.setStatus('SUCCESS');
    logger.setDescription('Handler executed. size=' + Trigger.size);
  } catch (Exception e) {
    logger.createExceptionLog(e);

    logger.setStatus('ERROR');
    logger.setDescription('Trigger failed: ' + e.getMessage());
  } finally {
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();
  }
}