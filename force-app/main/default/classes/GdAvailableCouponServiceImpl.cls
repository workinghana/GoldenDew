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
      SELECT Id, VoucherDefinitionId, VoucherDefinition.Name, Status, ExpirationDate
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
        SELECT Id, EffectiveDate, ExpirationDate, ExpirationType, ExpirationPeriod, ExpirationPeriodUnit, HasTimeBasedVoucherPeriod, Name
        FROM VoucherDefinition
        WHERE Id IN :defIds
      ]
    );
  }

  /** 사용 가능 쿠폰 필터 */
  protected virtual List<Voucher> filterAvailableVouchers(List<Voucher> vouchers, Map<Id, VoucherDefinition> defMap) {
    List<Voucher> result = new List<Voucher>();

    for (Voucher v : vouchers) {
      // 상태 (Issued만 포함)
      if (v.Status != 'Issued')
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

  /**
   * 소멸쿠폰 조회
   * 회원이 보유 중인 Expired 상태의 쿠폰을 조회합니다.
   */
  public ApiResult getExpiredCoupon(Map<String, Object> reqData) {
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

      /* ================= 소멸 쿠폰 조회 ================= */
      List<Voucher> expiredVouchers = [
        SELECT Id, VoucherDefinitionId, VoucherDefinition.Name, Status, ExpirationDate, VoucherCode
        FROM Voucher
        WHERE LoyaltyProgramMemberId = :lpmId AND Status = 'Expired'
        ORDER BY ExpirationDate DESC
        LIMIT 200
      ];

      /* ================= 응답 데이터 구성 ================= */
      List<Map<String, Object>> voucherDtoList = new List<Map<String, Object>>();
      for (Voucher v : expiredVouchers) {
        Map<String, Object> dto = new Map<String, Object>();
        dto.put('id', v.Id);
        dto.put('voucherCode', v.VoucherCode);
        dto.put('voucherDefinitionId', v.VoucherDefinitionId);
        dto.put('name', v.VoucherDefinition.Name); // 쿠폰명
        dto.put('expirationDate', v.ExpirationDate);
        dto.put('status', v.Status);
        voucherDtoList.add(dto);
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('list', voucherDtoList);

      return ApiResult.ok(200, '조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}