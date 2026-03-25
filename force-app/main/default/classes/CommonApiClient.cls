public with sharing class CommonApiClient {
  // =========================
  // Defaults (Top-level only)
  // =========================

  // 기본 재시도 대상 HTTP Status 코드 셋(요청 옵션에서 별도 지정 없을 때 사용)
  // 408(Request Timeout), 429(Too Many Requests), 5xx(서버 오류) 계열을 기본 재시도로 취급
  private static final Set<Integer> DEFAULT_RETRY_STATUS = new Set<Integer>{ 408, 429, 500, 502, 503, 504 };

  /**
   * [기본 응답 헤더 Allowlist]
   * - HttpResponse에서 어떤 헤더를 수집할지 결정하는 기본 목록
   * - 보안/로그 사이즈/불필요한 정보 수집 방지를 위해 필요한 헤더만 제한적으로 수집
   */
  private static Set<String> defaultResponseHeaderAllowlist() {
    return new Set<String>{
      'Content-Type',
      'Retry-After',
      'X-Request-Id',
      'X-Correlation-Id',
      'X-RateLimit-Limit',
      'X-RateLimit-Remaining',
      'X-RateLimit-Reset'
    };
  }

  // =========================
  // Public Types
  // 요청 설정
  // =========================

  /**
   * [RequestOptions]
   * - 외부 API 호출(HTTP Callout) 설정을 담는 DTO
   * - method/endpoint는 필수
   * - headers/query/body/timeout/retry/파싱옵션 등을 포함
   */
  public class RequestOptions {
    public String method; // HTTP Method (GET/POST/PUT/PATCH/DELETE)
    public String endpoint; // callout:NamedCredential/path 또는 https://...
    public Map<String, String> headers; // 요청 헤더
    public Map<String, Object> query; // QueryString 파라미터
    public Object body; // 요청 바디 (Object/Map/List/String)
    public Integer timeoutMs; // 타임아웃(ms)
    public Integer maxRetries; // 재시도 횟수(루프 기준)
    public Boolean throwOnHttpError; // 2xx가 아니면 예외 던질지
    public Boolean parseJson; // 응답 바디 JSON 파싱할지
    // public String debugLabel; // 로그 식별자(옵션)
    public String tokenCacheKey; // ex) 'CAFE24'
    public Integer tokenSkewSeconds; // ex) 60

    public Set<String> responseHeaderAllowlist; // 응답 헤더 중 수집할 항목 allowlist
    public Boolean refreshTokenOn401; // 401 발생 시 tokenRefresher로 토큰 갱신 시도인지 여부
    public Set<Integer> retryStatusCodes; // 재시도 대상 status 커스터마이즈(옵션)

    /**
     * [기본값 세팅]
     * - headers/query null 방지
     * - timeout=60s, maxRetries=0, throwOnHttpError=true, parseJson=true 등
     */
    public RequestOptions() {
      headers = new Map<String, String>();
      query = new Map<String, Object>();
      timeoutMs = 60000;
      maxRetries = 0;
      throwOnHttpError = true;
      parseJson = true;
      refreshTokenOn401 = false;
      responseHeaderAllowlist = CommonApiClient.defaultResponseHeaderAllowlist();
      retryStatusCodes = null;
      tokenCacheKey = null;
      tokenSkewSeconds = 60;
    }
  }

  /**
   * [ResponseWrapper]
   * - HttpResponse를 공통 형태로 포장한 결과 DTO
   * - rawBody(원문), jsonBody(파싱 결과), headers(allowlist로 수집한 헤더) 포함
   * - isSuccess()로 2xx 여부 판단
   */
  public class ResponseWrapper {
    public Integer statusCode;
    public String status;
    public Map<String, String> headers;
    public String rawBody;

    public String requestUrl; // 요청 URL
    public Datetime responseDateTime; // 응답 일시
    public String method; // 호출 타입

    public Object jsonBody; // JSON.deserializeUntyped 결과(Map/List 등)
    public String jsonParseError; // JSON 파싱 실패 시 에러 메시지

    public Integer attempts; // 실제 시도 횟수(1부터 증가)
    public Boolean tokenRefreshed; // 401에서 토큰 갱신 로직이 수행되었는지

    /**
     * [성공 판정]
     * - HTTP statusCode가 200~299면 성공으로 간주
     */
    public Boolean isSuccess() {
      return statusCode != null && statusCode >= 200 && statusCode < 300;
    }
  }

  /**
   * [HttpErrorException]
   * - HTTP 호출이 실패(2xx 아님)했을 때 상세 정보를 담기 위한 커스텀 예외
   * - Apex 예외 생성자 이슈를 피하기 위해 생성자 정의 없이 필드로만 정보 전달
   */
  // public class HttpErrorException extends Exception {
  //   public Integer statusCode;
  //   public String responseBody;
  //   public String endpoint;
  //   public String method;
  //   public Map<String, String> responseHeaders;
  // }

  /**
   * [ITokenRefresher]
   * - 401(Unauthorized) 발생 시 토큰을 갱신하고 요청 헤더 등을 수정해 재시도할 수 있게 하는 훅
   * - Named Credential(External Credential/OAuth) 쓰면 보통 필요 없고,
   *   직접 토큰 관리하는 API(Cafe24 등)에서 사용
   *
   * * 명명된 자격 증명, 외부 자격 증명을 못 쓰는 경우 직접 토큰 갱신 로직 구현 시 필요한 메서드
   */
  public interface ITokenRefresher {
    Boolean refresh(RequestOptions opt, ResponseWrapper lastResponse);
  }

  // 401 토큰 갱신 로직 주입용(선택)
  private static ITokenRefresher tokenRefresher;

  /**
   * [TokenRefresher 설정]
   * - 외부에서 구현체를 주입하면, 401 발생 시 1회 토큰 갱신 후 재시도 시도
   */
  public static void setTokenRefresher(ITokenRefresher r) {
    tokenRefresher = r;
  }

  // =========================
  // Public API
  // =========================

  /**
   * [send]
   * - 공통 HTTP Callout 실행 메서드
   * - validateOptions()로 요청 옵션 검증/기본값 보정
   * - buildRequest()로 HttpRequest 생성(쿼리스트링/헤더/바디 적용)
   * - http.send() 실행 후 toWrapper()로 표준 결과로 변환
   * - 401 + refreshTokenOn401=true 이면 tokenRefresher로 갱신 후 1회 재시도(continue)
   * - 실패 시:
   *   - shouldRetry()가 true면 재시도 루프
   *   - throwOnHttpError=true면 HttpErrorException throw
   *   - throwOnHttpError=false면 ResponseWrapper 반환(호출자가 statusCode로 판단)
   */
  public static ResponseWrapper send(RequestOptions opt) {
    System.debug('send 진입');
    validateOptions(opt); // 유효성 검사
    ensureTokenRefresher(); // NamedCredentialTokenRefresher 주입

    Http http = new Http();
    Integer attempt = 1; // 실제 시도 횟수
    Boolean didTokenRefresh = false; // 토큰 갱신을 했는 지 여부
    Exception lastEx;
    ResponseWrapper lastRes;

    if (didTokenRefresh) {
      // 401에서 토큰 갱신 로직이 수행되었는지 확인
      System.debug('didTokenRefresh가 true이므로 토큰 갱신 로직이 수행됐음.');
    } else {
      System.debug('didTokenRefresh가 false이므로 토큰 갱신 로직이 수행되지 않았음.');
    }

    System.debug('재시도 최대 횟수 : ' + opt.maxRetries);
    while (attempt <= opt.maxRetries) {
      System.debug('시도 횟수 : ' + attempt);
      // maxRetries = 재시도 횟수(루프 기준)
      attempt++;
      try {
        // buildRequest 전에 캐시 토큰 주입(있으면)
        injectBearerFromCache(opt); // 캐시에서 토큰 불러오기
        HttpRequest req = buildRequest(opt);
        System.debug('http.send 하기 전 req : ' + req);
        System.debug('endpoint=' + req.getEndpoint());
        System.debug('userId=' + UserInfo.getUserId());
        System.debug('username=' + UserInfo.getUserName());
        HttpResponse res = http.send(req);
        System.debug('http.send 응답 값 res : ' + res);

        // HttpResponse를 ResponseWrapper로 변환
        ResponseWrapper wrap = toWrapper(opt, res);
        System.debug('wrap : ' + wrap);
        wrap.attempts = attempt;
        wrap.tokenRefreshed = didTokenRefresh;
        lastRes = wrap;

        System.debug('opt.refreshTokenOn401(401 발생 시 tokenRefresher로 토큰 갱신 시도 여부) : ' + opt.refreshTokenOn401);
        // System.debug('tokenRefresher : ' + tokenRefresher);
        System.debug('didTokenRefresh(401에서 토큰 갱신 로직이 수행되었는지) : ' + didTokenRefresh);

        System.debug('wrap.statusCode : ' + wrap.statusCode);
        System.debug('opt.refreshTokenOn401 : ' + opt.refreshTokenOn401); // 토큰 재갱신 시도 요청건인지
        System.debug('!didTokenRefresh : ' + !didTokenRefresh);
        System.debug('tokenRefresher : ' + tokenRefresher);
        // 401 토큰 갱신(옵션, 1회만) : 401에러 발생 + 토큰 갱신이 아닌 요청 + 갱신을 안 했을 때 + 토큰 갱신 주입 구현체가 있을 때
        if (wrap.statusCode == 401 && opt.refreshTokenOn401 == false && !didTokenRefresh && tokenRefresher != null) {
          System.debug('(wrap.statusCode == 401 && opt.refreshTokenOn401 == true && tokenRefresher != null && !didTokenRefresh) 진입');
          System.debug('401 발생 -> 토큰 재발급(캐시 갱신) 후 재시도');

          Boolean refreshed = tokenRefresher.refresh(opt, wrap); // 토큰 강제 갱신 시도
          if (refreshed == true) {
            System.debug('(refreshed == true) 진입');
            didTokenRefresh = true;
            // 401은 여기서 바로 다음 루프(재시도)
            // 토큰 갱신 성공 후 재요청
            continue;
          }
        }

        // 2xx면 성공 반환
        if (wrap.isSuccess()) {
          System.debug('(wrap.isSuccess()) 진입');
          return wrap;
        }

        // 재시도 가능한 HTTP 상태면 재시도
        if (shouldRetry(opt, wrap.statusCode, null, attempt)) {
          System.debug('(shouldRetry(opt, wrap.statusCode, null, attempt)) 진입');
          continue;
        }

        // 실패 처리: throwOnHttpError=true면 예외로, 아니면 wrap을 그대로 반환
        if (opt.throwOnHttpError) {
          System.debug('(opt.throwOnHttpError) 진입');
          throw buildHttpError(opt, wrap);
        }
        return wrap;
      } catch (System.CalloutException ce) {
        // 네트워크/타임아웃 등 CalloutException은 재시도 가능(정책에 따라)
        System.debug('(System.CalloutException ce) 진입');
        lastEx = ce;
        if (shouldRetry(opt, null, ce, attempt)) {
          System.debug('(shouldRetry(opt, null, ce, attempt)) 진입');
          continue;
        }
        break;
      } catch (HttpErrorException he) {
        // HTTP 오류 예외는 여기서 종료(이미 buildHttpError에서 정보 세팅됨)
        // System.debug('(HttpErrorException he) 진입 : ' + he.responseBody);
        he.requestUrl = opt.endpoint;
        // System.debug('(HttpErrorException he) 진입 : ' + he.requestUrl);
        lastEx = he;
        break;
      } catch (Exception e) {
        // 그 외 예외는 기본적으로 재시도 없이 종료(원하면 정책 확장 가능)
        System.debug('(Exception e) 진입 : ' + e.getMessage());
        lastEx = e;
        break;
      }
    }

    // 재시도 후에도 실패하면 마지막 예외를 throw
    if (lastEx != null) {
      System.debug('(lastEx != null) 진입');
      throw lastEx;
    }
    return lastRes;
  }

  // =========================
  // Internal Helpers
  // =========================

  /**
   * [validateOptions]
   * - RequestOptions 유효성 검증 + 기본값 보정
   * - 필수값(method/endpoint) 누락 시 IllegalArgumentException
   * - method는 대문자 normalize 후 허용 메서드만 통과
   * - endpoint는 공백 포함 금지 + 시작 prefix 제한(callout:/http/https)
   * - headers/query/allowlist 등이 null이면 빈 객체/기본값으로 초기화
   */
  private static void validateOptions(RequestOptions opt) {
    System.debug('validateOptions 진입');
    if (opt == null) {
      System.debug('(opt == null) 진입');
      throw new IllegalArgumentException('RequestOptions is required.');
    }
    if (String.isBlank(opt.method)) {
      System.debug('(String.isBlank(opt.method)) 진입');
      throw new IllegalArgumentException('method is required.');
    }

    if (String.isBlank(opt.endpoint)) {
      System.debug('(String.isBlank(opt.endpoint)) 진입');
      throw new IllegalArgumentException('endpoint is required.');
    }

    String m = opt.method.trim().toUpperCase();
    Set<String> allowed = new Set<String>{ 'GET', 'POST', 'PUT', 'PATCH', 'DELETE' };
    if (!allowed.contains(m)) {
      System.debug('(!allowed.contains(m)) 진입');
      throw new IllegalArgumentException('Unsupported method: ' + opt.method);
    }
    opt.method = m;

    if (opt.timeoutMs == null || opt.timeoutMs <= 0) {
      System.debug('(opt.timeoutMs == null || opt.timeoutMs <= 0) 진입');
      opt.timeoutMs = 60000;
    }
    if (opt.maxRetries == null || opt.maxRetries < 0) {
      System.debug('(opt.maxRetries == null || opt.maxRetries < 0) 진입');
      opt.maxRetries = 0;
    }
    if (opt.throwOnHttpError == null) {
      System.debug('(opt.throwOnHttpError == null) 진입');
      opt.throwOnHttpError = true;
    }
    if (opt.parseJson == null) {
      System.debug('(opt.parseJson == null) 진입');
      opt.parseJson = true;
    }
    if (opt.refreshTokenOn401 == null) {
      System.debug('(opt.refreshTokenOn401 == null) 진입');
      opt.refreshTokenOn401 = false;
    }

    if (opt.headers == null) {
      System.debug('(opt.headers == null) 진입');
      opt.headers = new Map<String, String>();
    }
    if (opt.query == null) {
      System.debug('(opt.query == null) 진입');
      opt.query = new Map<String, Object>();
    }
    if (opt.responseHeaderAllowlist == null) {
      System.debug('(opt.responseHeaderAllowlist == null) 진입');
      opt.responseHeaderAllowlist = CommonApiClient.defaultResponseHeaderAllowlist();
    }

    String ep = opt.endpoint.trim();
    if (ep.contains(' ')) {
      System.debug('(ep.contains( )) 진입');
      throw new IllegalArgumentException('endpoint contains spaces.');
    }
    if (!(ep.startsWith('callout:') || ep.startsWith('http://') || ep.startsWith('https://'))) {
      System.debug('(!(ep.startsWith(callout:) || ep.startsWith(http://) || ep.startsWith(https://))) 진입');
      // opt.endpoint = 'callout:ERP_NC/api/coupons/issue'; 이렇게 들어오면
      // req.setEndpoint('callout:ERP_NC/api/coupons/issue'); 이렇게 외부 자격 증명 조회
      // 토큰 확인 후 만료됐으면 자동으로 재발급
      // 헤더 자동 주입 후 HTTP 요청 전송
      throw new IllegalArgumentException('endpoint must start with callout:, http://, or https://');
    }
    opt.endpoint = ep;
  }

  /**
   * [buildRequest]
   * - RequestOptions를 기반으로 HttpRequest를 생성
   * - endpoint에 querystring을 붙이고(setEndpoint)
   * - headers를 모두 세팅(setHeader)
   * - Accept가 없으면 기본 'application/json' 추가
   * - GET이 아니고 body가 있으면:
   *   - body가 String이면 그대로 setBody
   *   - 아니면 JSON.serialize 후 setBody
   *   - Content-Type이 없으면 기본 'application/json' 추가
   */
  private static HttpRequest buildRequest(RequestOptions opt) {
    HttpRequest req = new HttpRequest();
    req.setMethod(opt.method);
    req.setTimeout(opt.timeoutMs);

    req.setEndpoint(appendQuery(opt.endpoint, opt.query));

    // headers
    for (String k : opt.headers.keySet()) {
      if (String.isBlank(k)) {
        System.debug('(String.isBlank(k)) 진입');
        continue;
      }
      String v = opt.headers.get(k);
      if (v == null) {
        System.debug('(v == null) 진입');
        continue;
      }
      req.setHeader(k, v);
    }

    // Accept 기본값 세팅(호출자가 이미 넣었으면 중복 세팅 방지)
    if (!hasHeaderIgnoreCase(opt.headers, 'Accept')) {
      System.debug('(!hasHeaderIgnoreCase(opt.headers, Accept)) 진입');
      req.setHeader('Accept', 'application/json');
    }

    // GET은 바디 비권장/미지원인 API가 많아서 제외
    if (opt.body != null && opt.method != 'GET') {
      System.debug('(opt.body != null && opt.method != GET) 진입');
      if (opt.body instanceof String) {
        req.setBody((String) opt.body);
      } else {
        req.setBody(JSON.serialize(opt.body));
        // Content-Type 기본값 세팅(호출자가 이미 넣었으면 중복 방지)
        if (!hasHeaderIgnoreCase(opt.headers, 'Content-Type')) {
          System.debug('(!hasHeaderIgnoreCase(opt.headers, Content-Type)) 진입');
          req.setHeader('Content-Type', 'application/json');
        }
      }
    }
    return req;
  }

  /**
   * [appendQuery]
   * - endpoint URL 뒤에 query 파라미터를 URL 인코딩해서 붙여주는 메서드
   * - 기존 endpoint에 '?'가 있으면 '&'로 이어붙임
   * - query map 값이 null이거나 key가 blank면 스킵
   */
  private static String appendQuery(String endpoint, Map<String, Object> query) {
    if (query == null || query.isEmpty()) {
      return endpoint;
    }

    List<String> parts = new List<String>();
    for (String key : query.keySet()) {
      if (String.isBlank(key)) {
        continue;
      }
      Object val = query.get(key);
      if (val == null) {
        continue;
      }

      parts.add(EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(String.valueOf(val), 'UTF-8'));
    }
    if (parts.isEmpty()) {
      return endpoint;
    }

    String qs = String.join(parts, '&');
    return endpoint.contains('?') ? (endpoint + '&' + qs) : (endpoint + '?' + qs);
  }

  /**
   * [hasHeaderIgnoreCase]
   * - headers Map에 name 헤더가 "대소문자 무시" 기준으로 존재하는지 확인
   * - HTTP 헤더는 표준상 대소문자를 구분하지 않지만,
   *   Apex Map은 key를 대소문자 구분하므로 별도 체크가 필요
   * - 예: 'content-type'이 있어도 'Content-Type' 검색이 false가 되는 문제를 방지
   */
  private static Boolean hasHeaderIgnoreCase(Map<String, String> headers, String name) {
    if (headers == null || String.isBlank(name)) {
      return false;
    }
    String n = name.toLowerCase();
    for (String k : headers.keySet()) {
      if (k != null && k.toLowerCase() == n) {
        return true;
      }
    }
    return false;
  }

  /**
   * [toWrapper]
   * - HttpResponse를 ResponseWrapper로 변환
   * - status/statusCode/body 저장
   * - responseHeaderAllowlist에 있는 헤더만 수집하여 headers Map에 저장
   * - parseJson=true이면 rawBody를 JSON.deserializeUntyped로 파싱(jsonBody)
   *   - 파싱 실패 시 jsonParseError에 메시지 저장(예외는 삼킴)
   */
  private static ResponseWrapper toWrapper(RequestOptions opt, HttpResponse res) {
    ResponseWrapper w = new ResponseWrapper();
    w.statusCode = res.getStatusCode();
    w.status = res.getStatus();
    w.rawBody = res.getBody();
    w.headers = new Map<String, String>();

    if (opt.endpoint != null) {
      w.requestUrl = opt.endpoint;
    }
    if (opt.method != null) {
      w.method = opt.method;
    }
    w.responseDateTime = System.now();

    if (opt.responseHeaderAllowlist != null) {
      for (String h : opt.responseHeaderAllowlist) {
        if (String.isBlank(h)) {
          continue;
        }
        String v = res.getHeader(h);
        if (v != null) {
          w.headers.put(h, v);
        }
      }
    }

    if (opt.parseJson == true && !String.isBlank(w.rawBody)) {
      try {
        w.jsonBody = JSON.deserializeUntyped(w.rawBody);
      } catch (Exception e) {
        w.jsonParseError = e.getMessage();
      }
    }
    return w;
  }

  /**
   * [shouldRetry]
   * - 재시도를 수행할지 판단하는 메서드
   * - attempt가 maxRetries를 넘으면 재시도 불가
   * - 예외(ex)가 있는 경우:
   *   - System.CalloutException(네트워크/타임아웃)만 재시도 허용(기본 정책)
   * - HTTP status 기반:
   *   - 401은 tokenRefresher 경로에서만 처리(여기서는 false)
   *   - retryStatusCodes가 지정되어 있으면 그것을 우선 사용
   *   - 없으면 DEFAULT_RETRY_STATUS(408/429/5xx)을 사용
   */
  private static Boolean shouldRetry(RequestOptions opt, Integer statusCode, Exception ex, Integer attempt) {
    if (attempt > opt.maxRetries) {
      return false;
    }

    if (ex != null) {
      // 네트워크/타임아웃류
      if (ex instanceof System.CalloutException) {
        return true;
      }
      return false;
    }

    if (statusCode == null) {
      return false;
    }
    if (statusCode == 401) {
      return false; // 401은 tokenRefresher 경로에서만
    }

    Set<Integer> retrySet = (opt.retryStatusCodes != null && !opt.retryStatusCodes.isEmpty()) ? opt.retryStatusCodes : DEFAULT_RETRY_STATUS;

    return retrySet.contains(statusCode);
  }

  /**
   * [buildHttpError]
   * - throwOnHttpError=true 일 때 던질 HttpErrorException을 생성/세팅하는 메서드
   * - 예외 메시지보다는 필드(statusCode/body/headers/endpoint/method)에 정보를 담아
   *   호출부에서 로깅/분기 처리할 수 있게 함
   */
  private static HttpErrorException buildHttpError(RequestOptions opt, ResponseWrapper wrap) {
    HttpErrorException ex = new HttpErrorException();
    ex.statusCode = wrap.statusCode;
    ex.responseBody = wrap.rawBody;
    ex.responseHeaders = wrap.headers;
    ex.endpoint = opt.endpoint;
    ex.method = opt.method;
    return ex;
  }

  /**
   * [injectBearerFromCache]
   * - Platform Cache(Org Cache)에 저장된 Access Token을 읽어와 요청 헤더(Authorization)에 주입하는 헬퍼
   *
   * 사용 목적
   * - 외부 API 호출 시 매번 토큰 발급 API를 호출하지 않고, 캐시에 저장된 토큰을 재사용하여 성능/Callout 비용을 절감
   * - 토큰 만료 임박(skewSeconds) 시에는 "유효하지 않음"으로 간주하여 주입하지 않음
   *   → 이후 401 발생 시 tokenRefresher(refreshTokenOn401) 경로로 재발급/재시도 유도
   *
   * 동작 방식
   * 1) opt.tokenCacheKey가 없으면(미사용) 바로 종료
   * 2) ApiTokenStore에서 tokenCacheKey로 TokenInfo 조회
   * 3) TokenInfo가 존재하고, 현재 시간 기준으로 만료되지 않았으면(skewSeconds 적용) Authorization 헤더를 주입
   * 4) Authorization 헤더가 이미 존재하면(호출자가 직접 넣은 경우) 덮어쓰지 않음(정책)
   *
   * 주의사항/정책 포인트
   * - Authorization을 "항상 캐시 토큰으로 덮어쓴다"가 필요하면, 아래 조건문을 변경하면 됨
   * - 캐시 Partition/TTL 정책은 Org 설정에 따라 다르므로 ApiTokenStore 구현과 함께 운영 정책을 맞춰야 함
   *
   * @param opt CommonApiClient.RequestOptions (tokenCacheKey/tokenSkewSeconds/headers를 사용)
   */
  private static void injectBearerFromCache(RequestOptions opt) {
    // tokenCacheKey가 없으면 토큰 캐시 기능을 사용하지 않는 요청이므로 종료
    if (String.isBlank(opt.tokenCacheKey)) {
      System.debug('tokenCacheKey가 없으므로 토큰 캐시 기능 미사용');
      return;
    }

    // 만료 안전 마진(초). 예: 60초면 "만료 60초 전"부터는 유효하지 않다고 보고 주입하지 않음
    Integer skew = (opt.tokenSkewSeconds == null) ? 60 : opt.tokenSkewSeconds;
    System.debug('토큰 캐시 기능 사용. tokenCacheKey : ' + opt.tokenCacheKey + ', tokenSkewSeconds : ' + skew);

    // 캐시에서 토큰 조회
    String token = ApiTokenStore.get(opt.tokenCacheKey);
    System.debug('캐시에서 조회된 토큰 : ' + token);

    // 토큰이 존재하고 유효(만료 임박 아님)한 경우에만 Authorization 헤더 주입
    if (token != null && !String.isBlank(token)) {
      if (opt.headers == null) {
        opt.headers = new Map<String, String>();
      }

      // 호출자가 이미 Authorization을 직접 지정했다면 덮어쓰지 않음(정책)
      // 캐시 토큰을 무조건 우선하려면 아래 if를 제거하고 항상 put하면 됨
      if (!hasHeaderIgnoreCase(opt.headers, 'Authorization')) {
        opt.headers.put('Authorization', 'Bearer ' + token);
      }
    }
  }

  private static void ensureTokenRefresher() {
    if (tokenRefresher != null) {
      System.debug('tokenRefresher 이미 설정됨');
      return;
    }

    tokenRefresher = new NamedCredentialTokenRefresher('GOLDENDEW', 'callout:GoldenDewTokenNC');
    System.debug('기본 NamedCredentialTokenRefresher 설정됨');
  }
}