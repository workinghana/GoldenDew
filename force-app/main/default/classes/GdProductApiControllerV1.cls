@RestResource(urlMapping='/gd/v1/product')
global with sharing class GdProductApiControllerV1 {
  private static GdProductService productService;
  private static GdPricebookEntryService pricebookEntryService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setProductService(GdProductService mock) {
    productService = mock;
  }

  private static GdProductService getProductService() {
    if (productService == null) {
      productService = new GdProductServiceImpl();
    }
    return productService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setPricebookEntryService(GdPricebookEntryService mock) {
    pricebookEntryService = mock;
  }

  private static GdPricebookEntryService getPricebookEntryService() {
    if (pricebookEntryService == null) {
      pricebookEntryService = new GdPricebookEntryServiceImpl();
    }
    return pricebookEntryService;
  }

  /**
   * 품목 등록
   * Product2, PricebookEntry create
   */
  @HttpPost
  global static void createProduct() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdProductApiControllerV1.class.getName());

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
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(500, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      {
        // Product2 생성
        ApiResult productResult = getProductService().createProduct(reqData);
        reqData.put('productId', productResult.data.get('productId'));
      }

      {
        // PricebookEntry 생성
        ApiResult pricebookEntryResult = getPricebookEntryService().createPricebookEntryByProduct2(reqData);
      }

      ApiResult result = ApiResult.ok(200, '품목 등록 완료', reqData);

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
   * 품목 수정
   * Product2, PricebookEntry update
   */
  @HttpPatch
  global static void updateProduct() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdProductApiControllerV1.class.getName());

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
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(500, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      {
        // Product2 update
        ApiResult productResult = getProductService().updateProduct(reqData);
        reqData.put('productId', productResult.data.get('productId'));
      }

      {
        // PricebookEntry update
        ApiResult pricebookEntryResult = getPricebookEntryService().updatePricebookEntryByProduct2(reqData);
      }

      ApiResult result = ApiResult.ok(200, '품목 수정 완료', reqData);

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
}