/**
 * ERP 토큰을 캐시에 저장하고 조회하는 유틸리티 클래스
 *
 * @author Changhwan Kim
 * @since 2026-01-13
 */
public with sharing class ApiTokenStore {
  public class TokenInfo {
    public String accessToken; // 토큰 값

    // 토큰 유효성 검사
    public Boolean isValid(Integer skewSeconds) {
      if (String.isBlank(accessToken)) {
        return false;
      }
      Long nowMs = DateTime.now().getTime();
      Long skewMs = (Long) skewSeconds * 1000;

      return skewMs > nowMs;
    }
  }

  // 토큰 정보를 캐시에서 조회
  public static String get(String tokenKey) {
    Object token = Cache.Org.get(tokenKey);

    return (token instanceof String) ? (String) token : null;
  }

  // 토큰 정보를 캐시에 저장
  public static void put(String tokenKey, String token, Integer ttlSeconds) {
    System.debug('캐시에 저장합니다. tokenKey : ' + tokenKey);
    System.debug('캐시에 저장합니다. token : ' + token);
    System.debug('캐시에 저장합니다. ttlSeconds : ' + ttlSeconds);
    // ttlSeconds는 null/0이면 기본 TTL 정책을 따르거나 에러가 날 수 있어 방어
    Integer ttl = (ttlSeconds == null || ttlSeconds <= 0) ? 300 : ttlSeconds;
    Cache.Org.put(tokenKey, token, ttl);
  }

  // 토큰 정보를 캐시에서 삭제
  public static void remove(String tokenKey) {
    // partition 인자 없이 key만 사용
    Cache.Org.remove(tokenKey);
  }
}