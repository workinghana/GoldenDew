public with sharing class LoyaltyPointService {
  private static final String LOYALTY_PROGRAM_NAME = 'Golden Dew';
  private static final String PROGRAM_CURRENCY_NAME = '포인트';

  /**
   * 포인트 지급
   */
  public static List<LoyaltyManagement.CreditPointsOutput> creditPoints(List<Map<String, Object>> reqData) {
    try {
      if (reqData.isEmpty()) {
        throw new CustomException(400, 'reqData is required.');
      }

      List<LoyaltyManagement.PointsInput> creditPointsList = new List<LoyaltyManagement.PointsInput>();
      for (Map<String, Object> v : reqData) {
        if (v.isEmpty()) {
          throw new CustomException(400, 'reqData is required.');
        }

        String loyaltyProgramMemberId = ValidationUtil.stringValidation(v.get('loyaltyProgramMemberId'), 'loyaltyProgramMemberId', true);
        Double points = ValidationUtil.doubleValidation(v.get('points'), 'points', true); // 포인트 금액
        String journalId = ValidationUtil.stringValidation(v.get('journalId'), 'journalId', true); // 트랜잭션 저널 ID
        String loyaltyProgramCurrencySubtypeName = ValidationUtil.stringValidation( // 포인트 하위 유형
          v.get('loyaltyProgramCurrencySubtypeName'),
          'loyaltyProgramCurrencySubtypeName',
          false
        );
        String pointsExpirationDate = ValidationUtil.stringValidation(v.get('pointsExpirationDate'), 'pointsExpirationDate', false); // 포인트 만료 일자
        String additionalNotes = ValidationUtil.stringValidation(v.get('additionalNotes'), 'additionalNotes', false); // 추가 노트

        System.debug('loyaltyProgramMemberId : ' + loyaltyProgramMemberId);
        System.debug('points : ' + points);
        System.debug('journalId : ' + journalId);
        System.debug('loyaltyProgramCurrencySubtypeName : ' + loyaltyProgramCurrencySubtypeName);
        System.debug('pointsExpirationDate : ' + pointsExpirationDate);
        System.debug('additionalNotes : ' + additionalNotes);

        System.debug('LOYALTY_PROGRAM_NAME : ' + LOYALTY_PROGRAM_NAME);
        System.debug('PROGRAM_CURRENCY_NAME : ' + PROGRAM_CURRENCY_NAME);

        LoyaltyManagement.PointsInputBuilder builder = new LoyaltyManagement.PointsInputBuilder()
          .setLoyaltyProgramMemberId(loyaltyProgramMemberId)
          .setProgramName(LOYALTY_PROGRAM_NAME)
          .setProgramCurrencyName(PROGRAM_CURRENCY_NAME)
          .setPoints(points)
          .setJournalId(journalId);

        if (loyaltyProgramCurrencySubtypeName != null) {
          builder.setLoyaltyProgramCurrencySubtypeName(loyaltyProgramCurrencySubtypeName);
        }
        if (pointsExpirationDate != null) {
          builder.setPointsExpirationDate(pointsExpirationDate);
        }
        if (additionalNotes != null) {
          builder.setAdditionalNotes(additionalNotes);
        }

        creditPointsList.add(builder.build());
      }

      List<LoyaltyManagement.CreditPointsOutput> creditPointActionResults = LoyaltyManagement.LoyaltyResources.creditPoints(creditPointsList);
      for (LoyaltyManagement.CreditPointsOutput result : creditPointActionResults) {
        if (!result.isSuccess()) {
          System.debug(result.getErrors().get(0).getMessage());
          throw new CustomException(500, result.getErrors().get(0).getMessage());
        }
      }

      return creditPointActionResults;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 차감(사용)
   */
  public static List<LoyaltyManagement.DebitPointsOutput> debitPoints(List<Map<String, Object>> reqData) {
    System.debug('LoyaltyPointService.debitPoints 진입');
    try {
      if (reqData.isEmpty()) {
        throw new CustomException(400, 'reqData is required.');
      }

      List<LoyaltyManagement.PointsInput> debitPointsList = new List<LoyaltyManagement.PointsInput>();
      for (Map<String, Object> v : reqData) {
        if (v.isEmpty()) {
          throw new CustomException(400, 'reqData is required.');
        }

        String loyaltyProgramMemberId = ValidationUtil.stringValidation(v.get('loyaltyProgramMemberId'), 'loyaltyProgramMemberId', true);
        Double points = ValidationUtil.doubleValidation(v.get('points'), 'points', true);
        String journalId = ValidationUtil.stringValidation(v.get('journalId'), 'journalId', true);
        String loyaltyProgramCurrencySubtypeName = ValidationUtil.stringValidation( // 포인트 하위 유형
          v.get('loyaltyProgramCurrencySubtypeName'),
          'loyaltyProgramCurrencySubtypeName',
          false
        );
        String additionalNotes = ValidationUtil.stringValidation(v.get('additionalNotes'), 'additionalNotes', false); // 추가 노트

        LoyaltyManagement.PointsInputBuilder builder = new LoyaltyManagement.PointsInputBuilder()
          .setLoyaltyProgramMemberId(loyaltyProgramMemberId)
          .setProgramName(LOYALTY_PROGRAM_NAME)
          .setProgramCurrencyName(PROGRAM_CURRENCY_NAME)
          .setPoints(points)
          .setJournalId(journalId);

        System.debug('loyaltyProgramMemberId : ' + loyaltyProgramMemberId);
        System.debug('LOYALTY_PROGRAM_NAME : ' + LOYALTY_PROGRAM_NAME);
        System.debug('PROGRAM_CURRENCY_NAME : ' + PROGRAM_CURRENCY_NAME);
        System.debug('points : ' + points);
        System.debug('journalId : ' + journalId);

        if (loyaltyProgramCurrencySubtypeName != null) {
          System.debug('loyaltyProgramCurrencySubtypeName : ' + loyaltyProgramCurrencySubtypeName);
          builder.setLoyaltyProgramCurrencySubtypeName(loyaltyProgramCurrencySubtypeName);
        }
        if (additionalNotes != null) {
          System.debug('additionalNotes : ' + additionalNotes);
          builder.setAdditionalNotes(additionalNotes);
        }

        debitPointsList.add(builder.build());
      }

      List<LoyaltyManagement.DebitPointsOutput> debitPointActionResults = LoyaltyManagement.LoyaltyResources.debitPoints(debitPointsList);
      for (LoyaltyManagement.DebitPointsOutput result : debitPointActionResults) {
        if (!result.isSuccess()) {
          throw new CustomException(500, result.getErrors().get(0).getMessage());
        }
      }

      return debitPointActionResults;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 조회
   */
  public static List<LoyaltyManagement.MemberPointBalanceOutput> getPointsBalance(String loyaltyProgramMemberId) {
    try {
      if (String.isBlank(loyaltyProgramMemberId)) {
        throw new CustomException(400, 'loyaltyProgramMemberId is required.');
      }

      List<LoyaltyManagement.MemberPointBalanceInput> memberPointsBalanceList = new List<LoyaltyManagement.MemberPointBalanceInput>();

      memberPointsBalanceList.add(
        new LoyaltyManagement.MemberPointBalanceInputBuilder()
          .setLoyaltyProgramMemberId(loyaltyProgramMemberId)
          .setProgramName(LOYALTY_PROGRAM_NAME)
          .setProgramCurrencyName(PROGRAM_CURRENCY_NAME)
          .build()
      );

      List<LoyaltyManagement.MemberPointBalanceOutput> pointBalanceActionResults = LoyaltyManagement.LoyaltyResources.getPointsBalance(
        memberPointsBalanceList
      );

      for (LoyaltyManagement.MemberPointBalanceOutput result : pointBalanceActionResults) {
        if (!result.isSuccess()) {
          throw new CustomException(500, result.getErrors().get(0).getMessage());
        }
      }

      return pointBalanceActionResults;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}