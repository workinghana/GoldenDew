public with sharing class GdPromotionServiceImpl implements GdPromotionService {
  public GdPromotionServiceImpl() {
  }

  private static final String LOYALTY_PROGRAM_NAME = 'Golden Dew';

  /**
   * ! 사용 X
   * 프로모션 등록
   * Promotion insert
   */
  public ApiResult createPromotion(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', true);
      String name = ValidationUtil.stringValidation(reqData.get('Name'), 'Name', true);
      String displayName = ValidationUtil.stringValidation(reqData.get('DisplayName'), 'DisplayName', false);
      Date startDate = ValidationUtil.dateValidation(reqData.get('StartDate'), 'StartDate', true);
      Date endDate = ValidationUtil.dateValidation(reqData.get('EndDate'), 'EndDate', false);
      String typeCode = ValidationUtil.stringValidation(reqData.get('TypeCode__c'), 'TypeCode__c', false);
      Decimal discountRate = ValidationUtil.decimalValidation(reqData.get('DiscountRate__c'), 'DiscountRate__c', false);
      String statusCode = ValidationUtil.stringValidation(reqData.get('StatusCode__c'), 'StatusCode__c', false);

      // if ([SELECT COUNT() FROM Promotion WHERE PromotionNo__c = :promotionNo] > 0) {
      //   throw new CustomException(400, '중복된 프로모션 번호 입니다. ' + promotionNo);
      // }
      if (
        [
          SELECT COUNT()
          FROM Promotion
          WHERE PromotionNo__c = :promotionNo
        ] > 0
      ) {
        throw new CustomException(400, '중복된 프로모션 번호 입니다. ' + promotionNo);
      }

      // 로열티 프로그램 체크
      List<LoyaltyProgram> lpList = [SELECT Id FROM LoyaltyProgram WHERE Name = :LOYALTY_PROGRAM_NAME LIMIT 1];
      if (lpList.isEmpty()) {
        throw new CustomException(400, 'LoyaltyProgram is null');
      }
      LoyaltyProgram lp = lpList[0];

      Promotion p = new Promotion();
      p.Name = name;
      p.StartDate = startDate;
      if (endDate != null) {
        p.EndDate = endDate;
      }
      if (displayName != null) {
        p.DisplayName = displayName;
      }
      if (typeCode != null) {
        p.TypeCode__c = typeCode;
      }
      if (discountRate != null) {
        p.DiscountRate__c = discountRate;
      }
      if (statusCode != null) {
        p.StatusCode__c = statusCode;
      }
      p.LoyaltyProgramId = lp.Id;

      Database.SaveResult result = Database.insert(p);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
      Map<String, Object> data = new Map<String, Object>();
      data.put('promotionId', p.Id);

      return ApiResult.ok(200, '프로모션 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 프로모션 조회
   */
  public ApiResult getPromotionList(Map<String, String> reqData) {
    Map<String, Object> result = new Map<String, Object>();
    try {
      Date startDate = ValidationUtil.dateValidation(reqData.get('StartDate'), 'StartDate', false);
      Date endDate = ValidationUtil.dateValidation(reqData.get('EndDate'), 'EndDate', false);
      String name = ValidationUtil.stringValidation(reqData.get('Name'), 'Name', false);
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false);
      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false);

      List<String> wheres = new List<String>();

      if (startDate != null)
        wheres.add('EndDate >= :startDate');
      if (endDate != null)
        wheres.add('StartDate <= :endDate');

      if (!String.isBlank(name)) {
        String likeName = '%' + name + '%';
        wheres.add('Name LIKE :likeName');
      }

      if (!String.isBlank(promotionNo)) {
        String likePromotionNo = '%' + promotionNo + '%';
        wheres.add('PromotionNo__c LIKE :likePromotionNo');
      }

      Set<Id> promotionIdFilter;
      if (!String.isBlank(storeCode)) {
        promotionIdFilter = new Set<Id>();
        for (PromotionAccount__c pa : [
          SELECT PromotionId__c
          FROM PromotionAccount__c
          WHERE AccountId__r.StoreCode__c = :storeCode
        ]) {
          if (pa.PromotionId__c != null)
            promotionIdFilter.add(pa.PromotionId__c);
        }

        for (Promotion promotion : [
          SELECT Id
          FROM Promotion
          WHERE IsAllStore__c = :true
        ]) {
          promotionIdFilter.add(promotion.Id);
        }

        if (promotionIdFilter.isEmpty()) {
          result.put('promotionList', new List<PromotionResDTO>());
          return ApiResult.ok(200, '프로모션 조회 성공', result);
        }

        wheres.add('Id IN :promotionIdFilter');
      }

      String whereClause = wheres.isEmpty() ? '' : (' WHERE ' + String.join(wheres, ' AND '));

      String soql =
        'SELECT Id, Name, PromotionNo__c, toLabel(BrandCode__c), toLabel(TypeCode__c),' +
        ' EndDateTime, StartDateTime, PublishStartDate__c, PublishEndDate__c,' +
        ' toLabel(StatusCode__c), IsCouponAllowed__c, IsFixedAmountCouponAllowed__c,' +
        ' IsRateCouponAllowed__c, IsSpecificCouponAllowed__c, IsPointUsageAllowed__c, IsAllStore__c, IsAllItem__c,' +
        ' IsDiscountRateApplicable__c' +
        ' FROM Promotion' +
        whereClause +
        ' ORDER BY StartDate DESC' +
        ' LIMIT 200';

      List<Promotion> pList = Database.query(soql);

      List<PromotionResDTO> dtoList = new List<PromotionResDTO>();
      for (Promotion p : pList) {
        dtoList.add(new PromotionResDTO(p));
      }

      result.put('promotionList', dtoList);
      return ApiResult.ok(200, '프로모션 조회 성공', result);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    }
  }

  /**
   * 프로모션 상세 조회
   */
  public ApiResult getPromotionDetail(String promotionNo) {
    Map<String, Object> resData = new Map<String, Object>();
    try {
      // 프로모션 조회
      List<Promotion> pList = [
        SELECT
          Name,
          PromotionNo__c,
          BrandCode__c,
          TypeCode__c,
          EndDateTime,
          StartDateTime,
          PublishStartDate__c,
          PublishEndDate__c,
          StatusCode__c,
          IsCouponAllowed__c,
          IsFixedAmountCouponAllowed__c,
          IsRateCouponAllowed__c,
          IsSpecificCouponAllowed__c,
          IsPointUsageAllowed__c,
          IsDiscountRateApplicable__c
        FROM Promotion
        WHERE PromotionNo__c = :promotionNo
        LIMIT 1
      ];
      if (pList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 프로모션 번호 입니다. ' + promotionNo);
      }
      PromotionDetailResDTO.PromotionMaster pm = new PromotionDetailResDTO.PromotionMaster(pList[0]);

      // 프로모션 매장 조회
      List<PromotionAccount__c> paList = [
        SELECT
          Id,
          AccountId__r.StoreCode__c,
          toLabel(AccountId__r.BrandCode__c),
          toLabel(AccountId__r.StoreGroupCode__c),
          toLabel(AccountId__r.StoreType__c),
          AccountId__r.Name
        FROM PromotionAccount__c
        WHERE PromotionId__c = :pList[0].Id AND IsActive__c = TRUE
        LIMIT 1000
      ];
      if (!paList.isEmpty()) {
        for (PromotionAccount__c pa : paList) {
          pm.STORES.add(new PromotionDetailResDTO.PromotionStore(pa));
        }
      }

      // =========================
      // 프로모션 제품 조회
      // =========================
      List<PromotionProduct> ppList = [
        SELECT Product.ProductCode, Product.Name, ProductId, toLabel(Product.Family), toLabel(Product.ProductAccountCategoryCode__c)
        FROM PromotionProduct
        WHERE PromotionId = :pList[0].Id
        LIMIT 1000
      ];

      // =========================
      // ProductIds 수집
      // =========================
      Set<Id> productIds = new Set<Id>();
      for (PromotionProduct pp : ppList) {
        if (pp.ProductId != null) {
          productIds.add(pp.ProductId);
        }
      }

      // =========================
      // Product별 Primary Category 조회 + (대/중/소) fullCode 수집
      // =========================
      Map<Id, ProductCategoryProduct> catByProductId = new Map<Id, ProductCategoryProduct>();
      Set<String> codeSet = new Set<String>();

      if (!productIds.isEmpty()) {
        for (ProductCategoryProduct pcp : [
          SELECT
            Id,
            ProductId,
            ProductCategoryId,
            ProductCategory.SystemCode__c,
            ProductCategory.LargeCategoryCode__c,
            ProductCategory.MediumCategoryCode__c,
            ProductCategory.SmallCategoryCode__c
          FROM ProductCategoryProduct
          WHERE ProductId IN :productIds AND IsPrimaryCategory = TRUE
        ]) {
          if (!catByProductId.containsKey(pcp.ProductId)) {
            catByProductId.put(pcp.ProductId, pcp);
          }

          String sys = pcp.ProductCategory.SystemCode__c;
          String lc = pcp.ProductCategory.LargeCategoryCode__c;
          String mc = pcp.ProductCategory.MediumCategoryCode__c;
          String sc = pcp.ProductCategory.SmallCategoryCode__c;

          String largeFull = buildCategoryCode(sys, lc, null, null);
          String mediumFull = buildCategoryCode(sys, lc, mc, null);
          String smallFull = buildCategoryCode(sys, lc, mc, sc);

          if (largeFull != null) {
            codeSet.add(largeFull);
          }
          if (mediumFull != null) {
            codeSet.add(mediumFull);
          }
          if (smallFull != null) {
            codeSet.add(smallFull);
          }
        }
      }

      // =========================
      // Category Code -> Name 매핑
      // =========================
      Map<String, String> nameByFullCode = new Map<String, String>();
      if (!codeSet.isEmpty()) {
        for (ProductCategory pc : [
          SELECT Code, Name
          FROM ProductCategory
          WHERE Code IN :codeSet
        ]) {
          nameByFullCode.put(pc.Code, pc.Name);
        }
      }

      // =========================
      // 표준 Pricebook 가격 매핑
      // =========================
      Map<Id, PricebookEntry> priByProductId = new Map<Id, PricebookEntry>();
      if (!productIds.isEmpty()) {
        for (PricebookEntry pe : [
          SELECT Id, Product2Id, UnitPrice
          FROM PricebookEntry
          WHERE Pricebook2.IsStandard = TRUE AND Product2Id IN :productIds
        ]) {
          if (!priByProductId.containsKey(pe.Product2Id)) {
            priByProductId.put(pe.Product2Id, pe);
          }
        }
      }

      // =========================
      // DTO 생성 (카테고리 이름 매핑 포함)
      // =========================
      for (PromotionProduct pp : ppList) {
        ProductCategoryProduct pcp = catByProductId.get(pp.ProductId);
        PricebookEntry pe = priByProductId.get(pp.ProductId);
        pm.ITEMS.add(new PromotionDetailResDTO.PromotionItem(pp, pcp, pe, nameByFullCode));
      }

      // 프로모션 쿠폰 조회
      List<VoucherLimit__c> vlList = [
        SELECT
          VoucherDefinitionId__r.Name,
          VoucherDefinitionId__r.FaceValue,
          VoucherDefinitionId__r.DiscountPercent,
          VoucherDefinitionId__r.Type,
          VoucherDefinitionId__r.EffectiveDate,
          VoucherDefinitionId__r.ExpirationDate
        FROM VoucherLimit__c
        WHERE PromotionId__c = :pList[0].Id AND Type__c = 'PromotionIncludeList' AND IsActive__c = TRUE
        LIMIT 1000
      ];
      if (!vlList.isEmpty()) {
        for (VoucherLimit__c vl : vlList) {
          pm.COUPONS.add(new PromotionDetailResDTO.PromotionCoupon(vl));
        }
      }

      // 프로모션 포인트 조회
      List<PromotionPointLimit__c> pplList = [
        SELECT Id, Name, toLabel(Type__c), LoyaltyPgmCurrencySubtypeName__c, Value__c
        FROM PromotionPointLimit__c
        WHERE PromotionId__c = :pList[0].Id
        LIMIT 1000
      ];
      if (!pplList.isEmpty()) {
        for (PromotionPointLimit__c ppl : pplList) {
          pm.POINTS.add(new PromotionDetailResDTO.PromotionPoint(ppl));
        }
      }

      resData.put('PromotionDetail', pm);

      return ApiResult.ok(200, '프로모션 상세 조회 성공', resData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  @TestVisible
  private static String buildCategoryCode(String sys, String lc, String mc, String sc) {
    if (String.isBlank(sys) || String.isBlank(lc)) {
      return null;
    }

    List<String> parts = new List<String>();
    parts.add(sys);
    parts.add(lc);
    if (!String.isBlank(mc)) {
      parts.add(mc);
    }
    if (!String.isBlank(sc)) {
      parts.add(sc);
    }

    return String.join(parts, '-');
  }
}