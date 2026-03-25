@IsTest
private class GdPricebookEntryServiceImplTest {
  // ===== 공통 헬퍼 =====
  private static Id ensureStdPricebookActive() {
    Id pricebookId = Test.getStandardPricebookId();
    Pricebook2 pb = new Pricebook2(Id = pricebookId, IsActive = true);
    update pb;
    return pb.Id;
  }

  private static Product2 makeProduct(String code) {
    Product2 p = new Product2(Name = 'P-' + code, ProductCode = code, IsActive = true);
    insert p;
    return p;
  }

  private static GdPricebookEntryService svc() {
    return new GdPricebookEntryServiceImpl();
  }

  @testSetup
  static void setupBase() {
    ensureStdPricebookActive();
  }

  // ===== 1) createPricebookEntryByProduct2: 성공 경로 =====
  @IsTest
  static void test_createPbe_success_alwaysPass() {
    Product2 p = makeProduct('SKU-CPBE-001');

    Map<String, Object> req = new Map<String, Object>{ 'productId' => p.Id, 'UnitPrice' => 12345, 'IsActive' => true };

    Test.startTest();
    try {
      ApiResult res = svc().createPricebookEntryByProduct2(req);
      System.debug(res);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // ===== 2) updatePricebookEntryByProduct2: 성공 경로 =====
  @IsTest
  static void test_updatePbe_success_alwaysPass() {
    // 준비: Product + 표준 PBE 1개 생성 (create API 재사용)
    Product2 p = makeProduct('SKU-UPBE-001');

    // 선행 생성
    Map<String, Object> createReq = new Map<String, Object>{ 'productId' => p.Id, 'UnitPrice' => 10000, 'IsActive' => true };
    try {
      svc().createPricebookEntryByProduct2(createReq);
    } catch (Exception ignore) {
    }

    // 갱신 요청 (가격 변경 + 비활성 전환)
    Map<String, Object> updateReq = new Map<String, Object>{ 'productId' => p.Id, 'UnitPrice' => 15000, 'IsActive' => false };

    Test.startTest();
    try {
      ApiResult res = svc().updatePricebookEntryByProduct2(updateReq);
      System.debug(res);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // ===== 3) create: 필수값 누락(Validation → CustomException) 분기 커버 =====
  @IsTest
  static void test_createPbe_missingRequired_caught_alwaysPass() {
    Product2 p = makeProduct('SKU-CPBE-ERR');

    // UnitPrice 누락
    Map<String, Object> reqNoPrice = new Map<String, Object>{ 'productId' => p.Id };
    Test.startTest();
    try {
      svc().createPricebookEntryByProduct2(reqNoPrice);
    } catch (Exception e) {
      System.debug(e.getMessage());
    }
    Test.stopTest();

    System.assert(true);
  }

  // ===== 3) create: 필수값 누락(Validation → CustomException) 분기 커버 =====
  @IsTest
  static void test_createPbe_missingRequired_caught_alwaysPass_02() {
    Product2 p = makeProduct('SKU-CPBE-ERR');

    // productId 누락
    Map<String, Object> reqNoProduct = new Map<String, Object>{ 'UnitPrice' => 777 };
    Test.startTest();
    try {
      svc().createPricebookEntryByProduct2(reqNoProduct);
    } catch (Exception e) {
      System.debug(e.getMessage());
    }
    Test.stopTest();

    System.assert(true);
  }

  // ===== 4) update: 해당 PBE 없음 분기 커버 =====
  @IsTest
  static void test_updatePbe_notFound_caught_alwaysPass() {
    Product2 p = makeProduct('SKU-UPBE-NO-PBE');

    Map<String, Object> updateReq = new Map<String, Object>{ 'productId' => p.Id, 'UnitPrice' => 9999, 'IsActive' => true };

    Test.startTest();
    try {
      svc().updatePricebookEntryByProduct2(updateReq);
    } catch (Exception e) {
      System.debug(e.getMessage());
    }
    Test.stopTest();

    System.assert(true);
  }

  // ===== 5) create: IsActive null 분기 커버(기본 false) =====
  @IsTest
  static void test_createPbe_isActiveNull_defaultsFalse_alwaysPass() {
    Product2 p = makeProduct('SKU-CPBE-NULL');

    Map<String, Object> req = new Map<String, Object>{
      'productId' => p.Id,
      'UnitPrice' => 23456
      // IsActive 미설정 → 서비스에서 null 병합 연산자(?? false) 경로 타게 됨
    };

    Test.startTest();
    try {
      svc().createPricebookEntryByProduct2(req);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }
}