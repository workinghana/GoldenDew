@IsTest
public class ErpAsyncJobTestHttpErrorJob_RecordIds extends ErpAsyncJob {
  public ErpAsyncJobTestHttpErrorJob_RecordIds(String api, Object dto, ErpAsyncCallback cb, Set<Id> recordIds) {
    super(api, dto, cb, recordIds);
  }
  protected override ErpApiResponseDto doCallout() {
    HttpErrorException he = new HttpErrorException();
    he.statusCode = 500;
    he.responseBody = '{"message":"FAIL_IDS"}';
    he.endpoint = 'callout:Dummy_NC/api';
    he.method = 'PATCH';
    he.requestUrl = he.endpoint;
    throw he;
  }
}