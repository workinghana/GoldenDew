/**
 * ERP Promotion API Client
 * - CommonApiClient 기반
 * - 토큰 캐시/401 갱신 로직은 CommonApiClient + NamedCredentialTokenRefresher에 위임
 *
 * @author Changhwan Kim
 * @since 2026-01-27
 */
public with sharing class ErpPromotionApiClient {
  // =========================
  // Config
  // =========================
  private static final String ERP_NC = 'GoldenDewApiNC';
  private static final String TOKEN_CACHE_KEY = 'GOLDENDEW';
  private static final Integer DEFAULT_TIMEOUT_MS = 60000;

  // =========================
  // API Paths
  // =========================
  private static final String PROMOTION_MASTER_PATH = '/Crm/Promotion'; // 프로모션 마스터 등록,수정,삭제

  // =========================
  // Public Methods
  // =========================

  /** 프로모션 마스터 등록 */
  public static ErpApiResponseDto createMaster(ErpPromotionReqDto.CreateRequest req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }
    // req.validate()가 없다면 아래 3줄 검증으로 바꾸세요.
    // if (String.isBlank(req.no_man_coupon) || String.isBlank(req.no_mbr) || String.isBlank(req.id_insert)) ...
    // req.validate();

    CommonApiClient.RequestOptions opt = baseOptions('POST', ncEndpoint(PROMOTION_MASTER_PATH));
    opt.body = req; // DTO 그대로 넘기면 CommonApiClient가 JSON.serialize 처리

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  /** 프로모션 마스터 수정 */
  public static ErpApiResponseDto updateMaster(ErpPromotionReqDto.UpdateRequest req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('PATCH', ncEndpoint(PROMOTION_MASTER_PATH));
    opt.body = req;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  /** 프로모션 마스터 삭제 */
  public static ErpApiResponseDto deleteMaster(ErpPromotionReqDto.DeleteRequest req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('DELETE', ncEndpoint(PROMOTION_MASTER_PATH));

    opt.query.put('no_prom', req.no_prom);
    opt.query.put('id_delete', req.id_delete);

    // body 사용 안 함
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
}