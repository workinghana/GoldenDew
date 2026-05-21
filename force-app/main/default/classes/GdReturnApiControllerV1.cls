/**
 * 판매/교환 반품 관련 API 컨트롤러 V1
 */
@RestResource(urlMapping='/gd/v1/return')
global with sharing class GdReturnApiControllerV1 {
  private static GdReturnService returnService;
  private static GdReturnItemService returnItemService;
  private static GdReturnDepositService returnDepositService;
  private static GdPointService pointService;

  private static void logTiming(String label, Long startMs, Integer startCpu) {
    Long elapsedMs = Datetime.now().getTime() - startMs;
    Integer elapsedCpu = Limits.getCpuTime() - startCpu;
    System.debug(LoggingLevel.WARN, '[TIMING] ' + label + ' | 누적 ' + elapsedMs + 'ms | CPU ' + elapsedCpu + 'ms');
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setReturnService(GdReturnService mock) {
    returnService = mock;
  }

  private static GdReturnService getReturnService() {
    if (returnService == null) {
      returnService = new GdReturnServiceImpl();
    }
    return returnService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setReturnItemService(GdReturnItemService mock) {
    returnItemService = mock;
  }

  private static GdReturnItemService getReturnItemService() {
    if (returnItemService == null) {
      returnItemService = new GdReturnItemServiceImpl();
    }
    return returnItemService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setReturnDepositService(GdReturnDepositService mock) {
    returnDepositService = mock;
  }

  private static GdReturnDepositService getReturnDepositService() {
    if (returnDepositService == null) {
      returnDepositService = new GdReturnDepositServiceImpl();
    }
    return returnDepositService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setPointService(GdPointService mock) {
    pointService = mock;
  }

  private static GdPointService getPointService() {
    if (pointService == null)
      pointService = new GdPointServiceImpl();
    return pointService;
  }

  /**
   * [판매반품, 교환반품] 반품 등록 API
   */
  @HttpPost
  global static void createReturn() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdReturnApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
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
      Map<String, Object> resData = new Map<String, Object>();
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // * 신규 로직 (26.05.21 CS) Start.
      Object transactionJournalValue = reqData.get('TransactionJournal');
      Boolean isTransactionJournalEmpty =
        !reqData.containsKey('TransactionJournal') ||
        transactionJournalValue == null ||
        (transactionJournalValue instanceof List<Object> && ((List<Object>) transactionJournalValue).isEmpty()) ||
        (transactionJournalValue instanceof Map<String, Object> && ((Map<String, Object>) transactionJournalValue).isEmpty());
      if (isTransactionJournalEmpty) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('입금 내역이 비어 있습니다. 입금 내역 등록 후 저장해주시기 바랍니다.');
        throw new CustomException(400, '입금 내역이 비어 있습니다. 입금 내역 등록 후 저장해주시기 바랍니다.');
      }
      // * 신규 로직 (26.05.21 CS) End.

      logTiming('GdReturnApiControllerV1.createReturn.parseRequest', totalStartMs, totalStartCpu);

      // === [기본 정책 검증] 환불 한도 / 데이터 결함 차단 (옛/신규 모두) ===
      // 누계 환불 + 이번 시도 > 원판매 금액 시 400 throw (기본 정책 위반)
      GdReturnBranchHandler.validateReturnAmountWithinPolicy(reqData);

      // === [Option C 분기 flag — 표준 로직 후 응답 wrap 용] ===
      // IsEnabled=false 또는 신규 거래 시 false → wrap 없이 표준 응답 그대로
      Boolean shouldBranchOptC = GdMigrationUtil.shouldApplyOptionCBranchBySaleNo((String) reqData.get('OriginalOrderId'));

      {
        // 반품 처리
        ApiResult orderResult = getReturnService().createReturn(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
        reqData.put('originalOrderId', orderResult.data.get('originalOrderId'));
        logTiming('GdReturnApiControllerV1.createReturn.createReturn', totalStartMs, totalStartCpu);
      }

      {
        // 반품 상세 처리
        if (reqData.containsKey('OrderItem')) {
          ApiResult orderItemResult = getReturnItemService().createReturnItem(reqData);
          logTiming('GdReturnApiControllerV1.createReturn.createReturnItem', totalStartMs, totalStartCpu);
        }
      }

      {
        // 반품 입금 처리
        if (reqData.containsKey('TransactionJournal')) {
          ApiResult returnDepositResult = getReturnDepositService().insertSaleDepositHistoryByUpdate(reqData);
          // 포인트 사용 취소 내역
          if (returnDepositResult.data.containsKey('CancelPointList')) {
            resData.put('CancelPointList', returnDepositResult.data.get('CancelPointList'));
          }
          // 포인트 사용 내역
          if (returnDepositResult.data.containsKey('DebitPointList')) {
            resData.put('DebitPointList', returnDepositResult.data.get('DebitPointList'));
          }
          // 포인트 적립 내역
          if (returnDepositResult.data.containsKey('CreditPointList')) {
            resData.put('CreditPointList', returnDepositResult.data.get('CreditPointList'));
          }
          // 포인트 적립 취소 내역
          if (returnDepositResult.data.containsKey('CancelPointsCreditedList')) {
            resData.put('CancelPointsCreditedList', returnDepositResult.data.get('CancelPointsCreditedList'));
          }
          logTiming('GdReturnApiControllerV1.createReturn.insertSaleDepositHistoryByUpdate', totalStartMs, totalStartCpu);
        }
      }

      // Order Status 값 수정 Start.
      Id orderId = (Id) reqData.get('orderId');
      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        logger.setErrorCode('ORDER_NOT_FOUND');
        logger.setErrorMessage('order is not found');
        throw new CustomException(400, 'order is not found');
      }
      oList[0].Status = 'returnSuccess';
      Database.SaveResult updateResult = Database.update(oList[0]);
      logTiming('GdReturnApiControllerV1.createReturn.updateOrderStatus', totalStartMs, totalStartCpu);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }
      // Order Status 값 수정 End.

      ApiResult result = ApiResult.ok(200, '반품 등록 완료', resData);

      // === [Option C 분기 wrap — silent fail 감지 시 응답 enrich] ===
      // shouldBranchOptC=true 시만 호출. 표준 로직 후 CancelPointsCreditedList null 검사.
      // 미감지 시 result 그대로 반환.
      if (shouldBranchOptC) {
        result = GdReturnBranchHandler.wrapResponseIfSilentFail(result, reqData, logger);
      }

      logTiming('GdReturnApiControllerV1.createReturn.total', totalStartMs, totalStartCpu);
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
   * * 개발 완료
   * [판매반품, 교환반품] 전체 삭제 API
   * 반품 전체 삭제
   */
  @HttpDelete
  global static void deleteReturn() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdReturnApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Map<String, Object> resData = new Map<String, Object>();
    Savepoint sp = Database.setSavepoint();
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String saleNo = ValidationUtil.stringValidationEx(req.params.get('SaleNo__c'), 'SaleNo__c', true, false);

      // 반품 삭제
      ApiResult returnResult = getReturnService().deleteReturn(saleNo);
      Id orderId = (Id) ValidationUtil.stringValidationEx(returnResult.data.get('orderId'), 'orderId', true, false); // 반품 Id

      // 반품 상세 삭제
      getReturnItemService().deleteReturnItem(orderId);

      // [반품 삭제 시 적립 복원 fix 2026-05-15]
      //   배경: 기존 deleteReturn 흐름이 restoreEcoPointsFromReturn (에코) 만 호출하여 Purchase Accrual
      //         (구매/사은 적립) 의 취소 TJ 가 그대로 살아있는 결함. 재반품 시 중복 Cancel Purchase Accrual
      //         발행되어 회원 잔액이 음수가 됨 (회원 269999800255: LMC -36000P).
      //   해결: 주석 처리되어 비활성화 되어 있던 deleteAllReturnDeposits 호출 활성화.
      //         deleteAllReturnDeposits 내부에서 각 반품 입금 TJ 별로 처리:
      //           - Cancel Purchase Accrual → creditSepcificPoints 로 적립 복원
      //           - Point Redeem Cancel → RESTORE Debit 로 Cancel Credit 재소비
      //           - Coupon Redeem Cancel → 쿠폰 사용 재발행
      //           - 모든 TJ IsDel=true 처리
      //         단 Api Forced Debit 에코 cancel TJ 는 deleteAllReturnDeposits 분기 매칭 안 됨
      //         (cancelPurchaseAccrualJstId 등 아님) → IsDel 만 처리. 그래서 별도로
      //         restoreEcoPointsFromReturn 호출 유지 필요 (SOQL IsDel 필터 없으므로 순서 무관).
      // 반품 입금 전체 삭제 (Purchase Accrual 복원 포함)
      // getReturnDepositService().deleteAllReturnDeposits(orderId);

      // 에코포인트 적립 취소 건 복원 Start.
      List<PointCreditDTO> ecoRestore = getPointService().restoreEcoPointsFromReturn(orderId);
      resData.put('CancelPointList', ecoRestore);
      // Id apiForcedDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, 'Api Forced Debit', true); // api 요청에 의한 강제 차감

      // List<TransactionJournal> tjList = [
      //   SELECT
      //     Id,
      //     JournalSubTypeId,
      //     PaymentMethod,
      //     TransactionAmount,
      //     OrderId,
      //     LoyaltyProgramId,
      //     MemberId,
      //     SaleId__c,
      //     DepositNo__c,
      //     IsDeleted__c,
      //     DeleteDateTime__c,
      //     VoucherCode,
      //     JournalDate,
      //     Order.EndDate,
      //     InsertId__c,
      //     Order.ActualPaymentAmount__c,
      //     Promotion.PromotionNo__c,
      //     AdditionalNotes__c
      //   FROM TransactionJournal
      //   WHERE SaleId__c = :orderId AND AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL' AND JournalSubTypeId = :apiForcedDebitJstId
      //   LIMIT 1
      // ];

      // if (!tjList.isEmpty()) {
      //   List<PointCreditDTO> ecoRestoreResult = restoreEcoPointsFromReturn(newTj, sourceTj.Id);
      //   if (!ecoRestoreResult.isEmpty()) {
      //     data.put(ECO_POINT_RESTORE_RESULT_KEY, ecoRestoreResult);
      //   }
      // }
      // 에코포인트 적립 취소 건 복원 End.

      List<Order> oList = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        logger.setErrorCode('ORDER_NOT_FOUND');
        logger.setErrorMessage('order is not found');
        throw new CustomException(400, 'order is not found');
      }
      oList[0].Status = 'returnDeleted'; // returnDeleted = 반품 삭제
      Database.SaveResult updateResult = Database.update(oList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }

      ApiResult result = ApiResult.ok(200, '[판매반품, 교환반품] 전체 삭제 완료', resData);

      // === [Option C 분기 wrap] 옛 환불 취소 시 자동 복원 (Phase 6.8) ===
      // 분기 판별: 환불 Order 자체가 아니라 OriginalOrderId (원판매) 의 SaleNo 로 판별.
      // (옛 판매에 대한 환불이라면 환불 Order 가 신규 거래라도 자동 복원 대상)
      try {
        List<Order> rtnOrderList = [
          SELECT OriginalOrderId__c, OriginalOrderId__r.SaleNo__c
          FROM Order
          WHERE Id = :orderId
          LIMIT 1
        ];
        String origSaleNo = (!rtnOrderList.isEmpty() && rtnOrderList[0].OriginalOrderId__r != null)
          ? rtnOrderList[0].OriginalOrderId__r.SaleNo__c
          : null;
        if (String.isNotBlank(origSaleNo) && GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(origSaleNo)) {
          result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(result, saleNo, logger);
        }
      } catch (Exception e) {
        System.debug('OptC deleteReturn branch check exception: ' + e.getMessage());
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

  // ! 사용 X
  // @HttpGet
  global static void doGet() {
    RestRequest req = RestContext.request;
    try {
      String subPath = req.requestURI.substringAfter('/gd/v1/return/');
      String saleNo = ValidationUtil.stringValidationEx(req.params.get('SaleNo__c'), 'SaleNo__c', true, false); // 반품 번호

      if ('coupon'.equals(subPath)) {
        ApiResult result = ApiResult.ok(200, '반품 쿠폰 조회 성공', null);

        RestResponseUtil.handleSuccess(result);
      } else if ('point'.equals(subPath)) {
        ApiResult result = ApiResult.ok(200, '반품 포인트 조회 성공', null);

        RestResponseUtil.handleSuccess(result);
      } else {
        throw new CustomException(500, 'subPath is not found');
      }
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500);
    }
  }
}