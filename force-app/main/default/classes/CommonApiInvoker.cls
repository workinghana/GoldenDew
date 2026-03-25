/**
 * ! 보류
 * CommonApiInvoker
 * - Flow에서 재사용 가능한 Invocable 액션
 * - CommonApiClient를 사용하여 외부 API를 호출
 *
 * 사용 방법(Flow):
 * - inputs에 한 번에 여러 호출을 전달하면, 순서대로 호출되고 동일한 길이의 outputs가 반환됨
 * - endpoint는 가능하면 'callout:NamedCredential/path' 형식 사용
 */
public with sharing class CommonApiInvoker {
  // // Invocable 입력 DTO
  // public class InvocationInput {
  //   @InvocableVariable(required=true)
  //   public String method; // GET/POST/PUT/PATCH/DELETE

  //   @InvocableVariable(required=true)
  //   public String endpoint; // 전체 URL 또는 callout:NamedCredential/path

  //   @InvocableVariable
  //   public String jsonBody; // JSON 문자열 (선택)

  //   @InvocableVariable
  //   public Map<String, String> headers; // 추가 헤더 (선택)

  //   @InvocableVariable
  //   public Map<String, Object> query; // 쿼리 파라미터 (선택)

  //   @InvocableVariable
  //   public Integer timeoutMs; // 선택, 기본 60000

  //   @InvocableVariable
  //   public Integer maxRetries; // 선택, 기본 0

  //   @InvocableVariable
  //   public Boolean throwOnHttpError; // 선택, 기본 true

  //   @InvocableVariable
  //   public String debugLabel; // 로그 라벨 (선택)
  // }

  // // Invocable 출력 DTO
  // public class InvocationOutput {
  //   @InvocableVariable
  //   public Integer statusCode;

  //   @InvocableVariable
  //   public String status;

  //   @InvocableVariable
  //   public String rawBody;

  //   @InvocableVariable
  //   public String contentType;

  //   @InvocableVariable
  //   public Boolean success;

  //   @InvocableVariable
  //   public String errorMessage; // throwOnHttpError=false 인 경우 비어있을 수 있음
  // }

  // /**
  //  * Flow에서 호출되는 Invocable 메서드
  //  */
  // @InvocableMethod(label='HTTP Callout (Common)' description='외부 API 호출 공통 액션. Named Credential 또는 절대 URL 사용 가능')
  // public static List<InvocationOutput> invoke(List<InvocationInput> inputs) {
  //   // 방어코드
  //   if (inputs == null)
  //     return new List<InvocationOutput>();

  //   List<InvocationOutput> results = new List<InvocationOutput>();
  //   for (InvocationInput inputItem : inputs) {
  //     results.add(processOne(inputItem));
  //   }
  //   return results;
  // }

  // // 단건 처리 (Bulk-safe)
  // private static InvocationOutput processOne(InvocationInput inputItem) {
  //   InvocationOutput out = new InvocationOutput();
  //   try {
  //     CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
  //     opt.method = inputItem != null ? inputItem.method : null;
  //     opt.endpoint = inputItem != null ? inputItem.endpoint : null;
  //     opt.timeoutMs = (inputItem != null && inputItem.timeoutMs != null) ? inputItem.timeoutMs : 60000;
  //     opt.maxRetries = (inputItem != null && inputItem.maxRetries != null) ? inputItem.maxRetries : 0;
  //     opt.throwOnHttpError = (inputItem != null && inputItem.throwOnHttpError != null) ? inputItem.throwOnHttpError : true;
  //     opt.debugLabel = inputItem != null ? inputItem.debugLabel : null;

  //     if (inputItem != null && inputItem.headers != null)
  //       opt.headers.putAll(inputItem.headers);
  //     if (inputItem != null && inputItem.query != null)
  //       opt.query.putAll(inputItem.query);

  //     // JSON 문자열이 전달된 경우 그대로 사용
  //     if (inputItem != null && !String.isBlank(inputItem.jsonBody)) {
  //       opt.body = inputItem.jsonBody;
  //       // Content-Type 기본 지정
  //       if (opt.headers == null)
  //         opt.headers = new Map<String, String>();
  //       if (!opt.headers.containsKey('Content-Type')) {
  //         opt.headers.put('Content-Type', 'application/json');
  //       }
  //     }

  //     CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);

  //     out.statusCode = res.statusCode;
  //     out.status = res.status;
  //     out.rawBody = res.rawBody;
  //     out.contentType = res.headers != null ? res.headers.get('Content-Type') : null;
  //     out.success = res.isSuccess();
  //   } catch (Exception e) {
  //     // throwOnHttpError=true 이거나 기타 예외 시
  //     out.success = false;
  //     out.errorMessage = e.getMessage();
  //   }
  //   return out;
  // }
}