@IsTest
private class ErpApiResponseDtoTest {
  @IsTest
  static void test_fromWrapper_jsonBody_map_success() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 200;
    w.requestUrl = 'callout:Dummy_NC/Crm/Member';
    w.responseDateTime = System.now();
    w.method = 'PATCH';

    Map<String, Object> root = new Map<String, Object>{
      'success' => true,
      'message' => 'Success',
      'data' => new Map<String, Object>{ 'id' => '00001', 'name' => 'Kim' }
    };
    w.jsonBody = root;

    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertNotEquals(null, dto);
    System.assertNotEquals(null, dto.info);
    System.assertEquals(200, dto.info.statusCode);
    System.assertEquals('callout:Dummy_NC/Crm/Member', dto.info.requestUrl);
    System.assertNotEquals(null, dto.info.responseDateTime);

    System.assertEquals(true, dto.success);
    System.assertEquals('Success', dto.message);
    System.assertEquals(true, dto.hasObjectData());
    System.assertEquals(false, dto.hasListData());
  }

  @IsTest
  static void test_fromWrapper_jsonBody_map_list_data() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 200;

    List<Object> dataList = new List<Object>{ new Map<String, Object>{ 'a' => 1 }, new Map<String, Object>{ 'b' => 2 } };
    w.jsonBody = new Map<String, Object>{ 'success' => true, 'message' => 'OK', 'data' => dataList };

    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertEquals(true, dto.success);
    System.assertEquals('OK', dto.message);
    System.assertEquals(false, dto.hasObjectData());
    System.assertEquals(true, dto.hasListData());
  }

  @IsTest
  static void test_fromWrapper_jsonBody_not_map_fallback() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 500;
    w.status = 'Internal Server Error';
    w.rawBody = 'raw error';
    w.jsonBody = new List<Object>{ 'x' }; // Map이 아님 -> fallback

    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertEquals(false, dto.success, '500이면 isSuccess=false');
    System.assertEquals('raw error', dto.message);
    System.assertEquals(null, dto.data);
    System.assertNotEquals(null, dto.info);
    System.assertEquals(500, dto.info.statusCode);
  }

  // @IsTest
  // static void test_fromWrapper_null_response_fallback() {
  //   ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(null);

  //   System.assertNotEquals(null, dto);
  //   System.assertNotEquals(null, dto.info);
  //   System.assertEquals(false, dto.success);
  //   System.assertEquals('No response', dto.message);
  //   System.assertEquals(null, dto.data);
  //   System.assertEquals(false, dto.hasObjectData());
  //   System.assertEquals(false, dto.hasListData());
  // }

  @IsTest
  static void test_fromWrapper_sets_info_even_when_json_missing() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 204; // No Content
    w.requestUrl = 'callout:Dummy_NC/no-content';
    w.responseDateTime = System.now();
    w.rawBody = '';

    // jsonBody null -> fallback
    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertEquals(204, dto.info.statusCode);
    System.assertEquals('callout:Dummy_NC/no-content', dto.info.requestUrl);
    System.assertNotEquals(null, dto.info.responseDateTime);
    System.assertEquals(true, dto.success, '204는 isSuccess=true');
  }

  // =========================================================
  // hasObjectData - data=null -> false
  // =========================================================
  @IsTest
  static void test_hasObjectData_when_data_null() {
    ErpApiResponseDto dto = new ErpApiResponseDto();
    dto.data = null;
    System.assertEquals(false, dto.hasObjectData(), 'data=null이면 false');
    System.assertEquals(false, dto.hasListData(), 'data=null이면 false');
  }

  // =========================================================
  // hasObjectData - data가 List이면 false, hasListData=true
  // hasListData  - data가 Map이면 false, hasObjectData=true
  // =========================================================
  @IsTest
  static void test_hasObjectData_and_hasListData_cross_check() {
    ErpApiResponseDto dto = new ErpApiResponseDto();

    // Map 세팅
    dto.data = new Map<String, Object>{ 'k' => 'v' };
    System.assertEquals(true, dto.hasObjectData(), 'Map -> hasObjectData=true');
    System.assertEquals(false, dto.hasListData(), 'Map -> hasListData=false');

    // List 세팅
    dto.data = new List<Object>{ 'a', 'b' };
    System.assertEquals(false, dto.hasObjectData(), 'List -> hasObjectData=false');
    System.assertEquals(true, dto.hasListData(), 'List -> hasListData=true');
  }

  // =========================================================
  // fromWrapper - jsonBody Map, data=null ("data": null)
  // =========================================================
  @IsTest
  static void test_fromWrapper_jsonBody_map_data_null() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 200;
    w.jsonBody = new Map<String, Object>{ 'success' => true, 'message' => 'OK', 'data' => null };

    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertEquals(true, dto.success);
    System.assertEquals('OK', dto.message);
    System.assertEquals(null, dto.data);
    System.assertEquals(false, dto.hasObjectData(), 'data=null -> hasObjectData=false');
    System.assertEquals(false, dto.hasListData(), 'data=null -> hasListData=false');
  }

  // =========================================================
  // fromWrapper - jsonBody Map, success=false
  // =========================================================
  @IsTest
  static void test_fromWrapper_jsonBody_map_success_false() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 400;
    w.jsonBody = new Map<String, Object>{ 'success' => false, 'message' => 'Bad Request', 'data' => null };

    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertEquals(false, dto.success, 'success=false 파싱');
    System.assertEquals('Bad Request', dto.message);
    System.assertEquals(400, dto.info.statusCode);
  }

  // =========================================================
  // fromWrapper - jsonBody Map, data(Map) 실제 값 접근
  // =========================================================
  @IsTest
  static void test_fromWrapper_map_data_value_accessible() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 200;
    w.jsonBody = new Map<String, Object>{
      'success' => true,
      'message' => 'OK',
      'data' => new Map<String, Object>{ 'memberId' => 'M001', 'grade' => 'VIP' }
    };

    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertEquals(true, dto.hasObjectData());
    Map<String, Object> dataMap = (Map<String, Object>) dto.data;
    System.assertEquals('M001', (String) dataMap.get('memberId'), 'memberId 값 일치');
    System.assertEquals('VIP', (String) dataMap.get('grade'), 'grade 값 일치');
  }

  // =========================================================
  // fromWrapper - jsonBody Map, data(List) 실제 값 접근
  // =========================================================
  @IsTest
  static void test_fromWrapper_list_data_value_accessible() {
    CommonApiClient.ResponseWrapper w = new CommonApiClient.ResponseWrapper();
    w.statusCode = 200;
    w.jsonBody = new Map<String, Object>{
      'success' => true,
      'message' => 'OK',
      'data' => new List<Object>{ new Map<String, Object>{ 'id' => 'A' }, new Map<String, Object>{ 'id' => 'B' } }
    };

    ErpApiResponseDto dto = ErpApiResponseDto.fromWrapper(w);

    System.assertEquals(true, dto.hasListData());
    List<Object> dataList = (List<Object>) dto.data;
    System.assertEquals(2, dataList.size(), '리스트 크기 2');
    Map<String, Object> first = (Map<String, Object>) dataList[0];
    System.assertEquals('A', (String) first.get('id'), '첫 번째 항목 id=A');
  }
}