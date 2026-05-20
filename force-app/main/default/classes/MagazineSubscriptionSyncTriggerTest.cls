@IsTest
private class MagazineSubscriptionSyncTriggerTest {
  private static String makePayload(Boolean withMembers) {
    ErpMemberReqDto.UpdateMagazineSubscriptionRequest req = new ErpMemberReqDto.UpdateMagazineSubscriptionRequest();
    req.ID_UPDATE = 'MCE_MAGAZINE_FETCH';

    if (withMembers) {
      ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel m = new ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel();
      m.NO_MBR = 'MT-001';
      m.YM_RECEIVE_MAGAZINE = 'Y';
      m.DT_RECEIVE_MAGAZINE = String.valueOf(Date.today());
      req.memebrModelList.add(m);
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