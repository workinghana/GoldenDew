public with sharing class GdProductServiceImpl implements GdProductService {
  public GdProductServiceImpl() {
  }

  /**
   * 품목 등록
   *
   * Product2 insert
   */
  public ApiResult createProduct(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String productCode = ValidationUtil.stringValidation(reqData.get('ProductCode'), 'ProductCode', true);
      String name = ValidationUtil.stringValidation(reqData.get('Name'), 'Name', true);
      String family = ValidationUtil.stringValidation(reqData.get('Family'), 'Family', false);
      String displayUrl = ValidationUtil.stringValidation(reqData.get('DisplayUrl'), 'DisplayUrl', false);
      Boolean isActive = ValidationUtil.booleanValidation(reqData.get('IsActive'), 'IsActive', false);

      String largeCategoryCode = ValidationUtil.stringValidationEx(reqData.get('LargeCategoryCode__c'), 'LargeCategoryCode__c', false, true); // 대분류 코드
      String mediumCategoryCode = ValidationUtil.stringValidationEx(reqData.get('MediumCategoryCode__c'), 'MediumCategoryCode__c', false, true); // 중분류 코드
      String smallCategoryCode = ValidationUtil.stringValidationEx(reqData.get('SmallCategoryCode__c'), 'SmallCategoryCode__c', false, true); // 소분류 코드
      String productAccountCategoryCode = ValidationUtil.stringValidationEx(
        reqData.get('ProductAccountCategoryCode__c'),
        'ProductAccountCategoryCode__c',
        false,
        false
      ); // 품목계정분류코드

      if ([SELECT COUNT() FROM Product2 WHERE ProductCode = :productCode] > 0) {
        throw new CustomException(400, '중복된 품목 번호 입니다. ' + productCode);
      }

      Product2 p = new Product2();
      p.ProductCode = productCode;
      p.Name = name;
      p.Family = family;
      p.DisplayUrl = displayUrl;
      p.IsActive = (isActive == null) ? false : isActive;
      p.ProductAccountCategoryCode__c = productAccountCategoryCode;

      Database.SaveResult result = Database.insert(p);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      if (largeCategoryCode != null) {
        String whereClause = 'WHERE LargeCategoryCode__c = :largeCategoryCode ';
        if (mediumCategoryCode != null) {
          whereClause += 'AND MediumCategoryCode__c = :mediumCategoryCode ';
          if (smallCategoryCode != null) {
            whereClause += 'AND SmallCategoryCode__c = :smallCategoryCode ';
          }
        }

        String soql = 'SELECT Id ' + 'FROM ProductCategory ' + whereClause + 'LIMIT 1';

        List<ProductCategory> pcList = Database.query(soql);

        if (pcList.isEmpty()) {
          throw new CustomException(400, '해당 카테고리가 존재하지 않습니다.');
        }

        ProductCategoryProduct pcp = new ProductCategoryProduct();
        pcp.ProductId = p.Id;
        pcp.ProductCategoryId = pcList[0].Id;
        pcp.IsPrimaryCategory = true;

        insert pcp;
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('productId', p.Id);
      return ApiResult.ok(200, '품목 생성 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 품목 수정
   *
   * @param reqData 품목 수정 요청 데이터
   * @return ApiResult 품목 수정 결과
   */
  public ApiResult updateProduct(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String productCode = ValidationUtil.stringValidation(reqData.get('ProductCode'), 'ProductCode', true);
      String name = ValidationUtil.stringValidation(reqData.get('Name'), 'Name', false);
      String family = ValidationUtil.stringValidation(reqData.get('Family'), 'Family', false);
      String displayUrl = ValidationUtil.stringValidation(reqData.get('DisplayUrl'), 'DisplayUrl', false);
      Boolean isActive = ValidationUtil.booleanValidation(reqData.get('IsActive'), 'IsActive', false);

      String largeCategoryCode = ValidationUtil.stringValidationEx(reqData.get('LargeCategoryCode__c'), 'LargeCategoryCode__c', false, true); //대분류 코드
      String mediumCategoryCode = ValidationUtil.stringValidationEx(reqData.get('MediumCategoryCode__c'), 'MediumCategoryCode__c', false, true); //중분류 코드
      String smallCategoryCode = ValidationUtil.stringValidationEx(reqData.get('SmallCategoryCode__c'), 'SmallCategoryCode__c', false, true); //소분류 코드
      String productAccountCategoryCode = ValidationUtil.stringValidationEx(
        reqData.get('ProductAccountCategoryCode__c'),
        'ProductAccountCategoryCode__c',
        false,
        false
      ); // 품목계정분류코드

      List<Product2> pList = [SELECT Id FROM Product2 WHERE ProductCode = :productCode LIMIT 1];
      if (pList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 상품 코드입니다. ' + productCode);
      }

      Product2 p = pList[0];
      if (name != null) {
        p.Name = name;
      }
      if (family != null) {
        p.Family = family;
      }
      if (displayUrl != null) {
        p.DisplayUrl = displayUrl;
      }
      if (isActive != null) {
        p.IsActive = isActive;
      }
      if (productAccountCategoryCode != null) {
        p.ProductAccountCategoryCode__c = productAccountCategoryCode;
      }

      Database.SaveResult result = Database.update(p);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      if (largeCategoryCode != null) {
        String whereClause = 'WHERE LargeCategoryCode__c = :largeCategoryCode ';
        if (mediumCategoryCode != null) {
          whereClause += 'AND MediumCategoryCode__c = :mediumCategoryCode ';
          if (smallCategoryCode != null) {
            whereClause += 'AND SmallCategoryCode__c = :smallCategoryCode ';
          }
        }

        String soql = 'SELECT Id ' + 'FROM ProductCategory ' + whereClause + 'LIMIT 1';

        List<ProductCategory> pcList = Database.query(soql);

        if (pcList.isEmpty()) {
          throw new CustomException(400, '해당 카테고리가 존재하지 않습니다.');
        }

        // 기존 Primary 매핑 조회
        List<ProductCategoryProduct> oldList = [
          SELECT Id
          FROM ProductCategoryProduct
          WHERE ProductId = :p.Id AND IsPrimaryCategory = TRUE
          LIMIT 1
        ];

        // 1) 기존이 있으면 삭제
        if (!oldList.isEmpty()) {
          delete oldList[0];
        }

        // 2) 새로 insert
        ProductCategoryProduct newPcp = new ProductCategoryProduct();
        newPcp.ProductId = p.Id;
        newPcp.ProductCategoryId = pcList[0].Id; // 새 카테고리 Id
        newPcp.IsPrimaryCategory = true;
        insert newPcp;
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('productId', p.Id);
      return ApiResult.ok(200, '품목 수정 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 품목 도움창 조회 (프로모션 연동)
   *
   * @param promotionNo 프로모션 번호
   * @return ApiResult
   */
  public ApiResult getProductByPromotion(String promotionNo) {
    try {
      Map<String, Object> data = new Map<String, Object>();

      // 프로모션 제품(PromotionProduct) 조회
      List<PromotionProduct> ppList = [SELECT Product.ProductCode FROM PromotionProduct WHERE Promotion.PromotionNo__c = :promotionNo LIMIT 1000];

      data.put('적용 가능 품목 목록', ppList);

      return ApiResult.ok(200, '품목 도움창 조회 (프로모션 연동) 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}