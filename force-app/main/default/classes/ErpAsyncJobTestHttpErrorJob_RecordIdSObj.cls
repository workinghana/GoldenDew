@IsTest
public class ErpAsyncJobTestHttpErrorJob_RecordIdSObj extends ErpAsyncJob {
  public ErpAsyncJobTestHttpErrorJob_RecordIdSObj(String api, Object dto, ErpAsyncCallback cb, Id rid, SObject o) {
    super(api, dto, cb, rid, o);
  }
  protected override ErpApiResponseDto doCallout() {
    HttpErrorException he = new HttpErrorException();
    he.statusCode = 500;
    he.responseBody = '{"message":"FAIL_SOBJ"}';
    he.endpoint = 'callout:Dummy_NC/api';
    he.method = 'PATCH';
    he.requestUrl = he.endpoint;
    throw he;
  }
}