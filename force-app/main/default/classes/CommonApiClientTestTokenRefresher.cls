public with sharing class CommonApiClientTestTokenRefresher implements CommonApiClient.ITokenRefresher {
  public Boolean refresh(CommonApiClient.RequestOptions opt, CommonApiClient.ResponseWrapper lastResponse) {
    // 테스트용 토큰을 캐시에 넣고 요청 헤더도 갱신
    String token = 'TEST_TOKEN';
    ApiTokenStore.put('GOLDENDEW', token, 300);

    if (opt.headers == null)
      opt.headers = new Map<String, String>();
    opt.headers.put('Authorization', 'Bearer ' + token);
    return true;
  }
}