/**
 * ERP Point API Client
 * - CommonApiClient 기반
 * - 토큰 캐시/401 갱신 로직은 CommonApiClient + NamedCredentialTokenRefresher에 위임
 *
 * 전제:
 * - ErpApiResponseDto (공통 응답 DTO)는 별도 클래스로 존재
 */
public with sharing class ErpPointApiClient {
  // =========================
  // Config
  // =========================
  private static final String ERP_NC = 'GoldenDewApiNC';
  private static final String TOKEN_CACHE_KEY = 'GOLDENDEW';
  private static final Integer DEFAULT_TIMEOUT_MS = 60000;

  // =========================
  // API Paths
  // =========================
  private static final String POINT_DESTORY_PATH = '/Crm/PointDestory'; // 포인트 소멸
  private static final String POINT_SAVE_PATH = '/Crm/PointSave'; // 포인트 지급

  // =========================
  // Public Methods
  // =========================

  /** 포인트 소멸 */
  public static ErpApiResponseDto expiryPoint(ErpPointReqDto.ExpiryRequest req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('PATCH', ncEndpoint(POINT_DESTORY_PATH));
    opt.body = req;

    CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
    return ErpApiResponseDto.fromWrapper(res);
  }

  /** 포인트 지급 */
  public static ErpApiResponseDto creditPoint(ErpPointReqDto.CreditRequest req) {
    if (req == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    CommonApiClient.RequestOptions opt = baseOptions('POST', ncEndpoint(POINT_SAVE_PATH));

    // null 필드 제거 후 body 설정
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(req));
    body = (Map<String, Object>) pruneNulls(body);

    opt.body = body;

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

  public static Object pruneNulls(Object data) {
    if (data == null) {
      return null;
    }

    if (data instanceof Map<String, Object>) {
      Map<String, Object> m = (Map<String, Object>) data;
      List<String> keys = new List<String>(m.keySet());
      for (String k : keys) {
        Object v = m.get(k);
        if (v == null) {
          m.remove(k);
        } else {
          Object pv = pruneNulls(v);
          if (pv == null) {
            m.remove(k);
          } else {
            m.put(k, pv);
          }
        }
      }
      return m;
    }

    if (data instanceof List<Object>) {
      List<Object> arr = (List<Object>) data;
      for (Integer i = arr.size() - 1; i >= 0; i--) {
        Object v = arr[i];
        if (v == null) {
          arr.remove(i);
        } else {
          Object pv = pruneNulls(v);
          if (pv == null) {
            arr.remove(i);
          } else {
            arr[i] = pv;
          }
        }
      }
      return arr;
    }

    return data;
  }

  /** Named Credential endpoint 생성 */
  private static String ncEndpoint(String path) {
    return 'callout:' + ERP_NC + path;
  }
}