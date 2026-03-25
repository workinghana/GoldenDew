/**
 * 판매/교환 반품 관련 API 컨트롤러 V1
 */
@RestResource(urlMapping='/gd/v1/return')
global with sharing class GdReturnApiControllerV1 {
  private static GdReturnService returnService;
  private static GdReturnItemService returnItemService;
  private static GdReturnDepositService returnDepositService;

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

      {
        // 반품 처리
        ApiResult orderResult = getReturnService().createReturn(reqData);
        reqData.put('orderId', orderResult.data.get('orderId'));
        reqData.put('originalOrderId', orderResult.data.get('originalOrderId'));
      }

      {
        // 반품 상세 처리
        if (reqData.containsKey('OrderItem')) {
          ApiResult orderItemResult = getReturnItemService().createReturnItem(reqData);
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

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        logger.setErrorCode('ORDER_UPDATE_FAILED');
        logger.setErrorMessage(err.getMessage());
        throw new CustomException(400, err.getMessage());
      }
      // Order Status 값 수정 End.

      ApiResult result = ApiResult.ok(200, '반품 등록 완료', resData);

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
      Id orderId = (Id) ValidationUtil.stringValidationEx(returnResult.data.get('orderId'), 'orderId', true, false);

      // 반품 상세 삭제
      getReturnItemService().deleteReturnItem(orderId);

      // 반품 입금 전체 삭제
      getReturnDepositService().deleteAllReturnDeposits(orderId);

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