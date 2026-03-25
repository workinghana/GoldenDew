@IsTest
public class ErpAsyncJobTestSuccessJob extends ErpAsyncJob {
  public ErpAsyncJobTestSuccessJob(String api, Object dto, ErpAsyncCallback cb, Id rid) {
    super(api, dto, cb, rid);
  }
  protected override ErpApiResponseDto doCallout() {
    ErpApiResponseDto dto = new ErpApiResponseDto();
    dto.info = new ErpApiResponseDto.Info();
    dto.info.statusCode = 200;
    dto.info.requestUrl = 'callout:Dummy_NC/api';
    dto.info.responseDateTime = System.now();
    dto.info.method = 'PATCH';
    dto.success = true;
    dto.message = 'OK';
    dto.data = new Map<String, Object>{ 'x' => 1 };
    return dto;
  }
}