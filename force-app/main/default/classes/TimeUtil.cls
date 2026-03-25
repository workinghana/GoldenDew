public class TimeUtil {
  private static final String KST_TZ = 'Asia/Seoul';

  /**
   * Datetime을 "KST로 본 시간"을 기준으로 ISO-8601 UTC(Z) 문자열로 변환
   * 예) 입력이 2023-01-01 12:00:00Z(UTC) 라면
   *     KST로 보면 2023-01-01 21:00:00 이고,
   *     그 "KST 시각"을 UTC로 재표현하면 2023-01-01T12:00:00Z 가 됨
   */
  public static String toKstIsoZ(Datetime dt) {
    if (dt == null)
      return null;

    // 1) dt를 KST 타임존으로 포맷(문자열)
    String kstStr = dt.format('yyyy-MM-dd HH:mm:ss', KST_TZ);

    // 2) 그 문자열을 "KST로 해석한" Datetime으로 다시 생성(사용자 TZ 영향 제거)
    //    valueOfGmt는 입력 문자열을 GMT 기준으로 해석하므로,
    //    kstStr(=KST시각)을 GMT로 해석 => 결과는 "KST시각을 UTC로 옮긴 값"이 됨
    Datetime kstAsUtc = Datetime.valueOfGmt(kstStr);

    // 3) ISO-8601(Z)로 직렬화
    //    JSON.serialize(Datetime)는 UTC 기반 ISO 문자열을 내줌
    return (String) JSON.deserializeUntyped(JSON.serialize(kstAsUtc));
  }

  /**
   * Date를 KST 기준 "00:00:00"으로 잡아 ISO-8601 UTC(Z) 문자열로 변환
   */
  public static String dateToKstIsoZ(Date d) {
    if (d == null)
      return null;

    // KST 기준 날짜 00:00:00 문자열 생성
    String kstStr = d.format() + ' 00:00:00'; // yyyy-MM-dd 00:00:00

    // kstStr을 GMT로 해석 => KST 00:00을 UTC로 재표현한 Datetime
    Datetime kstAsUtc = Datetime.valueOfGmt(kstStr);

    return (String) JSON.deserializeUntyped(JSON.serialize(kstAsUtc));
  }

  /**
   * Date를 UTC 기준 00:00:00 Datetime으로 변환
   */
  public static Datetime dateToUtcStartOfDay(Date d) {
    if (d == null) {
      return null;
    }

    return Datetime.newInstanceGmt(d.year(), d.month(), d.day(), 0, 0, 0);
  }
}