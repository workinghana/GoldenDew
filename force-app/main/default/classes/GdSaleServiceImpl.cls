/**
 * implements GdSaleDepositService
 * 판매 서비스 로직 구현
 */
public with sharing class GdSaleServiceImpl implements GdSaleService {
  private enum Status {
    Draft,
    saleSuccess
  }

  /**
   * ! 보류
   * 판매 등록
   * Order insert
   */
  /*
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
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true); // 등록자

      // 판매번호(SaleNo__c) 중복 체크
      if ([SELECT COUNT() FROM Order WHERE SaleNo__c = :saleNo] > 0) {
        throw new CustomException(400, 'SaleNo__c already exists.');
      }

      List<Contact> contactList = [SELECT Id, MemberNo__c FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
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
      List<Account> storeList = [SELECT Id FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
      if (storeList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 매장 코드입니다. ' + storeCode);
      }
      Account store = storeList[0];

      // Standard Pricebook 조회
      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Order o = new Order();
      o.AccountId = company.Id;
      o.StoreCode__c = store.Id;
      o.Status = String.valueOf(Status.Draft);
      o.EffectiveDate = Date.today();
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

      Database.SaveResult insertResult = Database.insert(o);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();

      reqData.put('orderId', o.Id);
      createSaleItem(reqData); // 판매 상세 등록

      o.Status = String.valueOf(Status.saleSuccess);
      Database.SaveResult updateResult = Database.update(o);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      return ApiResult.ok(200, '판매 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  */

  /**
   * ! 보류
   * 판매 상세 등록
   * OrderItem insert
   */
  /**
  public void createSaleItem(Map<String, Object> reqData) {
    try {
      List<Object> saleItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);

      List<OrderItem> oiList = new List<OrderItem>();

      for (Object v : saleItemList) {
        Map<String, Object> saleItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String saleSeqNo = ValidationUtil.stringValidation(saleItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', true); // 판매 일련 번호
        String orderNo = ValidationUtil.stringValidation(saleItem.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호
        String productCode = ValidationUtil.stringValidation(saleItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(saleItem.get('Quantity'), 'Quantity', true); // 수량

        // Product2 조회
        List<Product2> productList = [SELECT Id FROM Product2 WHERE Product2.ProductCode = :productCode LIMIT 1];
        if (productList.isEmpty()) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

        // Standard Pricebook 조회
        Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

        // PricebookEntry 조회
        List<PricebookEntry> pricebookEntryList = [
          SELECT Id, UnitPrice, Name
          FROM PricebookEntry
          WHERE ProductCode = :productCode AND Pricebook2Id = :standardPricebookId
          LIMIT 1
        ];
        if (pricebookEntryList.isEmpty()) {
          throw new CustomException(400, '해당 PricebookEntry 가 없습니다.');
        }

        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.PricebookEntryId = pricebookEntryList[0].Id;
        oi.Quantity = quantity;
        oi.UnitPrice = pricebookEntryList[0].UnitPrice;
        oi.SaleSeqNo__c = saleSeqNo;
        oi.SaleItemNo__c = orderId + '-' + saleSeqNo; // 판매 상세 번호 (외부 ID)

        if (orderNo != null) {
          List<Order> oList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
          if (oList.isEmpty()) {
            throw new CustomException(400, '해당 주문 건이 없습니다. ' + orderNo);
          }
          oi.OrderId__c = oList[0].Id;
        }

        oiList.add(oi);
      }

      List<Database.SaveResult> resultList = Database.insert(oiList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }
      return;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  */

  /**
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

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT Id, DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c, DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c
        FROM LoyaltyLedgerTraceability
        WHERE
          CreditLoyaltyLedger.TransactionJournal.OrderId = :oList[0].Id
          AND CreditLoyaltyLedger.TransactionJournal.JournalSubType.Name = 'Purchase Accrual'
          AND ActionType = 'Debit'
      ];

      if (!lltList.isEmpty()) {
        String saleNumberList = '';
        String orderNumberList = '';
        for (LoyaltyLedgerTraceability llt : lltList) {
          if (llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
            saleNumberList += llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c + ', ';
          } else if (llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
            orderNumberList += llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c + ', ';
          }
        }
        throw new CustomException(
          400,
          '해당 판매 건은 삭제할 수 없습니다. 적립된 포인트가 존재합니다. 판매번호: ' + saleNumberList + ', 주문번호: ' + orderNumberList
        );
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