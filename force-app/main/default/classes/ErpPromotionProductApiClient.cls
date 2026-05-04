/**
 * ERP Promotion Product API Client
 * - CommonApiClient 기반
 * - 토큰 캐시/401 갱신 로직은 CommonApiClient + NamedCredentialTokenRefresher에 위임
 *
 * @author Changhwan Kim
 * @since 2026-02-04
 */
public with sharing class ErpPromotionProductApiClient {
  // =========================
  // Config
  // =========================
  private static final String ERP_NC = 'GoldenDewApiNC';
  private static final String TOKEN_CACHE_KEY = 'GOLDENDEW';
  private static final Integer DEFAULT_TIMEOUT_MS = 60000;

  // =========================
  // API Paths
  // =========================
  private static final String PROMOTION_PRODUCT_MASTER_PATH = '/Crm/PromotionItem'; // 프로모션 제품 등록,수정,삭제

  // =========================
  // Public Methods
  // =========================

  /** 프로모션 제품 등록 */
  public static ErpApiResponseDto createPromotionProduct(ErpPromotionProductReqDto.CreateRequestList req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }
    validateCreateRequest(req);
    // req.validate()가 없다면 아래 3줄 검증으로 바꾸세요.
    // if (String.isBlank(req.no_man_coupon) || String.isBlank(req.no_mbr) || String.isBlank(req.id_insert)) ...
    // req.validate();

    CommonApiClient.RequestOptions opt = baseOptions('POST', ncEndpoint(PROMOTION_PRODUCT_MASTER_PATH));
    opt.body = req; // DTO 그대로 넘기면 CommonApiClient가 JSON.serialize 처리

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  /** 프로모션 제품 수정 */
  public static ErpApiResponseDto updatePromotionProduct(ErpPromotionProductReqDto.UpdateRequestList req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }
    validateUpdateRequest(req);

    CommonApiClient.RequestOptions opt = baseOptions('PATCH', ncEndpoint(PROMOTION_PRODUCT_MASTER_PATH));
    opt.body = req;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  /** 프로모션 제품 삭제 */
  public static ErpApiResponseDto deletePromotionProduct(ErpPromotionProductReqDto.DeleteRequestList req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    if (req.promotionItemList == null || req.promotionItemList.isEmpty()) {
      throw new IllegalArgumentException('Delete request item is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('DELETE', ncEndpoint(PROMOTION_PRODUCT_MASTER_PATH));
    ErpPromotionProductReqDto.PromotionItem item = req.promotionItemList[0];
    opt.query.put('no_prom', item.no_prom);
    opt.query.put('cd_item', item.cd_item);
    opt.query.put('id_delete', item.id_delete);
    opt.body = null;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  // =========================
  // Internal Helpers
  // =========================

  /** 공통 옵션 생성 */
  private static CommonApiClient.RequestOptions baseOptions(String method, String endpoint) {
    CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
    opt.method = method;
    opt.endpoint = endpoint;

    opt.timeoutMs = DEFAULT_TIMEOUT_MS;

    // ⚠️ CommonApiClient의 while 조건이 attempt <= maxRetries 라면,
    // maxRetries=1일 때 1회만 수행될 수 있습니다(구현 확인 필요).
    opt.maxRetries = 2; // 재시도 최대 횟수

    opt.throwOnHttpError = true;
    opt.parseJson = true;

    // 토큰 캐시 사용
    opt.tokenCacheKey = TOKEN_CACHE_KEY;
    opt.tokenSkewSeconds = 60;

    // 401 갱신은 CommonApiClient + TokenRefresher에 위임
    // (현재 CommonApiClient 구현이 refreshTokenOn401==false 일 때 갱신 분기라면 그대로 false)
    opt.refreshTokenOn401 = false;

    // 기본 헤더
    opt.headers.put('Accept', 'application/json');
    opt.headers.put('Content-Type', 'application/json');

    return opt;
  }

  /** Named Credential endpoint 생성 */
  private static String ncEndpoint(String path) {
    return 'callout:' + ERP_NC + path;
  }

  private static void validateCreateRequest(ErpPromotionProductReqDto.CreateRequestList req) {
    if (req.promotionItemList == null || req.promotionItemList.isEmpty()) {
      throw new IllegalArgumentException('Create request item is required.');
    }
    Integer idx = 0;
    for (ErpPromotionProductReqDto.PromotionItem item : req.promotionItemList) {
      if (item == null) {
        throw new IllegalArgumentException('Promotion item at index ' + idx + ' is required.');
      }
      if (String.isBlank(item.no_prom)) {
        throw new IllegalArgumentException('Promotion item[' + idx + '].no_prom is required.');
      }
      if (String.isBlank(item.cd_item)) {
        throw new IllegalArgumentException('Promotion item[' + idx + '].cd_item is required.');
      }
      if (String.isBlank(item.id_insert)) {
        throw new IllegalArgumentException('Promotion item[' + idx + '].id_insert is required.');
      }
      if (String.isBlank(item.id_update)) {
        throw new IllegalArgumentException('Promotion item[' + idx + '].id_update is required.');
      }
      idx++;
    }
  }

  private static void validateUpdateRequest(ErpPromotionProductReqDto.UpdateRequestList req) {
    if (req.promotionItemList == null || req.promotionItemList.isEmpty()) {
      throw new IllegalArgumentException('Update request item is required.');
    }
    Integer idx = 0;
    for (ErpPromotionProductReqDto.PromotionItem item : req.promotionItemList) {
      if (item == null) {
        throw new IllegalArgumentException('Promotion item at index ' + idx + ' is required.');
      }
      if (String.isBlank(item.no_prom)) {
        throw new IllegalArgumentException('Promotion item[' + idx + '].no_prom is required.');
      }
      if (String.isBlank(item.cd_item)) {
        throw new IllegalArgumentException('Promotion item[' + idx + '].cd_item is required.');
      }
      if (String.isBlank(item.id_update)) {
        throw new IllegalArgumentException('Promotion item[' + idx + '].id_update is required.');
      }
      idx++;
    }
  }
}