/**
 * ! 보류
 * GdCouponAsyncService
 * - 쿠폰 관련 외부 API 호출을 비동기로 처리하는 통합 서비스
 * - Action(작업유형) + Handler(구현체) + Queueable(실행기) 구조
 *
 * 지원 작업
 * - ISSUE  : 쿠폰 발급/지급
 * - CANCEL : 쿠폰 발급 취소
 * - RESEND : 쿠폰 재전송(알림/재발송 등)
 *
 * 재시도(재큐잉) 정책(기본)
 * - 네트워크/타임아웃(System.CalloutException)
 * - 408, 429, 5xx
 * - 4xx(401 제외)는 재시도하지 않음
 *
 * 주의
 * - Apex에는 sleep이 없으므로 Retry-After 기반 "지연 재시도"는 Schedulable 패턴으로 확장 필요
 * - 인증/보안은 Named Credential 권장
 */
public with sharing class GdCouponAsyncService {
  //   // =========================
  //   // Action
  //   // =========================
  //   public enum Action {
  //     ISSUE,
  //     CANCEL,
  //     RESEND
  //   }

  //   // =========================
  //   // Request DTO
  //   // =========================
  //   public class CouponAsyncRequest {
  //     @AuraEnabled
  //     public Action action;
  //     @AuraEnabled
  //     public String memberId;
  //     @AuraEnabled
  //     public String couponCode;
  //     @AuraEnabled
  //     public String requestId; // 멱등/추적키(권장)
  //     @AuraEnabled
  //     public Integer retryCount; // 현재 재시도 횟수
  //     @AuraEnabled
  //     public Integer maxRetries; // 최대 재시도 횟수
  //     @AuraEnabled
  //     public Map<String, Object> extra;

  //     public CouponAsyncRequest() {
  //     }

  //     public CouponAsyncRequest(Action action, String memberId, String couponCode, String requestId, Map<String, Object> extra) {
  //       this.action = action;
  //       this.memberId = memberId;
  //       this.couponCode = couponCode;
  //       this.requestId = requestId;
  //       this.retryCount = 0;
  //       this.maxRetries = 2;
  //       this.extra = (extra == null) ? new Map<String, Object>() : new Map<String, Object>(extra);
  //     }
  //   }

  //   // =========================
  //   // Handler Interface
  //   // =========================
  //   public interface ICouponAsyncHandler {
  //     CommonApiClient.RequestOptions buildOptions(CouponAsyncRequest req);
  //     void handleResult(CouponAsyncRequest req, CommonApiClient.ResponseWrapper res);
  //   }

  //   // =========================
  //   // Handlers
  //   // =========================

  //   /**
  //    * ISSUE Handler: 쿠폰 지급/발급
  //    */
  //   public class IssueHandler implements ICouponAsyncHandler {
  //     public CommonApiClient.RequestOptions buildOptions(CouponAsyncRequest req) {
  //       System.debug('buildOptions 진입');
  //       Map<String, Object> body = new Map<String, Object>{ 'memberId' => req.memberId, 'couponCode' => req.couponCode, 'requestId' => req.requestId };
  //       if (req.extra != null && !req.extra.isEmpty()) {
  //         System.debug('(req.extra != null && !req.extra.isEmpty()) 진입');
  //         body.put('extra', req.extra);
  //       }

  //       CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
  //       opt.method = 'POST';
  //       opt.endpoint = 'callout:Goldendew_Named_Credentials';
  //       opt.headers.put('Content-Type', 'application/json');
  //       if (!String.isBlank(req.requestId)) {
  //         opt.headers.put('X-Idempotency-Key', req.requestId);
  //         opt.headers.put('X-Trace-Id', req.requestId);
  //       }
  //       opt.body = body;

  //       // Queueable 내부에서는 결과 수집형 권장
  //       opt.throwOnHttpError = false;
  //       opt.maxRetries = 0; // 재시도는 "재큐잉"으로 통제
  //       opt.timeoutMs = 60000;
  //       opt.debugLabel = 'GdCouponAsyncService.ISSUE';
  //       return opt;
  //     }

  //     public void handleResult(CouponAsyncRequest req, CommonApiClient.ResponseWrapper res) {
  //       // TODO: 성공/실패 로깅(커스텀 오브젝트), Platform Event 발행 등
  //       // 예: res.isSuccess(), res.statusCode, res.rawBody 활용
  //     }
  //   }

  //   /**
  //    * CANCEL Handler: 쿠폰 취소
  //    */
  //   public class CancelHandler implements ICouponAsyncHandler {
  //     public CommonApiClient.RequestOptions buildOptions(CouponAsyncRequest req) {
  //       Map<String, Object> body = new Map<String, Object>{ 'memberId' => req.memberId, 'couponCode' => req.couponCode, 'requestId' => req.requestId };
  //       if (req.extra != null && !req.extra.isEmpty()) {
  //         body.put('extra', req.extra);
  //       }

  //       CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
  //       opt.method = 'POST';
  //       opt.endpoint = 'callout:YourNamedCred/api/coupons/cancel';
  //       opt.headers.put('Content-Type', 'application/json');
  //       if (!String.isBlank(req.requestId)) {
  //         opt.headers.put('X-Idempotency-Key', req.requestId);
  //         opt.headers.put('X-Trace-Id', req.requestId);
  //       }
  //       opt.body = body;

  //       opt.throwOnHttpError = false;
  //       opt.maxRetries = 0;
  //       opt.timeoutMs = 60000;
  //       opt.debugLabel = 'GdCouponAsyncService.CANCEL';
  //       return opt;
  //     }

  //     public void handleResult(CouponAsyncRequest req, CommonApiClient.ResponseWrapper res) {
  //       // TODO: 로깅/PE/알림
  //     }
  //   }

  //   /**
  //    * RESEND Handler: 쿠폰 재전송
  //    */
  //   public class ResendHandler implements ICouponAsyncHandler {
  //     public CommonApiClient.RequestOptions buildOptions(CouponAsyncRequest req) {
  //       Map<String, Object> body = new Map<String, Object>{ 'memberId' => req.memberId, 'couponCode' => req.couponCode, 'requestId' => req.requestId };
  //       if (req.extra != null && !req.extra.isEmpty()) {
  //         body.put('extra', req.extra);
  //       }

  //       CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
  //       opt.method = 'POST';
  //       opt.endpoint = 'callout:YourNamedCred/api/coupons/resend';
  //       opt.headers.put('Content-Type', 'application/json');
  //       if (!String.isBlank(req.requestId)) {
  //         opt.headers.put('X-Trace-Id', req.requestId);
  //       }
  //       opt.body = body;

  //       opt.throwOnHttpError = false;
  //       opt.maxRetries = 0;
  //       opt.timeoutMs = 60000;
  //       opt.debugLabel = 'GdCouponAsyncService.RESEND';
  //       return opt;
  //     }

  //     public void handleResult(CouponAsyncRequest req, CommonApiClient.ResponseWrapper res) {
  //       // TODO: 로깅/PE/알림
  //     }
  //   }

  //   // =========================
  //   // Enqueue API
  //   // =========================
  //   public static Id enqueue(CouponAsyncRequest req) {
  //     validate(req);
  //     return System.enqueueJob(new CouponAsyncJob(req));
  //   }

  //   // 편의 메서드(가독성)
  //   public static Id enqueueIssue(String memberId, String couponCode, String requestId, Map<String, Object> extra) {
  //     return enqueue(new CouponAsyncRequest(Action.ISSUE, memberId, couponCode, requestId, extra));
  //   }
  //   public static Id enqueueCancel(String memberId, String couponCode, String requestId, Map<String, Object> extra) {
  //     return enqueue(new CouponAsyncRequest(Action.CANCEL, memberId, couponCode, requestId, extra));
  //   }
  //   public static Id enqueueResend(String memberId, String couponCode, String requestId, Map<String, Object> extra) {
  //     return enqueue(new CouponAsyncRequest(Action.RESEND, memberId, couponCode, requestId, extra));
  //   }

  //   // =========================
  //   // 유효성 검사
  //   // =========================
  //   private static void validate(CouponAsyncRequest req) {
  //     if (req == null) {
  //       throw new IllegalArgumentException('CouponAsyncRequest is required.');
  //     }
  //     if (req.action == null) {
  //       throw new IllegalArgumentException('action is required.');
  //     }
  //     if (String.isBlank(req.memberId)) {
  //       throw new IllegalArgumentException('memberId is required.');
  //     }
  //     if (String.isBlank(req.couponCode)) {
  //       throw new IllegalArgumentException('couponCode is required.');
  //     }
  //     if (String.isBlank(req.requestId)) {
  //       throw new IllegalArgumentException('requestId is required.');
  //     }

  //     if (req.retryCount == null) {
  //       req.retryCount = 0;
  //     }
  //     if (req.maxRetries == null) {
  //       req.maxRetries = 2;
  //     }
  //     if (req.extra == null) {
  //       req.extra = new Map<String, Object>();
  //     }
  //   }

  //   // =========================
  //   // Queueable Executor (single)
  //   // =========================
  //   public class CouponAsyncJob implements Queueable, Database.AllowsCallouts {
  //     private CouponAsyncRequest req;

  //     public CouponAsyncJob(CouponAsyncRequest req) {
  //       this.req = req;
  //     }

  //     public void execute(QueueableContext qc) {
  //       ICouponAsyncHandler handler = resolveHandler(req.action);

  //       try {
  //         CommonApiClient.RequestOptions opt = handler.buildOptions(req);
  //         CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);

  //         // 후처리(로그/PE/저장)
  //         handler.handleResult(req, res);

  //         // 일시 장애면 재큐잉
  //         if (!res.isSuccess() && shouldRequeue(res.statusCode, req)) {
  //           System.enqueueJob(new CouponAsyncJob(cloneForRetry(req)));
  //         }
  //       } catch (Exception e) {
  //         // 예외도 일시 장애로 판단되면 재큐잉
  //         if (req.retryCount < req.maxRetries) {
  //           System.enqueueJob(new CouponAsyncJob(cloneForRetry(req)));
  //         }
  //         // TODO: 최종 실패 로깅/알림
  //       }
  //     }
  //   }

  //   // =========================
  //   // Routing / Retry helpers
  //   // =========================
  //   private static ICouponAsyncHandler resolveHandler(Action action) {
  //     if (action == GdCouponAsyncService.Action.ISSUE) {
  //       return new IssueHandler();
  //     }
  //     if (action == GdCouponAsyncService.Action.CANCEL) {
  //       return new CancelHandler();
  //     }
  //     if (action == GdCouponAsyncService.Action.RESEND) {
  //       return new ResendHandler();
  //     }
  //     throw new IllegalArgumentException('Unsupported action: ' + String.valueOf(action));
  //   }

  //   private static Boolean shouldRequeue(Integer statusCode, CouponAsyncRequest req) {
  //     if (req.retryCount >= req.maxRetries) {
  //       return false;
  //     }

  //     // 네트워크 예외 등으로 statusCode가 null이면 재시도
  //     if (statusCode == null) {
  //       return true;
  //     }

  //     // 일시 장애만 재시도
  //     if (statusCode == 408) {
  //       return true;
  //     }
  //     if (statusCode == 429) {
  //       return true;
  //     }
  //     if (statusCode >= 500 && statusCode <= 599) {
  //       return true;
  //     }

  //     // 401은 케이스에 따라 토큰 갱신 후 재시도 패턴이 필요하면 CommonApiClient tokenRefresher를 쓰는 방식 권장
  //     return false;
  //   }

  //   private static CouponAsyncRequest cloneForRetry(CouponAsyncRequest req) {
  //     CouponAsyncRequest n = new CouponAsyncRequest();
  //     n.action = req.action;
  //     n.memberId = req.memberId;
  //     n.couponCode = req.couponCode;
  //     n.requestId = req.requestId;

  //     n.extra = (req.extra == null) ? new Map<String, Object>() : new Map<String, Object>(req.extra);

  //     n.maxRetries = req.maxRetries;
  //     n.retryCount = (req.retryCount == null ? 0 : req.retryCount) + 1;
  //     return n;
  //   }
}