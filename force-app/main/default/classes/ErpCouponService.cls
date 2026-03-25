public with sharing class ErpCouponService {
  // Named Credential 사용 권장
  private static final String ENDPOINT = 'callout:Coupon_API_NC/v1/coupons/issue';

  /**
   * 쿠폰 지급 API 호출
   * @param memberNo   회원번호
   * @param couponCode 쿠폰 코드
   * @param qty        지급 수량(기본 1)
   * @param reason     지급 사유(선택)
   * @param requestId  멱등/추적용 requestId(권장: Salesforce 레코드 Id, 또는 UUID)
   */
  public static ErpCouponIssueDto.IssueResponse issueCoupon(String memberNo, String couponCode, Integer qty, String reason, String requestId) {
    // ===== 1) 요청값 검증(필수)
    if (String.isBlank(memberNo)) {
      throw new IllegalArgumentException('memberNo is required');
    }
    if (String.isBlank(couponCode)) {
      throw new IllegalArgumentException('couponCode is required');
    }
    if (qty == null || qty <= 0) {
      qty = 1;
    }

    // ===== 2) 요청 DTO 구성
    ErpCouponIssueDto.IssueRequest reqBody = new ErpCouponIssueDto.IssueRequest();
    reqBody.memberNo = memberNo;
    reqBody.couponCode = couponCode;
    reqBody.qty = qty;
    reqBody.reason = reason;
    reqBody.requestId = requestId;

    // ===== 3) CommonApiClient 옵션 세팅
    CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
    opt.method = 'POST';
    opt.endpoint = ENDPOINT;
    opt.body = reqBody;
    opt.timeoutMs = 60000;
    opt.maxRetries = 1; // 429/5xx만 재시도(기본 룰)
    opt.debugLabel = 'CouponIssueService.issueCoupon';

    // 헤더 필요 시 추가(예: idempotency key, trace id)
    // Named Credential이 인증 처리하면 Authorization은 보통 불필요
    opt.headers.put('Content-Type', 'application/json');
    if (!String.isBlank(requestId)) {
      opt.headers.put('X-Idempotency-Key', requestId);
      opt.headers.put('X-Trace-Id', requestId);
    }

    // ===== 4) 호출
    try {
      CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);

      // ===== 5) 응답 파싱 (Typed로 변환)
      ErpCouponIssueDto.IssueResponse out = (ErpCouponIssueDto.IssueResponse) JSON.deserialize(res.rawBody, ErpCouponIssueDto.IssueResponse.class);

      // ===== 6) 비즈니스 실패 처리(HTTP 200인데 success=false 같은 경우)
      if (out == null) {
        throw new CalloutException('쿠폰 지급 응답이 비었습니다.');
      }
      if (out.success != true) {
        String msg = '쿠폰 지급 실패: ' + (String.isBlank(out.errorMessage) ? out.message : out.errorMessage);
        throw new CalloutException(msg);
      }

      return out;
    } catch (CommonApiClient.HttpErrorException he) {
      // HTTP 레벨 실패(4xx/5xx)
      // 운영에서는 he.statusCode + he.responseBody를 로깅/모니터링 대상
      throw new CalloutException('쿠폰 지급 API HTTP 오류. status=' + he.statusCode + ', body=' + truncate(he.responseBody, 500));
    }
  }

  private static String truncate(String s, Integer maxLen) {
    if (s == null)
      return null;
    if (maxLen == null || maxLen <= 0)
      return s;
    return (s.length() > maxLen) ? s.substring(0, maxLen) + '...' : s;
  }
}