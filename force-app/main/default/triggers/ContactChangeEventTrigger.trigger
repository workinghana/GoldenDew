trigger ContactChangeEventTrigger on ContactChangeEvent(after insert) {
  for (ContactChangeEvent event : Trigger.New) {
    // Get some event header fields
    EventBus.ChangeEventHeader header = event.ChangeEventHeader;
    System.debug('Received change event for ' + header.entityName + ' for the ' + header.changeType + ' operation.');

    // Create a followup task
    if (header.changetype == 'CREATE') {
      System.debug('Iterate over the list of changed fields.ㅇㅇㅇㅇ');
    } else if ((header.changetype == 'UPDATE')) {
      System.debug('Iterate over the list of changed fields.');
    }
  }

}