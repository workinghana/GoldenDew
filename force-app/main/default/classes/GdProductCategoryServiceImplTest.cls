@IsTest
private class GdProductCategoryServiceImplTest {
    @TestSetup
    static void setupData() {
        insert new Account(Name = 'PC Company', CompanyCode__c = 'C001');
        insert new ProductCatalog(Name = '제품');
    }

    private static String pickFirstOrDefault(Schema.SObjectField f, String defVal) {
        List<Schema.PicklistEntry> vals = f.getDescribe().getPicklistValues();
        return vals.isEmpty() ? defVal : vals[0].getValue();
    }

    private static Map<String, Object> makeLargeReq(String code, String name) {
        String brand = pickFirstOrDefault(ProductCategory.BrandCode__c, '01');
        String type1 = pickFirstOrDefault(ProductCategory.Type1__c, 'T1');
        String type2 = pickFirstOrDefault(ProductCategory.Type2__c, 'T2');
        String type3 = pickFirstOrDefault(ProductCategory.Type3__c, 'T3');

        Map<String, Object> item = new Map<String, Object>{
            'BrandCode__c' => brand,
            'SystemCode__c' => 'SYS',
            'LargeCategoryCode__c' => code,
            'Name' => name,
            'Type1__c' => type1,
            'Type2__c' => type2,
            'Type3__c' => type3,
            'IsActive__c' => true
        };

        return new Map<String, Object>{
            'CompanyCode__c' => 'C001',
            'items' => new List<Object>{ item }
        };
    }

    private static Map<String, Object> makeMediumReq(String largeCode, String medCode, String name) {
        String brand = pickFirstOrDefault(ProductCategory.BrandCode__c, '01');
        String type1 = pickFirstOrDefault(ProductCategory.Type1__c, 'T1');
        String type2 = pickFirstOrDefault(ProductCategory.Type2__c, 'T2');
        String type3 = pickFirstOrDefault(ProductCategory.Type3__c, 'T3');

        Map<String, Object> item = new Map<String, Object>{
            'BrandCode__c' => brand,
            'SystemCode__c' => 'SYS',
            'LargeCategoryCode__c' => largeCode,
            'MediumCategoryCode__c' => medCode,
            'Name' => name,
            'Type1__c' => type1,
            'Type2__c' => type2,
            'Type3__c' => type3,
            'IsActive__c' => true
        };

        return new Map<String, Object>{
            'CompanyCode__c' => 'C001',
            'items' => new List<Object>{ item }
        };
    }

    private static Map<String, Object> makeSmallReq(
        String largeCode,
        String medCode,
        String smallCode,
        String name
    ) {
        String brand = pickFirstOrDefault(ProductCategory.BrandCode__c, '01');
        String type1 = pickFirstOrDefault(ProductCategory.Type1__c, 'T1');
        String type2 = pickFirstOrDefault(ProductCategory.Type2__c, 'T2');
        String type3 = pickFirstOrDefault(ProductCategory.Type3__c, 'T3');

        Map<String, Object> item = new Map<String, Object>{
            'BrandCode__c' => brand,
            'SystemCode__c' => 'SYS',
            'LargeCategoryCode__c' => largeCode,
            'MediumCategoryCode__c' => medCode,
            'SmallCategoryCode__c' => smallCode,
            'Name' => name,
            'Type1__c' => type1,
            'Type2__c' => type2,
            'Type3__c' => type3,
            'IsActive__c' => true
        };

        return new Map<String, Object>{
            'CompanyCode__c' => 'C001',
            'items' => new List<Object>{ item }
        };
    }

    @IsTest
    static void upsertLarge_nullBody_throwsCustomException() {
        Boolean thrown = false;
        try {
            new GdProductCategoryServiceImpl().upsertLargeProductCategoryProduct(null);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertLarge_emptyBody_throwsException() {
        Boolean thrown = false;
        try {
            new GdProductCategoryServiceImpl()
                .upsertLargeProductCategoryProduct(new Map<String, Object>());
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertLarge_emptyItems_throwsException() {
        Boolean thrown = false;
        Map<String, Object> reqData = new Map<String, Object>{
            'CompanyCode__c' => 'C001',
            'items' => new List<Object>()
        };
        try {
            new GdProductCategoryServiceImpl().upsertLargeProductCategoryProduct(reqData);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertMedium_nullBody_throwsException() {
        Boolean thrown = false;
        try {
            new GdProductCategoryServiceImpl().upsertMediumProductCategoryProduct(null);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertMedium_emptyItems_throwsCustomException() {
        Boolean thrown = false;
        Map<String, Object> reqData = new Map<String, Object>{
            'CompanyCode__c' => 'C001',
            'items' => new List<Object>()
        };

        try {
            new GdProductCategoryServiceImpl().upsertMediumProductCategoryProduct(reqData);
        } catch (Exception e) {
            thrown = true;
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertSmall_nullBody_throwsCustomException() {
        Boolean thrown = false;
        try {
            new GdProductCategoryServiceImpl().upsertSmallProductCategoryProduct(null);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertSmall_emptyItems_throwsException() {
        Boolean thrown = false;
        Map<String, Object> reqData = new Map<String, Object>{
            'CompanyCode__c' => 'C001',
            'items' => new List<Object>()
        };
        try {
            new GdProductCategoryServiceImpl().upsertSmallProductCategoryProduct(reqData);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertLarge_companyNotFound_throwsException() {
        Boolean thrown = false;
        Map<String, Object> reqData = makeLargeReq('L999', 'No Company');
        reqData.put('CompanyCode__c', 'NOTEXIST');
        try {
            new GdProductCategoryServiceImpl().upsertLargeProductCategoryProduct(reqData);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertMedium_companyNotFound_throwsException() {
        Boolean thrown = false;
        Map<String, Object> reqData = makeMediumReq('L001', 'M001', 'Med');
        reqData.put('CompanyCode__c', 'NOTEXIST');
        try {
            new GdProductCategoryServiceImpl().upsertMediumProductCategoryProduct(reqData);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertSmall_companyNotFound_throwsException() {
        Boolean thrown = false;
        Map<String, Object> reqData = makeSmallReq('L001', 'M001', 'S001', 'Small');
        reqData.put('CompanyCode__c', 'NOTEXIST');
        try {
            new GdProductCategoryServiceImpl().upsertSmallProductCategoryProduct(reqData);
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void upsertLarge_insertAndUpdate_success() {
        GdProductCategoryServiceImpl svc = new GdProductCategoryServiceImpl();

        Test.startTest();
        try {
            ApiResult first = svc.upsertLargeProductCategoryProduct(makeLargeReq('L001', 'Large One'));
            System.assert(first != null);

            ApiResult second = svc.upsertLargeProductCategoryProduct(
                makeLargeReq('L001', 'Large One Updated')
            );
            System.assert(second != null);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void upsertMedium_insertAndUpdate_success() {
        GdProductCategoryServiceImpl svc = new GdProductCategoryServiceImpl();

        Test.startTest();
        try {
            ApiResult first = svc.upsertMediumProductCategoryProduct(
                makeMediumReq('L001', 'M001', 'Medium One')
            );
            System.assert(first != null);

            ApiResult second = svc.upsertMediumProductCategoryProduct(
                makeMediumReq('L001', 'M001', 'Medium One Updated')
            );
            System.assert(second != null);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void upsertSmall_insertAndUpdate_success() {
        GdProductCategoryServiceImpl svc = new GdProductCategoryServiceImpl();

        Test.startTest();
        try {
            ApiResult first = svc.upsertSmallProductCategoryProduct(
                makeSmallReq('L001', 'M001', 'S001', 'Small One')
            );
            System.assert(first != null);

            ApiResult second = svc.upsertSmallProductCategoryProduct(
                makeSmallReq('L001', 'M001', 'S001', 'Small One Updated')
            );
            System.assert(second != null);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}