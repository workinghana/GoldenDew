/**
 * JSON Request Body Parser
 *
 * @author ChangHwan Kim
 * @since 2026-01-15
 */
public class JsonRequestParser {
  public static Map<String, Object> parseToMap(String body) {
    if (String.isBlank(body)) {
      throw new ValidationException('JsonRequestParser.parseToMap()', 'Request body is empty.');
    }

    try {
      Object o = JSON.deserializeUntyped(body);
      // body가 배열로 올 가능성까지 방어하고 싶으면 여기서 분기
      if (!(o instanceof Map<String, Object>)) {
        throw new ValidationException('JsonRequestParser.parseToMap()', 'Request body must be a JSON object.');
      }
      return (Map<String, Object>) o;
    } catch (ValidationException ve) {
      throw ve;
    } catch (Exception e) {
      throw new ValidationException('JsonRequestParser.parseToMap()', 'JSON 역직렬화 실패: ' + e.getMessage());
    }
  }
}