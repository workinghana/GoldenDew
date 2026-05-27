public with sharing class GdProductServiceImpl implements GdProductService {
  /**
   * 품목계정분류코드(ProductAccountCategoryCode__c) 입력값 정규화 매핑
   * - ERP에서 들어오는 코드를 로열티 저장값으로 변환
   * - 매핑이 없는 코드는 입력값 그대로 사용
   *
   * 26.05.27 HN 수정 : ERP 코드 "3" → "2" 치환 (고객사 요청)
   */
  private static final Map<String, String> PRODUCT_ACCOUNT_CATEGORY_CODE_MAPPING = new Map<String, String>{ '3' => '2' };

  /**
   * 품목계정분류코드 입력값 정규화
   * @param  code ERP에서 받은 원본 코드 (null 허용)
   * @return 매핑 테이블에 정의된 코드면 치환값, 아니면 원본 그대로 반환
   */
  @TestVisible
  private static String normalizeProductAccountCategoryCode(String code) {
    if (code == null) {
      return null;
    }
    String mapped = PRODUCT_ACCOUNT_CATEGORY_CODE_MAPPING.get(code);
    return (mapped != null) ? mapped : code;
  }

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

      // 26.04.04 WT 수정 :BrandCode__c 추가
      // 26.05.27 HN 수정 : productAccountCategoryCode 수정
      String brandCode = ValidationUtil.stringValidationEx(reqData.get('BrandCode__c'), 'BrandCode__c', false, true);

      String largeCategoryCode = ValidationUtil.stringValidationEx(reqData.get('LargeCategoryCode__c'), 'LargeCategoryCode__c', false, true); // 대분류 코드
      String mediumCategoryCode = ValidationUtil.stringValidationEx(reqData.get('MediumCategoryCode__c'), 'MediumCategoryCode__c', false, true); // 중분류 코드
      String smallCategoryCode = ValidationUtil.stringValidationEx(reqData.get('SmallCategoryCode__c'), 'SmallCategoryCode__c', false, true); // 소분류 코드
      String productAccountCategoryCode = normalizeProductAccountCategoryCode(
        ValidationUtil.stringValidationEx(reqData.get('ProductAccountCategoryCode__c'), 'ProductAccountCategoryCode__c', false, false)
      ); // 품목계정분류코드 (ERP 코드 정규화 적용)

      String clarity = ValidationUtil.stringValidation(reqData.get('Clarity2__c'), 'Clarity2__c', false);
      String color = ValidationUtil.stringValidation(reqData.get('Color2__c'), 'Color2__c', false);
      String cut = ValidationUtil.stringValidation(reqData.get('Cut2__c'), 'Cut2__c', false);
      String scopeWeight = ValidationUtil.stringValidation(reqData.get('ScopeWeight2__c'), 'ScopeWeight2__c', false);
      String shape = ValidationUtil.stringValidation(reqData.get('Shape2__c'), 'Shape2__c', false);
      String unit = ValidationUtil.stringValidation(reqData.get('Unit2__c'), 'Unit2__c', false);
      String size = ValidationUtil.stringValidation(reqData.get('Size__c'), 'Size__c', false);

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

      p.Clarity2__c = clarity;
      p.Color2__c = color;
      p.Cut2__c = cut;
      p.ScopeWeight2__c = scopeWeight;
      p.Shape2__c = shape;
      p.Unit2__c = unit;
      p.Size__c = size;

      Database.SaveResult result = Database.insert(p);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      // 26.04.04 WT 수정 : 기존 코드
      // if (largeCategoryCode != null) {
      //   String whereClause = 'WHERE LargeCategoryCode__c = :largeCategoryCode ';
      //   if (mediumCategoryCode != null) {
      //     whereClause += 'AND MediumCategoryCode__c = :mediumCategoryCode ';
      //     if (smallCategoryCode != null) {
      //       whereClause += 'AND SmallCategoryCode__c = :smallCategoryCode ';
      //     }
      //   }

      // 26.04.04 WT 수정 : 수정 코드
      if (largeCategoryCode != null) {
        String whereClause = 'WHERE LargeCategoryCode__c = :largeCategoryCode ';
        if (mediumCategoryCode != null) {
          whereClause += 'AND MediumCategoryCode__c = :mediumCategoryCode ';
        }
        if (smallCategoryCode != null) {
          whereClause += 'AND SmallCategoryCode__c = :smallCategoryCode ';
        }
        if (productAccountCategoryCode != null) {
          whereClause += 'AND SystemCode__c = :productAccountCategoryCode ';
        }
        // if (brandCode != null) {
        //   whereClause += 'AND BrandCode__c = :brandCode ';
        // }

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

      // 26.04.04 WT 수정 : BrandCode__c 추가
      // 26.05.27 HN 수정 : productAccountCategoryCode 수정
      String brandCode = ValidationUtil.stringValidationEx(reqData.get('BrandCode__c'), 'SystemCode__c', false, true);

      String largeCategoryCode = ValidationUtil.stringValidationEx(reqData.get('LargeCategoryCode__c'), 'LargeCategoryCode__c', false, true); //대분류 코드
      String mediumCategoryCode = ValidationUtil.stringValidationEx(reqData.get('MediumCategoryCode__c'), 'MediumCategoryCode__c', false, true); //중분류 코드
      String smallCategoryCode = ValidationUtil.stringValidationEx(reqData.get('SmallCategoryCode__c'), 'SmallCategoryCode__c', false, true); //소분류 코드
      String productAccountCategoryCode = normalizeProductAccountCategoryCode(
        ValidationUtil.stringValidationEx(reqData.get('ProductAccountCategoryCode__c'), 'ProductAccountCategoryCode__c', false, false)
      ); // 품목계정분류코드 (ERP 코드 정규화 적용)

      String clarity = ValidationUtil.stringValidation(reqData.get('Clarity2__c'), 'Clarity2__c', false);
      String color = ValidationUtil.stringValidation(reqData.get('Color2__c'), 'Color2__c', false);
      String cut = ValidationUtil.stringValidation(reqData.get('Cut2__c'), 'Cut2__c', false);
      String scopeWeight = ValidationUtil.stringValidation(reqData.get('ScopeWeight2__c'), 'ScopeWeight2__c', false);
      String shape = ValidationUtil.stringValidation(reqData.get('Shape2__c'), 'Shape2__c', false);
      String unit = ValidationUtil.stringValidation(reqData.get('Unit2__c'), 'Unit2__c', false);
      String size = ValidationUtil.stringValidation(reqData.get('Size__c'), 'Size__c', false);

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

      p.Clarity2__c = clarity;
      p.Color2__c = color;
      p.Cut2__c = cut;
      p.ScopeWeight2__c = scopeWeight;
      p.Shape2__c = shape;
      p.Unit2__c = unit;
      p.Size__c = size;

      Database.SaveResult result = Database.update(p);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      // 26.04.04 WT 수정 : 수정 코드
      if (largeCategoryCode != null) {
        String whereClause = 'WHERE LargeCategoryCode__c = :largeCategoryCode ';
        if (mediumCategoryCode != null) {
          whereClause += 'AND MediumCategoryCode__c = :mediumCategoryCode ';
        }
        if (smallCategoryCode != null) {
          whereClause += 'AND SmallCategoryCode__c = :smallCategoryCode ';
        }
        if (productAccountCategoryCode != null) {
          whereClause += 'AND SystemCode__c = :productAccountCategoryCode ';
        }
        // if (brandCode != null) {
        //   whereClause += 'AND BrandCode__c = :brandCode ';
        // }

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
        // 26.04.04 WT 수정 : [0] 뺴고 복수의 레코드 삭제로 수정 (골든듀 제품 : 카테고리 1:1 구조 반영)
        if (!oldList.isEmpty()) {
          delete oldList;
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

  // 26.04.04  수정 : 프로모션 활성화 조건에 IsActive 필드 제거 및 게시 기간 조건 추가 반영
  public ApiResult getProductByPromotion(String promotionNo) {
    try {
      Map<String, Object> data = new Map<String, Object>();

      // 프로모션 제품(PromotionProduct) 조회
      List<PromotionProduct> ppList = [
        SELECT Product.ProductCode
        FROM PromotionProduct
        WHERE Promotion.PromotionNo__c = :promotionNo AND Promotion.IsActive = TRUE
        LIMIT 1000
      ];

      data.put('적용 가능 품목 목록', ppList);

      return ApiResult.ok(200, '품목 도움창 조회 (프로모션 연동) 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}
