@IsTest
private class ErpPromotionReqDtoTest {
  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static Promotion createPromotionRecord() {
    String statusCode = null;
    for (Schema.PicklistEntry e : Promotion.StatusCode__c.getDescribe().getPicklistValues()) {
      statusCode = e.getValue();
      break;
    }

    String typeCode = null;
    for (Schema.PicklistEntry e : Promotion.TypeCode__c.getDescribe().getPicklistValues()) {
      typeCode = e.getValue();
      break;
    }

    String brandCode = null;
    for (Schema.PicklistEntry e : Promotion.BrandCode__c.getDescribe().getPicklistValues()) {
      brandCode = e.getValue();
      break;
    }

    Promotion p = new Promotion(
      Name = uniq('Promo'),
      PromotionCode = uniq('PCODE'),
      BrandCode__c = brandCode,
      TypeCode__c = typeCode,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(7),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(3),
      StatusCode__c = statusCode,
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = true,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = true,
      IsAllStore__c = true,
      IsAllItem__c = false,
      DepartmentCode__c = 'D001',
      InsertId__c = 'Inserter',
      ResponId__c = 'Responder'
    );
    insert p;

    return [
      SELECT
        Id,
        Name,
        PromotionNo__c,
        PromotionCode,
        BrandCode__c,
        TypeCode__c,
        StartDate,
        EndDate,
        PublishStartDate__c,
        PublishEndDate__c,
        StatusCode__c,
        IsCouponAllowed__c,
        IsFixedAmountCouponAllowed__c,
        IsRateCouponAllowed__c,
        IsSpecificCouponAllowed__c,
        IsPointUsageAllowed__c,
        IsAllStore__c,
        IsAllItem__c,
        PointTypeCode__c,
        DepartmentCode__c,
        InsertId__c,
        ResponId__c,
        CreatedBy.Name,
        LastModifiedBy.Name
      FROM Promotion
      WHERE Id = :p.Id
      LIMIT 1
    ];
  }

  @IsTest
  static void test_outer_constructor() {
    ErpPromotionReqDto dto = new ErpPromotionReqDto();
    System.assertNotEquals(null, dto);
  }

  @IsTest
  static void test_createRequest_default_assignment() {
    ErpPromotionReqDto.CreateRequest req = new ErpPromotionReqDto.CreateRequest();
    req.no_prom = 'P001';
    req.nm_prom = '프로모션';
    req.id_insert = 'tester';
    // 26.04.22 하나 추가: 특정 매장/품목 여부 필드 할당 검증
    req.yn_spec_store = 'Y';
    req.yn_spec_item = 'N';
    // 26.04.23 하나 추가: 포인트 유형별 적립 여부 필드 할당 검증
    req.yn_pur_point = 'Y';
    req.yn_gift_point = 'N';
    req.yn_event_point = 'Y';

    System.assertEquals('P001', req.no_prom);
    System.assertEquals('프로모션', req.nm_prom);
    System.assertEquals('tester', req.id_insert);
    System.assertEquals('Y', req.yn_spec_store);
    System.assertEquals('N', req.yn_spec_item);
    System.assertEquals('Y', req.yn_pur_point);
    System.assertEquals('N', req.yn_gift_point);
    System.assertEquals('Y', req.yn_event_point);
  }

  @IsTest
  static void test_createRequest_fromPromotion() {
    Promotion p = createPromotionRecord();

    ErpPromotionReqDto.CreateRequest req = new ErpPromotionReqDto.CreateRequest(p);

    System.assertEquals(p.PromotionNo__c, req.no_prom);
    System.assertEquals(p.Name, req.nm_prom);
    System.assertEquals(p.BrandCode__c, req.cd_brand);
    System.assertEquals(p.TypeCode__c, req.cd_type_prom);
    System.assertEquals('Y', req.yn_use_coupon);
    System.assertEquals('Y', req.yn_use_fixed_coupon);
    System.assertEquals('Y', req.yn_use_rate_coupon);
    System.assertEquals('N', req.yn_use_specific_coupon);
    System.assertEquals('Y', req.yn_use_point);
    System.assertEquals('Y', req.yn_all_store);
    System.assertEquals('N', req.yn_all_item);
    System.assertEquals('Y', req.yn_all_coupon);
    System.assertEquals(p.DepartmentCode__c, req.cd_dept);
    System.assertEquals(p.InsertId__c, req.id_insert);
    System.assertEquals(p.LastModifiedBy.Name, req.id_update);
    System.assertEquals(p.ResponId__c, req.id_respon);
    // 26.04.22 하나 추가: DTO 생성자에서는 yn_spec_*를 세팅하지 않음(트리거에서 주입)
    System.assertEquals(null, req.yn_spec_store);
    System.assertEquals(null, req.yn_spec_item);
    // 26.04.23 하나 추가: PointTypeCode__c가 NULL일 때 모든 포인트 유형 적립 가능('Y')
    System.assertEquals('Y', req.yn_pur_point);
    System.assertEquals('Y', req.yn_gift_point);
    System.assertEquals('Y', req.yn_event_point);
  }

  @IsTest
  static void test_createRequest_fromPromotion_withSpecFlags() {
    Promotion p = createPromotionRecord();

    ErpPromotionReqDto.CreateRequest req = new ErpPromotionReqDto.CreateRequest(p, true, true);

    System.assertEquals('N', req.yn_spec_store);
    System.assertEquals('Y', req.yn_spec_item);
  }

  @IsTest
  static void test_deleteRequest_fromPromotion() {
    Promotion p = createPromotionRecord();

    ErpPromotionReqDto.DeleteRequest req = new ErpPromotionReqDto.DeleteRequest(p);

    System.assertEquals(p.PromotionCode, req.no_prom);
    System.assertEquals(UserInfo.getUserId(), req.id_delete);
  }

  @IsTest
  static void test_updateRequest_default_assignment() {
    ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest();
    req.no_prom = 'P002';
    req.id_update = 'updater';
    // 26.04.22 하나 추가: 특정 매장/품목 여부 필드 할당 검증
    req.yn_spec_store = 'N';
    req.yn_spec_item = 'Y';
    // 26.04.23 하나 추가: 포인트 유형별 적립 여부 필드 할당 검증
    req.yn_pur_point = 'N';
    req.yn_gift_point = 'Y';
    req.yn_event_point = 'N';

    System.assertEquals('P002', req.no_prom);
    System.assertEquals('updater', req.id_update);
    System.assertEquals('N', req.yn_spec_store);
    System.assertEquals('Y', req.yn_spec_item);
    System.assertEquals('N', req.yn_pur_point);
    System.assertEquals('Y', req.yn_gift_point);
    System.assertEquals('N', req.yn_event_point);
  }

  @IsTest
  static void test_updateRequest_fromPromotion() {
    Promotion p = createPromotionRecord();

    ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest(p);

    System.assertEquals(p.PromotionNo__c, req.no_prom);
    System.assertEquals(p.Name, req.nm_prom);
    System.assertEquals(p.BrandCode__c, req.cd_brand);
    System.assertEquals(p.TypeCode__c, req.cd_type_prom);
    System.assertEquals('Y', req.yn_use_coupon);
    System.assertEquals('Y', req.yn_use_fixed_coupon);
    System.assertEquals('Y', req.yn_use_rate_coupon);
    System.assertEquals('N', req.yn_use_specific_coupon);
    System.assertEquals('Y', req.yn_use_point);
    System.assertEquals('Y', req.yn_all_store);
    System.assertEquals('N', req.yn_all_item);
    System.assertEquals('Y', req.yn_all_coupon);
    System.assertEquals(p.CreatedBy.Name, req.id_insert);
    System.assertEquals(p.LastModifiedBy.Name, req.id_update);
    // 26.04.22 하나 추가: DTO 생성자에서는 yn_spec_*를 세팅하지 않음(트리거에서 주입)
    System.assertEquals(null, req.yn_spec_store);
    System.assertEquals(null, req.yn_spec_item);
    // 26.04.23 하나 추가: PointTypeCode__c가 NULL일 때 모든 포인트 유형 적립 가능('Y')
    System.assertEquals('Y', req.yn_pur_point);
    System.assertEquals('Y', req.yn_gift_point);
    System.assertEquals('Y', req.yn_event_point);
  }

  @IsTest
  static void test_updateRequest_fromPromotion_withSpecFlags() {
    Promotion p = createPromotionRecord();

    ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest(p, true, true);

    System.assertEquals('N', req.yn_spec_store);
    System.assertEquals('Y', req.yn_spec_item);
  }

  @IsTest
  static void test_helpers() {
    System.assertEquals('', ErpPromotionReqDto.dateToYmd(null));
    System.assertEquals('20260309', ErpPromotionReqDto.dateToYmd(Date.newInstance(2026, 3, 9)));

    System.assertEquals('', ErpPromotionReqDto.dtToYmd(null));
    Datetime dt = Datetime.newInstance(2026, 3, 9, 10, 20, 30);
    System.assertEquals('20260309', ErpPromotionReqDto.dtToYmd(dt));

    System.assertEquals('Y', ErpPromotionReqDto.boolToYn(true));
    System.assertEquals('N', ErpPromotionReqDto.boolToYn(false));
    System.assertEquals('N', ErpPromotionReqDto.boolToYn(null));

    System.assertEquals('', ErpPromotionReqDto.isStrNull(null));
    System.assertEquals('', ErpPromotionReqDto.isStrNull(''));
    System.assertEquals('', ErpPromotionReqDto.isStrNull('   '));
    System.assertEquals('A', ErpPromotionReqDto.isStrNull('A'));

    System.assertEquals('Y', ErpPromotionReqDto.isAllCoupon('Y', 'Y', 'Y'));
    System.assertEquals('N', ErpPromotionReqDto.isAllCoupon('Y', 'N', 'Y'));

    // 26.04.23 하나 추가: isPointTypeAllowed 헬퍼 검증
    // 빈값/NULL → 'Y' (제한 없음)
    System.assertEquals('Y', ErpPromotionReqDto.isPointTypeAllowed(null, '01'));
    System.assertEquals('Y', ErpPromotionReqDto.isPointTypeAllowed('', '01'));
    // 단일 코드 포함 → 'N'
    System.assertEquals('N', ErpPromotionReqDto.isPointTypeAllowed('01', '01'));
    // 여러 코드 중 하나 포함 → 'N'
    System.assertEquals('N', ErpPromotionReqDto.isPointTypeAllowed('01;06;07', '06'));
    // 여러 코드 중 미포함 → 'Y'
    System.assertEquals('Y', ErpPromotionReqDto.isPointTypeAllowed('01;06', '07'));
    // 공백 섞인 경우도 정상 처리
    System.assertEquals('N', ErpPromotionReqDto.isPointTypeAllowed(' 01 ; 06 ', '01'));
  }
}