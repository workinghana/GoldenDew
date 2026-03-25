public with sharing class GdLoyaltyTierServiceImpl implements GdLoyaltyTierService {
  public GdLoyaltyTierServiceImpl() {
  }

  /**
   * 회원 등급 변경
   * LoyaltyTier update | insert
   */
  public ApiResult changeTier(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String loyaltyProgramMemberId = ValidationUtil.stringValidation(reqData.get('LoyaltyProgramMemberId'), 'LoyaltyProgramMemberId', true);
      String targetTierName = ValidationUtil.stringValidation(reqData.get('TargetTierName'), 'TargetTierName', true);
      String changeReason = ValidationUtil.stringValidation(reqData.get('ChangeReason'), 'ChangeReason', false);

      List<LoyaltyManagement.ChangeTierInput> changeTierList = new List<LoyaltyManagement.ChangeTierInput>();

      List<LoyaltyTierGroup> ltgList = [SELECT Name FROM LoyaltyTierGroup WHERE IsPrimary = TRUE LIMIT 1];
      if (ltgList.isEmpty()) {
        throw new CustomException(400, 'Tier Group is not found.');
      }

      List<LoyaltyProgram> lpList = [SELECT Name FROM LoyaltyProgram WHERE IsPrimary = TRUE LIMIT 1];
      if (lpList.isEmpty()) {
        throw new CustomException(400, 'LoyaltyProgram is not found.');
      }

      LoyaltyManagement.ChangeTierInputBuilder changeTierBuilder = new LoyaltyManagement.ChangeTierInputBuilder();
      changeTierBuilder.setLoyaltyProgramMemberId(loyaltyProgramMemberId);
      changeTierBuilder.setProgramName(lpList[0].Name);
      changeTierBuilder.setTierGroupName(ltgList[0].Name);
      changeTierBuilder.setTargetTierName(targetTierName);
      if (changeReason != null) {
        changeTierBuilder.setChangeReason(changeReason);
      }

      LoyaltyManagement.ChangeTierInput changeTierInput = changeTierBuilder.build();

      changeTierList.add(changeTierInput);

      List<LoyaltyManagement.ChangeTierOutput> changeTierActionResults = LoyaltyManagement.LoyaltyResources.changeTier(changeTierList);

      if (!changeTierActionResults.get(0).isSuccess()) {
        throw new CustomException(400, changeTierActionResults.get(0).getErrors()[0].getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      return ApiResult.ok(200, '티어 변경 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}