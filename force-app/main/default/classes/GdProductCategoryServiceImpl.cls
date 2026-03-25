public with sharing class GdProductCategoryServiceImpl implements GdProductCategoryService {
    /* =========================================================
     * 공통 조회
     * ========================================================= */
    private Account getCompany(String companyCode) {
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE CompanyCode__c = :companyCode
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new CustomException(400, 'Company not found: ' + companyCode);
        }
        return accounts[0];
    }

    private ProductCatalog getProductCatalog() {
        List<ProductCatalog> catalogs = [
            SELECT Id
            FROM ProductCatalog
            WHERE Name = '제품'
            LIMIT 1
        ];
        if (catalogs.isEmpty()) {
            throw new CustomException(400, 'ProductCatalog not found: 제품');
        }
        return catalogs[0];
    }
    /* =========================================================
     * 대분류 카테고리 등록/수정
     * ========================================================= */
    public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
        if (reqData == null || reqData.isEmpty()) {
            throw new CustomException(400, 'Request body is empty.');
        }

        String companyCode = ValidationUtil.stringValidationEx(
            reqData.get('CompanyCode__c'),
            'CompanyCode__c',
            true,
            false
        );

        List<Object> items = (List<Object>) reqData.get('items');
        if (items == null || items.isEmpty()) {
            throw new CustomException(400, 'items is empty.');
        }

        Account companyAcc = getCompany(companyCode);
        ProductCatalog catalog = getProductCatalog();

        /* =====================================================
         * 1. Code 수집
         * ===================================================== */
        Set<String> codeSet = new Set<String>();
        List<Map<String, Object>> parsedItems = new List<Map<String, Object>>();

        for (Object o : items) {
            Map<String, Object> item = (Map<String, Object>) o;

            String systemCode = ValidationUtil.stringValidationEx(
                item.get('SystemCode__c'),
                'SystemCode__c',
                true,
                true
            );
            String largecode = ValidationUtil.stringValidationEx(
                item.get('LargeCategoryCode__c'),
                'LargeCategoryCode__c',
                true,
                true
            );
            String code = systemCode + '-' + largecode;

            codeSet.add(code);
            parsedItems.add(item);
        }

        /* =====================================================
         * 2. 기존 데이터 조회
         * ===================================================== */
        Map<String, ProductCategory> existMap = new Map<String, ProductCategory>();
        for (ProductCategory pc : [
            SELECT Id, Code
            FROM ProductCategory
            WHERE Code IN :codeSet
        ]) {
            existMap.put(pc.Code, pc);
        }

        /* =====================================================
         * 3. INSERT / UPDATE 분기
         * ===================================================== */
        List<ProductCategory> insertList = new List<ProductCategory>();
        List<ProductCategory> updateList = new List<ProductCategory>();

        for (Map<String, Object> item : parsedItems) {
            String brandcode = ValidationUtil.stringValidationEx(
                item.get('BrandCode__c'),
                'BrandCode__c',
                true,
                false
            );
            String systemCode = ValidationUtil.stringValidationEx(
                item.get('SystemCode__c'),
                'SystemCode__c',
                true,
                true
            );
            String largecode = ValidationUtil.stringValidationEx(
                item.get('LargeCategoryCode__c'),
                'LargeCategoryCode__c',
                true,
                true
            );
            String name = ValidationUtil.stringValidationEx(item.get('Name'), 'Name', true, true);

            String type1 = ValidationUtil.stringValidationEx(
                item.get('Type1__c'),
                'Type1__c',
                true,
                false
            );
            String type2 = ValidationUtil.stringValidationEx(
                item.get('Type2__c'),
                'Type2__c',
                true,
                false
            );
            String type3 = ValidationUtil.stringValidationEx(
                item.get('Type3__c'),
                'Type3__c',
                true,
                false
            );

            Boolean isactive = ValidationUtil.booleanValidation(
                item.get('IsActive__c'),
                'IsActive__c',
                true
            );

            String code = systemCode + '-' + largecode;

            ProductCategory pc;

            if (existMap.containsKey(code)) {
                pc = existMap.get(code);
                updateList.add(pc);
            } else {
                pc = new ProductCategory();
                pc.CatalogId = catalog.Id;
                pc.Code = code;
                pc.SystemCode__c = systemCode;
                pc.LargeCategoryCode__c = largecode;
                insertList.add(pc);
            }

            // 공통 필드 세팅
            pc.Name = name;
            pc.CompanyCode__c = companyAcc.Id;
            pc.BrandCode__c = brandcode;
            pc.Type1__c = type1;
            pc.Type2__c = type2;
            pc.Type3__c = type3;
            pc.IsActive__c = isactive;
        }

        if (!insertList.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(insertList, false);

            for (Database.SaveResult sr : insertResults) {
                if (!sr.isSuccess()) {
                    Database.Error err = sr.getErrors()[0];
                    throw new CustomException(400, err.getMessage());
                }
            }
        }

        if (!updateList.isEmpty()) {
            Database.SaveResult[] updateResults = Database.update(updateList, false);

            for (Database.SaveResult sr : updateResults) {
                if (!sr.isSuccess()) {
                    Database.Error err = sr.getErrors()[0];
                    throw new CustomException(400, err.getMessage());
                }
            }
        }

        /* =====================================================
         * 5. 응답 데이터 (실제 처리된 데이터 반환)
         * ===================================================== */
        Map<String, Object> data = new Map<String, Object>();
        data.put('insertItems', insertList);
        data.put('updateItems', updateList);

        return ApiResult.ok(200, '제품 대분류 카테고리 등록/수정 완료', data);
    }

    /* =========================================================
     * 제품 중분류 카테고리 등록/수정
     * ========================================================= */
    public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
        if (reqData == null || reqData.isEmpty()) {
            throw new CustomException(400, 'Request body is empty.');
        }

        String companyCode = ValidationUtil.stringValidationEx(
            reqData.get('CompanyCode__c'),
            'CompanyCode__c',
            true,
            false
        );

        List<Object> items = (List<Object>) reqData.get('items');
        if (items == null || items.isEmpty()) {
            throw new CustomException(400, 'items is empty.');
        }

        Account companyAcc = getCompany(companyCode);
        ProductCatalog catalog = getProductCatalog();

        /* =====================================================
         * 1. Code 수집
         * ===================================================== */
        Set<String> codeSet = new Set<String>();
        List<Map<String, Object>> parsedItems = new List<Map<String, Object>>();

        for (Object o : items) {
            Map<String, Object> item = (Map<String, Object>) o;

            String systemCode = ValidationUtil.stringValidationEx(
                item.get('SystemCode__c'),
                'SystemCode__c',
                true,
                true
            );
            String largecode = ValidationUtil.stringValidationEx(
                item.get('LargeCategoryCode__c'),
                'LargeCategoryCode__c',
                true,
                true
            );
            String mediumcode = ValidationUtil.stringValidationEx(
                item.get('MediumCategoryCode__c'),
                'MediumCategoryCode__c',
                true,
                true
            );

            String code = systemCode + '-' + largecode + '-' + mediumcode;

            codeSet.add(code);
            parsedItems.add(item);
        }

        /* =====================================================
         * 2. 기존 데이터 조회
         * ===================================================== */
        Map<String, ProductCategory> existMap = new Map<String, ProductCategory>();
        for (ProductCategory pc : [
            SELECT Id, Code
            FROM ProductCategory
            WHERE Code IN :codeSet
        ]) {
            existMap.put(pc.Code, pc);
        }

        /* =====================================================
         * 3. INSERT / UPDATE 분기
         * ===================================================== */
        List<ProductCategory> insertList = new List<ProductCategory>();
        List<ProductCategory> updateList = new List<ProductCategory>();

        for (Map<String, Object> item : parsedItems) {
            String brandcode = ValidationUtil.stringValidationEx(
                item.get('BrandCode__c'),
                'BrandCode__c',
                true,
                false
            );
            String systemCode = ValidationUtil.stringValidationEx(
                item.get('SystemCode__c'),
                'SystemCode__c',
                true,
                true
            );
            String largecode = ValidationUtil.stringValidationEx(
                item.get('LargeCategoryCode__c'),
                'LargeCategoryCode__c',
                true,
                true
            );
            String mediumcode = ValidationUtil.stringValidationEx(
                item.get('MediumCategoryCode__c'),
                'MediumCategoryCode__c',
                true,
                true
            );
            String name = ValidationUtil.stringValidationEx(item.get('Name'), 'Name', true, true);

            String type1 = ValidationUtil.stringValidationEx(
                item.get('Type1__c'),
                'Type1__c',
                true,
                false
            );
            String type2 = ValidationUtil.stringValidationEx(
                item.get('Type2__c'),
                'Type2__c',
                true,
                false
            );
            String type3 = ValidationUtil.stringValidationEx(
                item.get('Type3__c'),
                'Type3__c',
                true,
                false
            );

            Boolean isactive = ValidationUtil.booleanValidation(
                item.get('IsActive__c'),
                'IsActive__c',
                true
            );

            String code = systemCode + '-' + largecode + '-' + mediumcode;

            ProductCategory pc;

            if (existMap.containsKey(code)) {
                pc = existMap.get(code);
                updateList.add(pc);
            } else {
                pc = new ProductCategory();
                pc.CatalogId = catalog.Id;
                pc.Code = code;
                pc.SystemCode__c = systemCode;
                pc.LargeCategoryCode__c = largecode;
                pc.MediumCategoryCode__c = mediumcode;

                insertList.add(pc);
            }

            // 공통 필드 세팅
            pc.Name = name;
            pc.CompanyCode__c = companyAcc.Id;
            pc.BrandCode__c = brandcode;
            pc.Type1__c = type1;
            pc.Type2__c = type2;
            pc.Type3__c = type3;
            pc.IsActive__c = isactive;
        }

        /* =====================================================
         * 4. DML 실행 + 에러 처리
         * ===================================================== */
        if (!insertList.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(insertList, false);

            for (Database.SaveResult sr : insertResults) {
                if (!sr.isSuccess()) {
                    Database.Error err = sr.getErrors()[0];
                    throw new CustomException(400, err.getMessage());
                }
            }
        }

        if (!updateList.isEmpty()) {
            Database.SaveResult[] updateResults = Database.update(updateList, false);

            for (Database.SaveResult sr : updateResults) {
                if (!sr.isSuccess()) {
                    Database.Error err = sr.getErrors()[0];
                    throw new CustomException(400, err.getMessage());
                }
            }
        }

        /* =====================================================
         * 5. 응답 데이터 (실제 처리된 데이터 반환)
         * ===================================================== */
        Map<String, Object> data = new Map<String, Object>();
        data.put('insertItems', insertList);
        data.put('updateItems', updateList);

        return ApiResult.ok(200, '제품 중분류 카테고리 등록/수정 완료', data);
    }

    /* =========================================================
     * 제품 소분류 카테고리 등록/수정
     * ========================================================= */
    public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
        if (reqData == null || reqData.isEmpty()) {
            throw new CustomException(400, 'Request body is empty.');
        }

        String companyCode = ValidationUtil.stringValidationEx(
            reqData.get('CompanyCode__c'),
            'CompanyCode__c',
            true,
            false
        );

        List<Object> items = (List<Object>) reqData.get('items');
        if (items == null || items.isEmpty()) {
            throw new CustomException(400, 'items is empty.');
        }

        Account companyAcc = getCompany(companyCode);
        ProductCatalog catalog = getProductCatalog();

        /* =====================================================
         * 1. Code 수집
         * ===================================================== */
        Set<String> codeSet = new Set<String>();
        List<Map<String, Object>> parsedItems = new List<Map<String, Object>>();

        for (Object o : items) {
            Map<String, Object> item = (Map<String, Object>) o;

            String systemCode = ValidationUtil.stringValidationEx(
                item.get('SystemCode__c'),
                'SystemCode__c',
                true,
                true
            );
            String largecode = ValidationUtil.stringValidationEx(
                item.get('LargeCategoryCode__c'),
                'LargeCategoryCode__c',
                true,
                true
            );
            String mediumcode = ValidationUtil.stringValidationEx(
                item.get('MediumCategoryCode__c'),
                'MediumCategoryCode__c',
                true,
                true
            );
            String smallcode = ValidationUtil.stringValidationEx(
                item.get('SmallCategoryCode__c'),
                'SmallCategoryCode__c',
                true,
                true
            );

            String code = systemCode + '-' + largecode + '-' + mediumcode + '-' + smallCode;

            codeSet.add(code);
            parsedItems.add(item);
        }

        /* =====================================================
         * 2. 기존 데이터 조회
         * ===================================================== */
        Map<String, ProductCategory> existMap = new Map<String, ProductCategory>();
        for (ProductCategory pc : [
            SELECT Id, Code
            FROM ProductCategory
            WHERE Code IN :codeSet
        ]) {
            existMap.put(pc.Code, pc);
        }

        /* =====================================================
         * 3. INSERT / UPDATE 분기
         * ===================================================== */
        List<ProductCategory> insertList = new List<ProductCategory>();
        List<ProductCategory> updateList = new List<ProductCategory>();

        for (Map<String, Object> item : parsedItems) {
            String brandcode = ValidationUtil.stringValidationEx(
                item.get('BrandCode__c'),
                'BrandCode__c',
                true,
                false
            );
            String systemCode = ValidationUtil.stringValidationEx(
                item.get('SystemCode__c'),
                'SystemCode__c',
                true,
                true
            );
            String largecode = ValidationUtil.stringValidationEx(
                item.get('LargeCategoryCode__c'),
                'LargeCategoryCode__c',
                true,
                true
            );
            String mediumcode = ValidationUtil.stringValidationEx(
                item.get('MediumCategoryCode__c'),
                'MediumCategoryCode__c',
                true,
                true
            );
            String smallcode = ValidationUtil.stringValidationEx(
                item.get('SmallCategoryCode__c'),
                'SmallCategoryCode__c',
                true,
                true
            );
            String name = ValidationUtil.stringValidationEx(item.get('Name'), 'Name', true, true);

            String type1 = ValidationUtil.stringValidationEx(
                item.get('Type1__c'),
                'Type1__c',
                true,
                false
            );
            String type2 = ValidationUtil.stringValidationEx(
                item.get('Type2__c'),
                'Type2__c',
                true,
                false
            );
            String type3 = ValidationUtil.stringValidationEx(
                item.get('Type3__c'),
                'Type3__c',
                true,
                false
            );

            Boolean isactive = ValidationUtil.booleanValidation(
                item.get('IsActive__c'),
                'IsActive__c',
                true
            );

            String code = systemCode + '-' + largecode + '-' + mediumcode + '-' + smallCode;

            ProductCategory pc;

            if (existMap.containsKey(code)) {
                pc = existMap.get(code);
                updateList.add(pc);
            } else {
                pc = new ProductCategory();
                pc.CatalogId = catalog.Id;
                pc.Code = code;
                pc.SystemCode__c = systemCode;
                pc.LargeCategoryCode__c = largecode;
                pc.MediumCategoryCode__c = mediumcode;
                pc.SmallCategoryCode__c = smallcode;

                insertList.add(pc);
            }

            // 공통 필드 세팅
            pc.Name = name;
            pc.CompanyCode__c = companyAcc.Id;
            pc.BrandCode__c = brandcode;
            pc.Type1__c = type1;
            pc.Type2__c = type2;
            pc.Type3__c = type3;
            pc.IsActive__c = isactive;
        }

        /* =====================================================
         * 4. DML 실행 + 에러 처리
         * ===================================================== */
        if (!insertList.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(insertList, false);

            for (Database.SaveResult sr : insertResults) {
                if (!sr.isSuccess()) {
                    Database.Error err = sr.getErrors()[0];
                    throw new CustomException(400, err.getMessage());
                }
            }
        }

        if (!updateList.isEmpty()) {
            Database.SaveResult[] updateResults = Database.update(updateList, false);

            for (Database.SaveResult sr : updateResults) {
                if (!sr.isSuccess()) {
                    Database.Error err = sr.getErrors()[0];
                    throw new CustomException(400, err.getMessage());
                }
            }
        }

        /* =====================================================
         * 5. 응답 데이터 (실제 처리된 데이터 반환)
         * ===================================================== */
        Map<String, Object> data = new Map<String, Object>();
        data.put('insertItems', insertList);
        data.put('updateItems', updateList);

        return ApiResult.ok(200, '제품 소분류 카테고리 등록/수정 완료', data);
    }
}