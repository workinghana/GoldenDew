@IsTest
private class ErpPromotionStoreJobTest {
  private class TestCallback implements ErpAsyncCallback {
    public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
    }
    public void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace) {
    }
    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId) {
    }
    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject o) {
    }
    public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
    }
    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) {
    }
    public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {
    }
    public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
    }
  }

  private static Id makeRecordId() {
    Account a = new Account(Name = 'ERP_PROMO_STORE_JOB_' + String.valueOf(Datetime.now().getTime()));
    insert a;
    return a.Id;
  }

  @TestSetup
  static void setupOnce() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
  }

  @IsTest
  static void test_execute_createPromotionStore_success() {
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    ErpPromotionStoreReqDto.CreateRequestList req = new ErpPromotionStoreReqDto.CreateRequestList();
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.CreateRequest('1000', 'PROM001', 'S001', 'Gangnam', 'tester'));

    Id rid = makeRecordId();

    Test.startTest();
    System.enqueueJob(new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.CREATE_PROMOTION_STORE, req, new TestCallback(), rid));
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals('Completed', job.Status);
    System.assertEquals(0, job.NumberOfErrors);
  }

  @IsTest
  static void test_execute_updatePromotionStore_success() {
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    ErpPromotionStoreReqDto.UpdateRequestList req = new ErpPromotionStoreReqDto.UpdateRequestList();
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.UpdateRequest('1000', 'PROM002', 'S002', 'Myeongdong', 'updater'));

    Id rid = makeRecordId();

    Test.startTest();
    System.enqueueJob(new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.UPDATE_PROMOTION_STORE, req, new TestCallback(), rid));
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals('Completed', job.Status);
    System.assertEquals(0, job.NumberOfErrors);
  }

  @IsTest
  static void test_execute_deletePromotionStore_success() {
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    ErpPromotionStoreReqDto.DeleteRequestList req = new ErpPromotionStoreReqDto.DeleteRequestList();
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.DeleteRequest('PROM003', 'S003', 'deleter'));

    Id rid = makeRecordId();

    Test.startTest();
    System.enqueueJob(new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.DELETE_PROMOTION_STORE, req, new TestCallback(), rid));
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals('Completed', job.Status);
    System.assertEquals(0, job.NumberOfErrors);
  }

  @IsTest
  static void test_constructor_with_sobject_overload_executes() {
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    ErpPromotionStoreReqDto.DeleteRequestList req = new ErpPromotionStoreReqDto.DeleteRequestList();
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.DeleteRequest('PROM004', 'S004', 'deleter2'));

    Account a = new Account(Name = 'SOBJ_' + String.valueOf(Datetime.now().getTime()));
    insert a;

    Test.startTest();
    System.enqueueJob(new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.DELETE_PROMOTION_STORE, req, new TestCallback(), a.Id, a));
    Test.stopTest();

    System.assert(true);
  }
}
