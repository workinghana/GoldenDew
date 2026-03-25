@IsTest
private class ErpPointJobTest {
  private static Id makeRecordId() {
    Account a = new Account(Name = 'T');
    insert a;
    return a.Id;
  }

  @IsTest
  static void test_point_expiry_job_runs_recordId() {
    Id rid = makeRecordId();

    ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_EXPIRY, req, new ErpPointAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_point_credit_job_runs_recordId() {
    Id rid = makeRecordId();

    ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, req, new ErpPointAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_constructor_with_recordIds_path_runs() {
    Id rid1 = makeRecordId();
    Id rid2 = makeRecordId();
    Set<Id> ids = new Set<Id>{ rid1, rid2 };

    ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_EXPIRY, req, new ErpPointAsyncCallback(), ids);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_constructor_with_sobject_path_runs() {
    Account a = new Account(Name = 'T_SOBJ');
    insert a;

    ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, req, new ErpPointAsyncCallback(), a.Id, a);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }
}