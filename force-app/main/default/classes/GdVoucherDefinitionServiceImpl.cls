public with sharing class GdVoucherDefinitionServiceImpl implements GdVoucherDefinitionService {
  public GdVoucherDefinitionServiceImpl() {
  }

  /**
   * 쿠폰 마스터 생성
   * VoucherDefinition insert
   */
  public ApiResult createVoucherDefinition(Map<String, Object> reqData) {
    try {
      String couponManNo = ValidationUtil.stringValidation(reqData.get('CouponManNo__c'), 'CouponManNo__c', true);
      String name = ValidationUtil.stringValidation(reqData.get('Name'), 'Name', true);
      String codePrefix = ValidationUtil.stringValidation(reqData.get('CodePrefix'), 'CodePrefix', false);
      String codeSuffix = ValidationUtil.stringValidation(reqData.get('CodeSuffix'), 'CodeSuffix', false);
      Date effectiveDate = ValidationUtil.dateValidation(reqData.get('EffectiveDate'), 'EffectiveDate', true);
      Date expirationDate = ValidationUtil.dateValidation(reqData.get('ExpirationDate'), 'ExpirationDate', false);
      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', true);
      Integer discountPercent = Type.equals('DiscountPercentage')
        ? ValidationUtil.integerValidation(reqData.get('DiscountPercent'), 'DiscountPercent', true)
        : null;
      Decimal faceValue = Type.equals('FixedValue') ? ValidationUtil.decimalValidation(reqData.get('FaceValue'), 'FaceValue', true) : null;
      String couponTypeCode = ValidationUtil.stringValidation(reqData.get('CouponTypeCode__c'), 'CouponTypeCode__c', false);
      Integer expirationPeriod = ValidationUtil.integerValidation(reqData.get('ExpirationPeriod'), 'ExpirationPeriod', false);
      String expirationType = (expirationPeriod == null) ? 'FixedDate' : 'Period';
      String expirationPeriodUnit = (expirationPeriod == null) ? null : 'Months';

      // 쿠폰 마스터(쿠폰관리번호) 중복 체크
      if ([SELECT COUNT() FROM VoucherDefinition WHERE CouponManNo__c = :couponManNo] > 0) {
        throw new CustomException(400, '이미 존재하는 쿠폰관리번호입니다. ' + couponManNo);
      }
      // 쿠폰 마스터(쿠폰명) 중복 체크
      if ([SELECT COUNT() FROM VoucherDefinition WHERE Name = :name] > 0) {
        throw new CustomException(400, '이미 존재하는 쿠폰명입니다. ' + name);
      }
      // 로열티 프로그램 체크
      List<LoyaltyProgram> lpList = [SELECT Id FROM LoyaltyProgram WHERE IsPrimary = TRUE LIMIT 1];
      if (lpList.isEmpty()) {
        throw new CustomException(400, '로열티 프로그램이 없습니다.');
      }

      VoucherDefinition vd = new VoucherDefinition();
      vd.CouponManNo__c = couponManNo;
      vd.Name = name;
      vd.CodePrefix = codePrefix;
      vd.CodeSuffix = codeSuffix;
      vd.EffectiveDate = effectiveDate;
      vd.ExpirationDate = expirationDate;
      vd.Type = type;
      vd.DiscountPercent = discountPercent;
      vd.FaceValue = faceValue;
      vd.CouponTypeCode__c = couponTypeCode;
      vd.ExpirationPeriod = expirationPeriod;
      vd.ExpirationType = expirationType;
      vd.ExpirationPeriodUnit = expirationPeriodUnit;

      vd.LoyaltyProgramId = lpList[0].Id;
      vd.IsActive = true;

      Database.SaveResult result = Database.insert(vd);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(vd));

      // 쿠폰 한도 설정
      Map<String, Object> limits = ValidationUtil.mapStrObjValidation(reqData.get('Limits'), 'Limits', false);
      if (limits != null) {
        limits.put('VoucherDefinitionId', vd.Id);
        addVoucherLimit(limits);
      } else {
        data.put('Limits', null);
      }

      return ApiResult.ok(200, '쿠폰 마스터 생성 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 프로모션 등록 시 사용 가능한 쿠폰 설정
   * VoucherLimit__c insert
   */
  public ApiResult addVoucherLimitByPromotion(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      // 프로모션에서 사용 가능한 쿠폰 설정
      List<Object> couponList = ValidationUtil.listObjValidation(reqData.get('CouponList'), 'CouponList', false);
      if (couponList == null) {
        return ApiResult.ok(200, '', null);
      }
      List<String> couponStrList = (List<String>) JSON.deserialize(JSON.serialize(CouponList), List<String>.class); // List<String> 타입으로 강제 형 변환

      String promotionId = ValidationUtil.stringValidation(reqData.get('promotionId'), 'promotionId', true);

      List<VoucherDefinition> vdList = [SELECT Id FROM VoucherDefinition WHERE CouponManNo__c IN :couponStrList];
      if (vdList.isEmpty()) {
        throw new CustomException(400, '쿠폰이 존재하지 않습니다.');
      }

      List<VoucherLimit__c> vlList = new List<VoucherLimit__c>();
      for (VoucherDefinition vd : vdList) {
        VoucherLimit__c vl = new VoucherLimit__c();
        vl.VoucherDefinitionId__c = vd.Id;
        vl.Value__c = promotionId;
        vl.Type__c = 'PromotionIncludeList';
        vl.ObjectName__c = 'Promotion';
        vlList.add(vl);
      }

      List<Database.SaveResult> resultList = Database.insert(vlList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      return ApiResult.ok(200, '쿠폰 한도 추가 완료', null);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 쿠폰 마스터 등록 시 쿠폰 한도 설정
   * VoucherLimit__c insert
   */
  public void addVoucherLimit(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String voucherDefinitionId = ValidationUtil.stringValidation(reqData.get('VoucherDefinitionId'), 'VoucherDefinitionId', true); // 쿠폰 마스터 Id

      List<String> productIncludeList = ValidationUtil.listObjToStrValidation(reqData.get('ProductIncludeList'), 'ProductIncludeList', false); // 사용O 품목 리스트
      List<String> productExcludeList = ValidationUtil.listObjToStrValidation(reqData.get('ProductExcludeList'), 'ProductExcludeList', false); // 사용X 품목 리스트
      List<String> storeIncludeList = ValidationUtil.listObjToStrValidation(reqData.get('StoreIncludeList'), 'StoreIncludeList', false); // 사용O 매장 리스트
      List<String> storeExcludeList = ValidationUtil.listObjToStrValidation(reqData.get('StoreExcludeList'), 'StoreExcludeList', false); // 사용X 매장 리스트
      List<String> storeTypeIncludeList = ValidationUtil.listObjToStrValidation(reqData.get('StoreTypeIncludeList'), 'StoreTypeIncludeList', false); // 사용O 매장 구분 리스트
      Decimal maxDiscountRate = ValidationUtil.decimalValidation(reqData.get('MaxDiscountRate'), 'MaxDiscountRate', false); // 적용가능 판매할인율
      List<String> gradeIncludeList = ValidationUtil.listObjToStrValidation(reqData.get('GradeIncludeList'), 'GradeIncludeList', false); // 사용O 회원 등급 리스트
      List<String> productCategoryIncludeList = ValidationUtil.listObjToStrValidation( // 사용O 품목분류 리스트
        reqData.get('ProductCategoryIncludeList'),
        'ProductCategoryIncludeList',
        false
      );
      List<String> productCategoryExcludeList = ValidationUtil.listObjToStrValidation( // 사용X 품목분류 리스트
        reqData.get('ProductCategoryExcludeList'),
        'ProductCategoryExcludeList',
        false
      );
      List<String> orderTypeIncludeList = ValidationUtil.listObjToStrValidation(reqData.get('OrderTypeIncludeList'), 'OrderTypeIncludeList', false); // 사용O 주문 분류 리스트
      Decimal minTotalQuantity = ValidationUtil.decimalValidation(reqData.get('MinTotalQuantity'), 'MinTotalQuantity', false); // 사용가능 판매 개수
      Decimal minSalesAmount = ValidationUtil.decimalValidation(reqData.get('MinSalesAmount'), 'MinSalesAmount', false); // 사용가능 판매 금액

      List<VoucherLimit__c> vlList = new List<VoucherLimit__c>();

      if (productIncludeList != null) {
        for (String productCode : productIncludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = productCode;
          vl.Type__c = 'ProductIncludeList';
          vl.ObjectName__c = 'Product2';
          vlList.add(vl);
        }
      }
      if (productExcludeList != null) {
        for (String productCode : productExcludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = productCode;
          vl.Type__c = 'ProductExcludeList';
          vl.ObjectName__c = 'Product2';
          vlList.add(vl);
        }
      }
      if (storeIncludeList != null) {
        for (String storeCode : storeIncludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = storeCode;
          vl.Type__c = 'StoreIncludeList';
          vl.ObjectName__c = 'Account';
          vlList.add(vl);
        }
      }
      if (storeExcludeList != null) {
        for (String storeCode : storeExcludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = storeCode;
          vl.Type__c = 'StoreExcludeList';
          vl.ObjectName__c = 'Account';
          vlList.add(vl);
        }
      }
      if (storeTypeIncludeList != null) {
        for (String storeType : storeTypeIncludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = storeType;
          vl.ObjectName__c = 'Account';
          vl.Type__c = 'StoreTypeIncludeList';
          vlList.add(vl);
        }
      }
      if (gradeIncludeList != null) {
        for (String grade : gradeIncludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = grade;
          vl.Type__c = 'GradeIncludeList';
          vl.ObjectName__c = 'Contact';
          vlList.add(vl);
        }
      }
      if (productCategoryIncludeList != null) {
        for (String productCategory : productCategoryIncludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = productCategory;
          vl.Type__c = 'ProductCategoryIncludeList';
          vl.ObjectName__c = 'ProductCategory';
          vlList.add(vl);
        }
      }
      if (productCategoryExcludeList != null) {
        for (String productCategory : productCategoryExcludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = productCategory;
          vl.Type__c = 'productCategoryExcludeList';
          vl.ObjectName__c = 'ProductCategory';
          vlList.add(vl);
        }
      }
      if (orderTypeIncludeList != null) {
        for (String orderType : orderTypeIncludeList) {
          VoucherLimit__c vl = new VoucherLimit__c();
          vl.VoucherDefinitionId__c = voucherDefinitionId;
          vl.Value__c = orderType;
          vl.Type__c = 'OrderTypeIncludeList';
          vl.ObjectName__c = 'Order';
          vlList.add(vl);
        }
      }
      if (maxDiscountRate != null) {
        VoucherLimit__c vl = new VoucherLimit__c();
        vl.VoucherDefinitionId__c = voucherDefinitionId;
        vl.Value__c = String.valueOf(maxDiscountRate);
        vl.Type__c = 'MaxDiscountRate';
        vlList.add(vl);
      }
      if (minTotalQuantity != null) {
        VoucherLimit__c vl = new VoucherLimit__c();
        vl.VoucherDefinitionId__c = voucherDefinitionId;
        vl.Value__c = String.valueOf(minTotalQuantity);
        vl.Type__c = 'MinTotalQuantity';
        vlList.add(vl);
      }
      if (minSalesAmount != null) {
        VoucherLimit__c vl = new VoucherLimit__c();
        vl.VoucherDefinitionId__c = voucherDefinitionId;
        vl.Value__c = String.valueOf(minSalesAmount);
        vl.Type__c = 'MinSalesAmount';
        vlList.add(vl);
      }

      List<Database.SaveResult> resultList = Database.insert(vlList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}