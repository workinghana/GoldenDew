trigger PromotionTrigger on Promotion(after insert, after delete, after update) {
  ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
  logger.logging('PromotionTrigger');
  logger.setRequestDatetime(Datetime.now());

  String triggerContext = 'isInsert=' + Trigger.isInsert + ', isUpdate=' + Trigger.isUpdate + ', isDelete=' + Trigger.isDelete;

  try {
    if (Trigger.new != null && !Trigger.new.isEmpty()) {
      logger.setScopedIds((List<SObject>) Trigger.new, 'Id');
    }

    System.debug('PromotionTrigger 진입');

    PromotionTriggerHandler handler = new PromotionTriggerHandler();
    handler.run();

    logger.setDescription('Handler executed. size=' + Trigger.size + '. ' + triggerContext);

    logger.setStatus('SUCCESS');
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