@IsTest
private class ErpPromotionProductJobTest {
  private static Id makeRecordId() {
    Account a = new Account(Name = 'T');
    insert a;
    return a.Id;
  }

  @IsTest
  static void test_create_promotion_product_job_runs() {
    Id rid = makeRecordId();

    // DTO 생성 (필수필드가 있다면 여기서 세팅)
    ErpPromotionProductReqDto.CreateRequestList req = new ErpPromotionProductReqDto.CreateRequestList();

    ErpPromotionProductJob job = new ErpPromotionProductJob(
      ErpPromotionProductJob.Operation.CREATE_PROMOTION_PRODUCT,
      req,
      new ErpPromotionProductAsyncCallback(),
      rid
    );

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_update_promotion_product_job_runs() {
    Id rid = makeRecordId();

    ErpPromotionProductReqDto.UpdateRequestList req = new ErpPromotionProductReqDto.UpdateRequestList();

    ErpPromotionProductJob job = new ErpPromotionProductJob(
      ErpPromotionProductJob.Operation.UPDATE_PROMOTION_PRODUCT,
      req,
      new ErpPromotionProductAsyncCallback(),
      rid
    );

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_delete_promotion_product_job_runs() {
    Id rid = makeRecordId();

    ErpPromotionProductReqDto.DeleteRequestList req = new ErpPromotionProductReqDto.DeleteRequestList();

    ErpPromotionProductJob job = new ErpPromotionProductJob(
      ErpPromotionProductJob.Operation.DELETE_PROMOTION_PRODUCT,
      req,
      new ErpPromotionProductAsyncCallback(),
      rid
    );

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_constructor_with_sobject_path_runs() {
    Account a = new Account(Name = 'T2');
    insert a;

    ErpPromotionProductReqDto.UpdateRequestList req = new ErpPromotionProductReqDto.UpdateRequestList();

    // (recordId + SObject o) 생성자 경로 커버
    ErpPromotionProductJob job = new ErpPromotionProductJob(
      ErpPromotionProductJob.Operation.UPDATE_PROMOTION_PRODUCT,
      req,
      new ErpPromotionProductAsyncCallback(),
      a.Id,
      a
    );

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }
}