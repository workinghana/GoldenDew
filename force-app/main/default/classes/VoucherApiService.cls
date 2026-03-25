// ! 사용 X
public with sharing class VoucherApiService {
  public class Request {
    @InvocableVariable
    public Id CouponId; //만료된 쿠폰의 id
    @InvocableVariable
    public Id AccountId; //쿠폰 소유 회원의 id
    @InvocableVariable
    public DateTime ExpiredDt; //만료된 날짜/시간
    @InvocableVariable
    public String ActionType; //보낼 액션 ex)expired, used 등등
  }

  public class Response {
    @InvocableVariable
    public Boolean isSuccess;
    @InvocableVariable
    public String message;
  }

  @InvocableMethod(label='Call ExpiredERP API')
  public static List<Response> callERP(List<Request> reqs) {
    List<Response> results = new List<Response>();

    for (Request r : reqs) {
      Response res = new Response();

      try {
        Http h = new Http();
        HttpRequest hr = new HttpRequest();

        hr.setMethod('POST');
        hr.setHeader('Content-Type', 'application/json');
        hr.setEndpoint('https://milvus@goldendew.com/api/utility'); // 또는 하드코딩

        hr.setBody(JSON.serialize(new Map<String, Object>{ 'Id' => r.couponId, 'Type' => r.actionType }));

        HttpResponse hp = h.send(hr);

        if (hp.getStatusCode() == 200) {
          res.isSuccess = true;
          res.message = 'ERP 전송 성공 (Status 200)';
        } else {
          res.isSuccess = false;
          res.message = 'ERP 응답 오류: Status ' + hp.getStatusCode() + ', Body: ' + hp.getBody();
        }
      } catch (Exception e) {
        res.isSuccess = false;
        res.message = 'Apex 오류 발생: ' + e.getMessage();
      }

      results.add(res);
    }

    return results;
  }
}