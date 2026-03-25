public with sharing class NamedCredentialTokenRefresher implements CommonApiClient.ITokenRefresher {
  private String tokenKey; // ex) 'GOLDENDEW'
  private String tokenEndpoint; // 토큰 발급 endpoint (Named Credential 사용)

  // 만료 안전 마진(초) - exp 60초 전부터는 만료로 간주
  private Integer skewSeconds = 60;

  public NamedCredentialTokenRefresher(String tokenKey, String tokenEndpoint) {
    this.tokenKey = tokenKey;
    this.tokenEndpoint = tokenEndpoint;
  }

  public Boolean refresh(CommonApiClient.RequestOptions opt, CommonApiClient.ResponseWrapper lastResponse) {
    System.debug('NamedCredentialTokenRefresher.refresh 진입');
    // 1) ERP 토큰 발급 API 호출
    CommonApiClient.RequestOptions tOpt = new CommonApiClient.RequestOptions();
    tOpt.method = 'GET';
    tOpt.endpoint = tokenEndpoint;
    tOpt.throwOnHttpError = true;
    tOpt.parseJson = true;
    tOpt.maxRetries = 0;
    tOpt.timeoutMs = 60000;
    tOpt.refreshTokenOn401 = true;
    tOpt.maxRetries = 1; // 재시도 최대 횟수
    // tOpt.debugLabel = 'TOKEN_ISSUE';

    // tOpt.headers.put('Content-Type', 'application/json');

    // 토큰 발급 API 호출
    System.debug('토큰 발급 API 호출');
    CommonApiClient.ResponseWrapper tRes = CommonApiClient.send(tOpt);

    if (!tRes.isSuccess() || tRes.jsonBody == null || !(tRes.jsonBody instanceof Map<String, Object>)) {
      return false;
    }

    // 응답에서 data.token 추출
    Map<String, Object> root = (Map<String, Object>) tRes.jsonBody;
    Object dataObj = root.get('data');
    if (!(dataObj instanceof Map<String, Object>)) {
      return false;
    }

    Map<String, Object> data = (Map<String, Object>) dataObj;
    String token = (String) data.get('token');
    if (String.isBlank(token)) {
      return false;
    }

    // 캐시에 토큰 저장 시간 (4시간)
    Integer ttlSec = 4 * 60 * 60; // 14400초

    System.debug('캐시에 저장 할 토큰 값 token : ' + token);

    ApiTokenStore.put(tokenKey, token, ttlSec);

    // 5) 원 요청 Authorization 갱신(다음 루프에서 재시도)
    if (opt.headers == null) {
      opt.headers = new Map<String, String>();
    }
    opt.headers.put('Authorization', 'Bearer ' + token);

    return true;
  }
}