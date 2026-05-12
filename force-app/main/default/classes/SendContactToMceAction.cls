public class SendContactToMceAction {
    @InvocableMethod(label='Send Contact to MCE')
    public static void send(List<Id> contactIds) {
        System.enqueueJob(new SendContactToMceJob(contactIds));
    }
}