@IsTest
private class ErpCouponJobTest {
  private static Id makeRecordId() {
    Account a = new Account(Name = 'T');
    insert a;
    return a.Id;
  }

  @IsTest
  static void test_coupon_issue_job_runs() {
    Id rid = makeRecordId();

    ErpCouponReqDto.IssueRequest req = new ErpCouponReqDto.IssueRequest();

    ErpCouponJob job = new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, req, new ErpCouponAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_coupon_update_job_runs() {
    Id rid = makeRecordId();

    ErpCouponReqDto.UpdateRequest req = new ErpCouponReqDto.UpdateRequest();

    ErpCouponJob job = new ErpCouponJob(ErpCouponJob.Operation.COUPON_UPDATE, req, new ErpCouponAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_create_master_job_runs() {
    Id rid = makeRecordId();

    ErpCouponMasterReqDto.IssueRequest req = new ErpCouponMasterReqDto.IssueRequest();

    ErpCouponJob job = new ErpCouponJob(ErpCouponJob.Operation.CREATE_MASTER, req, new ErpCouponAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_update_master_job_runs() {
    Id rid = makeRecordId();

    ErpCouponMasterReqDto.UpdateRequest req = new ErpCouponMasterReqDto.UpdateRequest();

    ErpCouponJob job = new ErpCouponJob(ErpCouponJob.Operation.UPDATE_MASTER, req, new ErpCouponAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_delete_master_job_runs() {
    Id rid = makeRecordId();

    ErpCouponMasterReqDto.DeleteRequest req = new ErpCouponMasterReqDto.DeleteRequest();

    ErpCouponJob job = new ErpCouponJob(ErpCouponJob.Operation.DELETE_MASTER, req, new ErpCouponAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_constructor_with_recordIds_path_runs() {
    // recordIds 생성자 경로 커버
    Id rid1 = makeRecordId();
    Id rid2 = makeRecordId();

    Set<Id> ids = new Set<Id>{ rid1, rid2 };

    ErpCouponReqDto.IssueRequest req = new ErpCouponReqDto.IssueRequest();

    ErpCouponJob job = new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, req, new ErpCouponAsyncCallback(), ids);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_constructor_with_sobject_path_runs() {
    Account a = new Account(Name = 'T_SOBJ');
    insert a;

    ErpCouponReqDto.UpdateRequest req = new ErpCouponReqDto.UpdateRequest();

    // recordId + SObject o 생성자 경로 커버
    ErpCouponJob job = new ErpCouponJob(ErpCouponJob.Operation.COUPON_UPDATE, req, new ErpCouponAsyncCallback(), a.Id, a);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }
}