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
      p.PublishStartDate__c = startDate;
      if (endDate != null) {
        p.EndDate = endDate;
        p.PublishEndDate__c = endDate;
      } else {
        p.PublishEndDate__c = startDate;
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

      // [Promotion Search Overlap Fix 2026-04-28] 요청 기간과 프로모션 게시 기간이 "겹치는(overlap)" 프로모션 조회
      //   조건: 프로모션 시작 ≤ 요청 종료  AND  프로모션 종료 ≥ 요청 시작
      //   - 두 기간이 단 하루라도 교차하면 노출 (요청이 프로모션 밖으로 삐져나가도 일부 겹치면 노출)
      //   - startDate 만 들어오면 "그 시점 이후 유효한 프로모션" / endDate 만 들어오면 "그 시점 이전 시작 프로모션" 의미로 자연 동작
      if (startDate != null) {
        wheres.add('PublishEndDate__c >= :startDate');
      }
      if (endDate != null) {
        wheres.add('PublishStartDate__c <= :endDate');
      }

      // ✅ [Solution-22] 게시 기간 기반 활성화 조건 추가 (IsActive 필드 제거에 따른 대체)
      // 원래 : PublishStartDate__c <= TODAY() <= PublishEndDate__c 범위 내만 게시 프로모션으로 처리
      // 변경 : 게시일자 + 활성화 여부(true) 판단으로 게시 프로모션 처리
      // Date today = Date.today();
      wheres.add('IsActive = TRUE');
      // wheres.add('PublishStartDate__c <= :today AND PublishEndDate__c >= :today');

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

        // ① 개별 매장 코드로 PromotionAccount__c 조회
        for (PromotionAccount__c pa : [
          SELECT PromotionId__c
          FROM PromotionAccount__c
          WHERE AccountId__r.StoreCode__c = :storeCode
        ]) {
          if (pa.PromotionId__c != null)
            promotionIdFilter.add(pa.PromotionId__c);
        }

        // ② 전체 매장 프로모션 포함
        for (Promotion promotion : [
          SELECT Id
          FROM Promotion
          WHERE IsAllStore__c = :true
        ]) {
          promotionIdFilter.add(promotion.Id);
        }

        // ③ 매장의 StoreType__c와 Promotion.StoreType__c(multipicklist) 매칭
        List<Account> storeList = [
          SELECT StoreType__c
          FROM Account
          WHERE StoreCode__c = :storeCode
          LIMIT 1
        ];
        if (!storeList.isEmpty() && !String.isBlank(storeList[0].StoreType__c)) {
          String storeType = storeList[0].StoreType__c;
          for (Promotion p : Database.query('SELECT Id FROM Promotion WHERE StoreType__c INCLUDES (\'' + storeType + '\')')) {
            promotionIdFilter.add(p.Id);
          }
        }

        if (promotionIdFilter.isEmpty()) {
          result.put('promotionList', new List<PromotionResDTO>());
          return ApiResult.ok(200, '프로모션 조회 성공', result);
        }

        wheres.add('Id IN :promotionIdFilter');
      }

      String whereClause = wheres.isEmpty() ? '' : (' WHERE ' + String.join(wheres, ' AND '));

      String soql =
        'SELECT Id, Name, PromotionNo__c, IsActive, toLabel(BrandCode__c), toLabel(TypeCode__c), HasTargetProductCondition__c, IsStoreSpecific__c,' +
        ' EndDateTime, StartDateTime, StartDate, EndDate, PublishStartDate__c, PublishEndDate__c,' +
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
          Id,
          Name,
          PromotionNo__c,
          IsActive,
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
          IsAllStore__c,
          IsAllItem__c,
          HasTargetProductCondition__c,
          IsDiscountRateApplicable__c,
          IsStoreSpecific__c
        FROM Promotion
        WHERE PromotionNo__c = :promotionNo
        LIMIT 1
      ];
      if (pList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 프로모션 번호 입니다. ' + promotionNo);
      }

      // ✅ [Solution-22] 게시 기간 검증 (IsActive 필드 제거에 따른 대체)
      // PublishStartDate__c <= TODAY() <= PublishEndDate__c 범위 내에만 조회 가능
      // 2026-04-14 (하나): 프로모션 전체 품목 설정 여부(YN_ALL_ITEM) 응답 추가
      Promotion promotion = pList[0];
      Date today = Date.today();
      Boolean isPublishable =
        promotion.IsActive == true &&
        promotion.PublishStartDate__c != null &&
        promotion.PublishEndDate__c != null &&
        promotion.PublishStartDate__c <= today &&
        promotion.PublishEndDate__c >= today;
      if (!isPublishable) {
        System.debug(
          LoggingLevel.WARN,
          'Promotion is not publishable: ' +
            promotionNo +
            ' (IsActive: ' +
            promotion.IsActive +
            ', PublishStartDate: ' +
            promotion.PublishStartDate__c +
            ', PublishEndDate: ' +
            promotion.PublishEndDate__c +
            ', Today: ' +
            today +
            ')'
        );
        // 주석: 엄격하게 처리하려면 아래 주석 해제
        // throw new CustomException(400, '게시 기간을 벗어난 프로모션 입니다.');
      }

      PromotionDetailResDTO.PromotionMaster pm = new PromotionDetailResDTO.PromotionMaster(promotion);
      Boolean shouldLoadItems =
        isPublishable &&
        promotion.IsAllItem__c != true &&
        promotion.HasTargetProductCondition__c == true;
      Boolean shouldLoadStores = promotion.IsAllStore__c != true && promotion.IsStoreSpecific__c == true;

      // 프로모션 매장 조회
      if (shouldLoadStores) {
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
      }

      // =========================
      // 프로모션 제품 조회
      // =========================
      if (shouldLoadItems) {
        List<PromotionProduct> ppList = [
          SELECT
            Product.ProductCode,
            Product.Name,
            ProductId,
            toLabel(Product.Family),
            toLabel(Product.ProductAccountCategoryCode__c),
            Product.Size__c,
            toLabel(Product.Color2__c),
            toLabel(Product.Clarity2__c),
            toLabel(Product.Cut2__c)
          FROM PromotionProduct
          WHERE PromotionId = :promotion.Id
          LIMIT 5000
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
          // [PromotionItem Category Mapping Fix 2026-04-30]
          //   기존: IsPrimaryCategory = TRUE 인 PCP 만 조회 → Primary 가 false 인 Product 의 카테고리명이 빈값으로 노출
          //   변경: IsPrimaryCategory 우선 정렬로 모든 PCP 조회 → Primary 가 있으면 우선, 없으면 첫 PCP 사용
          //   - 아래 Apex if (!catByProductId.containsKey(...)) 분기로 첫 레코드만 매핑되므로 Primary=true 가 자연 우선됨
          for (ProductCategoryProduct pcp : [
            SELECT
              Id,
              ProductId,
              ProductCategoryId,
              IsPrimaryCategory,
              ProductCategory.SystemCode__c,
              ProductCategory.LargeCategoryCode__c,
              ProductCategory.MediumCategoryCode__c,
              ProductCategory.SmallCategoryCode__c
            FROM ProductCategoryProduct
            WHERE ProductId IN :productIds
            ORDER BY IsPrimaryCategory DESC, Id ASC
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
            System.debug('pc.Name : ' + pc.Name);
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
      }

      // 프로모션 쿠폰 조회
      Set<String> addedCouponKeySet = new Set<String>();
      Set<String> allowedVoucherTypeSet = new Set<String>();
      Date couponToday = Date.today();
      if (pList[0].IsCouponAllowed__c == true) {
        allowedVoucherTypeSet.add('DiscountPercentage');
        allowedVoucherTypeSet.add('FixedValue');
        allowedVoucherTypeSet.add('ProductOrService');
      } else {
        if (pList[0].IsRateCouponAllowed__c == true) {
          allowedVoucherTypeSet.add('DiscountPercentage');
        }
        if (pList[0].IsFixedAmountCouponAllowed__c == true) {
          allowedVoucherTypeSet.add('FixedValue');
        }
      }

      if (!allowedVoucherTypeSet.isEmpty()) {
        List<VoucherDefinition> vdList = [
          SELECT Id, Name, FaceValue, DiscountPercent, Type, EffectiveDate, ExpirationDate
          FROM VoucherDefinition
          WHERE IsActive = TRUE
            AND Type IN :allowedVoucherTypeSet
            AND (ExpirationDate = NULL OR ExpirationDate >= :couponToday)
          LIMIT 1000
        ];
        for (VoucherDefinition vd : vdList) {
          String couponKey = String.valueOf(vd.Id);
          if (addedCouponKeySet.contains(couponKey)) {
            continue;
          }
          pm.COUPONS.add(new PromotionDetailResDTO.PromotionCoupon(vd));
          addedCouponKeySet.add(couponKey);
        }
      }

      if (pList[0].IsSpecificCouponAllowed__c == true) {
        List<VoucherLimit__c> vlList = [
          SELECT
            VoucherDefinitionId__c,
            VoucherDefinitionId__r.Name,
            VoucherDefinitionId__r.FaceValue,
            VoucherDefinitionId__r.DiscountPercent,
            VoucherDefinitionId__r.Type,
            VoucherDefinitionId__r.EffectiveDate,
            VoucherDefinitionId__r.ExpirationDate
          FROM VoucherLimit__c
          WHERE PromotionId__c = :pList[0].Id
            AND IsActive__c = TRUE
            AND (VoucherDefinitionId__r.ExpirationDate = NULL OR VoucherDefinitionId__r.ExpirationDate >= :couponToday)
          LIMIT 1000
        ];
        if (!vlList.isEmpty()) {
          for (VoucherLimit__c vl : vlList) {
            String couponKey = String.valueOf(vl.VoucherDefinitionId__c);
            if (addedCouponKeySet.contains(couponKey)) {
              continue;
            }
            pm.COUPONS.add(new PromotionDetailResDTO.PromotionCoupon(vl));
            addedCouponKeySet.add(couponKey);
          }
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