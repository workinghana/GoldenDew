trigger ContactAfterInsertTrigger on Contact (after insert) {
    List<Id> contactIds = new List<Id>();

    for (Contact c : Trigger.new) {
        contactIds.add(c.Id);
    }

    if (!contactIds.isEmpty()) {
        System.enqueueJob(new ContactToMcQueueable(contactIds));
    }
}