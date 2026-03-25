public with sharing class ErpPromotionCouponApiClient {

  // =========================
  // Config
  // =========================
  private static final String ERP_NC = 'GoldenDewApiNC';
  private static final String TOKEN_CACHE_KEY = 'GOLDENDEW';
  private static final Integer DEFAULT_TIMEOUT_MS = 60000;

  // =========================
  // API Paths
  // =========================
  private static final String PROMOTION_COUPON_PATH = '/Crm/PromotionCoupon';

  // =========================
  // Public Methods
  // =========================

  /** 프로모션 쿠폰 등록 */
  public static ErpApiResponseDto createPromotionCoupon(
    ErpPromotionCouponReqDto.CreateRequest req
  ) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt =
      baseOptions('POST', ncEndpoint(PROMOTION_COUPON_PATH));
    opt.body = req;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  /** 프로모션 쿠폰 삭제 */
  public static ErpApiResponseDto deletePromotionCoupon(
    ErpPromotionCouponReqDto.DeleteRequest req
  ) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt =
      baseOptions('DELETE', ncEndpoint(PROMOTION_COUPON_PATH));

    opt.query.put('no_prom', req.no_prom);
    opt.query.put('cd_coupon', req.cd_coupon);
    opt.query.put('id_delete', req.id_delete);

    opt.body = null;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  // =========================
  // Internal Helpers
  // =========================

  private static CommonApiClient.RequestOptions baseOptions(
    String method,
    String endpoint
  ) {
    CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
    opt.method = method;
    opt.endpoint = endpoint;

    opt.timeoutMs = DEFAULT_TIMEOUT_MS;
    opt.maxRetries = 2;

    opt.throwOnHttpError = true;
    opt.parseJson = true;

    opt.tokenCacheKey = TOKEN_CACHE_KEY;
    opt.tokenSkewSeconds = 60;
    opt.refreshTokenOn401 = false;

    opt.headers.put('Accept', 'application/json');
    opt.headers.put('Content-Type', 'application/json');

    return opt;
  }

  private static String ncEndpoint(String path) {
    return 'callout:' + ERP_NC + path;
  }
}