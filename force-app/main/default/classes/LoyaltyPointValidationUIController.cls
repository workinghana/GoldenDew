/**
 * LoyaltyPointValidationUIController
 *
 * LWC 버튼 클릭 호출용 포인트 정합성 검증 + 재정합 컨트롤러.
 *
 * 구성:
 *   - validatePoints(memberNo)         — read-only 검증 (현재 잔액 + LASEL 정밀)
 *   - rebuildAndValidate(memberNo)     — LASEL 재정합 + 재검증 (before/after 비교)
 *
 * 내부 위임:
 *   - LoyaltyPointInstantValidator.validateByMemberNo (§12 잔액 + LASEL 정밀 검증)
 *   - GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger (LASEL storage 재계산)
 *
 * LWC 호환을 위해 결과는 @AuraEnabled DTO 로 wrapping.
 */
public with sharing class ExpirationPeriodUnit {
  // ============================================================
  // Public API — LWC 호출 진입점
  // ============================================================

  /**
   * 회원 포인트 정합성 검증 (read-only).
   * LWC 버튼 호출용. 데이터 변경 없이 현재 정합성 진단만 수행.
   *
   * @param memberNo Contact.MemberNo__c (회원번호 문자열)
   * @return ValidationResultDto — 잔액 차이, LASEL lump mismatch, 음수 LASEL 등 종합
   */
  @AuraEnabled
  public static ValidationResultDto validatePoints(String memberNo) {
    try {
      if (String.isBlank(memberNo)) {
        throw new AuraHandledException('회원번호가 비어있습니다.');
      }
      LoyaltyPointInstantValidator.ValidationResult result = LoyaltyPointInstantValidator.validateByMemberNo(memberNo);
      return toDto(result);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw new AuraHandledException('포인트 정합성 검증 실패: ' + e.getMessage());
    }
  }

  /**
   * 회원 포인트 재정합 + 재검증.
   *
   * 동작:
   *   1. 재정합 전 상태 검증 (before)
   *   2. GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger 호출 — LASEL storage 재계산
   *   3. 재정합 후 상태 재검증 (after)
   *   4. 두 결과를 비교하여 RebuildResultDto 로 반환
   *
   * 주의:
   *   - 본 메서드는 LL/LMC 자체는 건드리지 않음. LASEL storage 필드만 LL/LLT 기준으로 재계산.
   *   - LL 자체에 결함이 있으면 재정합으로 해결 불가 (LL 정리는 별도 보정 작업 필요).
   *
   * @param memberNo Contact.MemberNo__c
   * @return RebuildResultDto — before/after ValidationResult + 성공 여부
   */
  @AuraEnabled
  public static RebuildResultDto rebuildAndValidate(String memberNo) {
    RebuildResultDto resultDto = new RebuildResultDto();
    try {
      if (String.isBlank(memberNo)) {
        throw new AuraHandledException('회원번호가 비어있습니다.');
      }

      // 1. 재정합 전 검증
      LoyaltyPointInstantValidator.ValidationResult beforeRaw = LoyaltyPointInstantValidator.validateByMemberNo(memberNo);
      resultDto.beforeResult = toDto(beforeRaw);

      if (beforeRaw.memberId == null) {
        resultDto.success = false;
        resultDto.message = '회원을 찾을 수 없습니다: ' + memberNo;
        return resultDto;
      }

      // 2. LASEL 재정합 실행
      GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(beforeRaw.memberId);

      // 3. 재정합 후 검증
      LoyaltyPointInstantValidator.ValidationResult afterRaw = LoyaltyPointInstantValidator.validateByMemberNo(memberNo);
      resultDto.afterResult = toDto(afterRaw);

      // 4. 평가
      resultDto.success = afterRaw.isValid == true;
      resultDto.message = resultDto.success
        ? '재정합 완료 — 정합성 검증 통과'
        : '재정합 후에도 정합 미달성 — LL/TJ 레벨의 추가 보정 필요 (잔여 mismatch: ' + afterRaw.lumpMismatchCount + '건)';

      return resultDto;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      resultDto.success = false;
      resultDto.message = '재정합 실패: ' + e.getMessage();
      throw new AuraHandledException(resultDto.message);
    }
  }

  /**
   * 회원 비즈니스 정합성 검증 (Phase 3 — 거래 이력 기반).
   *
   * LoyaltyPointIntegrityEngine 호출. 회원의 판매 이력을 시간순으로 재실행하여
   * 기대 적립 vs 실제 적립을 비교 (Phase 3.1: Purchase Accrual 만).
   *
   * @param memberNo Contact.MemberNo__c
   * @return IntegrityResult — Expected/Actual/Difference per PointType
   */
  @AuraEnabled
  public static LoyaltyPointIntegrityEngine.IntegrityResult validateIntegrity(String memberNo) {
    try {
      if (String.isBlank(memberNo)) {
        throw new AuraHandledException('회원번호가 비어있습니다.');
      }
      return LoyaltyPointIntegrityEngine.validateByMemberNo(memberNo);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw new AuraHandledException('정합성 검증 실패: ' + e.getMessage());
    }
  }

  // ============================================================
  // 내부 변환 헬퍼 — InstantValidator 결과 → DTO
  // ============================================================
  private static ValidationResultDto toDto(LoyaltyPointInstantValidator.ValidationResult r) {
    ValidationResultDto dto = new ValidationResultDto();
    if (r == null) {
      return dto;
    }
    dto.memberId = r.memberId;
    dto.memberNo = r.memberNo;
    dto.memberName = r.memberName;
    dto.isValid = r.isValid;
    dto.lmcBalance = r.lmcBalance;
    dto.calculatedBalance = r.calculatedBalance;
    dto.difference = r.difference;
    dto.negativeAggrLedgerCount = r.negativeAggrLedgerCount;
    dto.negativeAggrAvailablePoints = r.negativeAggrAvailablePoints;
    dto.negativeAggrLedgerIds = r.negativeAggrLedgerIds;
    dto.lumpMismatchCount = r.lumpMismatchCount;
    dto.missingLumpCount = r.missingLumpCount;
    dto.orphanLumpCount = r.orphanLumpCount;
    dto.lumpMismatchDetails = r.lumpMismatchDetails;
    dto.summary = r.summary;
    return dto;
  }

  // ============================================================
  // DTOs — LWC 호환 (@AuraEnabled 필드)
  // ============================================================

  public class ValidationResultDto {
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String memberNo;
    @AuraEnabled
    public String memberName;
    @AuraEnabled
    public Boolean isValid;
    @AuraEnabled
    public Decimal lmcBalance;
    @AuraEnabled
    public Decimal calculatedBalance;
    @AuraEnabled
    public Decimal difference;
    @AuraEnabled
    public Integer negativeAggrLedgerCount;
    @AuraEnabled
    public Decimal negativeAggrAvailablePoints;
    @AuraEnabled
    public List<Id> negativeAggrLedgerIds;
    @AuraEnabled
    public Integer lumpMismatchCount;
    @AuraEnabled
    public Integer missingLumpCount;
    @AuraEnabled
    public Integer orphanLumpCount;
    @AuraEnabled
    public List<String> lumpMismatchDetails;
    @AuraEnabled
    public String summary;
  }

  public class RebuildResultDto {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public ValidationResultDto beforeResult;
    @AuraEnabled
    public ValidationResultDto afterResult;
  }
}
