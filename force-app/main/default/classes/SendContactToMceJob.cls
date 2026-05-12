public class SendContactToMceJob implements Queueable, Database.AllowsCallouts {
    private List<Id> contactIds;

    public SendContactToMceJob(List<Id> contactIds) {
        this.contactIds = contactIds;
    }

    public void execute(QueueableContext context) {
        System.debug('Contact IDs: ' + contactIds);
    }
}