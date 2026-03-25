@IsTest
public class ErpAsyncJobTestHttpErrorJob_RecordId extends ErpAsyncJob {
  public ErpAsyncJobTestHttpErrorJob_RecordId(String api, Object dto, ErpAsyncCallback cb, Id rid) {
    super(api, dto, cb, rid);
  }
  protected override ErpApiResponseDto doCallout() {
    HttpErrorException he = new HttpErrorException();
    he.statusCode = 500;
    he.responseBody = '{"message":"FAIL"}';
    he.endpoint = 'callout:Dummy_NC/api';
    he.method = 'PATCH';
    he.requestUrl = he.endpoint;
    throw he;
  }
}