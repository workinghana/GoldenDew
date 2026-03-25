/**
 * ! 사용 X
 * 생일 쿠폰 지급 스케줄러
 * 실행 시기 : 매월 1일
 */
global with sharing class BirthdayCouponIssueJob implements Schedulable {
  // private static GdVoucherService voucherService;

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setVoucherService(GdVoucherService mock) {
  //   voucherService = mock;
  // }

  // private static GdVoucherService getVoucherService() {
  //   if (voucherService == null)
  //     voucherService = new GdVoucherServiceImpl();
  //   return voucherService;
  // }

  global void execute(SchedulableContext sc) {
    // try {
    //   getVoucherService().issueBirthdayCoupon();
    // } catch (CustomException ce) {
    //   RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
    // } catch (Exception e) {
    //   RestResponseUtil.handleException(e, null, 50);
    // }
  }
}