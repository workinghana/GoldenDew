trigger SchedulerJobResultTrigger on SchedulerJobResult__e(after insert) {
  SchedulerJobResultTriggerHandler handler = new SchedulerJobResultTriggerHandler();
  System.debug('SchedulerJobResultTrigger 발동');
  handler.run();
}