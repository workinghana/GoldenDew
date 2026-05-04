global class MCUserSyncScheduler implements Schedulable {
    
    global void execute(SchedulableContext sc) {
        MCUserSyncService.syncAllUsers();
    }
}