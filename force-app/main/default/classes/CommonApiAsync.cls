/**
 * ! 보류
 * CommonApiAsync
 * - 회원 가입(Transaction) 완료 후, 쿠폰 지급은 별도 처리로 분리하고
 *   외부 API 호출을 비동기(Queueable)로 수행하는 공통 클래스
 *
 * 사용 시나리오(예):
 *  - 동기 트랜잭션(회원 생성/업데이트 등)에서 enqueueCallout(...) 호출만 수행
 *  - 실제 외부 시스템 연동은 별도 트랜잭션에서 실행되어, 커밋 지연/롤백 영향 최소화
 *
 * 설계 포인트
 *  - Queueable + Database.AllowsCallouts
 *  - 입력 DTO로 호출 파라미터 전달
 *  - CommonApiClient에 위임하여 실제 Callout 수행
 *  - 오류는 잡아서 로깅하고(확장지점), 실패 정보만 보관. 동기 트랜잭션 실패로 전파하지 않음
 *
 * 주의
 *  - Flow/Trigger/Controller 등 동기 경로에서 직접 callouts 하지 말고 enqueueCallout 사용
 *  - 인증은 Named Credential 사용 권장 (endpoint: 'callout:NCName/path')
 */
public with sharing class CommonApiAsync {
  // /**
  //  * 비동기 호출에 필요한 최소 입력
  //  */
  // public class AsyncCallRequest {
  //   public String method; // GET/POST/PUT/PATCH/DELETE (required)
  //   public String endpoint; // absolute URL or callout:NamedCredential/path (required)
  //   public Map<String, Object> query; // optional
  //   public Map<String, String> headers; // optional
  //   public String jsonBody; // optional (직렬화된 JSON 문자열)
  //   public Integer timeoutMs; // optional (default 60000)
  //   public Integer maxRetries; // optional (default 0)
  //   public String debugLabel; // optional

  //   public AsyncCallRequest() {
  //     this.query = new Map<String, Object>();
  //     this.headers = new Map<String, String>();
  //   }
  // }

  // /**
  //  * 결과(간략)
  //  */
  // public class AsyncCallResult {
  //   public Boolean success;
  //   public Integer statusCode;
  //   public String status;
  //   public String contentType;
  //   public String rawBody;
  //   public String errorMessage;
  // }

  // /**
  //  * Queueable 작업
  //  */
  // public class CalloutJob implements Queueable, Database.AllowsCallouts {
  //   private AsyncCallRequest req;

  //   public CalloutJob(AsyncCallRequest req) {
  //     this.req = req;
  //   }

  //   public void execute(QueueableContext qc) {
  //     AsyncCallResult result = new AsyncCallResult();
  //     try {
  //       CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
  //       opt.method = req != null ? req.method : null;
  //       opt.endpoint = req != null ? req.endpoint : null;
  //       if (req != null && req.query != null)
  //         opt.query.putAll(req.query);
  //       if (req != null && req.headers != null)
  //         opt.headers.putAll(req.headers);
  //       opt.timeoutMs = (req != null && req.timeoutMs != null) ? req.timeoutMs : 60000;
  //       opt.maxRetries = (req != null && req.maxRetries != null) ? req.maxRetries : 0;
  //       // 비동기에서는 기본적으로 throwOnHttpError = false 로 하여 예외 대신 결과로 반환
  //       opt.throwOnHttpError = false;
  //       opt.debugLabel = req != null ? req.debugLabel : null;

  //       if (req != null && !String.isBlank(req.jsonBody)) {
  //         opt.body = req.jsonBody;
  //         if (!opt.headers.containsKey('Content-Type')) {
  //           opt.headers.put('Content-Type', 'application/json');
  //         }
  //       }

  //       CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
  //       result.success = res.isSuccess();
  //       result.statusCode = res.statusCode;
  //       result.status = res.status;
  //       result.rawBody = res.rawBody;
  //       result.contentType = (res.headers != null) ? res.headers.get('Content-Type') : null;

  //       // TODO: 필요 시 성공 로그 저장 (Custom Object / Platform Event 등)
  //     } catch (Exception e) {
  //       result.success = false;
  //       result.errorMessage = e.getMessage();
  //       // TODO: 필요 시 에러 로그 저장 (Custom Object / Platform Event 등)
  //     }

  //     // 현재 구현에서는 결과를 외부로 반환하지 않음.
  //     // 필요 시, 결과를 특정 레코드에 매핑/저장하거나 PE 발행하도록 확장.
  //   }
  // }

  // /**
  //  * 비동기 호출 등록 (동기 트랜잭션에서 사용)
  //  * - 회원 가입 완료 후 쿠폰 지급은 별도 로직으로 넘기고
  //  *   외부 API는 여기서 Queueable에 등록하여 비동기로 처리
  //  */
  // public static Id enqueueCallout(AsyncCallRequest req) {
  //   if (req == null) {
  //     throw new IllegalArgumentException('AsyncCallRequest is required.');
  //   }
  //   if (String.isBlank(req.method)) {
  //     throw new IllegalArgumentException('method is required.');
  //   }
  //   if (String.isBlank(req.endpoint)) {
  //     throw new IllegalArgumentException('endpoint is required.');
  //   }
  //   return System.enqueueJob(new CalloutJob(req));
  // }
}