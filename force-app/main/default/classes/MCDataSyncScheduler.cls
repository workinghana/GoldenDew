global class MCDataSyncScheduler implements Schedulable {
    
    global void execute(SchedulableContext sc) {
        MCDataSyncBatchChain.startChain();
    }
}