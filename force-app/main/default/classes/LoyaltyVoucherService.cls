public with sharing class LoyaltyVoucherService {
  /**
   * 쿠폰 지급
   */
  public static List<LoyaltyManagement.IssueVoucherOutput> issueVoucher(List<Map<String, Object>> reqData) {
    try {
      if (reqData.isEmpty()) {
        throw new CustomException(400, 'reqData is required.');
      }

      List<LoyaltyManagement.IssueVoucherInput> issueVoucherList = new List<LoyaltyManagement.IssueVoucherInput>();
      for (Map<String, Object> v : reqData) {
        if (v.isEmpty()) {
          throw new CustomException(400, 'reqData is required.');
        }

        String loyaltyProgramMemberId = ValidationUtil.stringValidation(v.get('loyaltyProgramMemberId'), 'loyaltyProgramMemberId', true); // 로열티 멤버 Id
        String programName = ValidationUtil.stringValidation(v.get('programName'), 'programName', true); // 로열티 프로그램 Name
        String voucherDefinitionName = ValidationUtil.stringValidation(v.get('voucherDefinitionName'), 'voucherDefinitionName', true); // 바우처 정의 Name

        String journalId = ValidationUtil.stringValidation(v.get('journalId'), 'journalId', false); // 저널 Id
        String voucherCode = ValidationUtil.stringValidation(v.get('voucherCode'), 'voucherCode', false); // 바우처 코드
        String additionalNotes = ValidationUtil.stringValidation(v.get('additionalNotes'), 'additionalNotes', false); // 추가노트
        String benefitId = ValidationUtil.stringValidation(v.get('benefitId'), 'benefitId', false); // 보상 Id
        String contactId = ValidationUtil.stringValidation(v.get('contactId'), 'contactId', false); // 연락처 Id
        Integer discountPercent = ValidationUtil.integerValidation(v.get('discountPercent'), 'discountPercent', false); // 할인율
        String effectiveDate = ValidationUtil.stringValidation(v.get('effectiveDate'), 'effectiveDate', false); // 유효 시작일자
        String expiryDate = ValidationUtil.stringValidation(v.get('expiryDate'), 'expiryDate', false); // 만료일자
        Double faceValue = ValidationUtil.doubleValidation(v.get('faceValue'), 'faceValue', false); // 할인 금액
        String promotionId = ValidationUtil.stringValidation(v.get('promotionId'), 'promotionId', false); // 프로모션 Id

        LoyaltyManagement.IssueVoucherInputBuilder builder = new LoyaltyManagement.IssueVoucherInputBuilder()
          .setLoyaltyProgramMemberId(loyaltyProgramMemberId)
          .setProgramName(programName)
          .setVoucherDefinitionName(voucherDefinitionName)
          .setVoucherCode(voucherCode)
          .setJournalId(journalId);

        if (additionalNotes != null) {
          builder.setAdditionalNotes(additionalNotes);
        }
        if (benefitId != null) {
          builder.setBenefitId(benefitId);
        }
        if (contactId != null) {
          builder.setContactId(contactId);
        }
        if (discountPercent != null) {
          builder.setDiscountPercent(discountPercent);
        }
        if (effectiveDate != null) {
          builder.setEffectiveDate(effectiveDate);
        }
        if (expiryDate != null) {
          builder.setExpiryDate(expiryDate);
        }
        if (faceValue != null) {
          builder.setFaceValue(faceValue);
        }
        if (promotionId != null) {
          builder.setPromotionId(promotionId);
        }

        issueVoucherList.add(builder.build());
      }

      List<LoyaltyManagement.IssueVoucherOutput> issueVoucherActionResults = LoyaltyManagement.LoyaltyResources.issueVoucher(issueVoucherList);
      for (LoyaltyManagement.IssueVoucherOutput result : issueVoucherActionResults) {
        if (!result.isSuccess()) {
          throw new CustomException(500, result.getErrors().get(0).getMessage());
        }
      }

      return issueVoucherActionResults;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 쿠폰 지급
   * @version V2
   */
  public static List<LoyaltyManagement.IssueVoucherOutput> issueVoucherV2(List<Map<String, Object>> reqData) {
    try {
      if (reqData.isEmpty()) {
        return null;
      }

      List<LoyaltyManagement.IssueVoucherInput> issueVoucherList = new List<LoyaltyManagement.IssueVoucherInput>();
      for (Map<String, Object> v : reqData) {
        if (v.isEmpty()) {
          continue;
        }

        String loyaltyProgramMemberId = ValidationUtil.stringValidation(v.get('loyaltyProgramMemberId'), 'loyaltyProgramMemberId', true); // 로열티 멤버 Id
        String programName = ValidationUtil.stringValidation(v.get('programName'), 'programName', true); // 로열티 프로그램 Name
        String voucherDefinitionName = ValidationUtil.stringValidation(v.get('voucherDefinitionName'), 'voucherDefinitionName', true); // 바우처 정의 Name

        String journalId = ValidationUtil.stringValidation(v.get('journalId'), 'journalId', false); // 저널 Id
        String voucherCode = ValidationUtil.stringValidation(v.get('voucherCode'), 'voucherCode', false); // 바우처 코드
        String additionalNotes = ValidationUtil.stringValidation(v.get('additionalNotes'), 'additionalNotes', false); // 추가노트
        String benefitId = ValidationUtil.stringValidation(v.get('benefitId'), 'benefitId', false); // 보상 Id
        String contactId = ValidationUtil.stringValidation(v.get('contactId'), 'contactId', false); // 연락처 Id
        Integer discountPercent = ValidationUtil.integerValidation(v.get('discountPercent'), 'discountPercent', false); // 할인율
        String effectiveDate = ValidationUtil.stringValidation(v.get('effectiveDate'), 'effectiveDate', false); // 유효 시작일자
        String expiryDate = ValidationUtil.stringValidation(v.get('expiryDate'), 'expiryDate', false); // 만료일자
        Double faceValue = ValidationUtil.doubleValidation(v.get('faceValue'), 'faceValue', false); // 할인 금액
        String promotionId = ValidationUtil.stringValidation(v.get('promotionId'), 'promotionId', false); // 프로모션 Id

        LoyaltyManagement.IssueVoucherInputBuilder builder = new LoyaltyManagement.IssueVoucherInputBuilder()
          .setLoyaltyProgramMemberId(loyaltyProgramMemberId)
          .setProgramName(programName)
          .setVoucherDefinitionName(voucherDefinitionName)
          .setVoucherCode(voucherCode)
          .setJournalId(journalId);

        if (additionalNotes != null) {
          builder.setAdditionalNotes(additionalNotes);
        }
        if (benefitId != null) {
          builder.setBenefitId(benefitId);
        }
        if (contactId != null) {
          builder.setContactId(contactId);
        }
        if (discountPercent != null) {
          builder.setDiscountPercent(discountPercent);
        }
        if (effectiveDate != null) {
          builder.setEffectiveDate(effectiveDate);
        }
        if (expiryDate != null) {
          builder.setExpiryDate(expiryDate);
        }
        if (faceValue != null) {
          builder.setFaceValue(faceValue);
        }
        if (promotionId != null) {
          builder.setPromotionId(promotionId);
        }

        issueVoucherList.add(builder.build());
      }

      return LoyaltyManagement.LoyaltyResources.issueVoucher(issueVoucherList);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}