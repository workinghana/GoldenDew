public with sharing class ErpPromotionStoreApiClient {
  private static final String ERP_NC = 'GoldenDewApiNC';
  private static final String TOKEN_CACHE_KEY = 'GOLDENDEW';
  private static final Integer DEFAULT_TIMEOUT_MS = 60000;
  private static final String PROMOTION_STORE_PATH = '/Crm/PromotionStore';

  public static ErpApiResponseDto createPromotionStore(ErpPromotionStoreReqDto.CreateRequestList req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('POST', ncEndpoint(PROMOTION_STORE_PATH));
    opt.body = req;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  public static ErpApiResponseDto updatePromotionStore(ErpPromotionStoreReqDto.UpdateRequestList req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('PATCH', ncEndpoint(PROMOTION_STORE_PATH));
    opt.body = req;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  public static ErpApiResponseDto deletePromotionStore(ErpPromotionStoreReqDto.DeleteRequestList req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('DELETE', ncEndpoint(PROMOTION_STORE_PATH));
    opt.body = req;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  private static CommonApiClient.RequestOptions baseOptions(String method, String endpoint) {
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
