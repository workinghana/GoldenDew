public with sharing class ErpPointFlowAction {
  // =========================
  // Flow Input / Output
  // =========================
  public class CreditInput {
    // ---- 필수(ERP 스펙상) ----
    @InvocableVariable(required=true)
    public String cd_company; // 회사코드

    @InvocableVariable(required=true)
    public String no_mbr; // 회원번호

    @InvocableVariable(required=true)
    public Decimal pt_target; // 대상 포인트(예: 1000)

    // ---- 선택/권장 ----
    @InvocableVariable(required=false)
    public String id_insert; // 등록자(없으면 실행자명)

    @InvocableVariable(required=false)
    public String cd_save_ledger; // 로열티 포인트 생성 키값(있으면)

    @InvocableVariable(required=false)
    public String cd_type_save; // 적립유형(01~06)

    @InvocableVariable(required=false)
    public String cd_type_point; // 포인트 유형

    // ---- 날짜/문자 필드(ERP 포맷 그대로: YYYYMM, YYYYMMDD) ----
    @InvocableVariable(required=false)
    public String ym_create; // YYYYMM
    @InvocableVariable(required=false)
    public String dt_create; // YYYYMMDD
    @InvocableVariable(required=false)
    public String dt_save_plan; // YYYYMMDD
    @InvocableVariable(required=false)
    public String dt_save; // YYYYMMDD
    @InvocableVariable(required=false)
    public String dt_limit_start; // YYYYMMDD
    @InvocableVariable(required=false)
    public String dt_limit_end; // YYYYMMDD
    @InvocableVariable(required=false)
    public String dt_destroy_plan; // YYYYMMDD
    @InvocableVariable(required=false)
    public String dt_destroy_del_sale; // YYYYMMDD

    // ---- 매출/비고 등 ----
    @InvocableVariable(required=false)
    public String no_sal;
    @InvocableVariable(required=false)
    public Decimal am_sal;
    @InvocableVariable(required=false)
    public Decimal pt_use_sale;
    @InvocableVariable(required=false)
    public Decimal pt_save_plan;
    @InvocableVariable(required=false)
    public Decimal pt_save;
    @InvocableVariable(required=false)
    public String tx_remark;

    // ---- 콜백/추적용(옵션) ----
    @InvocableVariable(required=false)
    public Id recordId; // 관련 레코드 1건(예: TransactionJournal / Contact 등)
  }

  public class Output {
    @InvocableVariable
    public Boolean enqueued;
    @InvocableVariable
    public Integer requestCount;
    @InvocableVariable
    public String message;
  }

  // =========================
  // Invocable Method (Flow Action)
  // =========================
  @InvocableMethod(label='ERP 포인트 지급 요청 Enqueue' description='ERP 포인트 지급(POINT_CREDIT) 요청을 ErpPointJob Queueable로 enqueue 합니다.')
  public static List<Output> enqueuePointCredit(List<CreditInput> inputs) {
    Output out = new Output();
    out.enqueued = false;
    out.requestCount = 0;

    if (inputs == null || inputs.isEmpty()) {
      out.message = 'No inputs.';
      return buildOutputs(inputs, out);
    }

    // 현재 ErpPointApiClient.creditPoint는 CreditRequest "1건"을 받는 구조
    // Flow에서 여러 건을 보내면 여러 Queueable로 enqueue 하도록 처리
    Integer enqCnt = 0;

    for (CreditInput i : inputs) {
      if (i == null) {
        continue;
      }

      // 최소 필수값 방어(필요한 필수항목 더 있으면 여기 추가)
      if (String.isBlank(i.cd_company) || String.isBlank(i.no_mbr) || i.pt_target == null) {
        throw new AuraHandledException('cd_company/no_mbr/pt_target is required.');
      }

      ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();

      // 필수
      req.cd_company = i.cd_company;
      req.no_mbr = i.no_mbr;
      req.pt_target = i.pt_target;

      // 등록자
      req.id_insert = String.isBlank(i.id_insert) ? UserInfo.getName() : i.id_insert;

      // 선택 필드들 매핑
      req.cd_save_ledger = i.cd_save_ledger;
      req.cd_type_save = i.cd_type_save;
      req.cd_type_point = i.cd_type_point;

      req.ym_create = i.ym_create;
      req.dt_create = i.dt_create;
      req.dt_save_plan = i.dt_save_plan;
      req.pt_save_plan = i.pt_save_plan;
      req.dt_save = i.dt_save;
      req.pt_save = i.pt_save;

      req.dt_limit_start = i.dt_limit_start;
      req.dt_limit_end = i.dt_limit_end;
      req.dt_destroy_plan = i.dt_destroy_plan;
      req.dt_destroy_del_sale = i.dt_destroy_del_sale;

      req.no_sal = i.no_sal;
      req.am_sal = i.am_sal;
      req.pt_use_sale = i.pt_use_sale;
      req.tx_remark = i.tx_remark;

      //   DebugUtil.pretty('req : ', req);
      // recordId 처리(옵션)
      //   if (i.recordId != null) {
      // 1건 연결로 enqueue
      System.enqueueJob(new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, req, new ErpPointAsyncCallback(), i.recordId));
      //   } else {
      // recordId 없으면 null로(ErpAsyncJob에서 허용되는지 전제)
      // System.enqueueJob(new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, req, new ErpPointAsyncCallback(), (Id) null));
      //   }

      enqCnt++;
    }

    out.enqueued = (enqCnt > 0);
    out.requestCount = enqCnt;
    out.message = 'Enqueued POINT_CREDIT jobs=' + enqCnt;

    return buildOutputs(inputs, out);
  }

  // Flow 출력 개수 맞추기
  private static List<Output> buildOutputs(List<CreditInput> inputs, Output out) {
    List<Output> outs = new List<Output>();
    Integer n = (inputs == null) ? 1 : Math.max(1, inputs.size());
    for (Integer k = 0; k < n; k++) {
      outs.add(out);
    }
    return outs;
  }
}