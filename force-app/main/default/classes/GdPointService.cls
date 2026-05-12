public interface GdPointService {
  /**
   * 포인트 지급
   */
  ApiResult creditPoint(Map<String, Object> reqData);

  /**
   * 에코포인트 지급
   */
  ApiResult creditEcopoint(Map<String, Object> reqData);

  /**
   * 포인트 조회
   */
  Double getPointList(Map<String, Object> reqData);

  /**
   * [주문,판매] 포인트 적용 도움창 조회
   */
  ApiResult getPointApplyHelp(Map<String, Object> reqData);

  /**
   * [주문,판매] 포인트 적용 도움창 조회
   * @version V2
   */
  ApiResult getPointApplyHelpV2(Map<String, Object> reqData);

  // /**
  // ! 보류
  //  * [판매반품, 교환반품] 사용한 포인트 조회
  //  */
  //ApiResult getReturnUsedPoint(String originalOrderId);

  /**
   * 사용한 포인트 조회
   */
  ApiResult getDebitPointList(Map<String, Object> reqData);

  /**
   * 포인트 사용
   */
  List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj);

  /**
   * 판매 수정 전용 포인트 사용 (same-sale 적립 제외 + 커스텀 DML, 2026-04-23 V2-SCN06 fix)
   */
  List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj);

  /**
   * 특정 포인트 차감 ([판매반품, 교환반품] 전체 삭제 API 에서 사용됨)
   * @version V1
   */
  List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList);

  /**
   * 특정 포인트 차감 V2
   * @version V2
   */
  List<PointDebitDTO> debitSpecificPointsV2(TransactionJournal tj, List<LoyaltyLedger> llList);

  /**
   * ?뱀젙 ?ъ씤??李④컧 V3
   * @version V3
   */
  List<PointDebitDTO> debitSpecificPointsV3(TransactionJournal tj, Map<Id, Decimal> requestedPointsByLedgerId);

  /**
   * LMS debitPoints 대체 후보 커스텀 차감 메서드.
   */
  List<GdSaleApiController.PointDebitDTO> debitPointsCustom(TransactionJournal tj);

  /**
   * (특정 등급의 비율에 따른) 구매 시 포인트 지급
   */
  List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData);

  /**
   * (특정 등급의 비율에 따른) 구매 시 포인트 지급 취소
   */
  List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData);

  /**
   * 특정 포인트 지급 ([판매반품, 교환반품] 전체 삭제 API 에서 사용됨)
   */
  List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList);

  /**
   * 구매 시 포인트 지급
   */
  List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data);

  /**
   * 에코포인트 적립 취소 복원
   */
  List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId);

  /**
   * 구매 시 포인트 지급 V2
   */
  List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount);

  /**
   * [옵션 C — 옛 일자 신규 판매 전용] 구매 시 포인트 지급 (기타포인트 redirect)
   *
   * 표준 creditPointsOnPurchaseV2 와 동일 동작이되,
   *   - 등급 보상 중 PT='01' (구매포인트) 비율만 사용
   *   - 적립 SubType 은 '기타포인트' 로 강제 redirect
   *
   * 만료일 / 적립 일자 / LL/LLT/LASEL 자동 생성 / TJ.PostPointBalance 업데이트는 표준과 100% 동일.
   */
  List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount);

  /**
   * 프로모션 포인트 지급
   */
  List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount);

  /**
   * 포인트 사용 취소
   */
  Map<String, Object> cancelPointRedemption(TransactionJournal tj);

  /**
   * 구매 시 지급된 포인트 적립 취소
   */
  List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data);

  /**
   * 포인트 개별 삭제(소멸)
   */
  ApiResult deletePoint(Map<String, Object> reqData);

  /**
   * 포인트 적립 대상 판단
   */
  Boolean isAccrualEligible(TransactionJournal tj);

  /**
   * 포인트 수정
   */
  ApiResult updatePoint(Map<String, Object> reqData);
}