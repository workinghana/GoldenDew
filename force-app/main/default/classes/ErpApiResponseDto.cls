/**
 * ERP 공통 응답 래퍼 DTO
 * {
 *   "success": true,
 *   "message": "Success",
 *   "data": null | {...} | [...]
 * }
 */
public class ErpApiResponseDto {
  public Boolean success;
  public String message;
  public Object data;
  public Info info;

  public class Info {
    public Integer statusCode;
    public String requestUrl; // 요청 URL
    public Datetime responseDateTime; // 응답 일시
    public String method; // 호출 타입
  }

  public ErpApiResponseDto() {
  }

  /** CommonApiClient.ResponseWrapper -> ErpApiResponseDto */
  public static ErpApiResponseDto fromWrapper(CommonApiClient.ResponseWrapper res) {
    ErpApiResponseDto out = new ErpApiResponseDto();
    out.info = new Info();

    if (res != null) {
      out.info.statusCode = res.statusCode;
    }

    if (res.requestUrl != null) {
      out.info.requestUrl = res.requestUrl;
    }
    if (res.responseDateTime != null) {
      out.info.responseDateTime = res.responseDateTime;
    }

    if (res != null && res.jsonBody instanceof Map<String, Object>) {
      Map<String, Object> root = (Map<String, Object>) res.jsonBody;
      out.success = (Boolean) root.get('success');
      out.message = (String) root.get('message');
      out.data = root.get('data'); // null or Map or List
      return out;
    }

    // 안전망: 예상치 못한 형태/파싱 실패
    out.success = (res != null) ? res.isSuccess() : false;
    out.message = (res != null) ? res.rawBody : 'No response';
    out.data = null;
    return out;
  }

  /** data가 Map 형태인지 */
  public Boolean hasObjectData() {
    return data != null && (data instanceof Map<String, Object>);
  }

  /** data가 List 형태인지 */
  public Boolean hasListData() {
    return data != null && (data instanceof List<Object>);
  }
}