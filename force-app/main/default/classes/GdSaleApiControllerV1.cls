/**
 * 판매 등록, 수정, 전체 삭제에 관한 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 */
@RestResource(urlMapping='/gd/v1/sale')
global with sharing class GdSaleApiControllerV1 {
  private static GdOrderService orderService;
  private static GdSaleService saleService;
  private static GdOrderItemService orderItemService;
  private static GdSaleItemService saleItemService;
  private static GdVoucherService voucherService;
  private static GdSaleDepositService saleDepositService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setOrderService(GdOrderService mock) {
    orderService = mock;
  }

  private static GdOrderService getOrderService() {
    if (orderService == null) {
      orderService = new GdOrderServiceImpl();
    }
    return orderService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setSaleService(GdSaleService mock) {
    saleService = mock;
  }

  private static GdSaleService getSaleService() {
    if (saleService == null) {
      saleService = new GdSaleServiceImpl();
    }
    return saleService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setOrderItemService(GdOrderItemService mock) {
    orderItemService = mock;
  }

  private static GdOrderItemService getOrderItemService() {
    if (orderItemService == null) {
      orderItemService = new GdOrderItemServiceImpl();
    }
    return orderItemService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setSaleItemService(GdSaleItemService mock) {
    saleItemService = mock;
  }

  private static GdSaleItemService getSaleItemService() {
    if (saleItemService == null) {
      saleItemService = new GdSaleItemServiceImpl();
    }
    return saleItemService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  @TestVisible
  private static GdVoucherService getVoucherService() {
    if (voucherService == null) {
      voucherService = new GdVoucherServiceImpl();
    }
    return voucherService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setSaleDepositService(GdSaleDepositService mock) {
    saleDepositService = mock;
  }

  private static GdSaleDepositService getSaleDepositService() {
    if (saleDepositService == null) {
      saleDepositService = new GdSaleDepositServiceImpl();
    }
    return saleDepositService;
  }

  /**
   * 판매 등록
   * @throws CustomException
   */
  @HttpPost
  global static void createSale() {
    System.debug('판매 등록 입니다.');
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdSaleApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    logger.setMethod(String.isBlank(req.httpMethod) ? 'POST' : req.httpMethod);
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      {
        // Order 생성

        ApiResult orderResult = getOrderService().createSale(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
        reqData.put('storeTypeFour', orderResult.data.get('storeTypeFour'));
        reqData.put('storeType', orderResult.data.get('storeType'));
      }

      {
        // OrderItem 생성
        ApiResult orderItemResult = getOrderItemService().createSaleItem(reqData);
        reqData.put('oiList', orderItemResult.data.get('oiList'));
      }

      {
        // TransactionJournal 생성 - 입금 내역
        ApiResult transactionJournalResult = getSaleDepositService().createSaleDepositHistory(reqData);
        if (transactionJournalResult.data.containsKey('DebitPointList')) {
          resData.put('DebitPointList', transactionJournalResult.data.get('DebitPointList'));
        }
        if (transactionJournalResult.data.containsKey('CreditPointList')) {
          resData.put('CreditPointList', transactionJournalResult.data.get('CreditPointList'));
        }
      }

      Id orderId = (Id) reqData.get('orderId');
      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        logger.setErrorCode('ORDER_NOT_FOUND');
        logger.setErrorMessage('order is not found');
        throw new CustomException(400, 'order is not found');
      }
      oList[0].Status = 'saleSuccess';
      Database.SaveResult updateResult = Database.update(oList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }

      ApiResult result = ApiResult.ok(200, '판매 등록 완료', resData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }

  /**
   * 판매 수정
   * @throws CustomException
   */
  @HttpPatch
  global static void updateSale() {
    System.debug('판매 수정 입니다.');

    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdSaleApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    logger.setMethod(String.isBlank(req.httpMethod) ? 'PATCH' : req.httpMethod);
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // === [Option C — 변경 전 ActualPaymentAmount 캡처] ===
      // 옛 판매 수정 시 적립 차이 자동 조정 (Phase 6.6) 을 위해 변경 전 금액 보관.
      // SOQL 1회 추가만, 표준 service 흐름에 영향 없음.
      String saleNoForBranchCapture = (String) reqData.get('SaleNo__c');
      Decimal optCOldAmount = null;
      if (String.isNotBlank(saleNoForBranchCapture)
          && GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(saleNoForBranchCapture)) {
        try {
          List<Order> preUpdate = [
            SELECT ActualPaymentAmount__c FROM Order WHERE SaleNo__c = :saleNoForBranchCapture LIMIT 1
          ];
          if (!preUpdate.isEmpty()) {
            optCOldAmount = preUpdate[0].ActualPaymentAmount__c;
          }
        } catch (Exception e) {
          System.debug('OptC pre-update capture exception: ' + e.getMessage());
        }
      }

      {
        // Order update
        ApiResult orderResult = getOrderService().updateSale(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
      }

      {
        // OrderItem upsert
        if (reqData.containsKey('OrderItem')) {
          ApiResult orderItemResult = getOrderItemService().upsertSaleItem(reqData);
        }
      }

      {
        // TransactionJournal insert
        if (reqData.containsKey('TransactionJournal')) {
          // ApiResult saleDepositResult = getSaleDepositService().upsertSaleDeposit(reqData);
          // ApiResult saleDepositResult = getSaleDepositService().upsertSaleDepositV2(reqData); // 기존
          ApiResult saleDepositResult = getSaleDepositService().upsertSaleDepositV3(reqData); // 신규 (2026-05-10 CS)
          if (saleDepositResult.data.containsKey('CancelPointList')) {
            resData.put('CancelPointList', saleDepositResult.data.get('CancelPointList'));
          }
          if (saleDepositResult.data.containsKey('DebitPointList')) {
            resData.put('DebitPointList', saleDepositResult.data.get('DebitPointList'));
          }
          if (saleDepositResult.data.containsKey('CreditPointList')) {
            resData.put('CreditPointList', saleDepositResult.data.get('CreditPointList'));
          }
        }
      }

      ApiResult result = ApiResult.ok(200, '판매 수정 완료', reqData);

      // === [Option C 분기 wrap] 옛 판매 수정 시 응답 enrich + 적립 차이 자동 조정 ===
      // IsEnabled=false 또는 신규 거래 시 false → wrap 안 함 (표준 응답 그대로)
      String saleNoForBranchCheck = (String) reqData.get('SaleNo__c');
      if (GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(saleNoForBranchCheck)) {
        result = GdSalePatchBranchHandler.wrapResponseForOldSale(
          result, saleNoForBranchCheck, optCOldAmount, logger
        );
      }

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }

  /**
   * 판매 전체 삭제
   * Order update
   */
  @HttpDelete
  global static void deleteSale() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdSaleApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Map<String, Object> resData = new Map<String, Object>();
    Savepoint sp = Database.setSavepoint();
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String saleNo = ValidationUtil.stringValidationEx(req.params.get('SaleNo__c'), 'SaleNo__c', true, false);

      // Order update
      ApiResult saleResult = getSaleService().deleteSale(saleNo);

      Id orderId = (Id) ValidationUtil.stringValidationEx(saleResult.data.get('orderId'), 'orderId', true, false);

      // OrderItem update
      getSaleItemService().deleteSaleItem(orderId);

      /* 기존 로직
      // 판매 입금 전체 삭제 할 때 입금 건들에 대한 포인트 사용 취소, 포인트 적립 취소 로직이 필요함
      ApiResult saleDepositResult = getSaleDepositService().deleteAllSaleDeposits(orderId);

      resData.put('CancelPointList', saleDepositResult.data.get('pointRedemptionCanceled'));
      resData.put('CancelPointsCreditedList', saleDepositResult.data.get('purchasePointAccrualCanceled'));
      resData.put('CancelCoupon', saleDepositResult.data.get('couponCanceled'));
      */

      // 신규 로직 start.

      // [Feature Flag 분기 — 2026-05-05] EcoPointCancel_UseSpecificLedger ON 시 신규 경로 사용
      // 신규 경로: 자기 판매(orderId) 의 에코 적립 LL 만 직접 가리키는 Debit LL/Trace 수동 생성
      // Flag OFF: 기존 표준 LMS debitPoints() FIFO 경로 그대로 (회귀 영향 없음)
      // 결함: 표준 FIFO 가 다른 판매(예: 직전 판매) 의 에코 적립 LL 을 끌어다 차감 →
      //       Credit=다른판매 / Debit=현재판매 형태의 잘못된 LLT 발생 → 다른 판매 삭제 차단
      // * 현재 Flag On 상태
      if (GdFeatureFlag.isEnabled('EcoPointCancel_UseSpecificLedger')) {
        // 회원 조회 (lpm 객체 필요)
        List<LoyaltyProgramMember> lpmList = [
          SELECT Id, ProgramId
          FROM LoyaltyProgramMember
          WHERE ContactId IN (SELECT MemberNo__c FROM Order WHERE Id = :orderId)
          LIMIT 1
        ];
        if (!lpmList.isEmpty()) {
          List<PointDebitDTO> ecoCancelList = GdReturnDepositServiceImpl.cancelEcoPointsForSaleDelete(
            orderId, lpmList[0], 'SALE_DELETE'
          );
          if (ecoCancelList != null && !ecoCancelList.isEmpty()) {
            resData.put('CancelPointList', ecoCancelList);
          }
        }
        // Flag ON 경로 종료 — 기존 블록 (아래) 으로 진입하지 않음
      } else {

      Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, 'Accrual', true);
      Id apiForcedCreditJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, 'Api Forced Credit', true);

      // 판매에서 에코포인트 적립된 LoyaltyLedger 조회
      List<LoyaltyLedger> ecoCreditLedgerList = [
        SELECT Id, Points, LoyaltyPgmCrcySubtype.Name, TransactionJournal.LoyaltyProgramId, LoyaltyProgramMemberId
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.OrderId = :orderId
          AND TransactionJournal.JournalTypeId = :accrualJtId
          AND TransactionJournal.JournalSubTypeId = :apiForcedCreditJstId
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c = '05'
          AND EventType = 'Credit'
        LIMIT 200
      ];
      if (!ecoCreditLedgerList.isEmpty()) {
        Set<Id> creditLedgerIdSet = new Set<Id>();
        for (LoyaltyLedger ll : ecoCreditLedgerList) {
          creditLedgerIdSet.add(ll.Id);
        }

        // 지급된 에코포인트가 사용 추적 조회
        Map<Id, Integer> usedPointByCreditLedgerId = new Map<Id, Integer>();
        for (LoyaltyLedgerTraceability llt : [
          SELECT CreditLoyaltyLedgerId, Points, ActionType
          FROM LoyaltyLedgerTraceability
          WHERE CreditLoyaltyLedgerId IN :creditLedgerIdSet
          LIMIT 2000
        ]) {
          // 사용한 금액
          Integer current = usedPointByCreditLedgerId.containsKey(llt.CreditLoyaltyLedgerId)
            ? usedPointByCreditLedgerId.get(llt.CreditLoyaltyLedgerId)
            : 0;

          System.debug('에코포인트 사용한 금액 : ' + current);

          // 사용한 금액 || 적립 취소 금액
          if (llt.ActionType == 'Debit' || llt.ActionType == 'CreditCancellation') {
            current += (Integer) llt.Points;
          }
          usedPointByCreditLedgerId.put(llt.CreditLoyaltyLedgerId, current);
        }

        // 취소할 금액
        Integer remainingPoint = 0; // 취소할 금액
        for (LoyaltyLedger ecoLedger : ecoCreditLedgerList) {
          // 사용한 금액
          Integer usedPoint = usedPointByCreditLedgerId.containsKey(ecoLedger.Id) ? usedPointByCreditLedgerId.get(ecoLedger.Id) : 0;
          // 취소할 금액
          remainingPoint = (Integer) ecoLedger.Points - (Integer) usedPoint;
          System.debug('에코포인트 취소할 금액 : ' + remainingPoint);
        }

        if (remainingPoint > 0) {
          // 저널 유형 체크
          Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, 'Redemption', true);
          // 저날 하위 유형 체크
          Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => 'Api Forced Debit', 'JournalTypeId' => jtId };
          Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

          // 취소할 거래 이력 생성
          TransactionJournal ecoCancelTj = new TransactionJournal();
          ecoCancelTj.DepositNo__c = 'ECO-' + String.valueOf(orderId);
          ecoCancelTj.DeposiSeqNo__c = '1';
          ecoCancelTj.JournalDate = Datetime.now();
          ecoCancelTj.ActivityDate = Datetime.now();
          ecoCancelTj.LoyaltyProgramId = ecoCreditLedgerList[0].TransactionJournal.LoyaltyProgramId;
          ecoCancelTj.MemberId = ecoCreditLedgerList[0].LoyaltyProgramMemberId;
          ecoCancelTj.OrderId = orderId;
          ecoCancelTj.SaleId__c = orderId;
          ecoCancelTj.AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL';
          ecoCancelTj.transactionAmount = remainingPoint;
          ecoCancelTj.JournalReason__c = '1'; // 1 : 사용
          ecoCancelTj.JournalTypeId = jtId;
          ecoCancelTj.JournalSubTypeId = jstId;
          ecoCancelTj.Status = 'Pending';

          insert ecoCancelTj;

          List<Map<String, Object>> debitPointsReqList = new List<Map<String, Object>>();
          Map<String, Object> debitPointsReq = new Map<String, Object>();
          debitPointsReq.put('loyaltyProgramMemberId', ecoCancelTj.MemberId);
          debitPointsReq.put('points', remainingPoint);
          debitPointsReq.put('journalId', ecoCancelTj.Id);
          debitPointsReq.put('loyaltyProgramCurrencySubtypeName', '에코포인트');
          debitPointsReqList.add(debitPointsReq);

          List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(debitPointsReqList);

          System.debug('여기까지 진입');

          // 포인트 사용 추적 조회
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
            throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + ecoCancelTj.Id);
          }

          List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
          for (LoyaltyLedgerTraceability llt : lltList) {
            PointDebitDTO pcDto = new PointDebitDTO();
            pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
            pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // ecoCancelTj.Id; -> llt.CreditLoyaltyLedgerId;
            pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
            pcDto.CD_RESON = ecoCancelTj.JournalReason__c;
            pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
            if (String.isNotBlank(ecoCancelTj.Order.OrderNo__c)) {
              pcDto.NO_SAL = ecoCancelTj.Order.OrderNo__c; // 주문 번호
            } else if (String.isNotBlank(ecoCancelTj.Order.SaleNo__c)) {
              pcDto.NO_SAL = ecoCancelTj.Order.SaleNo__c; // 판매 번호
            }
            pcDto.PT_USE = llt.Points; // 사용처리된 금액
            pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 사용처리된 금액

            pdDtoList.add(pcDto);
          }

          resData.put('CancelPointList', pdDtoList);
        }
      }
      } // [Feature Flag 분기 — 2026-05-05] else (Flag OFF) 블록 종료
      // 신규 로직 end.

      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        logger.setErrorCode('ORDER_NOT_FOUND');
        logger.setErrorMessage('order is not found');
        throw new CustomException(400, 'order is not found');
      }
      oList[0].Status = 'saleDeleted';
      Database.SaveResult updateResult = Database.update(oList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }

      ApiResult result = ApiResult.ok(200, '판매 전체 삭제 완료', resData);

      // === [Option C 분기 wrap] 옛 판매 삭제 시 응답 enrich ===
      // IsEnabled=false 또는 신규 거래 시 false → wrap 안 함 (표준 응답 그대로)
      if (GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(saleNo)) {
        result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(result, saleNo, logger);
      }

      RestResponseUtil.handleSuccess(result, logger);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }
}