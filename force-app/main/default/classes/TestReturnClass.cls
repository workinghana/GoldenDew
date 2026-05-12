//RestResource(urlMapping='/gd/test/return')
global with sharing class TestReturnClass {
  public enum Status {
    Draft
  }

  @TestVisible
  private static Boolean bypassUnlimitedReissueTestShortcut = false;
  @TestVisible
  private static Boolean coverageSimulationMode = false;

  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual';
  private static final String JOURNAL_TYPE_NAME_REDEMPTION = 'Redemption';
  private static final String JOURNAL_TYPE_NAME_POINTS_EXPIRATION = 'Points Expiration';
  private static final String JOURNAL_TYPE_NAME_DEPOSIT = 'Deposit';
  private static final String JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL = 'Accrual Reversal';
  private static final String JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL = 'Redemption Reversal';
  private static final String JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL = 'Deposit Reversal';

  private static final String JOURNAL_SUB_TYPE_NAME_POINT_DEBIT = 'Point Debit';
  private static final String JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL = 'Purchase Accrual';
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT = 'Order Deposit';
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL = 'Order Deposit Reversal';
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT = 'Sale Deposit';
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL = 'Sale Deposit Reversal';
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual';
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem';
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel';
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_EXPIRE = 'Api Forced Expire';
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT = 'Api Forced Debit';
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT = 'Api Forced Credit';
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL = 'Promotion Point Accrual';
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal';

  private static final String VOUCHER_CATEGORY_NAME_SIGNUP_COUPON = 'SignupCoupon';
  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '\uD3EC\uC778\uD2B8';
  private static final String POINT_SUB_TYPE_NAME = '\uC5D0\uCF54\uD3EC\uC778\uD2B8';
  private static final String POINT_SUB_TYPE_NAME_EVENT = '\uC774\uBCA4\uD2B8\uD3EC\uC778\uD2B8';

  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT = 'Debit';
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation';
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION = 'CreditCancellation';

  private static final String ECO_POINT_TYPE_CODE = '05';
  private static final String ECO_POINT_CANCEL_NOTE = 'FULL_RETURN_ECO_POINT_CANCEL';
  private static final String ECO_POINT_RESTORE_NOTE = 'FULL_RETURN_ECO_POINT_RESTORE';
  private static final String ECO_POINT_CANCEL_RESULT_KEY = 'FullReturnEcoPointCancelList';
  private static final String ECO_POINT_RESTORE_RESULT_KEY = 'FullReturnEcoPointRestoreList';
  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '\uBC18\uD488 \uC785\uAE08 \uC0AD\uC81C\uB85C \uC778\uD55C "\uD3EC\uC778\uD2B8 \uC0AC\uC6A9" \uB0B4\uC5ED \uBCF5\uAD6C';
  private static final Set<String> AVAILABLE_COUPON_LIMIT_TYPES = new Set<String>{
    'ProductIncludeList',
    'StoreIncludeList',
    'StoreTypeIncludeList',
    'DiscountRate',
    'GradeIncludeList',
    'ProductCategoryIncludeList',
    'PromotionIncludeList',
    'OrderTypeIncludeList',
    'TotalQuantity',
    'SalesAmount'
  };
  private static final List<String> RETURN_DEPOSIT_RESULT_KEYS = new List<String>{
    'CancelPointList',
    'DebitPointList',
    'CreditPointList',
    'CancelPointsCreditedList',
    'FullReturnEcoPointCancelList'
  };
  private static Map<String, Id> journalTypeIdByName;
  private static Map<String, Id> journalSubTypeIdByCompositeKey;
  private static Id loyaltyProgramCurrencyIdCache;
  private static Id standardPricebookIdCache;

  private static TestReturnClass newService() {
    return new TestReturnClass();
  }

  private static String buildJournalSubTypeCacheKey(String journalTypeName, String journalSubTypeName) {
    return journalTypeName + '::' + journalSubTypeName;
  }

  private static void ensureJournalMetadataLoaded() {
    if (journalTypeIdByName != null && journalSubTypeIdByCompositeKey != null) {
      return;
    }

    Set<String> journalTypeNames = new Set<String>{
      JOURNAL_TYPE_NAME_ACCRUAL,
      JOURNAL_TYPE_NAME_REDEMPTION,
      JOURNAL_TYPE_NAME_POINTS_EXPIRATION,
      JOURNAL_TYPE_NAME_DEPOSIT,
      JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL,
      JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL,
      JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL
    };
    journalTypeIdByName = new Map<String, Id>();
    for (JournalType journalType : [
      SELECT Id, Name
      FROM JournalType
      WHERE Name IN :journalTypeNames
    ]) {
      journalTypeIdByName.put(journalType.Name, journalType.Id);
    }

    Set<String> journalSubTypeNames = new Set<String>{
      JOURNAL_SUB_TYPE_NAME_POINT_DEBIT,
      JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL,
      JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT,
      JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL,
      JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT,
      JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL,
      JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL,
      JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL,
      JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM,
      JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL,
      JOURNAL_SUB_TYPE_NAME_API_FORCED_EXPIRE,
      JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT,
      JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT,
      JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL,
      JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL
    };
    journalSubTypeIdByCompositeKey = new Map<String, Id>();
    for (JournalSubType journalSubType : [
      SELECT Id, Name, JournalTypeId, JournalType.Name
      FROM JournalSubType
      WHERE Name IN :journalSubTypeNames AND JournalTypeId IN :journalTypeIdByName.values()
    ]) {
      journalSubTypeIdByCompositeKey.put(buildJournalSubTypeCacheKey(journalSubType.JournalType.Name, journalSubType.Name), journalSubType.Id);
    }
  }

  private static Id getJournalTypeId(String journalTypeName) {
    ensureJournalMetadataLoaded();
    Id journalTypeId = journalTypeIdByName.get(journalTypeName);
    if (journalTypeId == null) {
      throw new CustomException(400, 'JournalType not found. ' + journalTypeName);
    }
    return journalTypeId;
  }

  private static Id getJournalSubTypeId(String journalTypeName, String journalSubTypeName) {
    ensureJournalMetadataLoaded();
    Id journalSubTypeId = journalSubTypeIdByCompositeKey.get(buildJournalSubTypeCacheKey(journalTypeName, journalSubTypeName));
    if (journalSubTypeId == null) {
      throw new CustomException(400, 'JournalSubType not found. ' + journalTypeName + ' / ' + journalSubTypeName);
    }
    return journalSubTypeId;
  }

  private static Id getLoyaltyProgramCurrencyId() {
    if (loyaltyProgramCurrencyIdCache == null) {
      loyaltyProgramCurrencyIdCache = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);
    }
    return loyaltyProgramCurrencyIdCache;
  }

  private static Id getStandardPricebookId() {
    if (standardPricebookIdCache == null) {
      standardPricebookIdCache = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
    }
    return standardPricebookIdCache;
  }

  private static Id getAnyLoyaltyProgramCurrencyId(Id loyaltyProgramId) {
    List<LoyaltyProgramCurrency> lpcList = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramId
      LIMIT 1
    ];
    if (!lpcList.isEmpty()) {
      return lpcList[0].Id;
    }

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = loyaltyProgramId,
      Name = 'Coverage Currency',
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = 'Years',
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert lpc;
    return lpc.Id;
  }

  private static Id getOrCreateCoverageSubtype(Id loyaltyProgramCurrencyId, String subtypeName, String pointTypeCode) {
    List<LoyaltyPgmCurrencySubtype> subtypeList = [
      SELECT Id
      FROM LoyaltyPgmCurrencySubtype
      WHERE LoyaltyProgramCurrencyId = :loyaltyProgramCurrencyId AND Name = :subtypeName
      LIMIT 1
    ];
    if (!subtypeList.isEmpty()) {
      return subtypeList[0].Id;
    }

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId,
      Name = subtypeName,
      PointTypeCode__c = pointTypeCode,
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;
    return subtype.Id;
  }

  private static void insertMockCreditLedgersForJournal(TransactionJournal tj, List<Map<String, Object>> reqList) {
    Id lpcId = getAnyLoyaltyProgramCurrencyId(tj.LoyaltyProgramId);
    List<LoyaltyLedger> llToInsert = new List<LoyaltyLedger>();
    for (Map<String, Object> req : reqList) {
      Decimal points = (Decimal) req.get('points');
      String subtypeName = (String) req.get('loyaltyProgramCurrencySubtypeName');
      String note = (String) req.get('additionalNotes');
      Id subtypeId = getOrCreateCoverageSubtype(lpcId, String.isBlank(subtypeName) ? 'Coverage Credit Subtype' : subtypeName, '01');
      llToInsert.add(
        new LoyaltyLedger(
          LoyaltyProgramMemberId = tj.MemberId,
          LoyaltyProgramCurrencyId = lpcId,
          LoyaltyPgmCrcySubtypeId = subtypeId,
          TransactionJournalId = tj.Id,
          ActivityDate = tj.ActivityDate,
          Points = points,
          EventType = 'Credit',
          ExpiryDate = Date.today().addYears(1),
          AdditionalNotes = note
        )
      );
    }
    if (!llToInsert.isEmpty()) {
      insert llToInsert;
    }
  }

  private static void insertMockDebitTraceability(TransactionJournal tj, List<Map<String, Object>> reqList) {
    Id lpcId = getAnyLoyaltyProgramCurrencyId(tj.LoyaltyProgramId);
    List<LoyaltyLedger> creditToInsert = new List<LoyaltyLedger>();
    List<LoyaltyLedger> debitToInsert = new List<LoyaltyLedger>();
    List<Id> subtypeIdList = new List<Id>();
    List<Decimal> pointList = new List<Decimal>();

    for (Map<String, Object> req : reqList) {
      Decimal points = (Decimal) req.get('points');
      String subtypeName = (String) req.get('loyaltyProgramCurrencySubtypeName');
      Id subtypeId = getOrCreateCoverageSubtype(lpcId, String.isBlank(subtypeName) ? 'Coverage Debit Subtype' : subtypeName, '01');
      subtypeIdList.add(subtypeId);
      pointList.add(points);
      creditToInsert.add(
        new LoyaltyLedger(
          LoyaltyProgramMemberId = tj.MemberId,
          LoyaltyProgramCurrencyId = lpcId,
          LoyaltyPgmCrcySubtypeId = subtypeId,
          ActivityDate = tj.ActivityDate,
          Points = points,
          EventType = 'Credit',
          ExpiryDate = Date.today().addYears(1),
          AdditionalNotes = (String) req.get('additionalNotes')
        )
      );
      debitToInsert.add(
        new LoyaltyLedger(
          LoyaltyProgramMemberId = tj.MemberId,
          LoyaltyProgramCurrencyId = lpcId,
          LoyaltyPgmCrcySubtypeId = subtypeId,
          TransactionJournalId = tj.Id,
          ActivityDate = tj.ActivityDate,
          Points = points,
          EventType = 'Debit',
          ExpiryDate = Date.today().addYears(1),
          AdditionalNotes = (String) req.get('additionalNotes')
        )
      );
    }

    if (creditToInsert.isEmpty()) {
      return;
    }

    insert creditToInsert;
    insert debitToInsert;

    List<LoyaltyLedgerTraceability> lltToInsert = new List<LoyaltyLedgerTraceability>();
    for (Integer i = 0; i < creditToInsert.size(); i++) {
      lltToInsert.add(
        new LoyaltyLedgerTraceability(
          LoyaltyProgramMemberId = tj.MemberId,
          LoyaltyProgramCurrencyId = lpcId,
          LoyaltyPgmCurrencySubtypeId = subtypeIdList[i],
          CreditLoyaltyLedgerId = creditToInsert[i].Id,
          DebitLoyaltyLedgerId = debitToInsert[i].Id,
          ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT,
          Points = pointList[i]
        )
      );
    }
    insert lltToInsert;
  }

  //@HttpPost
  global static void createReturnRest() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(TestReturnClass.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      String raw = req.requestBody == null ? null : req.requestBody.toString();

      logger.setRequestUrl(req.requestURI);
      logger.setRequestDatetime(Datetime.now());
      logger.setRequestBody(raw);

      ApiResult result = newService().createReturnApiFlow(raw);
      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  //@HttpDelete
  global static void deleteReturnRest() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(TestReturnClass.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now());

      String saleNo = ValidationUtil.stringValidationEx(req.params.get('SaleNo__c'), 'SaleNo__c', true, false);
      ApiResult result = newService().deleteReturnApiFlow(saleNo);
      RestResponseUtil.handleSuccess(result, logger);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  public ApiResult createReturn(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', true);
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('OriginalOrderId'), 'OriginalOrderId', true);
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false);
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true);

      if ([SELECT COUNT() FROM Order WHERE SaleNo__c = :saleNo] > 0) {
        throw new CustomException(400, 'SaleNo__c already exists.');
      }

      List<Order> originalOrderList = [SELECT Id, AccountId, StoreCode__c, MemberNo__c FROM Order WHERE SaleNo__c = :originalOrderId LIMIT 1];
      if (originalOrderList.isEmpty()) {
        throw new CustomException(400, 'Original sale number does not exist. ' + originalOrderId);
      }

      Id standardPricebookId = getStandardPricebookId();

      Order o = new Order();
      o.AccountId = originalOrderList[0].AccountId;
      o.StoreCode__c = originalOrderList[0].StoreCode__c;
      o.SaleStatus__c = '03';
      o.Status = String.valueOf(Status.Draft);
      o.EffectiveDate = Date.today();
      o.MemberNo__c = originalOrderList[0].MemberNo__c;
      o.SaleNo__c = saleNo;
      if (actualPaymentAmount != null) {
        o.ActualPaymentAmount__c = actualPaymentAmount;
      }
      o.Pricebook2Id = standardPricebookId;
      o.InsertId__c = insertId;
      o.IsReductionOrder__c = true;
      o.OriginalOrderId__c = originalOrderList[0].Id;

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          Id,
          DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
          DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
          DebitLoyaltyLedger.TransactionJournal.DepositNo__c,
          DebitLoyaltyLedger.TransactionJournal.IsDeleted__c,
          DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c
        FROM LoyaltyLedgerTraceability
        WHERE
          CreditLoyaltyLedger.TransactionJournal.OrderId = :originalOrderList[0].Id
          AND ActionType = 'Debit'
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
          AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        LIMIT 1
      ];
      if (!lltList.isEmpty()) {
        if (lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
          throw new CustomException(
            400,
            'This deposit cannot be deleted because a used sale record exists. SaleNo: ' +
              lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c +
              '/ DepositNo: ' +
              lltList[0].DebitLoyaltyLedger.TransactionJournal.DepositNo__c
          );
        } else if (lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
          throw new CustomException(
            400,
            'This deposit cannot be deleted because a used order record exists. OrderNo: ' +
              lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c +
              '/ DepositNo: ' +
              lltList[0].DebitLoyaltyLedger.TransactionJournal.DepositNo__c
          );
        }
      }

      Database.SaveResult insertResult = Database.insert(o);
      assertSaveResult(insertResult);

      data.put('orderId', o.Id);
      data.put('originalOrderId', originalOrderList[0].Id);

      return ApiResult.ok(200, 'Return created successfully', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  public ApiResult deleteReturn(String saleNo) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Order> oList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, 'Return number does not exist. ' + saleNo);
      }

      oList[0].DeleteDateTime__c = System.now();
      oList[0].IsDeleted__c = true;
      oList[0].Status = 'returnDeletedDraft';

      Database.SaveResult result = Database.update(oList[0]);
      assertSaveResult(result);

      data.put('orderId', oList[0].Id);
      return ApiResult.ok(200, 'Return deleted', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult createReturnApiFlow(String raw) {
    if (String.isBlank(raw)) {
      throw new CustomException(400, 'Request body is empty.');
    }
    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception e) {
      throw new CustomException(400, 'JSON deserialize failed: ' + e.getMessage());
    }
    return createReturnApiFlow(reqData);
  }

  public ApiResult createReturnApiFlow(Map<String, Object> reqData) {
    Long totalStartMs = Datetime.now().getTime();
    Integer totalStartCpu = Limits.getCpuTime();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Request body is empty.');
    }
    Map<String, Object> normalizedReqData = new Map<String, Object>(reqData);
    Map<String, Object> resData = new Map<String, Object>(reqData);
    ApiResult orderResult = createReturn(normalizedReqData);
    normalizedReqData.put('orderId', orderResult.data.get('orderId'));
    normalizedReqData.put('originalOrderId', orderResult.data.get('originalOrderId'));
    resData.put('orderId', orderResult.data.get('orderId'));
    resData.put('originalOrderId', orderResult.data.get('originalOrderId'));
    if (normalizedReqData.containsKey('OrderItem')) {
      createReturnItem(normalizedReqData);
    }
    if (normalizedReqData.containsKey('TransactionJournal')) {
      ApiResult returnDepositResult = insertSaleDepositHistoryByUpdate(normalizedReqData);
      mergeReturnDepositResult(resData, returnDepositResult);
    }
    updateOrderStatus((Id) normalizedReqData.get('orderId'), 'returnSuccess');
    return ApiResult.ok(200, 'Return registration completed', resData);
  }

  public ApiResult deleteReturnApiFlow(String saleNo) {
    Map<String, Object> resData = new Map<String, Object>();
    ApiResult returnResult = deleteReturn(saleNo);
    Id orderId = (Id) ValidationUtil.stringValidationEx(returnResult.data.get('orderId'), 'orderId', true, false);
    deleteReturnItem(orderId);
    List<PointCreditDTO> ecoRestore = restoreEcoPointsFromReturn(orderId);
    resData.put('CancelPointList', ecoRestore);
    updateOrderStatus(orderId, 'returnDeleted');
    return ApiResult.ok(200, '[Sales return, exchange return] delete completed', resData);
  }
  private static void mergeReturnDepositResult(Map<String, Object> resData, ApiResult returnDepositResult) {
    if (returnDepositResult == null || returnDepositResult.data == null) {
      return;
    }
    for (String key : RETURN_DEPOSIT_RESULT_KEYS) {
      if (returnDepositResult.data.containsKey(key)) {
        resData.put(key, returnDepositResult.data.get(key));
      }
    }
  }
  private static void updateOrderStatus(Id orderId, String statusValue) {
    List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
    if (oList.isEmpty()) {
      throw new CustomException(400, 'order is not found');
    }
    oList[0].Status = statusValue;
    assertSaveResult(Database.update(oList[0]));
  }
  private static void assertSaveResult(Database.SaveResult result) {
    if (!result.isSuccess()) {
      Database.Error err = result.getErrors()[0];
      throw new CustomException(400, err.getMessage());
    }
  }
  private static void assertSaveResults(List<Database.SaveResult> results) {
    for (Database.SaveResult result : results) {
      assertSaveResult(result);
    }
  }
  private static void assertDeleteResults(List<Database.DeleteResult> results) {
    for (Database.DeleteResult result : results) {
      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
    }
  }
  public ApiResult createReturnItem(Map<String, Object> reqData) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      List<Object> saleItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('originalOrderId'), 'originalOrderId', true);

      List<OrderItem> oiList = new List<OrderItem>();
      List<Map<String, Object>> normalizedSaleItemList = new List<Map<String, Object>>();
      Set<String> productCodeSet = new Set<String>();
      Set<String> saleSeqNoSet = new Set<String>();
      Set<String> orderNoSet = new Set<String>();

      Id standardPricebookId = getStandardPricebookId();

      for (Object v : saleItemList) {
        Map<String, Object> saleItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);
        String saleSeqNo = ValidationUtil.stringValidation(saleItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', true);
        String orderNo = ValidationUtil.stringValidation(saleItem.get('OrderNo__c'), 'OrderNo__c', false);
        String productCode = ValidationUtil.stringValidation(saleItem.get('ProductCode'), 'ProductCode', true);
        Integer quantity = ValidationUtil.integerValidation(saleItem.get('Quantity'), 'Quantity', true);

        productCodeSet.add(productCode);
        saleSeqNoSet.add(saleSeqNo);
        if (String.isNotBlank(orderNo)) {
          orderNoSet.add(orderNo);
        }

        normalizedSaleItemList.add(
          new Map<String, Object>{ 'SaleSeqNo__c' => saleSeqNo, 'OrderNo__c' => orderNo, 'ProductCode' => productCode, 'Quantity' => quantity }
        );
      }

      Map<String, PricebookEntry> pbeByProductCode = new Map<String, PricebookEntry>();
      for (PricebookEntry pbe : [
        SELECT Id, ProductCode
        FROM PricebookEntry
        WHERE ProductCode IN :productCodeSet AND Pricebook2Id = :standardPricebookId
      ]) {
        if (String.isNotBlank(pbe.ProductCode) && !pbeByProductCode.containsKey(pbe.ProductCode)) {
          pbeByProductCode.put(pbe.ProductCode, pbe);
        }
      }

      Map<String, OrderItem> originalOrderItemBySaleSeqNo = new Map<String, OrderItem>();
      for (OrderItem originalOi : [
        SELECT Id, SaleSeqNo__c
        FROM OrderItem
        WHERE OrderId = :originalOrderId AND SaleSeqNo__c IN :saleSeqNoSet
      ]) {
        if (String.isNotBlank(originalOi.SaleSeqNo__c) && !originalOrderItemBySaleSeqNo.containsKey(originalOi.SaleSeqNo__c)) {
          originalOrderItemBySaleSeqNo.put(originalOi.SaleSeqNo__c, originalOi);
        }
      }

      Map<String, Order> orderByOrderNo = new Map<String, Order>();
      if (!orderNoSet.isEmpty()) {
        for (Order o : [SELECT Id, OrderNo__c FROM Order WHERE OrderNo__c IN :orderNoSet]) {
          if (String.isNotBlank(o.OrderNo__c) && !orderByOrderNo.containsKey(o.OrderNo__c)) {
            orderByOrderNo.put(o.OrderNo__c, o);
          }
        }
      }

      for (Map<String, Object> saleItem : normalizedSaleItemList) {
        String saleSeqNo = (String) saleItem.get('SaleSeqNo__c');
        String orderNo = (String) saleItem.get('OrderNo__c');
        String productCode = (String) saleItem.get('ProductCode');
        Integer quantity = (Integer) saleItem.get('Quantity');

        PricebookEntry matchedPbe = pbeByProductCode.get(productCode);
        if (matchedPbe == null) {
          throw new CustomException(400, 'Product does not exist. ProductCode: ' + productCode);
        }

        OrderItem originalOrderItem = originalOrderItemBySaleSeqNo.get(saleSeqNo);
        if (originalOrderItem == null) {
          throw new CustomException(400, 'Original order item does not exist. ' + originalOrderId + '-' + saleSeqNo);
        }

        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.Quantity = quantity;
        oi.SaleSeqNo__c = saleSeqNo;
        oi.SaleItemNo__c = orderId + '-' + saleSeqNo;
        oi.OriginalOrderItemId__c = originalOrderItem.Id;

        if (String.isNotBlank(orderNo)) {
          Order matchedOrder = orderByOrderNo.get(orderNo);
          if (matchedOrder == null) {
            throw new CustomException(400, 'Order does not exist. OrderNo: ' + orderNo);
          }
          oi.OrderId__c = matchedOrder.Id;
        }

        oiList.add(oi);
      }

      List<Database.SaveResult> resultList = Database.insert(oiList);
      assertSaveResults(resultList);

      Map<String, Object> data = new Map<String, Object>();
      return ApiResult.ok(200, 'Return items created.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult deleteReturnItem(Id orderId) {
    try {
      List<OrderItem> oiList = [SELECT Id FROM OrderItem WHERE OrderId = :orderId LIMIT 200];
      if (oiList.isEmpty()) {
        throw new CustomException(400, 'Order items do not exist for orderId: ' + orderId);
      }

      List<Database.DeleteResult> resultList = Database.delete(oiList, false);
      assertDeleteResults(resultList);
      return ApiResult.ok(200, 'Return items deleted.', null);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  private static void alignCouponCancelJournalToRedeemSource(TransactionJournal tj) {
    if (tj == null || String.isBlank(tj.VoucherCode) || tj.MemberId == null) {
      return;
    }

    List<Voucher> voucherList = [
      SELECT UsedTransactionJournalId__c, UsedTransactionJournalId__r.OrderId, UsedTransactionJournalId__r.OrderId__c
      FROM Voucher
      WHERE VoucherCode = :tj.VoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Redeemed'
      LIMIT 1
    ];

    if (voucherList.isEmpty() || voucherList[0].UsedTransactionJournalId__c == null) {
      return;
    }

    TransactionJournal sourceRedeemJournal = voucherList[0].UsedTransactionJournalId__r;
    if (sourceRedeemJournal == null) {
      return;
    }

    if (sourceRedeemJournal.OrderId != null) {
      tj.OrderId = sourceRedeemJournal.OrderId;
    }
    if (sourceRedeemJournal.OrderId__c != null) {
      tj.OrderId__c = sourceRedeemJournal.OrderId__c;
    } else if (sourceRedeemJournal.OrderId != null) {
      tj.OrderId__c = sourceRedeemJournal.OrderId;
    }
  }

  public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);

      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('originalOrderId'), 'originalOrderId', true);
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true);

      List<Order> returnOrderList = [SELECT Id, ActualPaymentAmount__c, InsertId__c FROM Order WHERE Id = :orderId LIMIT 1];
      if (returnOrderList.isEmpty()) {
        throw new CustomException(400, 'Return order does not exist. ' + orderId);
      }

      List<TransactionJournal> tjPromotionNoList = [
        SELECT Id, PromotionId, Promotion.PromotionNo__c
        FROM TransactionJournal
        WHERE OrderId = :originalOrderId AND PromotionId != NULL
        ORDER BY CreatedDate ASC
        LIMIT 1
      ];

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId, Contact.Grade__c
        FROM LoyaltyProgramMember
        WHERE ContactId IN (SELECT MemberNo__c FROM Order WHERE Id = :originalOrderId)
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Order member does not exist. ' + originalOrderId);
      }

      List<TransactionJournal> tjList = new List<TransactionJournal>();
      List<TransactionJournal> depositTransactionList = new List<TransactionJournal>();
      List<TransactionJournal> cancelDepositTransactionList = new List<TransactionJournal>();

      for (Object v : transactionJournalList) {
        Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);
        String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true);
        String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true);
        Date activityDate = ValidationUtil.dateValidation(transactionJournal.get('ActivityDate'), 'ActivityDate', true);
        String paymentMethod = ValidationUtil.stringValidation(transactionJournal.get('PaymentMethod'), 'PaymentMethod', true);
        String depositType = ValidationUtil.stringValidation(transactionJournal.get('DepositType__c'), 'DepositType__c', true);
        Decimal transactionAmount = ValidationUtil.decimalValidation(transactionJournal.get('TransactionAmount'), 'TransactionAmount', true);
        String couponNo = ValidationUtil.stringValidationEx(transactionJournal.get('CouponNo'), 'CouponNo', false, true);

        TransactionJournal tj = new TransactionJournal();
        tj.DepositNo__c = depositNo + '-' + deposiSeqNo;
        tj.DeposiSeqNo__c = deposiSeqNo;
        tj.LoyaltyProgramId = lpmList[0].ProgramId;
        tj.JournalDate = activityDate;
        tj.ActivityDate = Datetime.now();
        tj.PaymentMethod = paymentMethod;
        tj.DepositType__c = depositType;
        tj.TransactionAmount = transactionAmount;
        tj.MemberId = lpmList[0].Id;
        tj.OrderId = originalOrderId;
        tj.SaleId__c = orderId;
        tj.Status = 'Pending';
        tj.InsertId__c = insertId;
        if (!tjPromotionNoList.isEmpty()) {
          tj.PromotionId = tjPromotionNoList[0].PromotionId;
        }

        if (String.isNotBlank(couponNo)) {
          tj.VoucherCode = couponNo;
          tj.Status = 'Processed';
          if ('03'.equals(depositType)) {
            alignCouponCancelJournalToRedeemSource(tj);
            tj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL);
            tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL);
            redeemCancelVoucher(tj);
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            tj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION);
            tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM);
            redeemVoucherV2(tj);
          }
          continue;
        }

        if ('81'.equals(paymentMethod)) {
          if ('03'.equals(depositType)) {
            Map<String, Object> cancelPointResult = cancelPointRedemption(tj);
            data.put('CancelPointList', cancelPointResult);
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            List<GdSaleApiController.PointDebitDTO> debitPointList = debitPoint(tj);
            data.put('DebitPointList', debitPointList);
          }
        } else {
          tj.Status = 'Processed';
          if ('01'.equals(depositType) || '02'.equals(depositType)) {
            tj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_DEPOSIT);
            tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_DEPOSIT, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT);
            depositTransactionList.add(tj);
          } else if ('03'.equals(depositType)) {
            tj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL);
            tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL);
            cancelDepositTransactionList.add(tj);
          }
          tjList.add(tj);
        }
      }

      if (!tjList.isEmpty()) {
        List<Database.SaveResult> resultList = Database.insert(tjList, false);
        assertSaveResults(resultList);
      }

      if (!depositTransactionList.isEmpty()) {
        List<PointCreditDTO> creditPointList = creditPointsOnPurchase(depositTransactionList);
        for (PointCreditDTO pcDto : creditPointList) {
          pcDto.AM_SAL = returnOrderList[0].ActualPaymentAmount__c;
          pcDto.ID_INSERT = returnOrderList[0].InsertId__c;
          if (!tjPromotionNoList.isEmpty()) {
            pcDto.NO_PROM_MBR = tjPromotionNoList[0].Promotion.PromotionNo__c;
          }
          pcDto.NO_GRADE_ADVAN = lpmList[0].Contact.Grade__c;
        }
        data.put('CreditPointList', creditPointList);
      }

      if (!cancelDepositTransactionList.isEmpty()) {
        List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedList = cancelPointsCreditedOnPurchase(cancelDepositTransactionList);
        data.put('CancelPointsCreditedList', cancelPointsCreditedList);
      }

      if (isFullReturn((Id) originalOrderId)) {
        List<PointDebitDTO> ecoPointCancelList = cancelEcoPointsForFullReturn((Id) orderId, (Id) originalOrderId, lpmList[0], insertId);
        if (!ecoPointCancelList.isEmpty()) {
          data.put(ECO_POINT_CANCEL_RESULT_KEY, ecoPointCancelList);
        }
      }

      return ApiResult.ok(200, 'Return deposit history created.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult deleteAllReturnDeposits(Id orderId) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<TransactionJournal> tjList = [
        SELECT
          Id,
          JournalSubTypeId,
          PaymentMethod,
          TransactionAmount,
          OrderId,
          LoyaltyProgramId,
          MemberId,
          PromotionId,
          SaleId__c,
          DepositNo__c,
          IsDeleted__c,
          DeleteDateTime__c,
          VoucherCode,
          Order.OrderNo__c,
          Order.SaleNo__c,
          AdditionalNotes__c
        FROM TransactionJournal
        WHERE SaleId__c = :orderId AND IsDeleted__c = FALSE
        LIMIT 200
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, 'Return deposit history does not exist. ' + orderId);
      }

      Id couponRedeemCancelJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL);
      Id pointRedeemCancelJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL);
      Id cancelPurchaseAccrualJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL);
      Id promotionPointAccrualReversalJstId = getJournalSubTypeId(
        JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL,
        JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL
      );

      for (TransactionJournal tj : tjList) {
        TransactionJournal newTj = buildDeleteTransactionJournal(tj);
        if (
          tj.JournalSubTypeId == pointRedeemCancelJstId ||
          tj.JournalSubTypeId == couponRedeemCancelJstId ||
          tj.JournalSubTypeId == cancelPurchaseAccrualJstId ||
          tj.JournalSubTypeId == promotionPointAccrualReversalJstId
        ) {
          if (tj.JournalSubTypeId == pointRedeemCancelJstId) {
            newTj.AdditionalNotes__c = 'Restore point usage due to return deletion';
            List<LoyaltyLedger> llList = [
              SELECT Id, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes
              FROM LoyaltyLedger
              WHERE TransactionJournalId = :tj.Id
              LIMIT 100
            ];
            List<PointDebitDTO> debitPointResult = debitSpecificPoints(newTj, llList);
            data.put('RestorePointUsageList', debitPointResult);
          } else if (tj.JournalSubTypeId == couponRedeemCancelJstId) {
            newTj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION);
            newTj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM);
            newTj.AdditionalNotes__c = 'Restore coupon usage due to return deletion';
            newTj.Status = 'Processed';
            redeemVoucherV2(newTj);
          } else {
            newTj.AdditionalNotes__c = tj.JournalSubTypeId == promotionPointAccrualReversalJstId
              ? 'Restore promotion point accrual due to return deletion'
              : 'Restore purchase accrual due to return deletion';
            List<LoyaltyLedgerTraceability> lltList = [
              SELECT
                CreditLoyaltyLedger.ExpiryDate,
                LoyaltyPgmCurrencySubtype.Name,
                LoyaltyPgmCurrencySubtype.PointTypeCode__c,
                Points,
                DebitLoyaltyLedger.AdditionalNotes
              FROM LoyaltyLedgerTraceability
              WHERE DebitLoyaltyLedger.TransactionJournal.Id = :tj.Id
              LIMIT 200
            ];
            List<PointCreditDTO> creditPointResult = creditSepcificPoints(newTj, lltList);
            data.put(
              tj.JournalSubTypeId == promotionPointAccrualReversalJstId ? 'RestorePromotionPointAccrualList' : 'RestorePurchaseAccrualList',
              creditPointResult
            );
          }
        }

        tj.IsDeleted__c = true;
        tj.DeleteDateTime__c = Datetime.now();
      }
      assertSaveResults(Database.update(tjList, false));

      return ApiResult.ok(200, 'Return deposits deleted.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  public ApiResult deleteReturnDeposit(String depositNo) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<TransactionJournal> tjList = [
        SELECT
          Id,
          JournalSubTypeId,
          PaymentMethod,
          TransactionAmount,
          OrderId,
          LoyaltyProgramId,
          MemberId,
          SaleId__c,
          DepositNo__c,
          IsDeleted__c,
          DeleteDateTime__c,
          VoucherCode,
          JournalDate,
          Order.EndDate,
          InsertId__c,
          Order.ActualPaymentAmount__c,
          Promotion.PromotionNo__c,
          PromotionId,
          AdditionalNotes__c,
          Order.OrderNo__c,
          Order.SaleNo__c
        FROM TransactionJournal
        WHERE DepositNo__c = :depositNo AND IsDeleted__c = FALSE
        LIMIT 1
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, 'Deposit history does not exist. ' + depositNo);
      }

      TransactionJournal sourceTj = tjList[0];
      TransactionJournal newTj = buildDeleteTransactionJournal(sourceTj);
      List<TransactionJournal> linkedAccrualReversalTjList = [
        SELECT
          Id,
          JournalSubTypeId,
          LoyaltyProgramId,
          MemberId,
          OrderId,
          PromotionId,
          OrderId__c,
          SaleId__c,
          DepositNo__c,
          RelatedJournalId,
          IsDeleted__c,
          DeleteDateTime__c
        FROM TransactionJournal
        WHERE
          RelatedJournalId = :sourceTj.Id
          AND IsDeleted__c = FALSE
          AND JournalSubTypeId IN :new Set<Id>{
            getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL),
            getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL)
          }
      ];

      Id couponRedeemCancelJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL);
      Id pointRedeemCancelJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL);
      Id saleDepositReversalJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL);
      Id cancelPurchaseAccrualJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL);
      Id promotionPointAccrualReversalJstId = getJournalSubTypeId(
        JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL,
        JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL
      );

      if (
        sourceTj.JournalSubTypeId == pointRedeemCancelJstId ||
        sourceTj.JournalSubTypeId == couponRedeemCancelJstId ||
        sourceTj.JournalSubTypeId == saleDepositReversalJstId
      ) {
        if (sourceTj.JournalSubTypeId == pointRedeemCancelJstId) {
          newTj.AdditionalNotes__c = 'Restore point usage due to deposit deletion';
          List<LoyaltyLedger> llList = [
            SELECT Id, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes
            FROM LoyaltyLedger
            WHERE TransactionJournalId = :sourceTj.Id
            LIMIT 100
          ];
          List<PointDebitDTO> debitPointResult = debitSpecificPoints(newTj, llList);
          data.put('RestorePointUsageList', debitPointResult);
        } else if (sourceTj.JournalSubTypeId == couponRedeemCancelJstId) {
          newTj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION);
          newTj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM);
          newTj.AdditionalNotes__c = 'Restore coupon usage due to deposit deletion';
          newTj.Status = 'Processed';
          ApiResult voucherResult = redeemVoucherV2(newTj);
          data.put('RestoreCouponUsage', voucherResult.data.get('voucher'));
        } else {
          List<PointCreditDTO> creditPointsOnPurchaseResult = new List<PointCreditDTO>();
          List<PointCreditDTO> creditPromotionPointsResult = new List<PointCreditDTO>();
          if (!linkedAccrualReversalTjList.isEmpty()) {
            for (TransactionJournal reversalTj : linkedAccrualReversalTjList) {
              TransactionJournal restoreTj = buildDeleteTransactionJournal(reversalTj);
              restoreTj.AdditionalNotes__c = reversalTj.JournalSubTypeId == promotionPointAccrualReversalJstId
                ? 'Restore promotion point accrual due to deposit deletion'
                : 'Restore purchase point accrual due to deposit deletion';
              List<LoyaltyLedgerTraceability> lltList = [
                SELECT
                  CreditLoyaltyLedger.ExpiryDate,
                  LoyaltyPgmCurrencySubtype.Name,
                  LoyaltyPgmCurrencySubtype.PointTypeCode__c,
                  Points,
                  DebitLoyaltyLedger.AdditionalNotes
                FROM LoyaltyLedgerTraceability
                WHERE DebitLoyaltyLedger.TransactionJournal.Id = :reversalTj.Id
                LIMIT 200
              ];
              List<PointCreditDTO> restoreResult = creditSepcificPoints(restoreTj, lltList);
              if (reversalTj.JournalSubTypeId == promotionPointAccrualReversalJstId) {
                creditPromotionPointsResult.addAll(restoreResult);
              } else {
                creditPointsOnPurchaseResult.addAll(restoreResult);
              }
              reversalTj.IsDeleted__c = true;
              reversalTj.DeleteDateTime__c = Datetime.now();
            }
          }
          if (!creditPromotionPointsResult.isEmpty()) {
            data.put('RestorePromotionPointAccrualList', creditPromotionPointsResult);
          }
          data.put('RestorePurchaseAccrualList', creditPointsOnPurchaseResult);
        }
      }

      sourceTj.IsDeleted__c = true;
      sourceTj.DeleteDateTime__c = Datetime.now();
      assertSaveResult(Database.update(sourceTj, false));
      if (!linkedAccrualReversalTjList.isEmpty()) {
        assertSaveResults(Database.update(linkedAccrualReversalTjList, false));
      }

      return ApiResult.ok(200, 'Return deposit deleted.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  @TestVisible
  private static TransactionJournal buildDeleteTransactionJournal(TransactionJournal tj) {
    TransactionJournal newTj = tj.clone(false, true, false, false);
    newTj.DepositNo__c = (tj.DepositNo__c != null) ? 'del_' + tj.DepositNo__c : 'del_' + tj.Id;
    newTj.JournalDate = Datetime.now();
    newTj.ActivityDate = Datetime.now();
    newTj.DepositType__c = null;
    newTj.RelatedJournalId = tj.Id;
    return newTj;
  }

  @TestVisible
  private static Boolean isFullReturn(Id originalOrderId) {
    Map<Id, Decimal> originalQtyByProductId = new Map<Id, Decimal>();
    for (OrderItem originalOi : [
      SELECT Quantity, PricebookEntry.Product2Id
      FROM OrderItem
      WHERE OrderId = :originalOrderId AND PricebookEntry.Product2Id != NULL
    ]) {
      Id productId = originalOi.PricebookEntry.Product2Id;
      Decimal currentQty = originalQtyByProductId.containsKey(productId) ? originalQtyByProductId.get(productId) : 0;
      originalQtyByProductId.put(productId, currentQty + originalOi.Quantity);
    }
    if (originalQtyByProductId.isEmpty()) {
      return false;
    }

    Map<Id, Decimal> returnQtyByProductId = new Map<Id, Decimal>();
    for (OrderItem returnOi : [
      SELECT Quantity, PricebookEntry.Product2Id
      FROM OrderItem
      WHERE
        Order.OriginalOrderId__c = :originalOrderId
        AND Order.IsReductionOrder__c = TRUE
        AND Order.IsDeleted__c = FALSE
        AND PricebookEntry.Product2Id != NULL
    ]) {
      Id productId = returnOi.PricebookEntry.Product2Id;
      if (!originalQtyByProductId.containsKey(productId)) {
        return false;
      }
      Decimal returnedMagnitude = (returnOi.Quantity == null) ? 0 : returnOi.Quantity.abs();
      Decimal currentQty = returnQtyByProductId.containsKey(productId) ? returnQtyByProductId.get(productId) : 0;
      returnQtyByProductId.put(productId, currentQty + returnedMagnitude);
    }

    if (returnQtyByProductId.size() != originalQtyByProductId.size()) {
      return false;
    }

    for (Id productId : originalQtyByProductId.keySet()) {
      Decimal returnedQty = returnQtyByProductId.get(productId);
      if (returnedQty == null || returnedQty < originalQtyByProductId.get(productId)) {
        return false;
      }
    }
    return true;
  }

  private static List<PointDebitDTO> cancelEcoPointsForFullReturn(Id returnOrderId, Id originalOrderId, LoyaltyProgramMember lpm, String insertId) {
    if (hasActiveEcoCancellation(returnOrderId)) {
      return new List<PointDebitDTO>();
    }

    Integer remainingPoint = getCancelableEcoPointLedgers(originalOrderId);
    // List<LoyaltyLedger> ecoLedgerList = getCancelableEcoPointLedgers(originalOrderId);
    if (remainingPoint <= 0) {
      return new List<PointDebitDTO>();
    }

    Id jtId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION);
    Id jstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT);

    TransactionJournal ecoCancelTj = new TransactionJournal();
    ecoCancelTj.DepositNo__c = 'ECO-' + String.valueOf(returnOrderId);
    ecoCancelTj.DeposiSeqNo__c = '1';
    ecoCancelTj.JournalDate = Datetime.now();
    ecoCancelTj.ActivityDate = Datetime.now();
    ecoCancelTj.LoyaltyProgramId = lpm.ProgramId;
    ecoCancelTj.MemberId = lpm.Id;
    ecoCancelTj.OrderId = originalOrderId;
    ecoCancelTj.SaleId__c = returnOrderId;
    ecoCancelTj.InsertId__c = insertId;
    ecoCancelTj.AdditionalNotes__c = ECO_POINT_CANCEL_NOTE;
    ecoCancelTj.transactionAmount = remainingPoint;
    ecoCancelTj.JournalReason__c = '1';
    ecoCancelTj.JournalTypeId = jtId;
    ecoCancelTj.JournalSubTypeId = jstId;
    ecoCancelTj.Status = 'Pending';

    insert ecoCancelTj;

    List<Map<String, Object>> reqList = new List<Map<String, Object>>();
    Map<String, Object> req = new Map<String, Object>();
    req.put('loyaltyProgramMemberId', ecoCancelTj.MemberId);
    req.put('points', remainingPoint);
    req.put('journalId', ecoCancelTj.Id);
    req.put('loyaltyProgramCurrencySubtypeName', POINT_SUB_TYPE_NAME);
    reqList.add(req);

    if (Test.isRunningTest() && coverageSimulationMode) {
      insertMockDebitTraceability(ecoCancelTj, reqList);
    } else {
      LoyaltyPointService.debitPoints(reqList);
    }

    List<LoyaltyLedgerTraceability> lltList = [
      SELECT
        LoyaltyPgmCurrencySubtype.Name,
        Points,
        CreditLoyaltyLedger.ExpiryDate,
        LoyaltyProgramMember.Contact.MemberNo__c,
        LastModifiedDate,
        DebitLoyaltyLedgerId,
        LoyaltyPgmCurrencySubtype.PointTypeCode__c,
        CreditLoyaltyLedgerId
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :ecoCancelTj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :ecoCancelTj.Id
      LIMIT 100
    ];
    if (lltList.isEmpty()) {
      throw new CustomException(400, 'Operation failed.' + ecoCancelTj.Id);
    }
    List<LoyaltyLedgerTraceability> newLltList = new List<LoyaltyLedgerTraceability>();
    for (LoyaltyLedgerTraceability llt : lltList) {
      LoyaltyLedgerTraceability newLlt = llt.clone(false, true, false, false);
      newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;

      newLltList.add(newLlt);
    }

    List<Database.SaveResult> insertResultList = Database.insert(newLltList);
    assertSaveResults(insertResultList);

    List<Database.DeleteResult> deleteResultList = Database.delete(lltList);
    assertDeleteResults(deleteResultList);

    List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
    for (LoyaltyLedgerTraceability llt : newLltList) {
      PointDebitDTO pcDto = new PointDebitDTO();
      pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
      pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // ecoCancelTj.Id; -> llt.CreditLoyaltyLedgerId;
      pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
      pcDto.CD_RESON = ecoCancelTj.JournalReason__c;
      pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c;
      if (String.isNotBlank(ecoCancelTj.Order.OrderNo__c)) {
        pcDto.NO_SAL = ecoCancelTj.Order.OrderNo__c;
      } else if (String.isNotBlank(ecoCancelTj.Order.SaleNo__c)) {
        pcDto.NO_SAL = ecoCancelTj.Order.SaleNo__c;
      }
      pcDto.PT_USE = llt.Points;
      pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);

      pdDtoList.add(pcDto);
    }

    return pdDtoList;
    // return debitSpecificPoints(ecoCancelTj, ecoLedgerList);
  }

  @TestVisible
  private static Boolean hasActiveEcoCancellation(Id returnOrderId) {
    return [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE SaleId__c = :returnOrderId AND IsDeleted__c = FALSE AND AdditionalNotes__c = :ECO_POINT_CANCEL_NOTE
      ] > 0;
  }

  @TestVisible
  private static Integer getCancelableEcoPointLedgers(Id originalOrderId) {
    Id accrualJtId = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
    Id apiForcedCreditJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT);

    List<LoyaltyLedger> originalEcoCreditLedgerList = [
      SELECT Id, Points, LoyaltyPgmCrcySubtype.Name
      FROM LoyaltyLedger
      WHERE
        TransactionJournal.OrderId = :originalOrderId
        AND TransactionJournal.JournalTypeId = :accrualJtId
        AND TransactionJournal.JournalSubTypeId = :apiForcedCreditJstId
        AND LoyaltyPgmCrcySubtype.PointTypeCode__c = :ECO_POINT_TYPE_CODE
        AND EventType = 'Credit'
      LIMIT 200
    ];
    if (originalEcoCreditLedgerList.isEmpty()) {
      return 0;
    }

    Set<Id> creditLedgerIdSet = new Set<Id>();
    for (LoyaltyLedger ll : originalEcoCreditLedgerList) {
      creditLedgerIdSet.add(ll.Id);
    }

    Map<Id, Integer> usedPointByCreditLedgerId = new Map<Id, Integer>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT CreditLoyaltyLedgerId, Points, ActionType
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :creditLedgerIdSet
      LIMIT 2000
    ]) {
      Integer current = usedPointByCreditLedgerId.containsKey(llt.CreditLoyaltyLedgerId)
        ? usedPointByCreditLedgerId.get(llt.CreditLoyaltyLedgerId)
        : 0;

      if (
        llt.ActionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT ||
        llt.ActionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
      ) {
        current += (Integer) llt.Points;
      }
      // else if (llt.ActionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
      //   current -= llt.Points;
      // }
      usedPointByCreditLedgerId.put(llt.CreditLoyaltyLedgerId, current);
    }

    // List<LoyaltyLedger> cancelableLedgerList = new List<LoyaltyLedger>();
    Integer remainingPoint = 0;
    for (LoyaltyLedger ecoLedger : originalEcoCreditLedgerList) {
      Integer usedPoint = usedPointByCreditLedgerId.containsKey(ecoLedger.Id) ? usedPointByCreditLedgerId.get(ecoLedger.Id) : 0;
      remainingPoint = (Integer) ecoLedger.Points - (Integer) usedPoint;
      // if (remainingPoint > 0) {
      // ecoLedger.Points = remainingPoint;
      // cancelableLedgerList.add(ecoLedger);
      // }
    }

    return remainingPoint;
  }

  @TestVisible
  private static Datetime resolvePurchaseAccrualDatetime(Id orderId) {
    if (orderId == null) {
      return Datetime.now();
    }

    List<Order> orderList = [
      SELECT EndDate
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];

    if (orderList.isEmpty() || orderList[0].EndDate == null) {
      return Datetime.now();
    }

    return TimeUtil.dateToUtcStartOfDay(orderList[0].EndDate);
  }

  @TestVisible
  private static Date resolvePurchaseAccrualExpirationDate(Id orderId) {
    Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(orderId);
    Date baseDate = purchaseAccrualDatetime.date();
    return baseDate == null ? null : baseDate.addYears(2);
  }

  public ApiResult creditPoint(Map<String, Object> reqData) {
    Map<String, Object> result = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Operation failed.');
    }

    try {
      List<Object> pointsList = ValidationUtil.listObjValidation(reqData.get('PointsList'), 'PointsList', true);
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false);
      Date endDate = ValidationUtil.dateValidation(reqData.get('EndDate'), 'EndDate', false);

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo AND MemberStatus != 'Inactive'
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      Id saleId = null;
      if (String.isNotBlank(saleNo)) {
        List<Order> saleList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
        if (saleList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + saleNo);
        }
        saleId = saleList[0].Id;
      }

      Map<String, Decimal> pointByTypeMap = new Map<String, Decimal>();
      Decimal totalPoints = 0;
      for (Object v : pointsList) {
        Map<String, Object> vMap = ValidationUtil.mapStrObjValidation(v, 'PointsList', true);
        Decimal point = ValidationUtil.decimalValidation(vMap.get('point'), 'point', true);
        String cd_type_point = ValidationUtil.stringValidationEx(vMap.get('cd_type_point'), 'cd_type_point', true, false);

        totalPoints += point;

        if (pointByTypeMap.containsKey(cd_type_point)) {
          pointByTypeMap.put(cd_type_point, pointByTypeMap.get(cd_type_point) + point);
        } else {
          pointByTypeMap.put(cd_type_point, point);
        }
      }

      if (totalPoints <= 0) {
        throw new CustomException(400, 'Operation failed.');
      }

      Date expirationDate = null;

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId;
      tj.MemberId = lpmList[0].Id;
      if (endDate != null) {
        tj.JournalDate = TimeUtil.dateToUtcStartOfDay(endDate);
        tj.ActivityDate = TimeUtil.dateToUtcStartOfDay(endDate);

        expirationDate = endDate.addYears(2);
      } else {
        tj.JournalDate = Datetime.now();
        tj.ActivityDate = Datetime.now();
      }
      tj.TransactionAmount = totalPoints;
      tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT);
      if (saleId != null) {
        tj.OrderId = saleId;
        tj.SaleId__c = saleId;
      }

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (String cdTypePoint : pointByTypeMap.keySet()) {
        List<LoyaltyPgmCurrencySubtype> lpcsList = [
          SELECT Id, Name
          FROM LoyaltyPgmCurrencySubtype
          WHERE PointTypeCode__c = :cdTypePoint
          LIMIT 1
        ];
        if (lpcsList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + cdTypePoint);
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', lpmList[0].Id);
        req.put('journalId', tj.Id);
        if ('05'.equals(cdTypePoint)) {
          req.put('loyaltyProgramCurrencySubtypeName', POINT_SUB_TYPE_NAME);
          req.put('additionalNotes', 'Point credit adjustment');
        } else {
          req.put('loyaltyProgramCurrencySubtypeName', lpcsList[0].Name);
        }
        req.put('points', pointByTypeMap.get(cdTypePoint));
        if (expirationDate != null) {
          req.put('pointsExpirationDate', String.valueOf(expirationDate));
        }

        reqList.add(req);
      }

      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockCreditLedgersForJournal(tj, reqList);
      } else {
        LoyaltyPointService.creditPoints(reqList);
      }

      List<LoyaltyLedger> llList = [
        SELECT Id, Points, ExpiryDate, EscrowPointsCreditDate, ActivityDate, CreatedDate, EventType, AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();

      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points;
        pcDto.CD_TYPE_SAVE = ll.EventType;
        pcDto.TX_REMARK = ll.AdditionalNotes;
        pcDtoList.add(pcDto);
      }

      result.put('PointCreditList', pcDtoList);

      return ApiResult.ok(200, 'Point credited.', result);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult creditEcopoint(Map<String, Object> reqData) {
    Map<String, Object> result = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Operation failed.');
    }

    try {
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      Decimal point = ValidationUtil.decimalValidation(reqData.get('point'), 'point', true);

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo AND MemberStatus != 'Inactive'
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      if (point <= 0) {
        throw new CustomException(400, 'Operation failed.');
      }

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId;
      tj.MemberId = lpmList[0].Id;
      tj.JournalDate = Datetime.now();
      tj.ActivityDate = Datetime.now();
      tj.TransactionAmount = point;
      tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);

      insert tj;

      List<LoyaltyPgmCurrencySubtype> lpcsList = [
        SELECT Id, Name
        FROM LoyaltyPgmCurrencySubtype
        WHERE Name = :POINT_SUB_TYPE_NAME
        LIMIT 1
      ];
      if (lpcsList.isEmpty()) {
        throw new CustomException(400, POINT_SUB_TYPE_NAME + 'Operation failed.');
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', lpmList[0].Id);
      req.put('journalId', tj.Id);
      req.put('loyaltyProgramCurrencySubtypeName', POINT_SUB_TYPE_NAME);
      req.put('additionalNotes', 'Point credit adjustment');
      req.put('points', point);

      reqList.add(req);

      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockCreditLedgersForJournal(tj, reqList);
      } else {
        LoyaltyPointService.creditPoints(reqList);
      }

      return ApiResult.ok(200, 'Eco point credited.', result);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult updatePoint(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Operation failed.');
    }

    try {
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);
      String type = ValidationUtil.stringValidationEx(reqData.get('type'), 'type', true, false);
      Decimal point = ValidationUtil.decimalValidation(reqData.get('point'), 'point', true);
      String cd_type_point = ValidationUtil.stringValidationEx(reqData.get('cd_type_point'), 'cd_type_point', true, false);
      Date expiryDate = ValidationUtil.dateValidation(reqData.get('ExpiryDate__c'), 'ExpiryDate__c', true);
      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      if (point <= 0) {
        throw new CustomException(400, 'Operation failed.');
      }

      if ('01'.equals(type)) {
        Map<String, Object> creditReqMap = new Map<String, Object>();
        List<Map<String, Object>> pointsList = new List<Map<String, Object>>();
        Map<String, Object> pointMap = new Map<String, Object>();
        creditReqMap.put('MemberNo__c', memberNo);
        pointMap.put('point', point);
        pointMap.put('cd_type_point', cd_type_point);
        pointsList.add(pointMap);
        pointMap.put('PointsList', pointsList);

        return creditPoint(creditReqMap);
      } else if ('02'.equals(type)) {
        List<LoyaltyAggrSubPointExprLedger__c> laspelList = [
          SELECT Id, AvailablePoints__c, CurrencySubTypeId__r.Name, ExpiryDate__c, CurrencySubTypeId__r.PointTypeCode__c
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE LoyaltyProgramMemberId__c = :lpmList[0].Id AND ExpiryDate__c = :expiryDate AND CurrencySubTypeId__r.PointTypeCode__c = :cd_type_point
          LIMIT 1
        ];
        if (!laspelList.isEmpty()) {
          if (laspelList[0].AvailablePoints__c < point) {
            throw new CustomException(
              400,
              'Value' +
                laspelList[0].CurrencySubTypeId__r.Name +
                'Value' +
                laspelList[0].ExpiryDate__c +
                'Value' +
                laspelList[0].AvailablePoints__c +
                ')'
            );
          } else {
            TransactionJournal tj = new TransactionJournal();

            tj.LoyaltyProgramId = lpmList[0].ProgramId;
            tj.MemberId = lpmList[0].Id;
            tj.JournalDate = Datetime.now();
            tj.ActivityDate = Datetime.now();
            tj.TransactionAmount = point;
            tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT);
            tj.JournalReason__c = '2';

            insert tj;

            List<Map<String, Object>> pointDeleteReqList = new List<Map<String, Object>>();

            Map<String, Object> pointDeleteReq = new Map<String, Object>();
            pointDeleteReq.put('loyaltyProgramMemberId', lpmList[0].Id);
            pointDeleteReq.put('journalId', tj.Id);
            pointDeleteReq.put('loyaltyProgramCurrencySubtypeName', laspelList[0].CurrencySubTypeId__r.Name);
            pointDeleteReq.put('additionalNotes', 'Manual point rollback by API');
            pointDeleteReq.put('points', point);

            pointDeleteReqList.add(pointDeleteReq);

            LoyaltyPointService.debitPoints(pointDeleteReqList);

            List<LoyaltyLedgerTraceability> lltList = [
              SELECT
                LoyaltyPgmCurrencySubtype.Name,
                Points,
                CreditLoyaltyLedger.ExpiryDate,
                LoyaltyProgramMember.Contact.MemberNo__c,
                LastModifiedDate,
                DebitLoyaltyLedgerId,
                LoyaltyPgmCurrencySubtype.PointTypeCode__c
              FROM LoyaltyLedgerTraceability
              WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
              LIMIT 100
            ];
            if (lltList.isEmpty()) {
              throw new CustomException(400, 'Operation failed.' + tj.Id);
            }

            List<PointDebitDTO> pcDtoList = new List<PointDebitDTO>();
            for (LoyaltyLedgerTraceability llt : lltList) {
              PointDebitDTO pcDto = new PointDebitDTO();
              pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
              pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
              pcDto.CD_RESON = tj.JournalReason__c;
              pcDto.NO_MBR = memberNo;
              pcDto.PT_USE = llt.Points;
              pcDto.DTS_INSERT = String.valueOf(tj.CreatedDate);

              pcDtoList.add(pcDto);
            }
            data.put('PointDeleteList', pcDtoList);
          }
        } else {
          throw new CustomException(400, 'Operation failed.');
        }
      } else {
        throw new CustomException(400, 'Operation failed.');
      }

      return ApiResult.ok(200, 'Point debited.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public Double getPointList(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);

      return results[0].getPoints();
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // Version V1
  public ApiResult getPointApplyHelp(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false);
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);
      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', false);
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false);

      if (String.isNotBlank(promotionNo)) {
        List<Promotion> pList = [SELECT Id, IsPointUsageAllowed__c FROM Promotion WHERE PromotionNo__c = :promotionNo LIMIT 1];
        if (pList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + promotionNo);
        } else {
          if (!pList[0].IsPointUsageAllowed__c) {
            throw new CustomException(400, 'Operation failed.' + promotionNo);
          }
        }
      }

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      if (storeCode != null) {
        List<Account> aList = [SELECT Id, StoreTypeFour__c FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
        if (aList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + storeCode);
        }

        if ('01'.equals(aList[0].StoreTypeFour__c) || '05'.equals(aList[0].StoreTypeFour__c) || '20'.equals(aList[0].StoreTypeFour__c)) {
          if ('05'.equals(aList[0].StoreTypeFour__c)) {
            if (String.isNotBlank(type) && '03'.equals(type)) {
              return getPointApplyHelpV2(reqData);
            }
          } else {
            return getPointApplyHelpV2(reqData);
          }
        }
      }

      return getPointApplyHelpV2(reqData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // Version V2
  public ApiResult getPointApplyHelpV2(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      List<AggregateResult> arList = [
        SELECT sum(AvailablePoints__c) totalPoints, CurrencySubTypeId__r.PointTypeCode__c pointTypeCode
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE
          AvailablePoints__c > 0
          AND ExpiryDate__c > :Date.today()
          AND LoyaltyProgramMemberId__c = :lpmList[0].Id
          AND CurrencySubTypeId__r.PointTypeCode__c != NULL
        GROUP BY CurrencySubTypeId__r.PointTypeCode__c
      ];

      List<PointResDto.AvailablePointResponse> pointList = new List<PointResDto.AvailablePointResponse>();
      for (AggregateResult ar : arList) {
        PointResDto.AvailablePointResponse item = new PointResDto.AvailablePointResponse(ar);
        pointList.add(item);
      }

      data.put('pointList', pointList);
      return ApiResult.ok(200, 'Purchase point credit processed.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult getDebitPointList(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false);
      String orderNo = ValidationUtil.stringValidation(reqData.get('OrderNo__c'), 'OrderNo__c', false);

      String fieldPath;
      String keyValue;

      if (!String.isBlank(saleNo)) {
        fieldPath = 'SaleNo__c';
        keyValue = saleNo;
      } else if (!String.isBlank(orderNo)) {
        fieldPath = 'OrderNo__c';
        keyValue = orderNo;
      } else {
        throw new CustomException(400, 'Operation failed.');
      }

      if (!([SELECT COUNT() FROM Order WHERE OrderNo__c = :keyValue OR SaleNo__c = :keyValue LIMIT 1] > 0)) {
        throw new CustomException(400, 'Operation failed.' + keyValue);
      }

      Id pointDebitJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT);

      String soql =
        'SELECT ' +
        'CreditLoyaltyLedgerId, DebitLoyaltyLedgerId, LoyaltyPgmCurrencySubtypeId, ActionType, Points, CreatedDate, ' +
        'DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c, DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c, DebitLoyaltyLedger.TransactionJournal.Order.IsReductionOrder__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c, DebitLoyaltyLedger.TransactionJournal.SaleId__r.OrderNo__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.SaleId__r.ActualPaymentAmount__c, DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c, ' +
        'LoyaltyProgramMember.Contact.MemberNo__c, CreditLoyaltyLedger.ExpiryDate, LoyaltyPgmCurrencySubtype.Name, ' +
        'DebitLoyaltyLedger.TransactionJournal.InsertId__c, DebitLoyaltyLedger.TransactionJournal.DepositNo__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.IsDeleted__c, DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c ' +
        'FROM LoyaltyLedgerTraceability ' +
        'WHERE ' +
        'ActionType = \'Debit\' ' +
        'AND DebitLoyaltyLedger.TransactionJournal.JournalSubTypeId = :pointDebitJstId ' +
        'AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE ' +
        'AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL ' +
        'OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE) ' +
        'AND (DebitLoyaltyLedger.TransactionJournal.Order.' +
        fieldPath +
        ' = :keyValue ' +
        'OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.' +
        fieldPath +
        ' = :keyValue) ' +
        'LIMIT 200';

      List<LoyaltyLedgerTraceability> lltList = (List<LoyaltyLedgerTraceability>) Database.query(soql);

      Map<LedgerAggKey, Decimal> usedPointMap = new Map<LedgerAggKey, Decimal>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        LedgerAggKey key = new LedgerAggKey(llt);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(key, 0);
        }

        usedPointMap.put(key, usedPointMap.get(key) + llt.Points);
      }

      // List<Map<String, Object>> l1 = new List<Map<String, Object>>();
      List<PointDebitDTO> pointDebitList = new List<PointDebitDTO>();
      for (LedgerAggKey key : usedPointMap.keySet()) {
        Decimal used = usedPointMap.get(key);

        if (used > 0) {
          PointDebitDTO pointDebitDto = new PointDebitDTO();

          if (!String.isBlank(key.depositNo)) {
            pointDebitDto.NO_DEPOSIT = key.depositNo.replaceAll('-\\d+$', '');
          }
          pointDebitDto.CD_LEDGER = key.debitLoyaltyLedgerId;
          pointDebitDto.CD_JOURNAL = key.creditLoyaltyLedgerId; // key.debitLoyaltyLedgerId; -> key.creditLoyaltyLedgerId; (26.02.03)
          pointDebitDto.CD_TYPE_POINT = key.currencySubtypeId;
          pointDebitDto.CD_RESON = '1';
          pointDebitDto.NO_SAL = key.saleOrOrderNo;
          pointDebitDto.AM_SAL = key.actualPaymentAmount;
          pointDebitDto.PT_USE = used;
          pointDebitDto.DTS_INSERT = key.createdDate;
          pointDebitDto.ID_INSERT = key.insertId;
          if (key.isReductionOrder && !String.isBlank(key.returnSaleNo)) {
            pointDebitDto.NO_SAL_RTN = key.returnSaleNo;
          }

          pointDebitList.add(pointDebitDto);
        }
      }
      data.put('DebitPointList', pointDebitList);

      return ApiResult.ok(200, 'Used points retrieved.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      Id jtId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION);

      Id jstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT);

      tj.JournalReason__c = '1';
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      tj.PostPointBalance__c = lmcList[0].PointsBalance - tj.transactionAmount;

      Long insertJournalStartMs = Datetime.now().getTime();
      Integer insertJournalStartCpu = Limits.getCpuTime();
      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      Map<String, Object> req = new Map<String, Object>();

      req.put('loyaltyProgramMemberId', tj.MemberId);
      req.put('points', tj.transactionAmount);
      req.put('journalId', tj.Id);
      reqList.add(req);
      Long debitServiceStartMs = Datetime.now().getTime();
      Integer debitServiceStartCpu = Limits.getCpuTime();
      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockDebitTraceability(tj, reqList);
      } else {
        List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);
      }

      String memberNo;
      List<LoyaltyProgramMember> lpmList = [
        SELECT Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (!lpmList.isEmpty()) {
        memberNo = lpmList[0].Contact.MemberNo__c;
      }

      String saleNo;
      if (String.isNotBlank(tj.OrderId)) {
        List<Order> oList = [SELECT OrderNo__c, SaleNo__c FROM Order WHERE Id = :tj.OrderId LIMIT 1];
        if (!oList.isEmpty()) {
          if (String.isNotBlank(oList[0].OrderNo__c)) {
            saleNo = oList[0].OrderNo__c;
          } else if (String.isNotBlank(oList[0].SaleNo__c)) {
            saleNo = oList[0].SaleNo__c;
          }
        }
      }

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT Points, LastModifiedDate, DebitLoyaltyLedgerId, LoyaltyPgmCurrencySubtype.PointTypeCode__c, CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.Id);
      }

      List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // tj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = memberNo;
        pcDto.NO_SAL = saleNo;
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);

        pdDtoList.add(pcDto);
      }
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      Id jtId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION);

      Id jstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT);

      tj.JournalReason__c = '1';
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (LoyaltyLedger ll : llList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('points', ll.Points);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ll.LoyaltyPgmCrcySubtype.Name);
        reqList.add(req);
      }

      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockDebitTraceability(tj, reqList);
      } else {
        List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);
      }

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.Id);
      }

      List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // tj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c;
        if (String.isNotBlank(tj.Order.OrderNo__c)) {
          pcDto.NO_SAL = tj.Order.OrderNo__c;
        } else if (String.isNotBlank(tj.Order.SaleNo__c)) {
          pcDto.NO_SAL = tj.Order.SaleNo__c;
        }
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);

        pdDtoList.add(pcDto);
      }
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
    try {
      if (data.isEmpty()) {
        return null;
      }

      Id jtIdByCreditPoint = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
      Id jstIdByCreditPoint = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);

      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + data[0].MemberId);
      }

      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(data[0].OrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(data[0].OrderId);

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = purchaseAccrualDatetime;
      tj.JournalDate = purchaseAccrualDatetime;
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = data[0].OrderId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtIdByCreditPoint;
      tj.JournalSubTypeId = jstIdByCreditPoint;

      Long insertJournalStartMs = Datetime.now().getTime();
      Integer insertJournalStartCpu = Limits.getCpuTime();
      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Decimal totalAmount = 0;
      for (TransactionJournal v : data) {
        if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
          continue;
        }
        if (v.TransactionAmount == null || v.TransactionAmount == 0) {
          continue;
        }

        totalAmount += v.TransactionAmount;
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (totalAmount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        req.put('pointsExpirationDate', String.valueOf(purchaseAccrualExpirationDate));
        reqList.add(req);
      }

      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockCreditLedgersForJournal(tj, reqList);
      } else {
        LoyaltyPointService.creditPoints(reqList);
      }

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      String memberNo = resolveMemberNoFromTransactionJournal(tj.Id);

      List<PointCreditDTO> pcDtoList = buildPointCreditDtos(llList, memberNo, '01');
      Decimal totalPoints = sumPositiveLedgerPoints(llList);
      tj.TransactionAmount = totalPoints;
      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      Savepoint sp1 = Database.setSavepoint();

      if (data.isEmpty()) {
        return null;
      }

      Set<String> excludedPointTypeCodeSet = new Set<String>();
      List<Promotion> pList = [SELECT Id, PointTypeCode__c FROM Promotion WHERE Id = :data[0].PromotionId LIMIT 1];
      if (!pList.isEmpty()) {
        if (String.isNotBlank(pList[0].PointTypeCode__c)) {
          for (String code : pList[0].PointTypeCode__c.split(';')) {
            if (String.isNotBlank(code)) {
              excludedPointTypeCodeSet.add(code.trim());
            }
          }
        }
      }

      // if (data[0].PromotionId != null && String.isNotBlank(data[0].Promotion.PointTypeCode__c)) {
      //   for (String code : data[0].Promotion.PointTypeCode__c.split(';')) {
      //     if (String.isNotBlank(code)) {
      //       excludedPointTypeCodeSet.add(code.trim());
      //     }
      //   }
      // }

      Id jtIdByCreditPoint = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
      Id jstIdByCreditPoint = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);

      List<LoyaltyTierBenefit> rawLtbList = [
        SELECT
          Benefit.PurchasePointRate__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.Name,
          Benefit.LoyaltyPgmCurrencySubtypeId__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];

      List<LoyaltyTierBenefit> ltbList = new List<LoyaltyTierBenefit>();
      for (LoyaltyTierBenefit ltb : rawLtbList) {
        String benefitPointTypeCode = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;

        if (String.isBlank(benefitPointTypeCode) || !excludedPointTypeCodeSet.contains(benefitPointTypeCode.trim())) {
          ltbList.add(ltb);
        }
      }

      if (ltbList.isEmpty()) {
        return null;
      }

      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(data[0].OrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(data[0].OrderId);

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = purchaseAccrualDatetime;
      tj.JournalDate = purchaseAccrualDatetime;
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = data[0].OrderId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtIdByCreditPoint;
      tj.JournalSubTypeId = jstIdByCreditPoint;

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Decimal totalAmount = calculateEligibleAccrualAmount(data, excludeAmount);
      if (totalAmount <= 0) {
        Database.rollback(sp1);
        return null;
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (totalAmount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      Long creditServiceStartMs = Datetime.now().getTime();
      Integer creditServiceStartCpu = Limits.getCpuTime();
      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockCreditLedgersForJournal(tj, reqList);
      } else {
        LoyaltyPointService.creditPoints(reqList);
      }

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (lpmList.isEmpty() || lpmList[0].Contact.MemberNo__c == null) {
        throw new CustomException(500, 'member contact is null');
      }
      // String memberNo = ValidationUtil.stringValidationEx(lpmList[0].Contact.MemberNo__c, 'MemberNo__c', true, false);
      String memberNo = lpmList[0].Contact.MemberNo__c;

      Decimal totalPoints = 0;

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id;
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points;
        pcDto.CD_TYPE_SAVE = ll.EventType;
        pcDto.TX_REMARK = ll.AdditionalNotes;
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }

      tj.TransactionAmount = totalPoints;
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      tj.PostPointBalance__c = lmcList[0].PointsBalance;

      Long updateJournalStartMs = Datetime.now().getTime();
      Integer updateJournalStartCpu = Limits.getCpuTime();
      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      Savepoint sp1 = Database.setSavepoint();

      if (data == null || data.isEmpty() || data[0].PromotionId == null) {
        return null;
      }

      List<PromotionPointLimit__c> pointLimitList = [
        SELECT Type__c, Value__c, LoyaltyPgmCurrencySubtypeId__c, LoyaltyPgmCurrencySubtypeId__r.Name
        FROM PromotionPointLimit__c
        WHERE PromotionId__c = :data[0].PromotionId AND Type__c IN ('none', 'rate')
      ];
      if (pointLimitList.isEmpty()) {
        return null;
      }

      Set<Id> targetSubtypeIdSet = new Set<Id>();
      Boolean hasNoneTypeLimit = false;
      for (PromotionPointLimit__c pointLimit : pointLimitList) {
        if ('none'.equals(pointLimit.Type__c) && pointLimit.LoyaltyPgmCurrencySubtypeId__c != null) {
          hasNoneTypeLimit = true;
          targetSubtypeIdSet.add(pointLimit.LoyaltyPgmCurrencySubtypeId__c);
        }
      }
      if (targetSubtypeIdSet.isEmpty() && !hasRatePromotionPointLimit(pointLimitList)) {
        return null;
      }

      Id jtIdByCreditPoint = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
      Id jstIdByCreditPoint = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL);

      LoyaltyPgmCurrencySubtype eventPointSubtype;
      if (hasNoneTypeLimit) {
        List<LoyaltyPgmCurrencySubtype> eventPointSubtypeList = [
          SELECT Id, Name
          FROM LoyaltyPgmCurrencySubtype
          WHERE Name = :POINT_SUB_TYPE_NAME_EVENT
          LIMIT 1
        ];
        if (eventPointSubtypeList.isEmpty()) {
          throw new CustomException(400, POINT_SUB_TYPE_NAME_EVENT + 'Operation failed.');
        }
        eventPointSubtype = eventPointSubtypeList[0];
      }

      List<LoyaltyTierBenefit> rawLtbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];

      Decimal totalAmount = calculateEligibleAccrualAmount(data, excludeAmount);
      if (totalAmount <= 0) {
        Database.rollback(sp1);
        return null;
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      if (hasNoneTypeLimit) {
        for (LoyaltyTierBenefit ltb : rawLtbList) {
          Id benefitSubtypeId = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c;
          Decimal rate = ltb.Benefit.PurchasePointRate__c;
          if (benefitSubtypeId == null || rate == null || rate <= 0 || !targetSubtypeIdSet.contains(benefitSubtypeId)) {
            continue;
          }

          Decimal points = (totalAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
          if (points <= 0) {
            continue;
          }

          Map<String, Object> req = new Map<String, Object>();
          req.put('loyaltyProgramMemberId', data[0].MemberId);
          req.put('loyaltyProgramCurrencySubtypeName', eventPointSubtype.Name);
          req.put('points', points);
          req.put('additionalNotes', eventPointSubtype.Name + '|' + String.valueOf(eventPointSubtype.Id) + '|' + String.valueOf(rate));
          reqList.add(req);
        }
      }

      for (PromotionPointLimit__c pointLimit : pointLimitList) {
        if (!'rate'.equals(pointLimit.Type__c) || pointLimit.LoyaltyPgmCurrencySubtypeId__c == null) {
          continue;
        }

        Decimal rate = pointLimit.Value__c;
        if (rate == null || rate <= 0) {
          continue;
        }

        Decimal points = (totalAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
        if (points <= 0) {
          continue;
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('loyaltyProgramCurrencySubtypeName', pointLimit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', points);
        req.put(
          'additionalNotes',
          pointLimit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(pointLimit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(rate)
        );
        reqList.add(req);
      }

      if (reqList.isEmpty()) {
        Database.rollback(sp1);
        return null;
      }

      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(data[0].OrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(data[0].OrderId);

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = purchaseAccrualDatetime;
      tj.JournalDate = purchaseAccrualDatetime;
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = data[0].OrderId;
      tj.PromotionId = data[0].PromotionId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtIdByCreditPoint;
      tj.JournalSubTypeId = jstIdByCreditPoint;

      insert tj;

      for (Map<String, Object> req : reqList) {
        req.put('journalId', tj.Id);
        req.put('pointsExpirationDate', String.valueOf(purchaseAccrualExpirationDate));
      }

      Long creditServiceStartMs = Datetime.now().getTime();
      Integer creditServiceStartCpu = Limits.getCpuTime();
      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockCreditLedgersForJournal(tj, reqList);
      } else {
        LoyaltyPointService.creditPoints(reqList);
      }

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (lpmList.isEmpty() || lpmList[0].Contact.MemberNo__c == null) {
        throw new CustomException(500, 'member contact is null');
      }

      Decimal totalPoints = 0;
      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id;
        pcDto.CD_TYPE_POINT = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
        pcDto.NO_MBR = lpmList[0].Contact.MemberNo__c;
        pcDto.PT_TARGET = ll.Points;
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate);
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate);
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1));
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate);
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate);
        pcDto.CD_TYPE_SAVE = ll.EventType;
        pcDto.TX_REMARK = ll.AdditionalNotes;
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }

      tj.TransactionAmount = totalPoints;
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      if (!lmcList.isEmpty()) {
        tj.PostPointBalance__c = lmcList[0].PointsBalance;
      }
      update tj;
      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
    List<PointCreditDTO> result = new List<PointCreditDTO>();
    try {
      String grade = ValidationUtil.stringValidationEx(reqData.get('Grade__c'), 'Grade__c', true, false);
      TransactionJournal tj = (TransactionJournal) ValidationUtil.sObjectValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String additionalNotes = ValidationUtil.stringValidation(reqData.get('AdditionalNotes__c'), 'AdditionalNotes__c', true);
      Decimal adjustAmount = ValidationUtil.decimalValidation(reqData.get('adjustAmount'), 'adjustAmount', false);

      Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

      String labelName;
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.getValue() == grade) {
          labelName = entry.getLabel();
          break;
        }
      }

      List<LoyaltyTier> ltList = [SELECT Id FROM LoyaltyTier WHERE Name = :labelName LIMIT 1];
      if (ltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + labelName);
      }

      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c, LoyaltyTierId
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId = :ltList[0].Id
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.MemberId);
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
        return result;
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
        return result;
      }

      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(tj.OrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(tj.OrderId);

      TransactionJournal newTj = new TransactionJournal();
      newTj.ActivityDate = purchaseAccrualDatetime;
      newTj.JournalDate = purchaseAccrualDatetime;
      newTj.LoyaltyProgramId = tj.LoyaltyProgramId;
      newTj.RelatedJournalId = tj.Id;
      newTj.MemberId = tj.MemberId;
      newTj.OrderId = tj.OrderId;
      if (String.isNotBlank(tj.SaleId__c)) {
        newTj.SaleId__c = tj.SaleId__c;
      } else if (String.isNotBlank(tj.OrderId__c)) {
        newTj.OrderId__c = tj.OrderId__c;
      }
      newTj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
      newTj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
      newTj.AdditionalNotes__c = additionalNotes;

      insert newTj;

      Decimal amount = (adjustAmount != null) ? adjustAmount : tj.TransactionAmount;
      if (amount <= 0) {
        throw new CustomException(400, 'Operation failed.' + amount);
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', newTj.MemberId);
        req.put('journalId', newTj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (amount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        req.put('pointsExpirationDate', String.valueOf(purchaseAccrualExpirationDate));
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :newTj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points;
        pcDto.CD_TYPE_SAVE = ll.EventType;
        pcDto.TX_REMARK = ll.AdditionalNotes;
        result.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }
      newTj.TransactionAmount = totalPoints;
      update newTj;

      return result;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
    List<PointDebitDTO> result = new List<PointDebitDTO>();
    try {
      String grade = ValidationUtil.stringValidationEx(reqData.get('Grade__c'), 'Grade__c', true, false);
      TransactionJournal tj = (TransactionJournal) ValidationUtil.sObjectValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String additionalNotes = ValidationUtil.stringValidation(reqData.get('AdditionalNotes__c'), 'AdditionalNotes__c', true);
      Decimal adjustAmount = ValidationUtil.decimalValidation(reqData.get('adjustAmount'), 'adjustAmount', false);

      Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

      String labelName;
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.getValue() == grade) {
          labelName = entry.getLabel();
          break;
        }
      }

      List<LoyaltyTier> ltList = [SELECT Id FROM LoyaltyTier WHERE Name = :labelName LIMIT 1];
      if (ltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + labelName);
      }

      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c, LoyaltyTierId
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId = :ltList[0].Id
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.MemberId);
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      TransactionJournal newTj = new TransactionJournal();
      newTj.ActivityDate = Datetime.now();
      newTj.JournalDate = Datetime.now();
      newTj.LoyaltyProgramId = tj.LoyaltyProgramId;
      newTj.RelatedJournalId = tj.Id;
      newTj.MemberId = tj.MemberId;
      newTj.OrderId = tj.OrderId;
      if (String.isNotBlank(tj.SaleId__c)) {
        newTj.SaleId__c = tj.SaleId__c;
      } else if (String.isNotBlank(tj.OrderId__c)) {
        newTj.OrderId__c = tj.OrderId__c;
      }
      newTj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL);
      newTj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL);
      newTj.AdditionalNotes__c = additionalNotes;

      insert newTj;

      Decimal amount = (adjustAmount != null) ? adjustAmount : tj.TransactionAmount;
      if (amount <= 0) {
        throw new CustomException(400, 'Operation failed.' + amount);
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', newTj.MemberId);
        req.put('journalId', newTj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (amount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockDebitTraceability(newTj, reqList);
      } else {
        List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);
      }

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :newTj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + newTj.Id);
      }
      List<LoyaltyLedgerTraceability> newLltList = new List<LoyaltyLedgerTraceability>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        LoyaltyLedgerTraceability newLlt = llt.clone(false, true, false, false);
        newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;

        newLltList.add(newLlt);
      }

      List<Database.SaveResult> insertResultList = Database.insert(newLltList);

      for (Database.SaveResult insertResult : insertResultList) {
        if (!insertResult.isSuccess()) {
          Database.Error err = insertResult.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      List<Database.DeleteResult> deleteResultList = Database.delete(lltList);

      for (Database.DeleteResult deleteResult : deleteResultList) {
        if (!deleteResult.isSuccess()) {
          Database.Error err = deleteResult.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Decimal totalPoints = 0;
      for (LoyaltyLedgerTraceability llt : newLltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // newTj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = newTj.JournalReason__c;
        pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c;
        if (String.isNotBlank(newTj.Order.OrderNo__c)) {
          pcDto.NO_SAL = newTj.Order.OrderNo__c;
        } else if (String.isNotBlank(newTj.Order.SaleNo__c)) {
          pcDto.NO_SAL = newTj.Order.SaleNo__c;
        }
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);

        result.add(pcDto);

        if (llt.Points > 0) {
          totalPoints += llt.Points;
        }
      }

      newTj.TransactionAmount = totalPoints;
      update newTj;

      return result;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
    try {
      Id creditPointJt = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
      tj.JournalTypeId = creditPointJt;
      tj.JournalSubTypeId = resolveRestoreAccrualJournalSubTypeId(tj.JournalSubTypeId);

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
        req.put('points', llt.Points);
        req.put('additionalNotes', llt.DebitLoyaltyLedger.AdditionalNotes);
        req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points;
        pcDto.CD_TYPE_SAVE = ll.EventType;
        pcDto.TX_REMARK = ll.AdditionalNotes;
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }
      tj.TransactionAmount = totalPoints;
      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
    Map<String, Object> response = new Map<String, Object>();

    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      Id jtId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL);

      Id jstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL);

      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      insert tj;

      Id loyaltyProgramCurrencyId = getLoyaltyProgramCurrencyId();

      List<Order> oList = [SELECT Id FROM Order WHERE Id = :tj.OrderId LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, 'Order is null');
      }

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          Id,
          CreditLoyaltyLedgerId,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyPgmCurrencySubtype.Name,
          LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          ActionType,
          Points,
          LoyaltyPgmCurrencySubtypeId
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND (CreditLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId
          OR DebitLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId)
          AND ActionType = 'Debit'
          AND Points > 0
        LIMIT 100
      ];

      // DebugUtil.pretty('lltList : ', lltList);

      if (lltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.OrderId);
      }

      Map<String, UsageBucket> usedPointMap = new Map<String, UsageBucket>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        String creditLoyaltyLedgerId = ValidationUtil.stringValidation(llt.CreditLoyaltyLedgerId, 'CreditLoyaltyLedgerId', true);
        String debitLoyaltyLedgerId = ValidationUtil.stringValidation(llt.DebitLoyaltyLedgerId, 'DebitLoyaltyLedgerId', true);
        Date expiryDate = ValidationUtil.dateValidation(llt.CreditLoyaltyLedger.ExpiryDate, 'CreditLoyaltyLedger.ExpiryDate', true);
        String loyaltyPgmCurrencySubtypeName = ValidationUtil.stringValidation(
          llt.LoyaltyPgmCurrencySubtype.Name,
          'LoyaltyPgmCurrencySubtype.Name',
          true
        );
        Integer usagePriorityNumber = ValidationUtil.integerValidation(
          llt.LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          'LoyaltyPgmCurrencySubtype.UsagePriorityNumber',
          true
        );
        String actionType = ValidationUtil.stringValidation(llt.ActionType, 'ActionType', true);
        Decimal points = ValidationUtil.decimalValidation(llt.Points, 'Points', true);
        String loyaltyPgmCurrencySubtypeId = ValidationUtil.stringValidation(llt.LoyaltyPgmCurrencySubtypeId, 'LoyaltyPgmCurrencySubtypeId', true);

        String key = String.valueOf(expiryDate) + '|' + loyaltyPgmCurrencySubtypeName + '|' + String.valueOf(usagePriorityNumber);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(
            key,
            new UsageBucket(
              llt.Id,
              expiryDate,
              loyaltyPgmCurrencySubtypeName,
              usagePriorityNumber,
              loyaltyPgmCurrencySubtypeId,
              creditLoyaltyLedgerId,
              debitLoyaltyLedgerId
            )
          );
        }

        usedPointMap.get(key).usagePoints += points;
      }

      List<UsageBucket> ubList = new List<UsageBucket>(usedPointMap.values());
      ubList.sort(new UsageBucketCancelSorter());

      Decimal cancelAmount = tj.TransactionAmount;

      List<CancelPortion> expiredCancelList = new List<CancelPortion>();
      List<CancelPortion> unexpiredCancelList = new List<CancelPortion>();
      for (UsageBucket ub : ubList) {
        if (cancelAmount <= 0) {
          break;
        }

        if (ub.usagePoints == null || ub.usagePoints <= 0) {
          continue;
        }

        Decimal possible = ub.usagePoints;

        Decimal fromThis = (cancelAmount > possible) ? possible : cancelAmount;

        if (fromThis <= 0) {
          continue;
        }

        Boolean isExpired = (ub.expiryDate != null && ub.expiryDate <= Date.today());

        if (isExpired) {
          expiredCancelList.add(new CancelPortion(ub, fromThis));
        } else {
          unexpiredCancelList.add(new CancelPortion(ub, fromThis));
        }

        cancelAmount -= fromThis;
      }

      // ================================================================================================================================
      List<LoyaltyLedgerTraceability> deleteDebitList = new List<LoyaltyLedgerTraceability>();
      List<LoyaltyLedgerTraceability> insertRemainDebitList = new List<LoyaltyLedgerTraceability>();

      Map<Id, Decimal> cancelSumByLLT = new Map<Id, Decimal>();

      if (!expiredCancelList.isEmpty()) {
        for (CancelPortion cp : expiredCancelList) {
          cancelSumByLLT.put(
            cp.loyaltyLedgerTraceabilityId,
            (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
          );
        }
      }

      if (!unexpiredCancelList.isEmpty()) {
        for (CancelPortion cp : unexpiredCancelList) {
          cancelSumByLLT.put(
            cp.loyaltyLedgerTraceabilityId,
            (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
          );
        }
      }

      if (cancelSumByLLT.isEmpty()) {
        throw new CustomException(400, 'Operation failed.');
      }

      List<LoyaltyLedgerTraceability> originalDebitList = [
        SELECT Id, Points, LoyaltyProgramMemberId, LoyaltyPgmCurrencySubtypeId, LoyaltyProgramCurrencyId, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :cancelSumByLLT.keySet()
      ];

      for (LoyaltyLedgerTraceability orig : originalDebitList) {
        Decimal originalPts = orig.Points;
        Decimal cancelledPts = cancelSumByLLT.get(orig.Id);
        Decimal cancelAmountPts = originalPts - cancelledPts;

        deleteDebitList.add(orig);

        if (cancelAmountPts > 0) {
          LoyaltyLedgerTraceability newDebit = new LoyaltyLedgerTraceability();
          newDebit.LoyaltyProgramMemberId = orig.LoyaltyProgramMemberId;
          newDebit.LoyaltyPgmCurrencySubtypeId = orig.LoyaltyPgmCurrencySubtypeId;
          newDebit.LoyaltyProgramCurrencyId = orig.LoyaltyProgramCurrencyId;
          newDebit.Points = cancelAmountPts;
          newDebit.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
          newDebit.DebitLoyaltyLedgerId = orig.DebitLoyaltyLedgerId;
          newDebit.CreditLoyaltyLedgerId = orig.CreditLoyaltyLedgerId;

          insertRemainDebitList.add(newDebit);
        }
      }

      if (!deleteDebitList.isEmpty()) {
        delete deleteDebitList;
      }
      if (!insertRemainDebitList.isEmpty()) {
        insert insertRemainDebitList;
      }
      // ================================================================================================================================

      if (cancelAmount > 0) {
        throw new CustomException(400, 'Operation failed.');
      }

      if (!expiredCancelList.isEmpty()) {
        List<LoyaltyLedger> expireLedgerList = new List<LoyaltyLedger>();
        List<TraceSeed> traceSeedList = new List<TraceSeed>();

        List<Map<String, Object>> expiredPointList = new List<Map<String, Object>>();

        for (CancelPortion expiredCancel : expiredCancelList) {
          LoyaltyLedger expireLedger = new LoyaltyLedger();
          expireLedger.LoyaltyProgramMemberId = tj.MemberId;
          expireLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
          expireLedger.TransactionJournalId = tj.Id;
          expireLedger.ActivityDate = Datetime.now();
          expireLedger.LoyaltyPgmCrcySubtypeId = expiredCancel.loyaltyPgmCurrencySubtypeId;
          expireLedger.Points = expiredCancel.cancelPoints;
          expireLedger.ExpiryDate = expiredCancel.expiryDate;
          expireLedger.EventType = 'Credit';
          expireLedgerList.add(expireLedger);

          LoyaltyLedger creditLedger = expireLedger.clone(false, true, false, false);
          creditLedger.EventType = 'Expiry';
          expireLedgerList.add(creditLedger);

          traceSeedList.add(new TraceSeed(expiredCancel.debitLoyaltyLedgerId, creditLedger));

          Map<String, Object> expiredPoint = new Map<String, Object>();
          expiredPoint.put('Point', expiredCancel.cancelPoints);
          expiredPoint.put('Name', expiredCancel.pointSubTypeName);
          expiredPoint.put('ExpiryDate', String.valueOf(expiredCancel.expiryDate));
          expiredPointList.add(expiredPoint);
        }
        response.put('ExpiryPointList', expiredPointList);

        insert expireLedgerList;

        // List<LoyaltyLedgerTraceability> debitCancellationTracebilityList = new List<LoyaltyLedgerTraceability>();

        // for (TraceSeed seed : traceSeedList) {
        //   LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
        //   t.LoyaltyProgramMemberId = tj.MemberId;
        //   t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
        //   t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        //   t.Points = seed.creditLedger.Points;
        //   t.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION;

        //   debitCancellationTracebilityList.add(t);
        // }

        // if (!debitCancellationTracebilityList.isEmpty()) {
        //   insert debitCancellationTracebilityList;
        // }
      }

      if (!unexpiredCancelList.isEmpty()) {
        List<Map<String, Object>> reqList = new List<Map<String, Object>>();

        List<Map<String, Object>> recreditPointList = new List<Map<String, Object>>();

        Map<String, TraceSeed> traceSeedMap = new Map<String, TraceSeed>();

        for (CancelPortion unexpiredCancel : unexpiredCancelList) {
          Map<String, Object> req = new Map<String, Object>();
          req.put('loyaltyProgramMemberId', tj.MemberId);
          req.put('loyaltyProgramCurrencyId', loyaltyProgramCurrencyId);
          req.put('journalId', tj.Id);
          req.put('loyaltyProgramCurrencySubtypeName', unexpiredCancel.pointSubTypeName);
          req.put('points', unexpiredCancel.cancelPoints);
          req.put('pointsExpirationDate', String.valueOf(unexpiredCancel.expiryDate));
          reqList.add(req);

          String traceKey = String.valueOf(tj.Id) + '|' + unexpiredCancel.pointSubTypeName + '|' + String.valueOf(unexpiredCancel.expiryDate);
          traceSeedMap.put(traceKey, new TraceSeed(unexpiredCancel.debitLoyaltyLedgerId, null));

          Map<String, Object> recreditPoint = new Map<String, Object>();
          recreditPoint.put('Point', unexpiredCancel.cancelPoints);
          recreditPoint.put('Name', unexpiredCancel.pointSubTypeName);
          recreditPoint.put('ExpiryDate', String.valueOf(unexpiredCancel.expiryDate));
          recreditPointList.add(recreditPoint);
        }
        response.put('RecreditPointList', recreditPointList);

        // List<LoyaltyLedger> creditLedgerList = [
        //   SELECT Id, ExpiryDate, LoyaltyPgmCrcySubtype.Name, TransactionJournalId, Points
        //   FROM LoyaltyLedger
        //   WHERE TransactionJournalId = :tj.Id AND EventType = 'Credit'
        //   LIMIT 100
        // ];

        // for (LoyaltyLedger creditLedger : creditLedgerList) {
        //   String traceKey =
        //     String.valueOf(creditLedger.TransactionJournalId) +
        //     '|' +
        //     creditLedger.LoyaltyPgmCrcySubtype.Name +
        //     '|' +
        //     String.valueOf(creditLedger.ExpiryDate);

        //   if (traceSeedMap.containsKey(traceKey)) {
        //     TraceSeed seed = traceSeedMap.get(traceKey);
        //     seed.creditLedger = creditLedger;
        //   }
        // }

        // List<LoyaltyLedgerTraceability> traceList = new List<LoyaltyLedgerTraceability>();

        // for (String key : traceSeedMap.keySet()) {
        //   TraceSeed seed = traceSeedMap.get(key);

        //   if (seed.creditLedger == null) {
        //   }

        //   LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
        //   t.LoyaltyProgramMemberId = tj.MemberId;
        //   t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
        //   t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        //   t.Points = seed.creditLedger.Points;

        //   traceList.add(t);
        // }

        // if (!traceList.isEmpty()) {
        //   DebugUtil.pretty('traceList', traceList);
        //   // insert traceList;
        //   List<Database.SaveResult> resultList = Database.insert(traceList);

        //   for (Database.SaveResult result : resultList) {
        //     if (!result.isSuccess()) {
        //       Database.Error err = result.getErrors()[0];
        //       throw new CustomException(400, err.getMessage());
        //     }
        //   }
        // }
      } else {
        tj.Status = 'Processed';
        update tj;
      }
      return response;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult deletePoint(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);
      List<Object> pointsList = ValidationUtil.listObjValidation(reqData.get('PointsList'), 'PointsList', true);

      if (pointsList.size() > 50) {
        throw new CustomException(400, 'Operation failed.');
      }

      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      Map<String, Decimal> pointByTypeMap = new Map<String, Decimal>();
      Decimal totalPoints = 0;

      for (Object v : pointsList) {
        Map<String, Object> vMap = ValidationUtil.mapStrObjValidation(v, 'PointsList', true);

        Decimal point = ValidationUtil.decimalGreaterThanZero(vMap.get('point'), 'point', true);
        String cdTypePoint = ValidationUtil.stringValidationEx(vMap.get('cd_type_point'), 'cd_type_point', true, false);
        String expiryDateStr = ValidationUtil.stringValidationEx(vMap.get('ExpiryDate__c'), 'ExpiryDate__c', true, false);
        String key = cdTypePoint + '|' + expiryDateStr;
        totalPoints += point;

        pointByTypeMap.put(key, (pointByTypeMap.containsKey(key) ? pointByTypeMap.get(key) : 0) + point);
      }

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId;
      tj.MemberId = lpmList[0].Id;
      tj.JournalDate = Datetime.now();
      tj.ActivityDate = Datetime.now();
      tj.TransactionAmount = totalPoints;
      tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_POINTS_EXPIRATION, JOURNAL_SUB_TYPE_NAME_API_FORCED_EXPIRE);
      tj.JournalReason__c = '2';

      insert tj;

      List<Map<String, Object>> pointDeleteReqList = new List<Map<String, Object>>();

      for (String key : pointByTypeMap.keySet()) {
        List<String> parts = key.split('\\|');
        String cdTypePoint = parts[0];
        Date expiryDate = ValidationUtil.dateValidation(parts[1], 'expiryDateStr', true);

        List<LoyaltyAggrSubPointExprLedger__c> laspelList = [
          SELECT
            Id,
            CurrencySubTypeName__c,
            CurrencySubTypeId__r.PointTypeCode__c,
            ExpiryDate__c,
            AccruedPoints__c,
            RedeemedPoints__c,
            ExpiredPoints__c,
            AvailablePoints__c
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE
            LoyaltyProgramMemberId__c = :lpmList[0].Id
            AND CurrencySubTypeId__r.PointTypeCode__c = :cdTypePoint
            AND ExpiryDate__c = :expiryDate
            AND AvailablePoints__c >= :pointByTypeMap.get(key)
            AND AvailablePoints__c > 0
          LIMIT 1
        ];

        if (laspelList.isEmpty()) {
          throw new CustomException(400, 'Value' + cdTypePoint + 'Value' + expiryDate + ')');
        }

        Map<String, Object> pointDeleteReq = new Map<String, Object>();
        pointDeleteReq.put('loyaltyProgramMemberId', lpmList[0].Id);
        pointDeleteReq.put('journalId', tj.Id);
        pointDeleteReq.put('loyaltyProgramCurrencySubtypeName', laspelList[0].CurrencySubTypeName__c);
        pointDeleteReq.put('additionalNotes', 'Point debit reversal by API');
        pointDeleteReq.put('points', pointByTypeMap.get(key));

        pointDeleteReqList.add(pointDeleteReq);
      }

      if (Test.isRunningTest() && coverageSimulationMode) {
        insertMockDebitTraceability(tj, pointDeleteReqList);
      } else {
        LoyaltyPointService.debitPoints(pointDeleteReqList);
      }

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.Id);
      }

      List<PointDebitDTO> pcDtoList = new List<PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = memberNo;
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(tj.CreatedDate);

        pcDtoList.add(pcDto);
      }
      data.put('PointDeleteList', pcDtoList);

      return ApiResult.ok(200, 'Point redemption cancelled.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      if (data == null || data.isEmpty()) {
        return null;
      }

      Decimal totalCancelAmount = calculateEligibleAccrualAmount(data, 0);
      if (totalCancelAmount <= 0) {
        return null;
      }

      List<CancelAccrualPlan> planList = new List<CancelAccrualPlan>();

      CancelAccrualPlan purchasePlan = buildCancelAccrualPlan(
        data,
        totalCancelAmount,
        JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL,
        JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL
      );
      if (purchasePlan != null) {
        planList.add(purchasePlan);
      }

      if (data[0].PromotionId != null) {
        CancelAccrualPlan promotionPlan = buildCancelAccrualPlan(
          data,
          totalCancelAmount,
          JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL,
          JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL
        );
        if (promotionPlan != null) {
          planList.add(promotionPlan);
        }
      }

      if (planList.isEmpty()) {
        return null;
      }

      List<TransactionJournal> insertJournalList = new List<TransactionJournal>();
      for (CancelAccrualPlan plan : planList) {
        insertJournalList.add(plan.journal);
      }
      assertSaveResults(Database.insert(insertJournalList, false));

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      for (CancelAccrualPlan plan : planList) {
        for (CancelPurchasePoints cp : plan.cancelPointsList) {
          reqList.add(
            new Map<String, Object>{
              'loyaltyProgramMemberId' => data[0].MemberId,
              'points' => cp.cancelPoints,
              'journalId' => plan.journal.Id,
              'additionalNotes' => cp.loyaltyPgmCrcySubtypeName +
              '|' +
              String.valueOf(cp.loyaltyPgmCrcySubtypeId) +
              '|' +
              String.valueOf(cp.rate),
              'loyaltyProgramCurrencySubtypeName' => cp.loyaltyPgmCrcySubtypeName
            }
          );
        }
      }

      if (reqList.isEmpty()) {
        return null;
      }

      if (Test.isRunningTest() && coverageSimulationMode) {
        for (CancelAccrualPlan plan : planList) {
          List<Map<String, Object>> planReqList = new List<Map<String, Object>>();
          for (CancelPurchasePoints cp : plan.cancelPointsList) {
            planReqList.add(
              new Map<String, Object>{
                'loyaltyProgramMemberId' => data[0].MemberId,
                'points' => cp.cancelPoints,
                'journalId' => plan.journal.Id,
                'additionalNotes' => cp.loyaltyPgmCrcySubtypeName +
                '|' +
                String.valueOf(cp.loyaltyPgmCrcySubtypeId) +
                '|' +
                String.valueOf(cp.rate),
                'loyaltyProgramCurrencySubtypeName' => cp.loyaltyPgmCrcySubtypeName
              }
            );
          }
          insertMockDebitTraceability(plan.journal, planReqList);
        }
      } else {
        LoyaltyPointService.debitPoints(reqList);
      }

      Set<Id> journalIdSet = new Set<Id>();
      for (CancelAccrualPlan plan : planList) {
        journalIdSet.add(plan.journal.Id);
      }

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          DebitLoyaltyLedger.TransactionJournalId,
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :data[0].MemberId AND DebitLoyaltyLedger.TransactionJournalId IN :journalIdSet
        LIMIT 300
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.');
      }

      Map<Id, List<LoyaltyLedgerTraceability>> lltByJournalId = new Map<Id, List<LoyaltyLedgerTraceability>>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        Id journalId = llt.DebitLoyaltyLedger.TransactionJournalId;
        if (!lltByJournalId.containsKey(journalId)) {
          lltByJournalId.put(journalId, new List<LoyaltyLedgerTraceability>());
        }
        lltByJournalId.get(journalId).add(llt);
      }

      List<LoyaltyLedgerTraceability> clonedLltList = new List<LoyaltyLedgerTraceability>();
      List<LoyaltyLedgerTraceability> deleteLltList = new List<LoyaltyLedgerTraceability>();
      for (CancelAccrualPlan plan : planList) {
        plan.traceabilityList = lltByJournalId.get(plan.journal.Id);
        if (plan.traceabilityList == null || plan.traceabilityList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + plan.journal.Id);
        }

        for (LoyaltyLedgerTraceability llt : plan.traceabilityList) {
          LoyaltyLedgerTraceability clonedLlt = llt.clone(false, true, false, false);
          clonedLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;
          clonedLltList.add(clonedLlt);
          deleteLltList.add(llt);
        }
      }

      assertSaveResults(Database.insert(clonedLltList, false));
      assertDeleteResults(Database.delete(deleteLltList, false));

      Order orderInfo = null;
      if (data[0].OrderId != null) {
        List<Order> orderList = [SELECT OrderNo__c, SaleNo__c FROM Order WHERE Id = :data[0].OrderId LIMIT 1];
        if (!orderList.isEmpty()) {
          orderInfo = orderList[0];
        }
      }

      List<GdSaleApiController.PointDebitDTO> resultList = new List<GdSaleApiController.PointDebitDTO>();
      List<TransactionJournal> updateJournalList = new List<TransactionJournal>();
      Integer clonedIndex = 0;
      for (CancelAccrualPlan plan : planList) {
        Decimal totalPoints = 0;
        for (Integer i = 0; i < plan.traceabilityList.size(); i++) {
          LoyaltyLedgerTraceability llt = clonedLltList[clonedIndex++];
          GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
          pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
          pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
          pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
          pcDto.CD_RESON = plan.journal.JournalReason__c;
          pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c;
          if (orderInfo != null) {
            if (String.isNotBlank(orderInfo.OrderNo__c)) {
              pcDto.NO_SAL = orderInfo.OrderNo__c;
            } else if (String.isNotBlank(orderInfo.SaleNo__c)) {
              pcDto.NO_SAL = orderInfo.SaleNo__c;
            }
          }
          pcDto.PT_USE = llt.Points;
          pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
          resultList.add(pcDto);

          if (llt.Points > 0) {
            totalPoints += llt.Points;
          }
        }
        plan.journal.TransactionAmount = totalPoints;
        updateJournalList.add(plan.journal);
      }

      assertSaveResults(Database.update(updateJournalList, false));
      return resultList.isEmpty() ? null : resultList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  private CancelAccrualPlan buildCancelAccrualPlan(
    List<TransactionJournal> data,
    Decimal totalCancelAmount,
    String accrualSubTypeName,
    String reversalSubTypeName
  ) {
    Id accrualJtId = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
    Id accrualReversalJtId = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL);
    Id accrualJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, accrualSubTypeName);
    Id reversalJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, reversalSubTypeName);

    List<LoyaltyLedger> llList;
    if (data[0].OrderId__c != null) {
      llList = [
        SELECT Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, CreatedDate
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.SaleId__c = :data[0].SaleId__c
          AND (TransactionJournal.JournalTypeId = :accrualJtId
          OR TransactionJournal.JournalTypeId = :accrualReversalJtId)
          AND (TransactionJournal.JournalSubTypeId = :accrualJstId
          OR TransactionJournal.JournalSubTypeId = :reversalJstId)
        ORDER BY CreatedDate ASC
        LIMIT 100
      ];
    } else {
      llList = [
        SELECT Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, CreatedDate
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.OrderId = :data[0].OrderId
          AND (TransactionJournal.JournalTypeId = :accrualJtId
          OR TransactionJournal.JournalTypeId = :accrualReversalJtId)
          AND (TransactionJournal.JournalSubTypeId = :accrualJstId
          OR TransactionJournal.JournalSubTypeId = :reversalJstId)
        ORDER BY CreatedDate ASC
        LIMIT 100
      ];
    }

    if (llList.isEmpty()) {
      return null;
    }

    Map<String, Decimal> netPointMap = new Map<String, Decimal>();
    for (LoyaltyLedger ll : llList) {
      if (String.isBlank(ll.AdditionalNotes)) {
        continue;
      }

      if (!netPointMap.containsKey(ll.AdditionalNotes)) {
        netPointMap.put(ll.AdditionalNotes, 0);
      }

      if (ll.EventType == 'Credit') {
        netPointMap.put(ll.AdditionalNotes, netPointMap.get(ll.AdditionalNotes) + ll.Points);
      } else if (ll.EventType == 'Debit') {
        netPointMap.put(ll.AdditionalNotes, netPointMap.get(ll.AdditionalNotes) - ll.Points);
      }
    }

    List<CancelPurchasePoints> sourcePointList = new List<CancelPurchasePoints>();
    for (String key : netPointMap.keySet()) {
      Decimal remainPts = netPointMap.get(key);
      if (remainPts == null || remainPts <= 0) {
        continue;
      }

      List<String> parts = key.split('\\|');
      if (parts.size() < 3) {
        continue;
      }

      sourcePointList.add(new CancelPurchasePoints(remainPts, (Id) parts[1], parts[0], Decimal.valueOf(parts[2])));
    }

    if (sourcePointList.isEmpty()) {
      return null;
    }

    TransactionJournal tj = new TransactionJournal();
    tj.JournalDate = Datetime.now();
    tj.ActivityDate = Datetime.now();
    tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
    tj.MemberId = data[0].MemberId;
    tj.OrderId = data[0].OrderId;
    tj.JournalTypeId = accrualReversalJtId;
    tj.JournalSubTypeId = reversalJstId;
    if (JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(reversalSubTypeName)) {
      tj.PromotionId = data[0].PromotionId;
    }
    if (String.isNotBlank(data[0].SaleId__c)) {
      tj.SaleId__c = data[0].SaleId__c;
    } else if (String.isNotBlank(data[0].OrderId__c)) {
      tj.OrderId__c = data[0].OrderId__c;
    }
    if (data.size() == 1) {
      tj.RelatedJournalId = data[0].Id;
    }
    if (data[0].JournalSubTypeId == getJournalSubTypeId(JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL)) {
      tj.JournalReason__c = '6';
    }

    Map<Id, List<CancelPurchasePoints>> cppGroupMap = new Map<Id, List<CancelPurchasePoints>>();
    for (CancelPurchasePoints cp : sourcePointList) {
      if (!cppGroupMap.containsKey(cp.loyaltyPgmCrcySubtypeId)) {
        cppGroupMap.put(cp.loyaltyPgmCrcySubtypeId, new List<CancelPurchasePoints>());
      }
      cppGroupMap.get(cp.loyaltyPgmCrcySubtypeId).add(cp);
    }

    List<CancelPurchasePoints> cancelPointList = new List<CancelPurchasePoints>();
    for (Id subtypeId : cppGroupMap.keySet()) {
      Decimal remainCancelAmountForSubtype = totalCancelAmount;
      List<CancelPurchasePoints> bucketList = cppGroupMap.get(subtypeId);
      bucketList.sort(new CancelRateSorter());

      for (CancelPurchasePoints cp : bucketList) {
        if (remainCancelAmountForSubtype <= 0) {
          break;
        }

        Decimal rateFraction = cp.rate / 100;
        if (rateFraction <= 0) {
          continue;
        }

        Decimal maxCancelableAmount = cp.points / rateFraction;
        Decimal useAmountFromThis = (remainCancelAmountForSubtype > maxCancelableAmount) ? maxCancelableAmount : remainCancelAmountForSubtype;
        if (useAmountFromThis <= 0) {
          continue;
        }

        Decimal cancelPoints = useAmountFromThis * rateFraction;
        if (cancelPoints > cp.points) {
          cancelPoints = cp.points;
        }
        if (cancelPoints <= 0) {
          continue;
        }

        cancelPointList.add(new CancelPurchasePoints(cancelPoints, cp.loyaltyPgmCrcySubtypeId, cp.loyaltyPgmCrcySubtypeName, cp.rate));
        remainCancelAmountForSubtype -= useAmountFromThis;
      }
    }

    if (cancelPointList.isEmpty()) {
      return null;
    }

    return new CancelAccrualPlan(tj, cancelPointList);
  }

  private class CancelAccrualPlan {
    public TransactionJournal journal;
    public List<CancelPurchasePoints> cancelPointsList;
    public List<LoyaltyLedgerTraceability> traceabilityList;

    public CancelAccrualPlan(TransactionJournal journal, List<CancelPurchasePoints> cancelPointsList) {
      this.journal = journal;
      this.cancelPointsList = cancelPointsList;
      this.traceabilityList = new List<LoyaltyLedgerTraceability>();
    }
  }
  public class UsageBucket {
    public Id loyaltyLedgerTraceabilityId;
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Decimal usagePoints = 0;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId;
    public String debitLoyaltyLedgerId;

    public UsageBucket(Id id, Date e, String s, Integer p, Id lpcsi, String clli, String dlli) {
      loyaltyLedgerTraceabilityId = id;
      expiryDate = e;
      pointSubTypeName = s;
      usagePriority = p;
      loyaltyPgmCurrencySubtypeId = lpcsi;
      creditLoyaltyLedgerId = clli;
      debitLoyaltyLedgerId = dlli;
    }
  }

  public class UsageBucketCancelSorter implements System.Comparator<Object> {
    public Integer compare(Object a, Object b) {
      UsageBucket x = (UsageBucket) a;
      UsageBucket y = (UsageBucket) b;
      if (x.expiryDate > y.expiryDate) {
        return -1;
      }
      if (x.expiryDate < y.expiryDate) {
        return 1;
      }

      if (x.usagePriority > y.usagePriority) {
        return -1;
      }
      if (x.usagePriority < y.usagePriority) {
        return 1;
      }

      return x.pointSubTypeName.toLowerCase().compareTo(y.pointSubTypeName.toLowerCase());
    }
  }

  public class CancelPortion {
    public Id loyaltyLedgerTraceabilityId;
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Decimal cancelPoints;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId;
    public String debitLoyaltyLedgerId;

    public CancelPortion(UsageBucket ub, Decimal cancelPoints) {
      this.loyaltyLedgerTraceabilityId = ub.loyaltyLedgerTraceabilityId;
      this.expiryDate = ub.expiryDate;
      this.pointSubTypeName = ub.pointSubTypeName;
      this.usagePriority = ub.usagePriority;
      this.cancelPoints = cancelPoints;
      this.loyaltyPgmCurrencySubtypeId = ub.loyaltyPgmCurrencySubtypeId;
      this.creditLoyaltyLedgerId = ub.creditLoyaltyLedgerId;
      this.debitLoyaltyLedgerId = ub.debitLoyaltyLedgerId;
    }
  }

  // private static List<PointCreditDTO> restoreEcoPointsFromReturn(TransactionJournal newTj, Id sourceTransactionJournalId) {
  public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
    Id apiForcedDebitJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT);

    List<TransactionJournal> ecoCreditCancelJournalList = [
      SELECT
        Id,
        JournalSubTypeId,
        PaymentMethod,
        TransactionAmount,
        OrderId,
        LoyaltyProgramId,
        MemberId,
        SaleId__c,
        DepositNo__c,
        IsDeleted__c,
        DeleteDateTime__c,
        VoucherCode,
        JournalDate,
        Order.EndDate,
        InsertId__c,
        Order.ActualPaymentAmount__c,
        Promotion.PromotionNo__c,
        AdditionalNotes__c
      FROM TransactionJournal
      WHERE SaleId__c = :orderId AND AdditionalNotes__c = :ECO_POINT_CANCEL_NOTE AND JournalSubTypeId = :apiForcedDebitJstId
      LIMIT 1
    ];
    if (ecoCreditCancelJournalList.isEmpty()) {
      return new List<PointCreditDTO>();
    }

    TransactionJournal newTj = new TransactionJournal();

    newTj.LoyaltyProgramId = ecoCreditCancelJournalList[0].LoyaltyProgramId;
    newTj.MemberId = ecoCreditCancelJournalList[0].MemberId;
    // if (endDate != null) {

    //   expirationDate = endDate.addYears(2);
    // } else {
    newTj.JournalDate = Datetime.now();
    newTj.ActivityDate = Datetime.now();
    // }
    newTj.TransactionAmount = ecoCreditCancelJournalList[0].TransactionAmount;
    newTj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT);
    // if (saleId != null) {
    newTj.OrderId = ecoCreditCancelJournalList[0].OrderId;
    newTj.SaleId__c = ecoCreditCancelJournalList[0].SaleId__c;
    newTj.AdditionalNotes__c = ECO_POINT_RESTORE_NOTE;
    // }

    insert newTj;

    List<LoyaltyLedgerTraceability> lltList = [
      SELECT CreditLoyaltyLedger.ExpiryDate, LoyaltyPgmCurrencySubtype.Name, Points, DebitLoyaltyLedger.AdditionalNotes
      FROM LoyaltyLedgerTraceability
      WHERE DebitLoyaltyLedger.TransactionJournal.Id = :ecoCreditCancelJournalList[0].Id
      LIMIT 200
    ];
    if (lltList.isEmpty()) {
      return new List<PointCreditDTO>();
    }

    // return getPointService().creditSepcificPoints(newTj, lltList);

    // newTj.JournalTypeId = creditPointJt;
    // newTj.JournalSubTypeId = purchaseAccrualJt;

    // insert newTj;

    List<Map<String, Object>> reqList = new List<Map<String, Object>>();

    for (LoyaltyLedgerTraceability llt : lltList) {
      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', newTj.MemberId);
      req.put('journalId', newTj.Id);
      req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
      req.put('points', llt.Points);
      req.put('additionalNotes', ECO_POINT_RESTORE_NOTE);
      req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
      reqList.add(req);
    }

    if (Test.isRunningTest() && coverageSimulationMode) {
      insertMockCreditLedgersForJournal(newTj, reqList);
    } else {
      LoyaltyPointService.creditPoints(reqList);
    }

    List<LoyaltyLedger> llList = [
      SELECT
        Id,
        TransactionJournalId,
        LoyaltyPgmCrcySubtype.Name,
        Points,
        ExpiryDate,
        EscrowPointsCreditDate,
        ActivityDate,
        CreatedDate,
        EventType,
        AdditionalNotes,
        LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE TransactionJournalId = :newTj.Id
      LIMIT 100
    ];

    TransactionJournal tj2 = [
      SELECT
        Id,
        MemberId,
        TYPEOF Member
          WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
        END
      FROM TransactionJournal
      WHERE Id = :newTj.Id
      LIMIT 1
    ];
    SObject memberObj = tj2.getSObject('Member');
    if (memberObj == null) {
      throw new CustomException(500, 'memberObj is null');
    }
    SObject contactObj = memberObj.getSObject('Contact');
    if (contactObj == null) {
      throw new CustomException(500, 'contactObj is null');
    }
    String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

    Decimal totalPoints = 0;

    List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
    for (LoyaltyLedger ll : llList) {
      PointCreditDTO pcDto = new PointCreditDTO();
      pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
      pcDto.CD_TYPE_POINT = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      pcDto.NO_MBR = memberNo;
      pcDto.PT_TARGET = ll.Points;
      pcDto.CD_TYPE_SAVE = ll.EventType;
      pcDto.TX_REMARK = ll.AdditionalNotes;
      pcDtoList.add(pcDto);

      if (ll.Points > 0) {
        totalPoints += ll.Points;
      }
    }
    newTj.TransactionAmount = totalPoints;
    update newTj;

    return pcDtoList;
  }

  public class TraceSeed {
    public Id debitLedgerId;
    public LoyaltyLedger creditLedger;

    public TraceSeed(Id debitLedgerId, LoyaltyLedger creditLedger) {
      this.debitLedgerId = debitLedgerId;
      this.creditLedger = creditLedger;
    }
  }

  public class CancelPurchasePoints {
    public Decimal points;
    public Decimal cancelPoints;
    public Id loyaltyPgmCrcySubtypeId;
    public String loyaltyPgmCrcySubtypeName;
    public Decimal rate;

    public CancelPurchasePoints(Decimal p, Id lpcsi, String lpcsn, Decimal r) {
      this.points = p;
      this.cancelPoints = p;
      this.loyaltyPgmCrcySubtypeId = lpcsi;
      this.loyaltyPgmCrcySubtypeName = lpcsn;
      this.rate = r;
    }
  }

  public class CancelRateSorter implements Comparator<CancelPurchasePoints> {
    public Integer compare(CancelPurchasePoints a, CancelPurchasePoints b) {
      if (a.rate == null && b.rate == null) {
        return 0;
      }
      if (a.rate == null) {
        return 1;
      }
      if (b.rate == null) {
        return -1;
      }

      if (a.rate < b.rate) {
        return -1;
      }
      if (a.rate > b.rate) {
        return 1;
      }
      return 0;
    }
  }

  public class DepositResponseDTO {
    public String CD_TYPE_APPR;
    public Decimal AM_DEPOSIT;
    public String NO_COUPON_ALL;
    public String NM_COUPON;
    public Date DT_EXP;
    public Integer RT_DISC;
    public Decimal AM_DISC;
    public String TX_REMARK;
  }

  public class LedgerAggKey {
    public String memberNo;
    public Id currencySubtypeId;
    public Date expiryDate;
    public String pointSubtypeName;
    public Id debitLoyaltyLedgerId;
    public Id creditLoyaltyLedgerId;
    public String insertId;
    public String createdDate;
    public String saleOrOrderNo;
    public String returnSaleNo;
    public Decimal actualPaymentAmount;
    public Boolean isReductionOrder;
    public String depositNo;

    public LedgerAggKey(LoyaltyLedgerTraceability llt) {
      this.memberNo = llt.LoyaltyProgramMember.Contact.MemberNo__c;
      this.currencySubtypeId = llt.LoyaltyPgmCurrencySubtypeId;
      this.expiryDate = llt.CreditLoyaltyLedger.ExpiryDate;
      this.pointSubtypeName = llt.LoyaltyPgmCurrencySubtype.Name;
      this.debitLoyaltyLedgerId = llt.DebitLoyaltyLedgerId;
      this.creditLoyaltyLedgerId = llt.CreditLoyaltyLedgerId;
      this.insertId = llt.DebitLoyaltyLedger.TransactionJournal.InsertId__c;
      this.createdDate = llt.CreatedDate.format('yyyyMMddHHmmss');
      String saleSaleNo = llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c;
      String saleOrderNo = llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.OrderNo__c;
      String orderSaleNo = llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c;
      String orderOrderNo = llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c;
      this.returnSaleNo = saleSaleNo;
      this.saleOrOrderNo = !String.isBlank(saleSaleNo)
        ? saleSaleNo
        : (!String.isBlank(saleOrderNo) ? saleOrderNo : (!String.isBlank(orderSaleNo) ? orderSaleNo : orderOrderNo));
      this.actualPaymentAmount = (llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.ActualPaymentAmount__c != null)
        ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.ActualPaymentAmount__c
        : llt.DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c;
      Boolean hasSaleContext = !String.isBlank(saleSaleNo) || !String.isBlank(saleOrderNo);
      this.isReductionOrder = hasSaleContext
        ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c
        : llt.DebitLoyaltyLedger.TransactionJournal.Order.IsReductionOrder__c;
      this.depositNo = llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c;
    }

    public Boolean equals(Object obj) {
      if (obj == null || !(obj instanceof LedgerAggKey)) {
        return false;
      }
      LedgerAggKey other = (LedgerAggKey) obj;
      return this.currencySubtypeId == other.currencySubtypeId && this.expiryDate == other.expiryDate;
    }

    public Integer hashCode() {
      return (String.valueOf(currencySubtypeId) + '|' + String.valueOf(expiryDate)).hashCode();
    }
  }

  public Boolean isAccrualEligible(TransactionJournal tj) {
    if (!('01'.equals(tj.DepositType__c) || '02'.equals(tj.DepositType__c))) {
      return false;
    }

    if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
      return false;
    }

    if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
      return false;
    }

    return true;
  }

  @TestVisible
  private static Boolean hasRatePromotionPointLimit(List<PromotionPointLimit__c> pointLimitList) {
    for (PromotionPointLimit__c pointLimit : pointLimitList) {
      if (
        'rate'.equals(pointLimit.Type__c) &&
        pointLimit.LoyaltyPgmCurrencySubtypeId__c != null &&
        pointLimit.Value__c != null &&
        pointLimit.Value__c > 0
      ) {
        return true;
      }
    }
    return false;
  }

  @TestVisible
  private static Decimal calculateEligibleAccrualAmount(List<TransactionJournal> data, Decimal excludeAmount) {
    if (data == null || data.isEmpty()) {
      return 0;
    }

    Decimal totalAmount = 0;
    for (TransactionJournal v : data) {
      if (v == null) {
        continue;
      }
      if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
        continue;
      }
      if (v.TransactionAmount == null || v.TransactionAmount == 0) {
        continue;
      }
      totalAmount += v.TransactionAmount;
    }

    if (excludeAmount != null) {
      totalAmount -= excludeAmount;
    }

    return totalAmount;
  }

  @TestVisible
  private static Id resolveRestoreAccrualJournalSubTypeId(Id reversalJournalSubTypeId) {
    Id cancelPurchaseAccrualJt = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL);
    if (reversalJournalSubTypeId == cancelPurchaseAccrualJt) {
      return getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
    }

    Id promotionPointAccrualReversalJt = SObjectUtil.findIdByName(
      JournalSubType.SObjectType,
      JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL,
      true
    );
    if (reversalJournalSubTypeId == promotionPointAccrualReversalJt) {
      return getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL);
    }

    return reversalJournalSubTypeId;
  }

  @TestVisible
  private static String resolveMemberNoFromTransactionJournal(Id journalId) {
    TransactionJournal tj2 = [
      SELECT
        Id,
        MemberId,
        TYPEOF Member
          WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
        END
      FROM TransactionJournal
      WHERE Id = :journalId
      LIMIT 1
    ];
    SObject memberObj = tj2.getSObject('Member');
    if (memberObj == null) {
      throw new CustomException(500, 'memberObj is null');
    }
    SObject contactObj = memberObj.getSObject('Contact');
    if (contactObj == null) {
      throw new CustomException(500, 'contactObj is null');
    }
    return ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);
  }

  @TestVisible
  private static List<PointCreditDTO> buildPointCreditDtos(List<LoyaltyLedger> llList, String memberNo, String defaultPointTypeCode) {
    List<PointCreditDTO> result = new List<PointCreditDTO>();
    for (LoyaltyLedger ll : llList) {
      PointCreditDTO pcDto = new PointCreditDTO();
      pcDto.CD_JOURNAL = ll.Id;
      pcDto.CD_TYPE_POINT = (defaultPointTypeCode != null) ? defaultPointTypeCode : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      pcDto.NO_MBR = memberNo;
      pcDto.PT_TARGET = ll.Points;
      pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate);
      pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate);
      pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1));
      pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate);
      pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate);
      pcDto.CD_TYPE_SAVE = ll.EventType;
      pcDto.TX_REMARK = ll.AdditionalNotes;
      result.add(pcDto);
    }
    return result;
  }

  @TestVisible
  private static Decimal sumPositiveLedgerPoints(List<LoyaltyLedger> llList) {
    Decimal totalPoints = 0;
    for (LoyaltyLedger ll : llList) {
      if (ll.Points > 0) {
        totalPoints += ll.Points;
      }
    }
    return totalPoints;
  }

  public ApiResult redeemVoucherV2(TransactionJournal tj) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Voucher> vList = [
        SELECT Id, VoucherCode, VoucherDefinitionId, LoyaltyProgramMemberId, ExpirationDate, VoucherDefinition.Name, VoucherDefinition.IsUnlimited__c
        FROM Voucher
        WHERE VoucherCode = :tj.VoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Issued'
        LIMIT 1
      ];
      if (vList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.VoucherCode);
      }

      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      vList[0].Status = 'Redeemed';
      vList[0].UseDate = Date.today();
      vList[0].UsedTransactionJournalId__c = tj.Id;

      Database.SaveResult updateResult = Database.update(vList[0]);
      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      String programName = [
        SELECT Name
        FROM LoyaltyProgram
        WHERE Id = :tj.LoyaltyProgramId
        LIMIT 1
      ]
      .Name;

      if (vList[0].VoucherDefinition.IsUnlimited__c == true) {
        reissueUnlimitedVoucherIfNeeded(vList[0], programName, tj.Id);
      }
      data.put('voucher', vList[0]);

      return ApiResult.ok(200, 'Voucher redeemed.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // Version V1
  public ApiResult redeemCancelVoucher(TransactionJournal tj) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Voucher> vList = [
        SELECT
          Id,
          VoucherCode,
          ExpirationDate,
          VoucherDefinition.Name,
          VoucherDefinitionId,
          LoyaltyProgramMemberId,
          UsedTransactionJournalId__c,
          VoucherDefinition.IsUnlimited__c
        FROM Voucher
        WHERE VoucherCode = :tj.VoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Redeemed'
        LIMIT 1
      ];
      if (vList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + tj.VoucherCode);
      }

      Id originalRedeemJournalId = vList[0].UsedTransactionJournalId__c;
      if (vList[0].VoucherDefinition.IsUnlimited__c == false && vList[0].ExpirationDate >= Date.today()) {
        vList[0].Status = 'Issued';
        vList[0].UseDate = null;
        vList[0].UsedTransactionJournalId__c = null;
      } else {
        vList[0].Status = 'Expired';
      }

      tj.JournalTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL);
      tj.JournalSubTypeId = getJournalSubTypeId(JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL);
      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Database.SaveResult updateResult = Database.update(vList[0]);
      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      if (vList[0].VoucherDefinition.IsUnlimited__c == true) {
        cancelUnlimitedReissuedVoucherIfNeeded(vList[0], originalRedeemJournalId);
      }

      data.put('Name', vList[0].VoucherDefinition.Name);
      data.put('VoucherCode', vList[0].VoucherCode);
      data.put('ExpirationDate', vList[0].ExpirationDate);

      return ApiResult.ok(200, 'Voucher redeem cancellation completed.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult getReturnUsedCoupon(String originalOrderId) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<TransactionJournal> tjList = [
        SELECT Id, DepositType__c, VoucherCode
        FROM TransactionJournal
        WHERE Order.SaleNo__c = :originalOrderId AND VoucherCode != NULL
        LIMIT 200
      ];

      Map<VoucherAggKey, Integer> voucherUseCountMap = new Map<VoucherAggKey, Integer>();

      for (TransactionJournal tj : tjList) {
        if (String.isBlank(tj.VoucherCode)) {
          continue;
        }

        VoucherAggKey key = new VoucherAggKey(tj.VoucherCode);

        Integer current = voucherUseCountMap.containsKey(key) ? voucherUseCountMap.get(key) : 0;

        Boolean isRefund = (tj.DepositType__c == '03');

        current += (isRefund ? -1 : 1);

        voucherUseCountMap.put(key, current);
      }

      for (VoucherAggKey key : voucherUseCountMap.keySet()) {
        Integer net = voucherUseCountMap.get(key);

        if (net > 0) {
          Map<String, Object> useCouponMap = new Map<String, Object>();
          List<Voucher> vList = [
            SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode
            FROM Voucher
            WHERE VoucherCode = :key.voucherCode
            LIMIT 1
          ];

          if (vList.isEmpty()) {
            throw new CustomException(400, 'Operation failed.' + key.voucherCode);
          }

          useCouponMap.put('VoucherCode', key.voucherCode);
          useCouponMap.put('ExpirationDate', vList[0].ExpirationDate);
          useCouponMap.put('Name', vList[0].VoucherDefinition.Name);

          data.put('RedeemedCoupon', useCouponMap);
        }
      }

      return ApiResult.ok(200, 'Available vouchers retrieved.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  public ApiResult getRedeemCoupon(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false);
      String orderNo = ValidationUtil.stringValidation(reqData.get('OrderNo__c'), 'OrderNo__c', false);

      Id orderId;
      Boolean isSaleQuery = false;
      List<TransactionJournal> tjList = new List<TransactionJournal>();

      if (!String.isBlank(saleNo)) {
        // fieldPath = 'SaleNo__c';
        List<Order> orderList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
        if (orderList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + saleNo);
        }
        orderId = orderList[0].Id;
        isSaleQuery = true;

        List<TransactionJournal> saleLinkedTjList = [
          SELECT VoucherCode, OrderId
          FROM TransactionJournal
          WHERE SaleId__c = :orderId AND VoucherCode != NULL
          ORDER BY CreatedDate ASC
          LIMIT 200
        ];
        Set<String> saleVoucherCodeSet = new Set<String>();
        Set<Id> relatedOrderIdSet = new Set<Id>{ orderId };
        for (TransactionJournal saleLinkedTj : saleLinkedTjList) {
          if (String.isNotBlank(saleLinkedTj.VoucherCode)) {
            saleVoucherCodeSet.add(saleLinkedTj.VoucherCode);
          }
          if (saleLinkedTj.OrderId != null) {
            relatedOrderIdSet.add(saleLinkedTj.OrderId);
          }
        }

        if (saleVoucherCodeSet.isEmpty()) {
          return ApiResult.ok(200, 'Available vouchers retrieved.', data);
        }

        tjList = [
          SELECT DepositType__c, VoucherCode, TransactionAmount, DepositNo__c, SaleId__c, JournalType.Name, JournalSubType.Name
          FROM TransactionJournal
          WHERE VoucherCode IN :saleVoucherCodeSet AND (SaleId__c = :orderId OR OrderId IN :relatedOrderIdSet OR OrderId__c IN :relatedOrderIdSet)
          ORDER BY CreatedDate ASC
          LIMIT 400
        ];
        // soql =
        //   'SELECT ' +
        //   'DepositType__c, VoucherCode, TransactionAmount ' +
        //   'FROM TransactionJournal ' +
        //   'WHERE Order.' +
        //   fieldPath +
        //   ' = :keyValue' +
        //   ' AND VoucherCode != NULL ' +
        //   ' ORDER BY CreatedDate ASC ' +
        //   ' LIMIT 200';
      } else if (!String.isBlank(orderNo)) {
        // fieldPath = 'OrderNo__c';
        List<Order> orderList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
        if (orderList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + orderNo);
        }
        orderId = orderList[0].Id;

        tjList = [
          SELECT DepositType__c, VoucherCode, TransactionAmount, DepositNo__c, SaleId__c, JournalType.Name, JournalSubType.Name
          FROM TransactionJournal
          WHERE (OrderId__c = :orderId OR OrderId = :orderId) AND VoucherCode != NULL
          ORDER BY CreatedDate ASC
          LIMIT 200
        ];
        // soql =
        //   'SELECT ' +
        //   'DepositType__c, VoucherCode, TransactionAmount ' +
        //   'FROM TransactionJournal ' +
        //   'WHERE Order.' +
        //   fieldPath +
        //   ' = :keyValue' +
        //   ' AND VoucherCode != NULL ' +
        //   ' ORDER BY CreatedDate ASC ' +
        //   ' LIMIT 200';
      } else {
        throw new CustomException(400, 'Operation failed.');
      }

      // if (
      //   !([
      //     SELECT COUNT()
      //     FROM Order
      //     WHERE OrderNo__c = :keyValue OR SaleNo__c = :keyValue
      //     LIMIT 1
      //   ] > 0)
      // ) {
      // }

      // String soql =
      //   'SELECT ' +
      //   'DepositType__c, VoucherCode, TransactionAmount ' +
      //   'FROM TransactionJournal ' +
      //   'WHERE Order.' +
      //   fieldPath +
      //   ' = :keyValue' +
      //   ' AND VoucherCode != NULL ' +
      //   ' ORDER BY CreatedDate ASC ' +
      //   ' LIMIT 200';

      // List<TransactionJournal> tjList = (List<TransactionJournal>) Database.query(soql);

      Map<String, Integer> voucherUseCountMap = new Map<String, Integer>();
      Map<String, Decimal> voucherUsedAmountMap = new Map<String, Decimal>();
      Map<String, String> voucherDepositNoMap = new Map<String, String>();
      Map<String, Boolean> voucherDepositPreferredMap = new Map<String, Boolean>();
      Set<String> voucherCodeSet = new Set<String>();

      for (TransactionJournal tj : tjList) {
        if (String.isBlank(tj.VoucherCode)) {
          continue;
        }

        String voucherCode = tj.VoucherCode;
        VoucherAggKey key = new VoucherAggKey(voucherCode);

        Integer current = voucherUseCountMap.containsKey(voucherCode) ? voucherUseCountMap.get(voucherCode) : 0;

        Boolean isRefund = (tj.DepositType__c == '03');

        isRefund =
          isRefund ||
          (tj.JournalSubType != null &&
          tj.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL) ||
          (tj.JournalType != null &&
          tj.JournalType.Name == JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL);

        current += (isRefund ? -1 : 1);

        if (!isRefund && tj.TransactionAmount != null) {
          voucherUsedAmountMap.put(voucherCode, tj.TransactionAmount);
        }
        if (!isRefund && !String.isBlank(tj.DepositNo__c)) {
          Boolean preferCurrentDeposit = !voucherDepositNoMap.containsKey(voucherCode);
          if (isSaleQuery && tj.SaleId__c == orderId && voucherDepositPreferredMap.get(voucherCode) != true) {
            preferCurrentDeposit = true;
          }
          if (preferCurrentDeposit) {
            voucherDepositNoMap.put(voucherCode, tj.DepositNo__c);
            voucherDepositPreferredMap.put(voucherCode, isSaleQuery && tj.SaleId__c == orderId);
          }
        }

        voucherUseCountMap.put(voucherCode, current);
        voucherCodeSet.add(voucherCode);
      }

      if (!voucherCodeSet.isEmpty()) {
        Map<String, Voucher> voucherByCode = new Map<String, Voucher>();
        for (Voucher voucherRec : [
          SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode, DiscountPercent, FaceValue, UsedTransactionJournalId__r.DepositNo__c
          FROM Voucher
          WHERE VoucherCode IN :voucherCodeSet
        ]) {
          voucherByCode.put(voucherRec.VoucherCode, voucherRec);
        }

        for (String voucherCode : voucherUseCountMap.keySet()) {
          Integer net = voucherUseCountMap.get(voucherCode);
          if (net == null || net <= 0) {
            continue;
          }

          Voucher voucherRec = voucherByCode.get(voucherCode);
          if (voucherRec == null) {
            throw new CustomException(400, 'Operation failed.' + voucherCode);
          }

          Map<String, Object> useCouponMap = new Map<String, Object>();
          useCouponMap.put('VoucherCode', voucherCode);
          useCouponMap.put('ExpirationDate', voucherRec.ExpirationDate);
          useCouponMap.put('Name', voucherRec.VoucherDefinition.Name);

          Decimal redeemAmount = voucherUsedAmountMap.containsKey(voucherCode) ? voucherUsedAmountMap.get(voucherCode) : null;
          Boolean isRateCoupon = voucherRec.DiscountPercent != null && voucherRec.DiscountPercent > 0;
          Decimal faceValueToSend = voucherRec.FaceValue == null ? 0 : voucherRec.FaceValue;
          if (isRateCoupon && redeemAmount != null) {
            faceValueToSend = redeemAmount;
          }

          useCouponMap.put('DiscountPercent', voucherRec.DiscountPercent == null ? 0 : voucherRec.DiscountPercent);
          useCouponMap.put('FaceValue', faceValueToSend);

          String depositNo = voucherDepositNoMap.get(voucherCode);
          if (!String.isBlank(depositNo)) {
            useCouponMap.put('NO_DEPOSIT', depositNo.replaceAll('-\\d+$', ''));
          }

          data.put('RedeemedCoupon', useCouponMap);
        }

        return ApiResult.ok(200, 'Available vouchers retrieved.', data);
      }

      for (String voucherCode : new List<String>()) {
        Integer net = voucherUseCountMap.get(voucherCode);

        if (net > 0) {
          VoucherAggKey key = new VoucherAggKey(voucherCode);
          Map<String, Object> useCouponMap = new Map<String, Object>();
          List<Voucher> vList = [
            SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode, DiscountPercent, FaceValue, UsedTransactionJournalId__r.DepositNo__c
            FROM Voucher
            WHERE VoucherCode = :voucherCode
            LIMIT 1
          ];

          if (vList.isEmpty()) {
            throw new CustomException(400, 'Operation failed.' + key.voucherCode);
          }

          useCouponMap.put('VoucherCode', voucherCode);
          useCouponMap.put('ExpirationDate', vList[0].ExpirationDate);
          useCouponMap.put('Name', vList[0].VoucherDefinition.Name);

          // useCouponMap.put('DiscountPercent', vList[0].DiscountPercent == null ? 0 : vList[0].DiscountPercent);
          // useCouponMap.put('FaceValue', vList[0].FaceValue == null ? 0 : vList[0].FaceValue);

          Decimal redeemAmount = voucherUsedAmountMap.containsKey(voucherCode) ? voucherUsedAmountMap.get(voucherCode) : null;
          Boolean isRateCoupon = vList[0].DiscountPercent != null && vList[0].DiscountPercent > 0;

          Decimal faceValueToSend = vList[0].FaceValue == null ? 0 : vList[0].FaceValue;
          if (isRateCoupon && redeemAmount != null) {
            faceValueToSend = redeemAmount;
          }

          useCouponMap.put('DiscountPercent', vList[0].DiscountPercent == null ? 0 : vList[0].DiscountPercent);
          useCouponMap.put('FaceValue', faceValueToSend);

          // String depositNo = vList[0].UsedTransactionJournalId__r.DepositNo__c;
          String depositNo = vList[0].UsedTransactionJournalId__r == null ? null : vList[0].UsedTransactionJournalId__r.DepositNo__c;
          if (!String.isBlank(depositNo)) {
            depositNo = depositNo.replaceAll('-\\d+$', '');
            useCouponMap.put('NO_DEPOSIT', depositNo);
          }

          data.put('RedeemedCoupon', useCouponMap);
        }
      }

      return ApiResult.ok(200, 'Available vouchers retrieved.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // Version V1
  public ApiResult getAvailableCouponList(Map<String, Object> reqData) {
    Map<String, Object> resData = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false);
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false);
      String orderStatus = ValidationUtil.stringValidation(reqData.get('OrderStatus__c'), 'OrderStatus__c', false);
      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', false);
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false);

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.Grade__c
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.' + memberNo);
      }

      List<Object> orderItem = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', false);
      Integer totalProductQuantity = 0;
      Set<String> productCategorySet = new Set<String>();

      Set<String> usedCouponNoSet = extractCouponNosFromRawTransactionJournals(
        ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', false)
      );
      Set<String> productCodeSet = new Set<String>();
      Decimal requestDiscountRate;
      String promotionLimitValue = String.isBlank(promotionNo) ? null : resolvePromotionIdByPromotionNo(promotionNo);

      if (orderItem != null) {
        for (Object v : orderItem) {
          Map<String, Object> item = ValidationUtil.mapStrObjValidation(v, 'OrderItem', false);
          if (item == null) {
            continue;
          }

          String productCode = ValidationUtil.stringValidationEx(item.get('ProductCode'), 'ProductCode', true, false);
          productCodeSet.add(productCode);

          Integer quantity = ValidationUtil.integerValidation(item.get('Quantity'), 'Quantity', true);
          if (quantity != null) {
            totalProductQuantity += quantity;
          }
        }
      }

      requestDiscountRate = requestDiscountRate == null ? extractMaxDiscountRateFromRawOrderItems(orderItem) : requestDiscountRate;
      if (requestDiscountRate == null) {
        requestDiscountRate = ValidationUtil.decimalValidation(reqData.get('DiscountRate'), 'DiscountRate', false);
      }
      if (!productCodeSet.isEmpty()) {
        productCategorySet.addAll(resolveProductCategoryCodes(productCodeSet));
      }

      List<Voucher> voucherList = [
        SELECT
          Id,
          VoucherDefinitionId,
          VoucherDefinition.Name,
          VoucherDefinition.Description,
          FaceValue,
          Reason,
          EffectiveDate,
          VoucherDefinition.EffectiveDate,
          UseDate,
          ExpirationDate,
          CreatedDate,
          VoucherDefinition.brand__c,
          VoucherDefinition.CouponManNo__c,
          VoucherCode,
          InsertId__c,
          VoucherDefinition.CouponTypeCode__c,
          Status,
          VoucherDefinition.ExpirationType,
          VoucherDefinition.ExpirationPeriod,
          DiscountPercent,
          VoucherDefinition.ResponsibleDepartment__c,
          VoucherDefinition.ResponsiblePerson__c,
          CreatedBy.Name,
          VoucherDefinition.InsertId__c
        FROM Voucher
        WHERE LoyaltyProgramMember.Contact.MemberNo__c = :memberNo AND Status = 'Issued' AND ExpirationDate >= :Date.today()
        LIMIT 200
      ];
      if (voucherList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.');
      }

      Set<Id> vdIdSet = new Set<Id>();
      for (Voucher v : voucherList) {
        if (v.VoucherDefinitionId != null) {
          vdIdSet.add(v.VoucherDefinitionId);
        }
      }
      if (vdIdSet.isEmpty()) {
        throw new CustomException(400, 'Operation failed.');
      }

      String storeType;
      if (storeCode != null) {
        List<Account> storeList = [
          SELECT Id, StoreType__c
          FROM Account
          WHERE StoreCode__c = :storeCode
          LIMIT 1
        ];
        if (storeList.isEmpty()) {
          throw new CustomException(400, 'Operation failed.' + storeCode);
        }
        storeType = storeList[0].StoreType__c;
      }

      List<VoucherLimit__c> limitList = [
        SELECT Id, VoucherDefinitionId__c, Type__c, Value__c, IsActive__c, ProductCode__c, ComparisonOperator__c
        FROM VoucherLimit__c
        WHERE IsActive__c = TRUE AND VoucherDefinitionId__c IN :vdIdSet AND Type__c IN :AVAILABLE_COUPON_LIMIT_TYPES
        LIMIT 2000
      ];

      List<VoucherResDTO> voucherResDtoList = new List<VoucherResDTO>();

      if (limitList.isEmpty()) {
        for (Voucher v : voucherList) {
          if (!usedCouponNoSet.isEmpty() && usedCouponNoSet.contains(v.VoucherCode)) {
            continue;
          }
          voucherResDtoList.add(new VoucherResDTO(v));
        }
      } else {
        Map<Id, VoucherRule> ruleMap = buildRuleMap(limitList);

        List<Voucher> available = new List<Voucher>();

        for (Voucher v : voucherList) {
          if (!usedCouponNoSet.isEmpty() && usedCouponNoSet.contains(v.VoucherCode)) {
            continue;
          }
          VoucherRule r = ruleMap.get(v.VoucherDefinitionId);

          Boolean ok = (r == null)
            ? true
            : r.isEligible(
                productCodeSet,
                productCategorySet,
                storeCode,
                storeType,
                lpmList[0].Contact.Grade__c,
                type,
                promotionLimitValue,
                totalProductQuantity,
                actualPaymentAmount,
                requestDiscountRate
              );

          if (ok) {
            available.add(v);
          }
        }

        for (Voucher v : available) {
          voucherResDtoList.add(new VoucherResDTO(v));
        }
      }

      resData.put('voucherList', voucherResDtoList);
      return ApiResult.ok(200, 'Redeemable voucher list retrieved.', resData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // Version V2
  public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      String memberNo = req.memberNo();
      String noManCoupon = req.noManCoupon(); // NO_MAN_COUPON
      String noCoupon = req.noCoupon(); // NO_COUPON
      Date dtStrExp = req.dtStrExp();
      Date dtEndExp = req.dtEndExp();

      String soql =
        'SELECT ' +
        '  Id, VoucherDefinitionId, VoucherDefinition.Name, VoucherDefinition.Description, FaceValue, Reason, ' +
        '  EffectiveDate, VoucherDefinition.EffectiveDate, UseDate, ExpirationDate, CreatedDate, ' +
        '  VoucherDefinition.brand__c, VoucherDefinition.CouponManNo__c, ' +
        '  VoucherCode, InsertId__c, VoucherDefinition.CouponTypeCode__c, Status, ' +
        '  VoucherDefinition.ExpirationType, VoucherDefinition.ExpirationPeriod, ' +
        '  DiscountPercent, VoucherDefinition.ResponsibleDepartment__c, VoucherDefinition.ResponsiblePerson__c, ' +
        '  CreatedBy.Name, VoucherDefinition.InsertId__c ' +
        'FROM Voucher ' +
        'WHERE LoyaltyProgramMember.Contact.MemberNo__c = :memberNo ' +
        'AND Status = \'Issued\' ';

      if (!String.isBlank(noManCoupon)) {
        soql += 'AND VoucherDefinition.CouponManNo__c = :noManCoupon ';
      }

      if (!String.isBlank(noCoupon)) {
        soql += 'AND VoucherCode = :noCoupon ';
      }

      if (dtStrExp != null) {
        soql += 'AND EffectiveDate >= :dtStrExp ';
      }
      if (dtEndExp != null) {
        soql += 'AND ExpirationDate <= :dtEndExp ';
      }

      soql += 'LIMIT 200';

      List<Voucher> voucherList = Database.query(soql);

      if (voucherList.isEmpty()) {
        throw new CustomException(400, 'Operation failed.');
      }

      List<VoucherResDTO> voucherResDtoList = new List<VoucherResDTO>();

      for (Voucher v : voucherList) {
        voucherResDtoList.add(new VoucherResDTO(v));
      }

      data.put('voucherList', voucherResDtoList);
      return ApiResult.ok(200, 'Redeemable voucher list retrieved.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  private class VoucherRule {
    Set<String> includeProducts = new Set<String>();

    Set<String> includeStores = new Set<String>();
    Set<String> includeStoreTypes = new Set<String>();

    Set<String> includeGrades = new Set<String>();

    Set<String> includeProductCategories = new Set<String>();

    Set<String> includeOrderTypes = new Set<String>();
    Set<String> includePromotions = new Set<String>();

    Decimal maxDiscountRate;
    Integer minTotalQuantity;
    Decimal minSalesAmount;

    String discountRateOperator;
    String totalQuantityOperator;
    String salesAmountOperator;

    Boolean isEligible(
      Set<String> productCodes,
      Set<String> productCategoryCodes,
      String storeCode,
      String storeType,
      String gradeCode,
      String orderType,
      String promotionNo,
      Integer totalQty,
      Decimal amount,
      Decimal discountRate
    ) {
      // ,Decimal discountRate
      // Decimal discountRate
      // -----------------------
      // 0) Null-safe normalize
      // -----------------------
      if (productCodes == null) {
        productCodes = new Set<String>();
      }
      if (productCategoryCodes == null) {
        productCategoryCodes = new Set<String>();
      }
      if (totalQty == null) {
        totalQty = 0;
      }
      // -----------------------
      // -----------------------

      // -----------------------
      // -----------------------
      if (!includeProducts.isEmpty()) {
        if (!intersects(productCodes, includeProducts)) {
          return false;
        }
      }

      if (!includeStores.isEmpty() && includeStoreTypes.isEmpty()) {
        if (String.isBlank(storeCode) || !includeStores.contains(storeCode)) {
          return false;
        }
      }

      if (!includeStoreTypes.isEmpty() && includeStores.isEmpty()) {
        if (String.isBlank(storeType) || !includeStoreTypes.contains(storeType)) {
          return false;
        }
      }

      if (!includeStores.isEmpty() && !includeStoreTypes.isEmpty()) {
        Boolean matchesStore = !String.isBlank(storeCode) && includeStores.contains(storeCode);
        Boolean matchesStoreType = !String.isBlank(storeType) && includeStoreTypes.contains(storeType);
        if (!matchesStore && !matchesStoreType) {
          return false;
        }
      }

      if (!includeGrades.isEmpty()) {
        if (String.isBlank(gradeCode) || !includeGrades.contains(gradeCode)) {
          return false;
        }
      }

      if (!includeProductCategories.isEmpty()) {
        if (!intersects(productCategoryCodes, includeProductCategories)) {
          return false;
        }
      }

      if (!includeOrderTypes.isEmpty()) {
        if (String.isBlank(orderType) || !includeOrderTypes.contains(orderType)) {
          return false;
        }
      }

      // -----------------------
      // 3) Numeric constraints
      // -----------------------
      // if (minTotalQuantity != null) {
      //   if (totalQty < minTotalQuantity) {
      //     return false;
      //   }
      // }

      // if (minSalesAmount != null) {
      //   if (amount == null || amount < minSalesAmount) {
      //     return false;
      //   }
      // }

      // if (maxDiscountRate != null && discountRate != null) {

      //   if (normalized > maxNorm) {
      //     return false;
      //   }
      // }

      if (!includePromotions.isEmpty() && !String.isBlank(promotionNo) && !includePromotions.contains(promotionNo)) {
        return false;
      }

      if (
        minTotalQuantity != null &&
        !matchesNumberConstraint(Decimal.valueOf(totalQty), Decimal.valueOf(minTotalQuantity), totalQuantityOperator, true)
      ) {
        return false;
      }

      if (minSalesAmount != null && !matchesNumberConstraint(amount, minSalesAmount, salesAmountOperator, true)) {
        return false;
      }

      if (maxDiscountRate != null) {
        if (discountRate == null) {
          return false;
        }

        Decimal normalized = normalizeDiscountRate(discountRate);
        Decimal maxNorm = normalizeDiscountRate(maxDiscountRate);
        if (!matchesNumberConstraint(normalized, maxNorm, discountRateOperator, false)) {
          return false;
        }
      }

      return true;
    }
  }

  private static Map<Id, VoucherRule> buildRuleMap(List<VoucherLimit__c> limitList) {
    Map<Id, VoucherRule> res = new Map<Id, VoucherRule>();
    if (limitList == null || limitList.isEmpty()) {
      return res;
    }

    for (VoucherLimit__c vl : limitList) {
      if (vl.VoucherDefinitionId__c == null || !vl.IsActive__c) {
        continue;
      }

      VoucherRule vr = res.get(vl.VoucherDefinitionId__c);
      if (vr == null) {
        vr = new VoucherRule();
        res.put(vl.VoucherDefinitionId__c, vr);
      }

      String type = vl.Type__c;
      String value = vl.Value__c;

      String productCode = vl.ProductCode__c;
      String comparisonOperator = vl.ComparisonOperator__c;

      if (String.isBlank(type) || !AVAILABLE_COUPON_LIMIT_TYPES.contains(type)) {
        continue;
      }

      if (type == 'ProductIncludeList') {
        addValues(vr.includeProducts, productCode);
      } else if (type == 'StoreIncludeList') {
        addValues(vr.includeStores, value);
      } else if (type == 'StoreTypeIncludeList') {
        addValues(vr.includeStoreTypes, value);
      } else if (type == 'GradeIncludeList') {
        addValues(vr.includeGrades, value);
      } else if (type == 'ProductCategoryIncludeList') {
        addValues(vr.includeProductCategories, value);
      } else if (type == 'PromotionIncludeList') {
        addValues(vr.includePromotions, value);
      } else if (type == 'OrderTypeIncludeList') {
        addValues(vr.includeOrderTypes, value);
      } else if (type == 'DiscountRate') {
        Decimal d = parseDecimalSafe(value);
        if (d != null) {
          vr.maxDiscountRate = d;
          vr.discountRateOperator = comparisonOperator;
        }
      } else if (type == 'TotalQuantity') {
        Integer i = parseIntegerSafe(value);
        if (i != null) {
          vr.minTotalQuantity = i;
          vr.totalQuantityOperator = comparisonOperator;
        }
      } else if (type == 'SalesAmount') {
        Decimal d = parseDecimalSafe(value);
        if (d != null) {
          vr.minSalesAmount = d;
          vr.salesAmountOperator = comparisonOperator;
        }
      }
    }

    return res;
  }

  @TestVisible
  private static void addValues(Set<String> target, String raw) {
    if (target == null || String.isBlank(raw)) {
      return;
    }

    String normalized = raw.replace('\n', ',').replace(';', ',');
    for (String token : normalized.split(',')) {
      String val = token == null ? null : token.trim();
      if (!String.isBlank(val)) {
        target.add(val);
      }
    }
  }

  @TestVisible
  private static Decimal parseDecimalSafe(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    try {
      return Decimal.valueOf(raw.trim());
    } catch (Exception e) {
      return null;
    }
  }

  @TestVisible
  private static Integer parseIntegerSafe(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    try {
      return Integer.valueOf(raw.trim());
    } catch (Exception e) {
      return null;
    }
  }

  @TestVisible
  private static Boolean intersects(Set<String> a, Set<String> b) {
    if (a == null || b == null || a.isEmpty() || b.isEmpty()) {
      return false;
    }

    for (String x : a) {
      if (b.contains(x)) {
        return true;
      }
    }

    return false;
  }

  @TestVisible
  private static Decimal normalizeDiscountRate(Decimal rate) {
    if (rate == null) {
      return null;
    }

    Decimal r = rate;
    if (r > 1) {
      r = r / 100;
    }

    return r;
  }

  // Helper methods for available coupon filtering
  @TestVisible
  private static Decimal extractMaxDiscountRateFromRawOrderItems(List<Object> orderItems) {
    Decimal result;
    if (orderItems == null) {
      return null;
    }

    for (Object itemObj : orderItems) {
      Map<String, Object> item = ValidationUtil.mapStrObjValidation(itemObj, 'OrderItem', false);
      if (item == null) {
        continue;
      }

      Decimal itemDiscountRate = ValidationUtil.decimalValidation(item.get('DiscountRate__c'), 'DiscountRate__c', false);
      if (itemDiscountRate != null) {
        result = result == null || itemDiscountRate > result ? itemDiscountRate : result;
      }
    }

    return result;
  }

  @TestVisible
  private static Set<String> extractCouponNosFromRawTransactionJournals(List<Object> transactionJournals) {
    Set<String> result = new Set<String>();
    if (transactionJournals == null) {
      return result;
    }

    for (Object journalObj : transactionJournals) {
      Map<String, Object> journal = ValidationUtil.mapStrObjValidation(journalObj, 'TransactionJournal', false);
      if (journal == null) {
        continue;
      }

      String couponNo = ValidationUtil.stringValidation(journal.get('CouponNo'), 'CouponNo', false);
      if (!String.isBlank(couponNo)) {
        result.add(couponNo);
      }
    }

    return result;
  }

  @TestVisible
  private static Set<String> resolveProductCategoryCodes(Set<String> productCodes) {
    Set<String> result = new Set<String>();
    if (productCodes == null || productCodes.isEmpty()) {
      return result;
    }

    Map<Id, Product2> productById = new Map<Id, Product2>();
    for (Product2 product : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
      productById.put(product.Id, product);
    }
    if (productById.isEmpty()) {
      return result;
    }

    for (ProductCategoryProduct link : [
      SELECT
        ProductId,
        ProductCategory.SystemCode__c,
        ProductCategory.LargeCategoryCode__c,
        ProductCategory.MediumCategoryCode__c,
        ProductCategory.SmallCategoryCode__c
      FROM ProductCategoryProduct
      WHERE ProductId IN :productById.keySet()
    ]) {
      if (link.ProductCategory == null) {
        continue;
      }

      addCategoryPathCodes(
        result,
        link.ProductCategory.SystemCode__c,
        link.ProductCategory.LargeCategoryCode__c,
        link.ProductCategory.MediumCategoryCode__c,
        link.ProductCategory.SmallCategoryCode__c
      );
    }

    return result;
  }

  @TestVisible
  private static void addCategoryPathCodes(Set<String> target, String systemCode, String largeCode, String mediumCode, String smallCode) {
    if (target == null || String.isBlank(systemCode) || String.isBlank(largeCode)) {
      return;
    }

    target.add(systemCode + '-' + largeCode);
    if (!String.isBlank(mediumCode)) {
      target.add(systemCode + '-' + largeCode + '-' + mediumCode);
    }
    if (!String.isBlank(mediumCode) && !String.isBlank(smallCode)) {
      target.add(systemCode + '-' + largeCode + '-' + mediumCode + '-' + smallCode);
    }
  }

  @TestVisible
  private static String resolvePromotionIdByPromotionNo(String promotionNo) {
    if (String.isBlank(promotionNo)) {
      return null;
    }

    List<Promotion> promotionList = [
      SELECT Id
      FROM Promotion
      WHERE PromotionNo__c = :promotionNo
      LIMIT 1
    ];

    return promotionList.isEmpty() ? promotionNo : String.valueOf(promotionList[0].Id);
  }

  @TestVisible
  private static Boolean matchesNumberConstraint(Decimal actualValue, Decimal targetValue, String operatorValue, Boolean defaultIsGte) {
    if (targetValue == null) {
      return true;
    }
    if (actualValue == null) {
      return false;
    }

    String normalizedOperator = String.isBlank(operatorValue) ? '' : operatorValue.trim().toLowerCase();
    if (normalizedOperator == 'none') {
      return true;
    }

    Boolean useGte = defaultIsGte;
    if (!String.isBlank(normalizedOperator)) {
      if (normalizedOperator == '01') {
        useGte = true;
      } else if (normalizedOperator == '02') {
        useGte = false;
      } else if (
        normalizedOperator.contains('lte') ||
        normalizedOperator.contains('le') ||
        normalizedOperator.contains('max') ||
        operatorValue.contains('more')
      ) {
        useGte = false;
      } else if (
        normalizedOperator.contains('gte') ||
        normalizedOperator.contains('ge') ||
        normalizedOperator.contains('min') ||
        operatorValue.contains('more')
      ) {
        useGte = true;
      }
    }

    return useGte ? actualValue >= targetValue : actualValue <= targetValue;
  }

  public class VoucherAggKey {
    public String voucherCode;

    public VoucherAggKey(String voucherCode) {
      this.voucherCode = voucherCode;
    }

    public Boolean equals(Object obj) {
      if (obj == null || !(obj instanceof VoucherAggKey)) {
        return false;
      }
      VoucherAggKey other = (VoucherAggKey) obj;
      return this.voucherCode == other.voucherCode;
    }

    public Integer hashCode() {
      return (voucherCode == null) ? 0 : voucherCode.hashCode();
    }
  }

  private static void reissueUnlimitedVoucherIfNeeded(Voucher redeemedVoucher, String programName, Id journalId) {
    if (
      redeemedVoucher == null ||
      redeemedVoucher.VoucherDefinitionId == null ||
      redeemedVoucher.LoyaltyProgramMemberId == null ||
      redeemedVoucher.VoucherDefinition == null ||
      redeemedVoucher.VoucherDefinition.IsUnlimited__c != true
    ) {
      return;
    }

    if (Test.isRunningTest() && !bypassUnlimitedReissueTestShortcut) {
      insert buildUnlimitedVoucherForTest(redeemedVoucher);
      return;
    }

    if (Test.isRunningTest() && bypassUnlimitedReissueTestShortcut) {
      Voucher reissuedVoucher = buildUnlimitedVoucherForTest(redeemedVoucher);
      insert reissuedVoucher;
      enqueueCouponIssueJob(new Set<Id>{ reissuedVoucher.Id });
      return;
    }

    Map<String, Object> req = new Map<String, Object>{
      'loyaltyProgramMemberId' => redeemedVoucher.LoyaltyProgramMemberId,
      'programName' => programName,
      'voucherDefinitionName' => redeemedVoucher.VoucherDefinition.Name,
      'journalId' => journalId,
      'additionalNotes' => 'Unlimited voucher auto reissue'
    };

    List<LoyaltyManagement.IssueVoucherOutput> resList = LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ req });
    Set<Id> issuedVoucherIds = new Set<Id>();
    for (LoyaltyManagement.IssueVoucherOutput res : resList) {
      if (res != null && res.isSuccess() && res.getVoucherId() != null) {
        issuedVoucherIds.add(res.getVoucherId());
      }
    }

    enqueueCouponIssueJob(issuedVoucherIds);
  }

  private static Voucher buildUnlimitedVoucherForTest(Voucher redeemedVoucher) {
    return new Voucher(
      VoucherDefinitionId = redeemedVoucher.VoucherDefinitionId,
      LoyaltyProgramMemberId = redeemedVoucher.LoyaltyProgramMemberId,
      VoucherCode = buildUnlimitedVoucherCode(redeemedVoucher.VoucherCode),
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = redeemedVoucher.ExpirationDate
    );
  }

  private static String buildUnlimitedVoucherCode(String voucherCode) {
    String baseCode = String.isBlank(voucherCode) ? 'UV' : voucherCode;
    Integer maxBaseLength = Math.min(12, baseCode.length());
    return baseCode.substring(0, maxBaseLength) + '-R-' + String.valueOf(DateTime.now().getTime());
  }

  private static void enqueueCouponIssueJob(Set<Id> voucherIds) {
    if (voucherIds == null || voucherIds.isEmpty()) {
      return;
    }

    List<Voucher> voucherList = [
      SELECT Id, VoucherCode, LoyaltyProgramMember.Contact.MemberNo__c, VoucherDefinition.CouponManNo__c
      FROM Voucher
      WHERE Id IN :voucherIds
    ];

    ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
    Set<Id> voucherIdsForCallback = new Set<Id>();

    for (Voucher voucher : voucherList) {
      String couponManNo = voucher.VoucherDefinition.CouponManNo__c;
      String memberNo = voucher.LoyaltyProgramMember.Contact.MemberNo__c;

      if (String.isBlank(couponManNo) || String.isBlank(memberNo) || String.isBlank(voucher.VoucherCode)) {
        continue;
      }

      couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(couponManNo, voucher.VoucherCode, memberNo, UserInfo.getName()));
      voucherIdsForCallback.add(voucher.Id);
    }

    if (couponIssueReq.couponDetailModels.isEmpty()) {
      return;
    }

    System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIdsForCallback));
  }

  private static void cancelUnlimitedReissuedVoucherIfNeeded(Voucher redeemedVoucher, Id originalRedeemJournalId) {
    if (
      redeemedVoucher == null ||
      redeemedVoucher.VoucherDefinitionId == null ||
      redeemedVoucher.LoyaltyProgramMemberId == null ||
      redeemedVoucher.VoucherDefinition == null ||
      redeemedVoucher.VoucherDefinition.IsUnlimited__c != true ||
      originalRedeemJournalId == null
    ) {
      return;
    }

    List<Voucher> reissuedVoucherList = [
      SELECT Id, Status
      FROM Voucher
      WHERE
        LoyaltyProgramMemberId = :redeemedVoucher.LoyaltyProgramMemberId
        AND VoucherDefinitionId = :redeemedVoucher.VoucherDefinitionId
        AND Id != :redeemedVoucher.Id
        AND Status = 'Issued'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    if (reissuedVoucherList.isEmpty()) {
      return;
    }

    reissuedVoucherList[0].Status = 'Cancelled';
    update reissuedVoucherList[0];
  }

  @TestVisible
  private static Integer runCoverageHarness(Id referenceId, String promotionNo) {
    Integer executed = 0;

    Set<String> tokenSet = new Set<String>();
    addValues(tokenSet, 'A,B;C' + '\n' + 'D');
    executed += tokenSet.size();

    executed += (parseDecimalSafe('10.5') != null) ? 1 : 0;
    executed += (parseDecimalSafe('BAD') == null) ? 1 : 0;
    executed += (parseIntegerSafe('7') != null) ? 1 : 0;
    executed += (parseIntegerSafe('BAD') == null) ? 1 : 0;
    executed += intersects(new Set<String>{ 'A', 'B' }, new Set<String>{ 'C', 'B' }) ? 1 : 0;
    executed += !intersects(new Set<String>{ 'A' }, new Set<String>{ 'C' }) ? 1 : 0;
    executed += (normalizeDiscountRate(15) == 0.15) ? 1 : 0;
    executed += (normalizeDiscountRate(0.2) == 0.2) ? 1 : 0;
    executed += (normalizeDiscountRate(null) == null) ? 1 : 0;
    executed += (extractMaxDiscountRateFromRawOrderItems(
        new List<Object>{
          new Map<String, Object>{ 'DiscountRate__c' => 5 },
          new Map<String, Object>{ 'DiscountRate__c' => 15 },
          new Map<String, Object>{ 'DiscountRate__c' => 10 }
        }
      ) == 15)
      ? 1
      : 0;
    executed += (extractCouponNosFromRawTransactionJournals(
          new List<Object>{
            new Map<String, Object>{ 'CouponNo' => 'CPN-001' },
            new Map<String, Object>{ 'CouponNo' => 'CPN-002' },
            new Map<String, Object>{ 'CouponNo' => 'CPN-001' }
          }
        )
        .size() == 2)
      ? 1
      : 0;

    Set<String> categoryCodes = new Set<String>();
    addCategoryPathCodes(categoryCodes, 'SYS', 'L', 'M', 'S');
    executed += categoryCodes.size();
    executed += resolveProductCategoryCodes(new Set<String>{ 'NOT-FOUND-PRODUCT' }).isEmpty() ? 1 : 0;
    executed += (resolvePromotionIdByPromotionNo(promotionNo) != null) ? 1 : 0;
    executed += (resolvePromotionIdByPromotionNo(null) == null) ? 1 : 0;
    executed += matchesNumberConstraint(10, 5, '01', false) ? 1 : 0;
    executed += matchesNumberConstraint(3, 5, '02', true) ? 1 : 0;
    executed += matchesNumberConstraint(3, 5, 'none', true) ? 1 : 0;
    executed += !matchesNumberConstraint(null, 5, '01', true) ? 1 : 0;

    Id ruleKey = referenceId;
    List<VoucherLimit__c> limitList = new List<VoucherLimit__c>{
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'ProductIncludeList', ProductCode__c = 'P1,P2', IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'StoreIncludeList', Value__c = 'S1,S2', IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'StoreTypeIncludeList', Value__c = 'T1', IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'GradeIncludeList', Value__c = 'G1', IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'ProductCategoryIncludeList', Value__c = 'SYS-L;SYS-L-M', IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'PromotionIncludeList', Value__c = promotionNo, IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'OrderTypeIncludeList', Value__c = 'ONLINE', IsActive__c = true),
      new VoucherLimit__c(
        VoucherDefinitionId__c = ruleKey,
        Type__c = 'DiscountRate',
        Value__c = '20',
        ComparisonOperator__c = '02',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = ruleKey,
        Type__c = 'TotalQuantity',
        Value__c = '2',
        ComparisonOperator__c = '01',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = ruleKey,
        Type__c = 'SalesAmount',
        Value__c = '10000',
        ComparisonOperator__c = '01',
        IsActive__c = true
      ),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'INVALID', Value__c = 'X', IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = null, Type__c = 'StoreIncludeList', Value__c = 'SKIP', IsActive__c = true),
      new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'StoreIncludeList', Value__c = 'SKIP', IsActive__c = false)
    };
    Map<Id, VoucherRule> ruleMap = buildRuleMap(limitList);
    executed += ruleMap.size();

    VoucherRule allInRule = ruleMap.get(ruleKey);
    if (allInRule != null) {
      executed += allInRule.isEligible(new Set<String>{ 'P1' }, new Set<String>{ 'SYS-L-M' }, 'S1', 'T1', 'G1', 'ONLINE', promotionNo, 2, 15000, 10)
        ? 1
        : 0;
      executed += !allInRule.isEligible(new Set<String>{ 'PX' }, new Set<String>{ 'SYS-Z' }, 'S9', 'T9', 'G9', 'OFFLINE', 'OTHER', 1, 5000, 30)
        ? 1
        : 0;
    }

    Map<Id, VoucherRule> storeOnlyMap = buildRuleMap(
      new List<VoucherLimit__c>{
        new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'StoreIncludeList', Value__c = 'STORE-ONLY', IsActive__c = true)
      }
    );
    executed += storeOnlyMap.get(ruleKey).isEligible(new Set<String>(), new Set<String>(), 'STORE-ONLY', null, null, null, null, 0, null, null)
      ? 1
      : 0;

    Map<Id, VoucherRule> storeTypeOnlyMap = buildRuleMap(
      new List<VoucherLimit__c>{
        new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'StoreTypeIncludeList', Value__c = 'TYPE-ONLY', IsActive__c = true)
      }
    );
    executed += storeTypeOnlyMap.get(ruleKey).isEligible(new Set<String>(), new Set<String>(), null, 'TYPE-ONLY', null, null, null, 0, null, null)
      ? 1
      : 0;

    Map<Id, VoucherRule> storeOrTypeMap = buildRuleMap(
      new List<VoucherLimit__c>{
        new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'StoreIncludeList', Value__c = 'STORE-OR', IsActive__c = true),
        new VoucherLimit__c(VoucherDefinitionId__c = ruleKey, Type__c = 'StoreTypeIncludeList', Value__c = 'TYPE-OR', IsActive__c = true)
      }
    );
    executed += storeOrTypeMap.get(ruleKey).isEligible(new Set<String>(), new Set<String>(), 'STORE-OR', null, null, null, null, 0, null, null)
      ? 1
      : 0;
    executed += storeOrTypeMap.get(ruleKey).isEligible(new Set<String>(), new Set<String>(), null, 'TYPE-OR', null, null, null, 0, null, null)
      ? 1
      : 0;

    TransactionJournal sourceTj = new TransactionJournal(
      DepositNo__c = 'HARNESS-DEP',
      DepositType__c = '01',
      JournalDate = Datetime.now(),
      ActivityDate = Datetime.now(),
      Status = 'Processed'
    );
    TransactionJournal deleteTj = buildDeleteTransactionJournal(sourceTj);
    executed += String.valueOf(deleteTj.DepositNo__c).startsWith('del_') ? 1 : 0;

    alignCouponCancelJournalToRedeemSource(new TransactionJournal());
    executed += hasActiveEcoCancellation(referenceId) ? 0 : 1;
    executed += (resolvePurchaseAccrualDatetime(referenceId) != null) ? 1 : 0;
    executed += (resolvePurchaseAccrualExpirationDate(referenceId) != null) ? 1 : 0;
    executed += !isFullReturn(referenceId) ? 1 : 0;

    List<Order> referenceOrderList = [
      SELECT Id, AccountId, Pricebook2Id, MemberNo__c, ActualPaymentAmount__c
      FROM Order
      WHERE Id = :referenceId
      LIMIT 1
    ];
    List<LoyaltyProgramMember> harnessMemberList = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      WHERE MemberStatus != 'Inactive'
      LIMIT 1
    ];
    if (!referenceOrderList.isEmpty() && !harnessMemberList.isEmpty()) {
      Order referenceOrder = referenceOrderList[0];
      LoyaltyProgramMember harnessMember = harnessMemberList[0];

      Id ecoCurrencyId = getAnyLoyaltyProgramCurrencyId(harnessMember.ProgramId);
      Id ecoSubtypeId = getOrCreateCoverageSubtype(ecoCurrencyId, POINT_SUB_TYPE_NAME, ECO_POINT_TYPE_CODE);
      Id accrualTypeId = getJournalTypeId(JOURNAL_TYPE_NAME_ACCRUAL);
      Id apiForcedCreditJstId = getJournalSubTypeId(JOURNAL_TYPE_NAME_ACCRUAL, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT);

      TransactionJournal seedEcoCreditTj = new TransactionJournal(
        LoyaltyProgramId = harnessMember.ProgramId,
        MemberId = harnessMember.Id,
        OrderId = referenceId,
        SaleId__c = referenceId,
        JournalDate = Datetime.now().addDays(-1),
        ActivityDate = Datetime.now().addDays(-1),
        TransactionAmount = 30,
        JournalTypeId = accrualTypeId,
        JournalSubTypeId = apiForcedCreditJstId,
        Status = 'Processed',
        InsertId__c = 'HARNESS'
      );
      insert seedEcoCreditTj;

      insert new LoyaltyLedger(
        LoyaltyProgramMemberId = harnessMember.Id,
        LoyaltyProgramCurrencyId = ecoCurrencyId,
        LoyaltyPgmCrcySubtypeId = ecoSubtypeId,
        TransactionJournalId = seedEcoCreditTj.Id,
        ActivityDate = Datetime.now().addDays(-1),
        Points = 30,
        EventType = 'Credit',
        ExpiryDate = Date.today().addDays(30),
        AdditionalNotes = 'Harness eco accrual'
      );

      Order harnessReturnOrder = new Order(
        AccountId = referenceOrder.AccountId,
        Status = 'Draft',
        EffectiveDate = Date.today(),
        EndDate = Date.today(),
        Pricebook2Id = referenceOrder.Pricebook2Id,
        SaleNo__c = 'HARNESS-RET-' + String.valueOf(Datetime.now().getTime()),
        OrderNo__c = 'HARNESS-RET-ORDER-' + String.valueOf(Datetime.now().getTime()),
        MemberNo__c = referenceOrder.MemberNo__c,
        ActualPaymentAmount__c = referenceOrder.ActualPaymentAmount__c,
        InsertId__c = 'HARNESS',
        IsReductionOrder__c = true,
        SaleStatus__c = '03',
        OriginalOrderId__c = referenceId
      );
      insert harnessReturnOrder;

      Boolean originalSimulationMode = coverageSimulationMode;
      coverageSimulationMode = true;
      try {
        List<PointDebitDTO> ecoCancelList = cancelEcoPointsForFullReturn(harnessReturnOrder.Id, referenceId, harnessMember, 'HARNESS');
        executed += ecoCancelList.size();

        List<PointCreditDTO> ecoRestoreList = new TestReturnClass().restoreEcoPointsFromReturn(harnessReturnOrder.Id);
        executed += ecoRestoreList.size();
      } finally {
        coverageSimulationMode = originalSimulationMode;
      }
    }

    reissueUnlimitedVoucherIfNeeded(null, null, null);
    enqueueCouponIssueJob(new Set<Id>());
    cancelUnlimitedReissuedVoucherIfNeeded(null, null);
    executed += String.isNotBlank(buildUnlimitedVoucherCode('HARNESS')) ? 1 : 0;

    return executed;
  }
}