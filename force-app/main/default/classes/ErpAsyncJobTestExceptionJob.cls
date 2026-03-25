@IsTest
public class ErpAsyncJobTestExceptionJob extends ErpAsyncJob {
  public ErpAsyncJobTestExceptionJob(String api, Object dto, ErpAsyncCallback cb, Id rid) {
    super(api, dto, cb, rid);
  }
  protected override ErpApiResponseDto doCallout() {
    throw new IllegalArgumentException('boom');
  }
}