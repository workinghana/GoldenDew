trigger VoucherDefinitionTrigger on VoucherDefinition(before insert, after insert, after delete, after update) {
  if (Trigger.isBefore && Trigger.isInsert) {
    CouponSequenceService.assignCouponCodes(Trigger.new);
    return;
  }

  ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
  logger.logging('VoucherDefinitionTrigger');
  logger.setRequestDatetime(Datetime.now());

  try {
    if (Trigger.new != null && !Trigger.new.isEmpty()) {
      logger.setScopedIds((List<SObject>) Trigger.new, 'Id');
    }

    System.debug('VoucherDefinitionTrigger 진입');
    VoucherDefinitionTriggerHandler handler = new VoucherDefinitionTriggerHandler();
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