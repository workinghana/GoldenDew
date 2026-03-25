/**
 * 매월 1일 지급 스케줄러
 * 실행 시기 : 매월 1일 새벽 2시
 */

global with sharing class MonthlyCouponissueJob implements Schedulable {
    private static GdVoucherService voucherService;
    @TestVisible
    private static Boolean testForceCustomException = false;
    @TestVisible
    private static Boolean testForceException = false;

    @Testvisible
    private static void setVoucherService(GdVoucherService mock) {
        voucherService = mock;
    }

    @TestVisible
    private static GdVoucherService getVoucherService() {
        if (voucherService == null)
            voucherService = new GdVoucherServiceImpl();
        return voucherService;
    }

    global void execute(SchedulableContext sc) {
        try {
            getVoucherService().issueBirthdayCoupon();
        } catch (CustomException ce) {
            RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
        } catch (Exception e) {
            RestResponseUtil.handleException(e, null, 500);
        }
    }
}