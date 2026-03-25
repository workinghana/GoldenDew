/**
 * Flow Action: ERP 쿠폰 지급(Queueable enqueue)
 * - Flow에서 입력값을 받아 ErpCouponReqDto.IssueRequest 생성
 * - System.enqueueJob(new ErpCouponJob(...)) 호출
 */
public with sharing class ErpCouponFlowAction {
  // =========================
  // Flow Input / Output
  // =========================
  public class IssueInput {
    @InvocableVariable(required=true)
    public String no_man_coupon; // 쿠폰 관리 번호 (CouponManNo)

    @InvocableVariable(required=true)
    public String no_man_coupon_mil; // 쿠폰 번호 (CouponNo)

    @InvocableVariable(required=true)
    public String no_mbr; // 회원 번호 (MemberNo)

    @InvocableVariable(required=false)
    public String id_insert; // 등록자(옵션) - 없으면 실행자명 사용

    @InvocableVariable(required=false)
    public Id voucherId; // 콜백용 voucherId(옵션)
  }

  public class Output {
    @InvocableVariable
    public Boolean enqueued;
    @InvocableVariable
    public Integer requestCount;
    @InvocableVariable
    public Integer voucherIdCount;
    @InvocableVariable
    public String message;
  }

  // =========================
  // Invocable Method (Flow Action)
  // =========================
  @InvocableMethod(label='ERP 쿠폰 지급 요청 Enqueue' description='ERP 쿠폰 지급(COUPON_ISSUE) 요청을 ErpCouponJob Queueable로 enqueue 합니다.')
  public static List<Output> enqueueCouponIssue(List<IssueInput> inputs) {
    Output out = new Output();
    out.enqueued = false;
    out.requestCount = 0;
    out.voucherIdCount = 0;

    if (inputs == null || inputs.isEmpty()) {
      out.message = 'No inputs.';
      return buildOutputs(inputs, out);
    }

    // 1) IssueRequest DTO 생성
    ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
    // Birthday batch에서 수동으로 new List 넣던 패턴과 동일하게 안전하게 세팅
    couponIssueReq.couponDetailModels = new List<ErpCouponReqDto.CouponDetailModel>();

    Set<Id> voucherIdsForCallback = new Set<Id>();

    // 기본 등록자(첫 레코드 기준) - 개별 입력에 값이 있으면 그 값 우선
    String defaultInsert = inputs[0].id_insert;
    if (String.isBlank(defaultInsert)) {
      defaultInsert = UserInfo.getName();
    }

    for (IssueInput i : inputs) {
      if (i == null) {
        continue;
      }

      if (String.isBlank(i.no_man_coupon) || String.isBlank(i.no_mbr)) {
        throw new AuraHandledException('no_man_coupon and no_mbr are required.');
      }

      String idInsert = String.isBlank(i.id_insert) ? defaultInsert : i.id_insert;

      couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(i.no_man_coupon, i.no_man_coupon_mil, i.no_mbr, idInsert));

      if (i.voucherId != null) {
        voucherIdsForCallback.add(i.voucherId);
      }
    }

    out.requestCount = couponIssueReq.couponDetailModels.size();
    out.voucherIdCount = voucherIdsForCallback.size();

    if (out.requestCount == 0) {
      out.message = 'No valid couponDetailModels.';
      return buildOutputs(inputs, out);
    }

    System.debug('Enqueueing COUPON_ISSUE request. req=' + couponIssueReq);
    // enqueue
    System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIdsForCallback));

    out.enqueued = true;
    out.message = 'Enqueued COUPON_ISSUE. req=' + out.requestCount + ', voucherIds=' + out.voucherIdCount;

    return buildOutputs(inputs, out);
  }

  // Invocable outputs size 맞추기(Flow에서 안정적)
  private static List<Output> buildOutputs(List<IssueInput> inputs, Output out) {
    List<Output> outs = new List<Output>();
    Integer n = (inputs == null) ? 1 : Math.max(1, inputs.size());
    for (Integer k = 0; k < n; k++) {
      outs.add(out);
    }
    return outs;
  }
}