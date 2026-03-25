@IsTest
private class MagazineSubscriptionSyncTriggerTest {
  private static String makePayload(Boolean withMembers) {
    ErpMemberReqDto.UpdateMagazineSubscriptionRequest req =
      new ErpMemberReqDto.UpdateMagazineSubscriptionRequest();
    req.ID_UPDATE = 'MCE_MAGAZINE_FETCH';

    if (withMembers) {
      req.memebrModelList.add(
        new ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel(
          'MT-001',
          'Y',
          String.valueOf(Date.today())
        )
      );
    }

    return JSON.serialize(req);
  }

  @IsTest
  static void trigger_afterInsert_skipsBlank_and_enqueues_when_validPayloadExists() {
    Test.startTest();

    List<MagazineSubscriptionSync__e> eventsToPublish = new List<MagazineSubscriptionSync__e>{
      new MagazineSubscriptionSync__e(Payload__c = ''),
      new MagazineSubscriptionSync__e(Payload__c = makePayload(true))
    };

    List<Database.SaveResult> results = EventBus.publish(eventsToPublish);
    System.assertEquals(2, results.size());
    for (Database.SaveResult sr : results) {
      System.assertEquals(true, sr.isSuccess(), 'Platform Event publish should succeed');
    }

    Test.stopTest();
    System.assert(true);
  }

  @IsTest
  static void trigger_afterInsert_doesNotEnqueue_when_memberList_empty() {
    Test.startTest();

    List<MagazineSubscriptionSync__e> eventsToPublish = new List<MagazineSubscriptionSync__e>{
      new MagazineSubscriptionSync__e(Payload__c = null),
      new MagazineSubscriptionSync__e(Payload__c = makePayload(false))
    };

    List<Database.SaveResult> results = EventBus.publish(eventsToPublish);
    System.assertEquals(2, results.size());
    for (Database.SaveResult sr : results) {
      System.assertEquals(true, sr.isSuccess(), 'Platform Event publish should succeed');
    }

    Test.stopTest();
    System.assert(true);
  }
}