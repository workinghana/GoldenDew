/**
 * 주문 관련 로직 처리하는 서비스 구현 클래스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 * @see GdOrderService
 */
public with sharing class GdOrderServiceImpl implements GdOrderService {
  public GdOrderServiceImpl() {
  }

  public enum Status {
    Draft
  }

  /**
   * 주문 등록 - Order 생성
   *
   * @param reqData
   * @return ApiResult에 등록된 주문(Order) 레코드 Id 담아서 반환
   * @throws CustomException
   */
  public ApiResult createOrder(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String accountId = ValidationUtil.stringValidation(reqData.get('AccountId'), 'AccountId', true);
      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', true);
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      String orderNo = ValidationUtil.stringValidation(reqData.get('OrderNo__c'), 'OrderNo__c', true);
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액
      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', false); // 주문 구분 코드
      String orderStatus = ValidationUtil.stringValidation(reqData.get('OrderStatus__c'), 'OrderStatus__c', false); // 주문 상태 코드
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true); // 등록자
      Date poDate = ValidationUtil.dateValidation(reqData.get('PoDate'), 'PoDate', false); // 주문 일자
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false); // 프로모션 번호

      // 주문번호(OrderNo__c) 중복 체크
      if ([SELECT COUNT() FROM Order WHERE OrderNo__c = :orderNo] > 0) {
        throw new CustomException(400, '이미 존재하는 주문번호 입니다.' + orderNo);
      }

      List<Contact> contactList = [SELECT Id, MemberNo__c FROM Contact WHERE MemberNo__c = :memberNo AND MemberDropDate__c = NULL LIMIT 1];
      if (contactList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }
      Contact contact = contactList[0];

      // 회사 코드 체크
      List<Account> companyList = [SELECT Id FROM Account WHERE CompanyCode__c = :accountId LIMIT 1];
      if (companyList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회사 코드입니다. ' + accountId);
      }
      Account company = companyList[0];

      // 매장 코드 체크
      List<Account> storeList = [SELECT Id, StoreTypeFour__c, StoreType__c FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
      if (storeList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 매장 코드입니다. ' + storeCode);
      }
      Account store = storeList[0];

      // Standard Pricebook 조회
      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Id promotionId;
      if (!String.isEmpty(promotionNo)) {
        List<Promotion> promotionList = [
          SELECT Id, IsActive, StartDate, EndDate
          FROM Promotion
          WHERE PromotionNo__c = :promotionNo AND PromotionNo__c != NULL
          LIMIT 1
        ];
        if (promotionList.isEmpty()) {
          throw new CustomException(400, '해당 프로모션이 없습니다. ' + promotionNo);
        }
        if (promotionList[0].IsActive == false) {
          throw new CustomException(400, '해당 프로모션은 비활성화 상태입니다. ' + promotionNo);
        }

        Promotion p = promotionList[0];
        Date orderDate = poDate == null ? Date.today() : poDate;
        if (p.StartDate != null && orderDate < p.StartDate) {
          throw new CustomException(
            400,
            '주문 일자가 프로모션 적용 기간 이전입니다. (프로모션: ' +
              promotionNo +
              ', 시작일: ' +
              String.valueOf(p.StartDate) +
              ', 종료일: ' +
              String.valueOf(p.EndDate) +
              ')'
          );
        }
        if (p.EndDate != null && orderDate > p.EndDate) {
          throw new CustomException(
            400,
            '주문 일자가 프로모션 적용 기간 이후입니다. (프로모션: ' +
              promotionNo +
              ', 시작일: ' +
              String.valueOf(p.StartDate) +
              ', 종료일: ' +
              String.valueOf(p.EndDate) +
              ')'
          );
        }
        promotionId = p.Id;
      }

      Order o = new Order();
      o.AccountId = company.Id;
      o.StoreCode__c = store.Id;
      o.Status = String.valueOf(Status.Draft);
      o.Type = type;
      o.EffectiveDate = Date.today();
      o.MemberNo__c = contact.Id;
      o.OrderNo__c = orderNo;
      o.ActualPaymentAmount__c = actualPaymentAmount;
      o.OrderStatus__c = orderStatus;
      o.Pricebook2Id = standardPricebookId;
      o.InsertId__c = insertId;
      o.PoDate = poDate == null ? Date.today() : poDate;
      if (promotionId != null) {
        o.PromotionId__c = promotionId;
      }

      Database.SaveResult result = Database.insert(o);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('orderId', o.Id);
      data.put('storeTypeFour', store.StoreTypeFour__c);
      data.put('storeType', store.StoreType__c);
      if (promotionId != null) {
        data.put('promotionId', promotionId);
      }

      return ApiResult.ok(200, '주문 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 주문 수정
   * Order update
   */
  public ApiResult updateOrder(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String orderNo = ValidationUtil.stringValidation(reqData.get('OrderNo__c'), 'OrderNo__c', true);
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false);
      String orderStatus = ValidationUtil.stringValidation(reqData.get('OrderStatus__c'), 'OrderStatus__c', false);

      List<Order> oList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 주문입니다. ' + orderNo);
      }

      if (actualPaymentAmount != null) {
        oList[0].ActualPaymentAmount__c = actualPaymentAmount;
      }
      if (orderStatus != null) {
        oList[0].OrderStatus__c = orderStatus;
      }

      Database.SaveResult result = Database.update(oList[0]);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('orderId', oList[0].Id);

      return ApiResult.ok(200, '주문 수정 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 등록
   * Order insert
   */
  public ApiResult createSale(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String accountId = ValidationUtil.stringValidation(reqData.get('AccountId'), 'AccountId', true);
      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', true);
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', true);
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false);
      String saleStatus = ValidationUtil.stringValidation(reqData.get('SaleStatus__c'), 'SaleStatus__c', false);
      Date saleDate = ValidationUtil.dateValidation(reqData.get('EndDate'), 'EndDate', false);
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true); // 등록자
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false); // 프로모션 번호

      // 판매번호(SaleNo__c) 중복 체크
      if ([SELECT COUNT() FROM Order WHERE SaleNo__c = :saleNo] > 0) {
        throw new CustomException(400, 'SaleNo__c already exists.');
      }

      List<Contact> contactList = [SELECT Id, MemberNo__c FROM Contact WHERE MemberNo__c = :memberNo AND MemberDropDate__c = NULL LIMIT 1];
      if (contactList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }
      Contact contact = contactList[0];

      // 회사 코드 체크
      List<Account> companyList = [SELECT Id FROM Account WHERE CompanyCode__c = :accountId LIMIT 1];
      if (companyList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회사 코드입니다. ' + accountId);
      }
      Account company = companyList[0];

      // 매장 코드 체크
      List<Account> storeList = [SELECT Id, StoreTypeFour__c, StoreType__c FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
      if (storeList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 매장 코드입니다. ' + storeCode);
      }
      Account store = storeList[0];

      // Standard Pricebook 조회
      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Id promotionId;
      if (!String.isEmpty(promotionNo)) {
        List<Promotion> promotionList = [
          SELECT Id, IsActive, StartDate, EndDate
          FROM Promotion
          WHERE PromotionNo__c = :promotionNo AND PromotionNo__c != NULL
          LIMIT 1
        ];
        if (promotionList.isEmpty()) {
          throw new CustomException(400, '해당 프로모션이 없습니다. ' + promotionNo);
        }
        promotionId = promotionList[0].Id;
      }

      Order o = new Order();
      o.AccountId = company.Id;
      o.StoreCode__c = store.Id;
      o.Status = String.valueOf(Status.Draft);
      o.EffectiveDate = saleDate == null ? Date.today() : saleDate;
      o.EndDate = saleDate == null ? Date.today() : saleDate;
      o.MemberNo__c = contact.Id;
      o.SaleNo__c = saleNo;
      if (actualPaymentAmount != null) {
        o.ActualPaymentAmount__c = actualPaymentAmount;
      }
      if (saleStatus != null) {
        o.SaleStatus__c = saleStatus;
      }
      o.Pricebook2Id = standardPricebookId;
      o.InsertId__c = insertId;
      if (promotionId != null) {
        o.PromotionId__c = promotionId;
      }

      Database.SaveResult insertResult = Database.insert(o);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('orderId', o.Id);
      data.put('storeTypeFour', store.StoreTypeFour__c);
      data.put('storeType', store.StoreType__c);

      return ApiResult.ok(200, '판매 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 수정
   * Order update
   */
  public ApiResult updateSale(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', true);
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false);
      String saleStatus = ValidationUtil.stringValidation(reqData.get('SaleStatus__c'), 'SaleStatus__c', false);
      // Date saleDate = ValidationUtil.dateValidation(reqData.get('EndDate'), 'EndDate', false); // 판매 수정 시 판매 일자 변경 불가능

      List<Order> oList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 판매입니다. ' + saleNo);
      }

      List<Order> returnOrderList = [SELECT Id FROM Order WHERE OriginalOrderId__c = :oList[0].Id AND IsDeleted__c = FALSE LIMIT 1];
      if (!returnOrderList.isEmpty()) {
        throw new CustomException(400, '반품 처리된 판매는 수정할 수 없습니다. ' + saleNo);
      }

      if (actualPaymentAmount != null) {
        oList[0].ActualPaymentAmount__c = actualPaymentAmount;
      }
      if (saleStatus != null) {
        oList[0].SaleStatus__c = saleStatus;
      }
      // if (saleDate != null) {
      //   oList[0].EffectiveDate = saleDate;
      //   oList[0].EndDate = saleDate;
      // }

      Database.SaveResult result = Database.update(oList[0]);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('orderId', oList[0].Id);

      return ApiResult.ok(200, '판매 수정 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 이관 대상
   * 판매 전체 삭제
   * Order update
   */
  public ApiResult deleteSale(String saleNo) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Order> oList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 판매 번호입니다. ' + saleNo);
      }

      oList[0].DeleteDateTime__c = System.now();
      oList[0].IsDeleted__c = true;

      Database.SaveResult result = Database.update(oList[0]);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      data.put('orderId', oList[0].Id);

      return ApiResult.ok(200, '판매 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}