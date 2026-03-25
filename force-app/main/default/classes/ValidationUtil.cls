/**
 * 유효성 검사 Util Class
 *
 * @author ChangHwan Kim
 * @since 2026-01-06
 */
public class ValidationUtil {
  /**
   * Object 타입의 값을 String 타입으로 검증 후 반환
   *
   * @param v 검증 대상 값
   * @param fieldName 오류 메시지에 사용될 필드명
   * @param isRequired 필수 값 여부
   * @return 검증된 String 값 또는 null
   * @throws ValidationException  필수값 누락 또는 타입이 String이 아닐 경우
   * */
  public static String stringValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('stringValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof String) {
      return (String) v;
    } else {
      throw new ValidationException('stringValidation()', fieldName + ' 값의 유형이 맞지 않습니다.');
    }
  }

  /**
   * String 타입 검증
   * 빈 값 체크
   */
  public static String stringValidationEx(Object v, String fieldName, Boolean isRequired, Boolean allowBlank) {
    try {
      if (v == null) {
        if (isRequired) {
          throw new ValidationException('stringValidationEx()', fieldName + ' 값이 없습니다.');
        }
        return null;
      }

      if (v instanceof String) {
        if (!allowBlank && String.isBlank((String) v)) {
          throw new ValidationException('stringValidationEx()', fieldName + ' 값이 비었습니다.');
        }
        return (String) v;
      } else {
        throw new ValidationException('stringValidationEx()', fieldName + ' 값의 유형이 맞지 않습니다.');
      }
    } catch (Exception e) {
      throw e;
    }
  }

  /** Integer 타입 검증 */
  public static Integer integerValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('integerValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof Integer) {
      return (Integer) v;
    } else {
      throw new ValidationException('integerValidation()', fieldName + ' 값의 유형이 맞지 않습니다.');
    }
  }

  /** Decimal 타입 검증*/
  public static Decimal decimalValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('decimalValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof Decimal) {
      return (Decimal) v;
    } else {
      throw new ValidationException('decimalValidation()', fieldName + ' 값의 유형이 맞지 않습니다.');
    }
  }

  /** Decimal 타입 검증 (0보다 클 때만 허용) */
  public static Decimal decimalGreaterThanZero(Object v, String fieldName, Boolean isRequired) {
    // 기본 Decimal 타입 / null 검증
    Decimal value = decimalValidation(v, fieldName, isRequired);

    // 필수가 아니라면 null 반환
    if (value == null) {
      return null;
    }

    // 값 검증 (0보다 커야 함)
    if (value <= 0) {
      throw new ValidationException('decimalGreaterThanZero()', fieldName + ' 값은 0보다 커야 합니다. (요청 값: ' + value + ')');
    }

    return value;
  }

  /** Double 타입 검증*/
  public static Double doubleValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('doubleValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof Double) {
      return (Double) v;
    } else {
      throw new ValidationException('doubleValidation()', fieldName + ' 값의 유형이 맞지 않습니다.');
    }
  }

  /** Boolean 타입 검증 */
  public static Boolean booleanValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('booleanValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof Boolean) {
      return (Boolean) v;
    } else {
      throw new ValidationException('booleanValidation()', fieldName + ' 값의 유형이 맞지 않습니다.');
    }
  }
  /**
   * Date 타입 검증
   * YYYY-MM-DD | YYYYMMDD 형식만 지원함
   * */
  public static Date dateValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('dateValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof Date) {
      return (Date) v;
    }

    if (v instanceof String) {
      String s = ((String) v).trim();
      if (String.isBlank(s)) {
        if (isRequired) {
          throw new ValidationException('dateValidation()', fieldName + ' 값이 비어 있습니다.');
        }
        return null;
      }

      try {
        // YYYY-MM-DD 형식
        if (s.contains('-')) {
          return Date.valueOf(s); // Date.valueOf 는 "YYYY-MM-DD" 형식만 지원함
        }
        // YYYYMMDD 형식
        else if (s.length() == 8 && Pattern.matches('\\d{8}', s)) {
          Integer year = Integer.valueOf(s.substring(0, 4));
          Integer month = Integer.valueOf(s.substring(4, 6));
          Integer day = Integer.valueOf(s.substring(6, 8));
          return Date.newInstance(year, month, day);
        }
        // 지원하지 않는 형식
        else {
          throw new ValidationException('dateValidation()', '지원하지 않는 날짜 형식입니다: ' + s);
        }
      } catch (ValidationException ve) {
        throw ve;
      } catch (Exception e) {
        throw new ValidationException('dateValidation()', '날짜 형식이 올바르지 않습니다. (YYYY-MM-DD 또는 YYYYMMDD): ' + s);
      }
    } else {
      throw new ValidationException('dateValidation()', fieldName + ' 값의 유형이 String이 아닙니다.');
    }
  }

  /**
   * Datetime 타입 검증
   * YYYY-MM-DD HH:MM:SS | YYYYMMDDHHMMSS 형식만 지원함
   * */
  public static Datetime datetimeValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('datetimeValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof Datetime) {
      return (Datetime) v;
    }

    if (v instanceof String) {
      String s = ((String) v).trim();

      if (String.isBlank(s)) {
        if (isRequired) {
          throw new ValidationException('datetimeValidation()', fieldName + ' 값이 비어 있습니다.');
        }
        return null;
      }

      try {
        // 표준 형식: "YYYY-MM-DD HH:MM:SS"
        if (s.contains('-') && s.contains(':')) {
          return Datetime.valueOf(s);
        }
        // 단축형식: "YYYYMMDDHHMMSS"
        else if (s.length() == 14 && Pattern.matches('\\d{14}', s)) {
          Integer year = Integer.valueOf(s.substring(0, 4));
          Integer month = Integer.valueOf(s.substring(4, 6));
          Integer day = Integer.valueOf(s.substring(6, 8));
          Integer hour = Integer.valueOf(s.substring(8, 10));
          Integer minute = Integer.valueOf(s.substring(10, 12));
          Integer second = Integer.valueOf(s.substring(12, 14));
          return Datetime.newInstance(year, month, day, hour, minute, second);
        }
        // 지원하지 않는 형식
        else {
          throw new ValidationException('datetimeValidation()', '지원하지 않는 날짜/시간 형식입니다: ' + s);
        }
      } catch (ValidationException ve) {
        throw ve;
      } catch (Exception e) {
        throw new ValidationException('datetimeValidation()', '날짜/시간 형식이 올바르지 않습니다. (YYYY-MM-DD HH:MM:SS 또는 YYYYMMDDHHMMSS): ' + s);
      }
    }

    // 다른 타입일 경우 예외 처리
    throw new ValidationException('datetimeValidation()', fieldName + ' 값의 유형이 올바르지 않습니다.');
  }

  /** List<Object> 타입 검증 */
  public static List<Object> listObjValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('listValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof List<Object>) {
      List<Object> listValue = (List<Object>) v;
      if (listValue.isEmpty() && isRequired) {
        throw new ValidationException('listValidation()', fieldName + ' 값이 비어 있습니다.');
      }
      return listValue;
    } else {
      throw new ValidationException('listValidation()', fieldName + ' 값의 유형이 List가 아닙니다.');
    }
  }

  /** List<Object> 타입 검증 후 List<String> 타입으로 반환 */
  public static List<String> listObjToStrValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('listValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof List<Object>) {
      List<Object> listValue = (List<Object>) v;
      if (listValue.isEmpty() && isRequired) {
        throw new ValidationException('listValidation()', fieldName + ' 값이 비어 있습니다.');
      }
      return (List<String>) JSON.deserialize(JSON.serialize(listValue), List<String>.class);
    } else {
      throw new ValidationException('listValidation()', fieldName + ' 값의 유형이 List가 아닙니다.');
    }
  }

  /** Map<String, Object> 타입 검증 */
  public static Map<String, Object> mapStrObjValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('mapValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof Map<String, Object>) {
      Map<String, Object> mapValue = (Map<String, Object>) v;
      if (mapValue.isEmpty() && isRequired) {
        throw new ValidationException('mapValidation()', fieldName + ' 값이 비어 있습니다.');
      }
      return mapValue;
    } else {
      throw new ValidationException('mapValidation()', fieldName + ' 값의 유형이 Map<String, Object>이 아닙니다.');
    }
  }

  /** SObject 타입 검증 */
  public static SObject sObjectValidation(Object v, String fieldName, Boolean isRequired) {
    if (v == null) {
      if (isRequired) {
        throw new ValidationException('sObjectValidation()', fieldName + ' 값이 없습니다.');
      }
      return null;
    }

    if (v instanceof SObject) {
      return (SObject) v;
    } else {
      throw new ValidationException('sObjectValidation()', fieldName + ' 값의 유형이 맞지 않습니다.');
    }
  }
}