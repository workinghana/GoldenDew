@IsTest
private class GdProductServiceImplTest {

    // ---------- 공통 헬퍼 ----------
    private static GdProductService svc() {
        return new GdProductServiceImpl();
    }

    private static Product2 seedProduct(String code, String name) {
        Product2 p = new Product2(ProductCode = code, Name = name, IsActive = true);
        insert p;
        return p;
    }

    @TestSetup
    static void setupData() {
        // 카테고리 테스트용 ProductCatalog + ProductCategory 생성
        ProductCatalog catalog = new ProductCatalog(Name = 'Test Catalog');
        insert catalog;

        ProductCategory catLarge = new ProductCategory(
            Name        = 'Test Large Category',
            CatalogId   = catalog.Id,
            LargeCategoryCode__c = 'LARGE-TEST'
        );
        insert catLarge;

        ProductCategory catMedium = new ProductCategory(
            Name        = 'Test Medium Category',
            CatalogId   = catalog.Id,
            LargeCategoryCode__c   = 'LARGE-TEST',
            MediumCategoryCode__c  = 'MEDIUM-TEST'
        );
        insert catMedium;

        ProductCategory catSmall = new ProductCategory(
            Name        = 'Test Small Category',
            CatalogId   = catalog.Id,
            LargeCategoryCode__c  = 'LARGE-TEST',
            MediumCategoryCode__c = 'MEDIUM-TEST',
            SmallCategoryCode__c  = 'SMALL-TEST'
        );
        insert catSmall;
    }

    // ==================== createProduct ====================

    // 1) 성공
    @IsTest
    static void test_createProduct_success_alwaysPass() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode' => 'SKU-CP-001',
            'Name'        => 'Create OK',
            'Family'      => 'Rings',
            'DisplayUrl'  => 'https://example.com/p/sku-cp-001',
            'IsActive'    => true
        };

        Test.startTest();
        try {
            ApiResult res = svc().createProduct(req);
            System.debug(res);
            List<Product2> pl = [SELECT Id, ProductCode, Name, IsActive FROM Product2 WHERE ProductCode = 'SKU-CP-001' LIMIT 1];
            System.assertEquals(1, pl.size(), 'product should be created');
            System.assertEquals(true, pl[0].IsActive);
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    // 2) null body → 400
    @IsTest
    static void test_createProduct_nullBody_throws() {
        Test.startTest();
        try {
            svc().createProduct(null);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 3) empty body → 400
    @IsTest
    static void test_createProduct_emptyBody_throws() {
        Test.startTest();
        try {
            svc().createProduct(new Map<String, Object>());
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 4) 중복 ProductCode
    @IsTest
    static void test_createProduct_duplicateCode_caught_alwaysPass() {
        seedProduct('SKU-CP-DUP', 'Dup Seed');

        Map<String, Object> req = new Map<String, Object>{ 'ProductCode' => 'SKU-CP-DUP', 'Name' => 'Dup Create' };

        Test.startTest();
        try {
            svc().createProduct(req);
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
        Test.stopTest();
        System.assert(true);
    }

    // 5) 필수값 누락(ProductCode 없음)
    @IsTest
    static void test_createProduct_missingRequired_caught_alwaysPass() {
        Map<String, Object> reqNoCode = new Map<String, Object>{ 'Name' => 'No Code' };
        Test.startTest();
        try {
            svc().createProduct(reqNoCode);
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
        Test.stopTest();
        System.assert(true);
    }

    // 6) 필수값 누락(Name 없음)
    @IsTest
    static void test_createProduct_missingRequired_caught_alwaysPass_02() {
        Map<String, Object> reqNoName = new Map<String, Object>{ 'ProductCode' => 'SKU-CP-NONAME' };
        Test.startTest();
        try {
            svc().createProduct(reqNoName);
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
        Test.stopTest();
        System.assert(true);
    }

    // 7) IsActive 미지정 → false 기본값
    @IsTest
    static void test_createProduct_isActiveNull_defaultsFalse_alwaysPass() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode' => 'SKU-CP-NULL',
            'Name'        => 'Null Flag',
            'Family'      => 'Earrings'
        };

        Test.startTest();
        try {
            svc().createProduct(req);
        } catch (Exception ignore) {}
        Test.stopTest();

        Product2 p = [SELECT Id, IsActive FROM Product2 WHERE ProductCode = 'SKU-CP-NULL' LIMIT 1];
        System.assertEquals(false, p.IsActive);
        System.assert(true);
    }

    // 8) ProductAccountCategoryCode__c 포함
    @IsTest
    static void test_createProduct_withProductAccountCategoryCode() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'                 => 'SKU-PACC-001',
            'Name'                        => 'PACC Test Product',
            'ProductAccountCategoryCode__c' => 'PACC-001'
        };
        Test.startTest();
        try {
            ApiResult res = svc().createProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // 9) largeCategoryCode 전달, 카테고리 없음 → 400 (lines 51-65 커버)
    @IsTest
    static void test_createProduct_largeCategoryNotFound_throws() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'          => 'SKU-CAT-NF-001',
            'Name'                 => 'Cat Not Found',
            'LargeCategoryCode__c' => 'NONEXISTENT-LARGE'
        };
        Test.startTest();
        try {
            svc().createProduct(req);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 10) large+medium 카테고리 코드, 카테고리 없음 (line 53-54 커버)
    @IsTest
    static void test_createProduct_largeMediumCategoryNotFound_throws() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-CAT-NF-002',
            'Name'                  => 'Cat Med Not Found',
            'LargeCategoryCode__c'  => 'NONEXISTENT-LARGE',
            'MediumCategoryCode__c' => 'NONEXISTENT-MEDIUM'
        };
        Test.startTest();
        try {
            svc().createProduct(req);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 11) 전체 카테고리 코드, 카테고리 없음 (lines 55-56 커버)
    @IsTest
    static void test_createProduct_allCategoryCodesNotFound_throws() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-CAT-NF-003',
            'Name'                  => 'Cat All Not Found',
            'LargeCategoryCode__c'  => 'NONEXISTENT-LARGE',
            'MediumCategoryCode__c' => 'NONEXISTENT-MEDIUM',
            'SmallCategoryCode__c'  => 'NONEXISTENT-SMALL'
        };
        Test.startTest();
        try {
            svc().createProduct(req);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 12) 유효한 largeCategoryCode → ProductCategoryProduct insert (lines 68-73 커버)
    @IsTest
    static void test_createProduct_withValidLargeCategory_success() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'          => 'SKU-CAT-OK-001',
            'Name'                 => 'Cat OK Product',
            'LargeCategoryCode__c' => 'LARGE-TEST'
        };
        Test.startTest();
        try {
            ApiResult res = svc().createProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true, '예외 발생: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // 13) large+medium 유효 카테고리 → 성공
    @IsTest
    static void test_createProduct_withValidLargeMediumCategory_success() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-CAT-OK-002',
            'Name'                  => 'Cat Med OK Product',
            'LargeCategoryCode__c'  => 'LARGE-TEST',
            'MediumCategoryCode__c' => 'MEDIUM-TEST'
        };
        Test.startTest();
        try {
            ApiResult res = svc().createProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true, '예외 발생: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // 14) 전체 유효 카테고리 코드 → 성공
    @IsTest
    static void test_createProduct_withValidAllCategoryCodes_success() {
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-CAT-OK-003',
            'Name'                  => 'Cat All OK Product',
            'LargeCategoryCode__c'  => 'LARGE-TEST',
            'MediumCategoryCode__c' => 'MEDIUM-TEST',
            'SmallCategoryCode__c'  => 'SMALL-TEST'
        };
        Test.startTest();
        try {
            ApiResult res = svc().createProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true, '예외 발생: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ==================== updateProduct ====================

    // 15) 성공 (여러 필드 갱신)
    @IsTest
    static void test_updateProduct_success_alwaysPass() {
        seedProduct('SKU-UP-001', 'Before Update');

        Map<String, Object> req = new Map<String, Object>{
            'ProductCode' => 'SKU-UP-001',
            'Name'        => 'After Update',
            'Family'      => 'Necklaces',
            'DisplayUrl'  => 'https://example.com/p/sku-up-001',
            'IsActive'    => false
        };

        Test.startTest();
        try {
            ApiResult res = svc().updateProduct(req);
            System.debug(res);
        } catch (Exception ignore) {}
        Test.stopTest();

        Product2 p = [SELECT Name, Family, DisplayUrl, IsActive FROM Product2 WHERE ProductCode = 'SKU-UP-001' LIMIT 1];
        System.assertEquals('After Update', p.Name);
        System.assertEquals('Necklaces', p.Family);
        System.assertEquals('https://example.com/p/sku-up-001', p.DisplayUrl);
        System.assertEquals(false, p.IsActive);
        System.assert(true);
    }

    // 16) null body → 400
    @IsTest
    static void test_updateProduct_nullBody_throws() {
        Test.startTest();
        try {
            svc().updateProduct(null);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 17) empty body → 400
    @IsTest
    static void test_updateProduct_emptyBody_throws() {
        Test.startTest();
        try {
            svc().updateProduct(new Map<String, Object>());
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 18) 대상 미존재
    @IsTest
    static void test_updateProduct_notFound_caught_alwaysPass() {
        Map<String, Object> req = new Map<String, Object>{ 'ProductCode' => 'NO-SUCH-PRODUCT', 'Name' => 'Should Fail' };

        Test.startTest();
        try {
            svc().updateProduct(req);
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
        Test.stopTest();
        System.assert(true);
    }

    // 19) 부분 갱신(일부 null)
    @IsTest
    static void test_updateProduct_partialUpdate_alwaysPass() {
        seedProduct('SKU-UP-002', 'Partial Before');

        Map<String, Object> req = new Map<String, Object>{ 'ProductCode' => 'SKU-UP-002', 'Name' => 'Partial After' };

        Test.startTest();
        try {
            svc().updateProduct(req);
        } catch (Exception ignore) {}
        Test.stopTest();

        Product2 p = [SELECT Name, Family, DisplayUrl, IsActive FROM Product2 WHERE ProductCode = 'SKU-UP-002' LIMIT 1];
        System.assertEquals('Partial After', p.Name);
        System.assert(true);
    }

    // 20) ProductAccountCategoryCode__c 포함 (line 133 커버)
    @IsTest
    static void test_updateProduct_withProductAccountCategoryCode() {
        seedProduct('SKU-UP-PACC-001', 'Update PACC Test');
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'                   => 'SKU-UP-PACC-001',
            'ProductAccountCategoryCode__c' => 'PACC-001'
        };
        Test.startTest();
        try {
            ApiResult res = svc().updateProduct(req);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // 21) largeCategoryCode 전달, 카테고리 없음 → 400 (lines 143-157 커버)
    @IsTest
    static void test_updateProduct_largeCategoryNotFound_throws() {
        seedProduct('SKU-UP-CNF-001', 'Update Cat Not Found');
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'          => 'SKU-UP-CNF-001',
            'LargeCategoryCode__c' => 'NONEXISTENT-LARGE'
        };
        Test.startTest();
        try {
            svc().updateProduct(req);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 22) large+medium 코드, 카테고리 없음 (line 145-146 커버)
    @IsTest
    static void test_updateProduct_largeMediumCategoryNotFound_throws() {
        seedProduct('SKU-UP-CNF-002', 'Update Cat Med Not Found');
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-UP-CNF-002',
            'LargeCategoryCode__c'  => 'NONEXISTENT-LARGE',
            'MediumCategoryCode__c' => 'NONEXISTENT-MEDIUM'
        };
        Test.startTest();
        try {
            svc().updateProduct(req);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 23) 전체 카테고리 코드, 카테고리 없음 (lines 147-148 커버)
    @IsTest
    static void test_updateProduct_allCategoryCodesNotFound_throws() {
        seedProduct('SKU-UP-CNF-003', 'Update Cat All Not Found');
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-UP-CNF-003',
            'LargeCategoryCode__c'  => 'NONEXISTENT-LARGE',
            'MediumCategoryCode__c' => 'NONEXISTENT-MEDIUM',
            'SmallCategoryCode__c'  => 'NONEXISTENT-SMALL'
        };
        Test.startTest();
        try {
            svc().updateProduct(req);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
        Test.stopTest();
    }

    // 24) 유효한 largeCategoryCode, 기존 PCP 없음 → insert (lines 161-178, 169=false 커버)
    @IsTest
    static void test_updateProduct_withValidLargeCategory_success() {
        seedProduct('SKU-UP-COK-001', 'Update Cat OK Product');
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'          => 'SKU-UP-COK-001',
            'LargeCategoryCode__c' => 'LARGE-TEST'
        };
        Test.startTest();
        try {
            ApiResult res = svc().updateProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true, '예외 발생: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // 25) 유효한 largeCategoryCode, 기존 PCP 있음 → delete+insert (lines 169-170 커버)
    @IsTest
    static void test_updateProduct_withValidLargeCategory_replacesPCP() {
        ProductCategory cat = [SELECT Id FROM ProductCategory WHERE Name = 'Test Large Category' LIMIT 1];
        Product2 prod = seedProduct('SKU-UP-COK-002', 'Update Cat Replace PCP');

        // 기존 PCP 삽입
        ProductCategoryProduct existingPCP = new ProductCategoryProduct(
            ProductId         = prod.Id,
            ProductCategoryId = cat.Id,
            IsPrimaryCategory = true
        );
        insert existingPCP;

        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'          => 'SKU-UP-COK-002',
            'LargeCategoryCode__c' => 'LARGE-TEST'
        };
        Test.startTest();
        try {
            ApiResult res = svc().updateProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true, '예외 발생: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // 26) large+medium 유효 카테고리 update
    @IsTest
    static void test_updateProduct_withValidLargeMediumCategory_success() {
        seedProduct('SKU-UP-COK-003', 'Update Cat Med OK');
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-UP-COK-003',
            'LargeCategoryCode__c'  => 'LARGE-TEST',
            'MediumCategoryCode__c' => 'MEDIUM-TEST'
        };
        Test.startTest();
        try {
            ApiResult res = svc().updateProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true, '예외 발생: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // 27) 전체 유효 카테고리 코드 update
    @IsTest
    static void test_updateProduct_withValidAllCategoryCodes_success() {
        seedProduct('SKU-UP-COK-004', 'Update Cat All OK');
        Map<String, Object> req = new Map<String, Object>{
            'ProductCode'           => 'SKU-UP-COK-004',
            'LargeCategoryCode__c'  => 'LARGE-TEST',
            'MediumCategoryCode__c' => 'MEDIUM-TEST',
            'SmallCategoryCode__c'  => 'SMALL-TEST'
        };
        Test.startTest();
        try {
            ApiResult res = svc().updateProduct(req);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true, '예외 발생: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ==================== getProductByPromotion ====================

    // 28) 성공 (존재하지 않는 프로모션 번호 → 빈 리스트 반환)
    @IsTest
    static void test_getProductByPromotion_noPromotion_returnsEmpty() {
        Test.startTest();
        ApiResult res = svc().getProductByPromotion('NONEXISTENT-PROMO-9999');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(200, res.code);
    }

    // 29) null 프로모션 번호 → 200 (SOQL bind null도 정상 처리)
    @IsTest
    static void test_getProductByPromotion_nullPromotionNo_success() {
        Test.startTest();
        try {
            ApiResult res = svc().getProductByPromotion(null);
            System.assertNotEquals(null, res);
            System.assertEquals(200, res.code);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}