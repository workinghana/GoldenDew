public with sharing class VoucherTriggerHandler extends TriggerHandler {
  public VoucherTriggerHandler() {
    this.setMaxLoopCount(2);
  }

  public override void afterUpdate() {
    Set<Id> expiredVoucherIds = new Set<Id>();

    for (Voucher newV : (List<Voucher>) Trigger.new) {
      Voucher oldV = (Voucher) Trigger.oldMap.get(newV.Id);

      // Status가 "Expired"로 변경된 경우만
      if ((newV.Status == 'Expired' && oldV.Status != 'Expired') || newV.ExpirationDate != oldV.ExpirationDate) {
        expiredVoucherIds.add(newV.Id);
      }
    }

    if (expiredVoucherIds.isEmpty()) {
      return;
    }

    List<Voucher> vList = [
      SELECT Id, VoucherDefinition.CouponManNo__c, Contact.MemberNo__c, VoucherCode, ExpirationDate, Status
      FROM Voucher
      WHERE Id IN :expiredVoucherIds
    ];

    ErpCouponReqDto.UpdateRequest req = new ErpCouponReqDto.UpdateRequest();
    for (Voucher v : vList) {
      req.couponDetailUpdateModels.add(new ErpCouponReqDto.CouponDetailUpdateModel(v));
    }

    if (req.couponDetailUpdateModels.isEmpty()) {
      return;
    }

    System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_UPDATE, req, new ErpCouponAsyncCallback(), expiredVoucherIds));
  }
}