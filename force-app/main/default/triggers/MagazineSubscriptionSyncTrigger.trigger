trigger MagazineSubscriptionSyncTrigger on MagazineSubscriptionSync__e(after insert) {
  // 여러 이벤트가 들어와도 enqueue는 1번만
  ErpMemberReqDto.UpdateMagazineSubscriptionRequest merged = new ErpMemberReqDto.UpdateMagazineSubscriptionRequest();
  merged.ID_UPDATE = 'MCE_MAGAZINE_FETCH';

  for (MagazineSubscriptionSync__e e : Trigger.new) {
    if (String.isBlank(e.Payload__c)) {
      continue;
    }

    ErpMemberReqDto.UpdateMagazineSubscriptionRequest req = (ErpMemberReqDto.UpdateMagazineSubscriptionRequest) JSON.deserialize(
      e.Payload__c,
      ErpMemberReqDto.UpdateMagazineSubscriptionRequest.class
    );

    if (req != null && req.memebrModelList != null && !req.memebrModelList.isEmpty()) {
      merged.memebrModelList.addAll(req.memebrModelList);
    }
  }

  System.debug('### trigger userId=' + UserInfo.getUserId());
  System.debug('### trigger username=' + UserInfo.getUserName());

  if (!merged.memebrModelList.isEmpty()) {
    System.enqueueJob(new ErpMemberJob(ErpMemberJob.Operation.UPDATE_MAGAZINE_SUBSCRIPTION, merged, null, (Id) null));
  }
}