public virtual with sharing class GdAvailableCouponServiceImpl {
  /* =====================================================
   * Public API
   * ===================================================== */
  public ApiResult getAvailableCoupon(Map<String, Object> reqData) {
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Request body is empty.');
    }

    try {
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);

      if (String.isBlank(memberNo)) {
        throw new CustomException(400, '해당 회원 번호가 없습니다.');
      }

      /* ================= LPM 조회 ================= */
      List<LoyaltyProgramMember> lpmList = findLpmByMemberNo(memberNo);

      if (lpmList.isEmpty()) {
        Map<String, Object> data = new Map<String, Object>();
        data.put('list', new List<Object>());
        return ApiResult.ok(200, '조회 성공', data);
      }

      Id lpmId = lpmList[0].Id;

      /* ================= Voucher 조회 ================= */
      List<Voucher> memberVouchers = findVouchersByLpm(lpmId);

      /* ================= Definition 로드 ================= */
      Map<Id, VoucherDefinition> defMap = loadVoucherDefinitions(memberVouchers);

      /* ================= 사용 가능 쿠폰 필터 ================= */
      List<Voucher> availableVouchers = filterAvailableVouchers(memberVouchers, defMap);

      Map<String, Object> data = new Map<String, Object>();
      data.put('list', availableVouchers);

      return ApiResult.ok(200, '조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /* =====================================================
   * 🔽 Test Seams (운영 영향 없음)
   * ===================================================== */

  /** 회원 번호로 LPM 조회 */
  protected virtual List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
    return [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo
      LIMIT 1
    ];
  }

  /** LPM 기준 Voucher 조회 */
  protected virtual List<Voucher> findVouchersByLpm(Id lpmId) {
    return [
      SELECT Id, VoucherDefinitionId, Status, ExpirationDate
      FROM Voucher
      WHERE LoyaltyProgramMemberId = :lpmId
    ];
  }

  /** VoucherDefinition 로드 */
  protected virtual Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
    Set<Id> defIds = new Set<Id>();
    for (Voucher v : vouchers) {
      if (v.VoucherDefinitionId != null) {
        defIds.add(v.VoucherDefinitionId);
      }
    }

    if (defIds.isEmpty()) {
      return new Map<Id, VoucherDefinition>();
    }

    return new Map<Id, VoucherDefinition>(
      [
        SELECT Id, EffectiveDate, ExpirationDate, ExpirationType, ExpirationPeriod, ExpirationPeriodUnit, HasTimeBasedVoucherPeriod
        FROM VoucherDefinition
        WHERE Id IN :defIds
      ]
    );
  }

  /** 사용 가능 쿠폰 필터 */
  protected virtual List<Voucher> filterAvailableVouchers(List<Voucher> vouchers, Map<Id, VoucherDefinition> defMap) {
    List<Voucher> result = new List<Voucher>();

    for (Voucher v : vouchers) {
      // 상태
      if (v.Status != '발급됨')
        continue;

      // 만료일
      if (v.ExpirationDate != null && v.ExpirationDate < Date.today()) {
        continue;
      }

      VoucherDefinition def = defMap.get(v.VoucherDefinitionId);
      if (def == null)
        continue;

      // 유효 시작일
      if (def.EffectiveDate != null && def.EffectiveDate > Date.today()) {
        continue;
      }

      result.add(v);
    }

    return result;
  }
}