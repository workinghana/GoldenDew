/**
 * ! 확인 필요
 * Base Request DTO (raw map + typed getters using ValidationUtil)
 *
 * - 외부 JSON 키가 snake_case / 대문자 / __c 형태여도 raw에서 그대로 꺼내서 검증 가능
 * - 각 요청 DTO는 "어떤 키를 어떤 의미로 쓸지"만 정의하면 됨
 *
 * @author ChangHwan Kim
 * @since 2026-01-15
 */
public abstract class BaseReqDto {
  protected Map<String, Object> raw;

  protected BaseReqDto(Map<String, Object> raw) {
    this.raw = raw == null ? new Map<String, Object>() : raw;
  }

  // -------------------------
  // Primitive getters
  // -------------------------
  protected String s(String key, String fieldName, Boolean required) {
    return ValidationUtil.stringValidation(raw.get(key), fieldName, required);
  }

  protected String sEx(String key, String fieldName, Boolean required, Boolean allowBlank) {
    return ValidationUtil.stringValidationEx(raw.get(key), fieldName, required, allowBlank);
  }

  protected Boolean b(String key, String fieldName, Boolean required) {
    return ValidationUtil.booleanValidation(raw.get(key), fieldName, required);
  }

  protected Date dt(String key, String fieldName, Boolean required) {
    return ValidationUtil.dateValidation(raw.get(key), fieldName, required);
  }

  protected Datetime dttm(String key, String fieldName, Boolean required) {
    return ValidationUtil.datetimeValidation(raw.get(key), fieldName, required);
  }

  /**
   * JSON.deserializeUntyped 숫자 타입 보정 포함 Integer getter
   */
  protected Integer i(String key, String fieldName, Boolean required) {
    Object v = raw.get(key);

    if (v == null) {
      return ValidationUtil.integerValidation(null, fieldName, required);
    }

    if (v instanceof Integer) {
      return (Integer) v;
    }
    if (v instanceof Decimal) {
      return ((Decimal) v).intValue();
    }
    if (v instanceof Double) {
      return Integer.valueOf(String.valueOf(v));
    }
    if (v instanceof Long) {
      return Integer.valueOf(String.valueOf(v));
    }
    if (v instanceof String) {
      return Integer.valueOf((String) v);
    }

    throw new ValidationException('BaseReqDto.i()', fieldName + ' 값의 유형이 맞지 않습니다.');
  }

  /**
   * JSON.deserializeUntyped 숫자 타입 보정 포함 Decimal getter
   */
  protected Decimal d(String key, String fieldName, Boolean required) {
    Object v = raw.get(key);

    if (v == null) {
      return ValidationUtil.decimalValidation(null, fieldName, required);
    }

    if (v instanceof Decimal) {
      return (Decimal) v;
    }
    if (v instanceof Integer) {
      return Decimal.valueOf(String.valueOf(v));
    }
    if (v instanceof Double) {
      return Decimal.valueOf(String.valueOf(v));
    }
    if (v instanceof Long) {
      return Decimal.valueOf(String.valueOf(v));
    }
    if (v instanceof String) {
      return Decimal.valueOf((String) v);
    }

    throw new ValidationException('BaseReqDto.d()', fieldName + ' 값의 유형이 맞지 않습니다.');
  }

  // -------------------------
  // Collection getters
  // -------------------------
  protected Map<String, Object> m(String key, String fieldName, Boolean required) {
    return ValidationUtil.mapStrObjValidation(raw.get(key), fieldName, required);
  }

  protected List<Object> l(String key, String fieldName, Boolean required) {
    return ValidationUtil.listObjValidation(raw.get(key), fieldName, required);
  }

  /**
   * List<Object> 안에 있는 요소(Map) 검증용
   */
  protected Map<String, Object> asMap(Object v, String fieldName, Boolean required) {
    return ValidationUtil.mapStrObjValidation(v, fieldName, required);
  }

  /**
   * raw 접근이 필요할 때(디버깅/로깅)
   */
  public Map<String, Object> getRaw() {
    return raw;
  }
}