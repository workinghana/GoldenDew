public with sharing class GdMemberHelpInfoServiceImpl implements GdMemberHelpInfoService {
  //결제 방법 결과 데이터 맵핑
  private static final Map<String, String> PAYMENT_METHOD_MAP = new Map<String, String>{
    '01' => '현금',
    '03' => '카드',
    '05' => '제예금',
    '06' => '가주문',
    '07' => '외상대금',
    '10' => '매입',
    '20' => 'Upgrade',
    '70' => 'CRD',
    '80' => '온라인몰포인트',
    '81' => '포인트',
    '82' => '스타일러스포인트',
    '90' => '본사상품권',
    '91' => '캐럿상품권',
    '92' => '백화점상품권',
    '93' => '본사교환권'
  };
  //쿠폰 관리 코드 맵핑
  private static final Map<String, String> COUPON_MAN_NO_MAP = new Map<String, String>{
    '01' => '교환권',
    '02' => '사은품쿠폰',
    '03' => '본사상품권',
    '04' => '(S)D/C쿠폰'
  };

  /**
   * 회원 정보 조회
   * */
  public ApiResult getMemberHelpInfo(Map<String, Object> reqData) {
    // 요청 body 검증
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Request body is empty.');
    }

    // 회원번호 추출
    String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

    //회원 조회(요청 데이터)
    List<LoyaltyProgramMember> lpmList = [
      SELECT Id, Contact.MemberNo__c, MemberStatus, Contact.Name, Contact.Phone, Contact.MobilePhone, Contact.Email, Contact.Birthdate
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo
      LIMIT 1
    ];

    if (lpmList.isEmpty()) {
      throw new CustomException(400, '존재하지 않는 회원입니다. memberNo=' + memberNo);
    }

    LoyaltyProgramMember lpm = lpmList[0];
    Map<String, Object> data = new Map<String, Object>();

    //---------임금 내역 조회---------
    List<TransactionJournal> tjlist = [
      SELECT
        Brand,
        DepositType__c,
        DepositNo__c,
        DeposiSeqNo__c,
        TransactionAmount,
        PaymentMethod,
        Quantity,
        ActivityDate,
        Status,
        JournalTypeName__c,
        JournalReason,
        TotalPromotionDiscount,
        PromotionId
      FROM TransactionJournal
      WHERE MemberId = :lpm.id AND TransactionAmount != NULL AND DepositNo__c != NULL
    ];

    List<Map<String, Object>> depositlist = new List<Map<String, Object>>();

    for (TransactionJournal t : tjlist) {
      Map<String, Object> deposit = new Map<String, Object>();
      deposit.put('Brand', t.Brand);
      deposit.put('DepositType', t.DepositType__c);
      deposit.put('DepositNo', t.DepositNo__c);
      deposit.put('DepositSeqNo', t.DeposiSeqNo__c);
      deposit.put('JournalReason', t.JournalReason);

      deposit.put('TransactionAmount', t.TransactionAmount);

      String paymentCode = t.PaymentMethod;
      String paymentLabel = PAYMENT_METHOD_MAP.containsKey(paymentCode) ? PAYMENT_METHOD_MAP.get(paymentCode) : paymentCode; // fallback

      deposit.put('PaymentMethodCode', paymentCode);
      deposit.put('PaymentMethodName', paymentLabel);

      deposit.put('Quantity', t.Quantity);
      deposit.put('Status', t.Status);

      deposit.put('JournalTypeName', t.JournalTypeName__c);
      deposit.put('JournalReason', t.JournalReason);

      deposit.put('TotalPromotionDiscount', t.TotalPromotionDiscount);
      deposit.put('PromotionId', t.PromotionId);

      depositlist.add(deposit);
    }

    data.put('Depositlist', depositlist);

    //---------구매 내역 조회---------
    List<Order> olist = [
      SELECT
        Name,
        EffectiveDate,
        Status,
        ActualPaymentAmount__c,
        TotalAmount,
        StoreCode__c,
        SaleNo__c,
        EndDate,
        Type,
        SaleStatus__c,
        OrderReferenceNumber,
        InsertId__c,
        ActivatedDate,
        DeleteDateTime__c
      FROM Order
      WHERE MemberNo__c = :lpm.ContactId
      LIMIT 1
    ];

    if (olist.isEmpty()) {
      // throw new CustomException(400, '해당 회원의 구매 내역이 없습니다.');
    }

    List<Map<String, Object>> orders = new List<Map<String, Object>>();

    for (Order o : olist) {
      Map<String, Object> order = new Map<String, Object>();

      // 기본 주문 정보
      order.put('OrderName', o.Name);
      order.put('OrderDate', o.EffectiveDate);
      order.put('Status', o.Status);

      // 금액 정보
      order.put('TotalAmount', o.TotalAmount);
      order.put('ActualPaymentAmount', o.ActualPaymentAmount__c);

      // 매장 정보
      order.put('StoreCode', o.StoreCode__c);

      // 판매 / ERP 연계 정보
      order.put('SaleNo', o.SaleNo__c);
      order.put('SaleEndDate', o.EndDate);
      order.put('OrderType', o.Type);
      order.put('SaleStatus', o.SaleStatus__c);
      order.put('OrderReferenceNumber', o.OrderReferenceNumber);
      order.put('InsertId', o.InsertId__c);

      // 상태/이력 관련
      order.put('ActivatedDate', o.ActivatedDate);
      order.put('DeleteDateTime', o.DeleteDateTime__c);

      orders.add(order);
    }

    data.put('OrdersList', orders);

    //데이터 존재X
    //---------수선 내역 조회---------
    List<WorkOrder> wlist = [
      SELECT
        WorkOrderNumber, // 작업 주문 번호 (수선 접수 번호)
        Subject, // 수선 제목 / 작업 주제
        Status, // 수선 진행 상태 (접수, 진행중, 완료 등)
        Priority, // 우선순위 (긴급 여부 판단)
        StartDate, // 수선 시작 일자
        EndDate, // 수선 완료 일자
        IsClosed, // 작업 종료 여부 (true = 완료)
        GrandTotal, // 총 수선 금액
        Discount, // 할인 금액 (무상/부분 유상 판단)
        Description, // 수선 상세 설명
        CreatedDate // 수선 접수(생성) 일자
      FROM WorkOrder
      WHERE ContactId = :lpm.ContactId
      ORDER BY CreatedDate DESC
    ];

    // if(wlist.isEmpty()){
    //             throw new CustomException(400, '해당 회원의 수선 내역이 없습니다.');
    // }

    List<Map<String, Object>> works = new List<Map<String, Object>>();

    for (WorkOrder w : wlist) {
      Map<String, Object> work = new Map<String, Object>();

      // 기본 식별 정보
      work.put('WorkOrderNumber', w.WorkOrderNumber);
      work.put('Subject', w.Subject);
      work.put('Description', w.Description);

      // 상태 정보
      work.put('Status', w.Status);
      work.put('Priority', w.Priority);
      work.put('IsClosed', w.IsClosed);

      // 날짜 정보
      work.put('StartDate', w.StartDate);
      work.put('EndDate', w.EndDate);
      work.put('CreatedDate', w.CreatedDate);

      // 금액 정보
      work.put('GrandTotal', w.GrandTotal);
      work.put('Discount', w.Discount);

      works.add(work);
    }

    data.put('WorksList', works);

    //     //데이터 존재X
    //     //---------CS 내역 조회---------
    List<Case> clist = [
      SELECT
        Id,
        CaseNumber, // 사례 번호
        Subject, // 제목
        Type, // 유형
        Reason, // 사례 이유
        Origin, // 접수 경로
        Status, // 상태
        Priority, // 중요도
        IsEscalated, // 에스컬레이션 여부
        CreatedDate, // 접수 일시
        ClosedDate, // 종료 일시
        Owner.Name, // 담당자
        Description // 설명
      FROM Case
      WHERE Contact.MemberNo__c = :memberNo
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    // if (cList.isEmpty()) {
    //             throw new CustomException(400, '해당 회원의 cs내역이 존재하지 않습니다.');
    // }

    List<Map<String, Object>> cases = new List<Map<String, Object>>();

    for (Case c : cList) {
      Map<String, Object> cs = new Map<String, Object>();

      cs.put('CaseId', c.Id);
      cs.put('CaseNumber', c.CaseNumber);
      cs.put('Subject', c.Subject);
      cs.put('Type', c.Type);
      cs.put('Reason', c.Reason);
      cs.put('Origin', c.Origin);
      cs.put('Status', c.Status);
      cs.put('Priority', c.Priority);
      cs.put('IsEscalated', c.IsEscalated);
      cs.put('CreatedDate', c.CreatedDate);
      cs.put('ClosedDate', c.ClosedDate);
      cs.put('OwnerName', c.Owner != null ? c.Owner.Name : null);
      cs.put('Description', c.Description);

      cases.add(cs);
    }

    data.put('CustomerServiceHistory', cases);

    //데이터 존재X
    //---------상담 내역 조회---------

    List<Task> tlist = [
      SELECT
        Id,
        Subject, // 상담 제목
        Type, // 상담 유형
        Status, // 상담 상태
        Priority, // 중요도
        ActivityDate, // 상담 일자
        Description, // 상담 내용
        CallType, // 통화 유형
        CallDisposition, // 통화 결과
        CallDurationInSeconds, // 통화 시간
        CompletedDateTime, // 완료 일시
        Owner.Name, // 상담 담당자
        CreatedDate, // 기록 생성일
        WhatId // 관련 Case / Order
      FROM Task
      WHERE WhoId = :lpm.ContactId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    // if(tlist.isEmpty()){
    //             throw new CustomException(400, '해당 회원의 상담 내역이 존재하지 않습니다.');
    // }

    List<Map<String, Object>> tasks = new List<Map<String, Object>>();

    for (Task t : tlist) {
      Map<String, Object> task = new Map<String, Object>();

      // 기본 식별 정보
      task.put('TaskId', t.Id);
      task.put('Subject', t.Subject); // 상담 제목
      task.put('Type', t.Type); // 상담 유형
      task.put('Status', t.Status); // 상담 상태
      task.put('Priority', t.Priority); // 중요도

      // 일정 / 시간 관련
      task.put('ActivityDate', t.ActivityDate); // 상담 일자
      task.put('CompletedDateTime', t.CompletedDateTime); // 완료 일시
      task.put('CallDurationInSeconds', t.CallDurationInSeconds); // 통화 시간(초)

      // 상담 내용
      task.put('Description', t.Description); // 상담 내용

      // 통화 상담 정보
      task.put('CallType', t.CallType); // 통화 유형
      task.put('CallDisposition', t.CallDisposition); // 통화 결과

      // 담당자 / 생성 정보
      task.put('OwnerName', t.Owner != null ? t.Owner.Name : null); // 상담 담당자
      task.put('CreatedDate', t.CreatedDate); // 기록 생성 일자

      // 연관 객체 (Case / Order 등)
      task.put('RelatedObjectId', t.WhatId);

      tasks.add(task);
    }

    data.put('ConsultationList', tasks);

    //데이터 존재X
    //---------상담 노트 조회---------
    //---------상담 노트 조회 (Task 기반)---------
    /** 상담 노트 연동 X */
    // List<Task> noteTasks = [
    //   SELECT Id, Subject, Description, CreatedDate, CompletedDateTime, Owner.Name, WhatId
    //   FROM Task
    //   WHERE WhoId = :lpm.ContactId
    //   ORDER BY CreatedDate DESC
    // ];

    // List<Map<String, Object>> consultNoteList = new List<Map<String, Object>>();

    // for (Task t : noteTasks) {
    //   // Apex 단에서 Description 존재 여부 판단
    //   if (String.isNotBlank(t.Description)) {
    //     Map<String, Object> note = new Map<String, Object>();
    //     note.put('TaskId', t.Id);
    //     note.put('Subject', t.Subject);
    //     note.put('Note', t.Description);
    //     note.put('CreatedDate', t.CreatedDate);
    //     note.put('OwnerName', t.Owner != null ? t.Owner.Name : null);
    //     note.put('RelatedObjectId', t.WhatId);

    //     consultNoteList.add(note);
    //   }
    // }

    // data.put('ConsultationNoteList', consultNoteList);

    //---------변경 내역 조회---------
    List<Map<String, Object>> historyList = new List<Map<String, Object>>();

    // 1. LoyaltyProgramMemberHistory
    for (LoyaltyProgramMemberHistory h : [
      SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
      FROM LoyaltyProgramMemberHistory
      WHERE LoyaltyProgramMemberId = :lpm.Id
    ]) {
      Map<String, Object> updates = new Map<String, Object>();
      updates.put('changeDate', h.CreatedDate);
      updates.put('changeTarget', 'LoyaltyProgramMember');
      updates.put('field', h.Field);
      updates.put('oldValue', String.valueOf(h.OldValue));
      updates.put('newValue', String.valueOf(h.NewValue));
      updates.put('changedBy', h.CreatedBy.Name);

      historyList.add(updates);
    }

    // 2. ContactHistory
    if (lpm.ContactId != null) {
      for (ContactHistory h : [
        SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
        FROM ContactHistory
        WHERE ContactId = :lpm.ContactId
      ]) {
        Map<String, Object> updates = new Map<String, Object>();
        updates.put('changeDate', h.CreatedDate);
        updates.put('changeTarget', 'Contact');
        updates.put('field', h.Field);
        updates.put('oldValue', String.valueOf(h.OldValue));
        updates.put('newValue', String.valueOf(h.NewValue));
        updates.put('changedBy', h.CreatedBy.Name);

        historyList.add(updates);
      }
    }

    if (historyList.isEmpty()) {
      throw new CustomException(400, '변경 내역이 없습니다.');
    }

    data.put('HistoryUpdatedList', historyList);

    //---------사은품 내역 -> 보상 내역으로 대체---------
    List<MemberBenefit> mbList = [
      SELECT
        Id,
        Name, // 사은품 지급 이름
        Status, // 지급 상태
        StartDate,
        EndDate,
        Description,
        CreatedDate,
        BenefitId,
        Benefit.Name, // 사은품명
        Benefit.BenefitTypeId, // 사은품 유형
        Benefit.Description, // 설명
        Benefit.ImageUrl // 이미지
      FROM MemberBenefit
      WHERE MemberId = :lpm.Id
      ORDER BY CreatedDate DESC
    ];

    List<Map<String, Object>> giftList = new List<Map<String, Object>>();

    for (MemberBenefit mb : mbList) {
      Map<String, Object> gift = new Map<String, Object>();

      // 지급 정보
      gift.put('MemberBenefitId', mb.Id);
      gift.put('Status', mb.Status);
      gift.put('StartDate', mb.StartDate);
      gift.put('EndDate', mb.EndDate);
      gift.put('CreatedDate', mb.CreatedDate);
      gift.put('Description', mb.Description);

      // 사은품 정의 정보
      gift.put('BenefitId', mb.BenefitId);
      gift.put('BenefitName', mb.Benefit != null ? mb.Benefit.Name : null);
      gift.put('BenefitCategory', mb.Benefit != null ? mb.Benefit.BenefitTypeId : null);
      gift.put('BenefitDescription', mb.Benefit != null ? mb.Benefit.Description : null);
      gift.put('BenefitImage', mb.Benefit != null ? mb.Benefit.ImageUrl : null);

      giftList.add(gift);
    }

    data.put('GiftList', giftList);

    //---------포인트 조회---------

    // List<LoyaltyMemberCurrency> lpcList = [
    //     SELECT
    //     LoyaltyMemberId,
    //         Name, //포인트 하위 이름
    //         LoyaltyProgramCurrency.HasEscrow, //포인트 적립 예정 유무
    //         LoyaltyProgramCurrency.LoyaltyTierGroupId, //멤버십 그룹
    //         PointsBalance, //포인트 잔액
    //         TotalPointsAccrued, // 누적된 포인트 총액
    //         EscrowPointsBalance, //포인트 예정 잔액
    //         TotalPointsRedeemed, //상황된 포인트 총액
    //         TotalEscrowRolloverPoints, //에스크로 롤오버 포인트 총액
    //         BalanceBeforeReset, //재설정 전 잔액

    //         LastEscrowProcessedDate, //포인트 지급 최종 일자
    //         LastPointsAggregationDate, //마지막 포인트 집계 일자
    //         LastResetDate, //마지막 재설정 일자
    //         NextResetDate, //다음 재설정 일자
    //         LastExpiredPtTraceabilityRunDt, //최근 만료된 포인트 추적 기능 실행 일자
    //         LastAccrualProcessedDate, //최종 누적 처리 일자
    //         RedemStlPendFromDateTime //상환 정산 보류 시작 일자 시간

    //     FROM LoyaltyMemberCurrency
    //     WHERE LoyaltyMember.Contact.MemberNo__c = :memberNo
    // ];

    // // if (lpcList.isEmpty()) {
    //     //     throw new CustomException(400,'보유한 포인트가 없습니다.');
    // // }

    // List<Map<String, Object>> pointList = new List<Map<String, Object>>();

    // for (LoyaltyMemberCurrency lpc : lpcList) {
    //     Map<String, Object> points = new Map<String, Object>();

    //     points.put('NamRedemStlPendFromDateTimee', lpc.RedemStlPendFromDateTime);
    //     points.put('LastAccrualProcessedDate', lpc.LastAccrualProcessedDate);
    //     points.put('NLastExpiredPtTraceabilityRunDtame', lpc.LastExpiredPtTraceabilityRunDt);
    //     points.put('NextResetDate', lpc.NextResetDate);
    //     points.put('LastResetDate', lpc.LastResetDate);
    //     points.put('LastPointsAggregationDate', lpc.LastPointsAggregationDate);
    //     points.put('NamLastEscrowProcessedDatee', lpc.LastEscrowProcessedDate);
    //     points.put('BalanceBeforeReset', lpc.BalanceBeforeReset);
    //     points.put('TotalEscrowRolloverPoints', lpc.TotalEscrowRolloverPoints);
    //     points.put('TotalPointsRedeemed', lpc.TotalPointsRedeemed);
    //     points.put('NaEscrowPointsBalancee', lpc.EscrowPointsBalance);
    //     points.put('TotalPointsAccrued', lpc.TotalPointsAccrued);
    //     points.put('PointsBalance', lpc.PointsBalance);
    //     points.put('LoyaltyTierGroupId',lpc.LoyaltyProgramCurrency.LoyaltyTierGroupId);
    //     points.put('HasEscrow',lpc.LoyaltyProgramCurrency.HasEscrow);
    //     points.put('Name', lpc.Name);
    //     points.put('LoyaltyMemberId', lpc.LoyaltyMemberId);

    //     pointList.add(points);
    // }

    // data.put('PointList', pointList);

    //고객사 요청 : 총포인트값만 보이게
    //--------- 포인트 조회 ---------

    List<LoyaltyMemberCurrency> lpcList = [
      SELECT PointsBalance
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMember.Contact.MemberNo__c = :memberNo
    ];

    // 총 포인트 (PointsBalance 합계)
    Decimal totalPointsBalance = 0;

    for (LoyaltyMemberCurrency lpc : lpcList) {
      if (lpc.PointsBalance != null) {
        totalPointsBalance += lpc.PointsBalance;
      }
    }

    // PointList : 총 포인트만 1건
    // List<Map<String, Object>> pointList = new List<Map<String, Object>>();

    // Map<String, Object> totalPointRow = new Map<String, Object>();
    // totalPointRow.put('TotalPointsBalance', totalPointsBalance);
    // pointList.add(totalPointRow);

    // 응답
    // data.put('PointList', pointList);
    data.put('TotalPointsBalance', totalPointsBalance);

    // --------- 쿠폰 조회 ---------
    List<Voucher> vouchers = [
      SELECT
        Id,
        Status, // 쿠폰 상태
        EffectiveDate, // 시작일자
        UseDate, // 사용일자
        ExpirationDate, // 종료일자
        CreatedDate, // 발급일자
        CreatedBy.Name, // 등록자
        FaceValue, // 할인금액(정액)
        DiscountPercent, // 할인율(정률)
        VoucherCode, // 쿠폰번호
        Reason,
        /* ===== VoucherDefinition ===== */
        VoucherDefinition.Type, // 쿠폰 타입
        VoucherDefinition.ExpirationPeriodUnit, // 기간 단위
        VoucherDefinition.ExpirationPeriod, // 기간 값
        VoucherDefinition.CouponManNo__c, // 쿠폰 관리 번호
        VoucherDefinition.CouponTypeCode__c, //쿠폰 구분 코드
        VoucherDefinition.InsertId__c, //등록자
        VoucherDefinition.Name, //쿠폰 이름
        VoucherDefinition.brand__c, //브랜드
        VoucherDefinition.ResponsibleDepartment__c, //담당부서
        VoucherDefinition.ExpirationType
      FROM Voucher
      WHERE LoyaltyProgramMemberId = :lpm.Id
      ORDER BY CreatedDate DESC
    ];

    // List<Map<String, Object>> couponList = new List<Map<String, Object>>();
    List<VoucherResDTO> voucherResDtoList = new List<VoucherResDTO>();

    for (Voucher v : vouchers) {
      // Map<String, Object> coupon = new Map<String, Object>();

      // // 기본 정보
      // coupon.put('Id', v.Id);
      // coupon.put('CouponName', v.VoucherDefinition.Name);
      // coupon.put('Status', v.Status);

      // // 날짜 정보
      // coupon.put('StartDate', v.EffectiveDate);
      // coupon.put('UseDate', v.UseDate);
      // coupon.put('EndDate', v.ExpirationDate);
      // coupon.put('IssuedDate', v.CreatedDate);

      // // 금액 / 할인
      // coupon.put('FaceValue', v.FaceValue);
      // coupon.put('DiscountPercent', v.DiscountPercent);

      // // 쿠폰 정보
      // coupon.put('VoucherCode', v.VoucherCode);
      // coupon.put('CouponType', v.VoucherDefinition.Type);
      // coupon.put('ExpirationPeriodUnit', v.VoucherDefinition.ExpirationPeriod);
      // coupon.put('ExpirationPeriod', v.VoucherDefinition.ExpirationPeriod);
      // coupon.put('CouponManNo', v.VoucherDefinition.CouponManNo__c);
      // coupon.put('Created By', v.VoucherDefinition.InsertId__c);
      // coupon.put('Brand', v.VoucherDefinition.brand__c);
      // coupon.put('ResponsibleDepartment', v.VoucherDefinition.ResponsibleDepartment__c);

      // String couponManNoCode = (v.VoucherDefinition != null) ? v.VoucherDefinition.CouponTypeCode__c : null;

      // coupon.put('CouponTypeCode', COUPON_MAN_NO_MAP.containsKey(couponManNoCode) ? COUPON_MAN_NO_MAP.get(couponManNoCode) : couponManNoCode);
      // // 등록자
      // coupon.put('CreatedBy', v.CreatedBy != null ? v.CreatedBy.Name : null);

      // couponList.add(coupon);
      voucherResDtoList.add(new VoucherResDTO(v));
    }

    data.put('CouponList', voucherResDtoList);

    // =======================================================
    // 포인트 이력 조회 (적립 / 사용 / 소멸)
    // =======================================================

    Id memberId = lpm.Id;

    // 결과 리스트
    // List<Map<String, Object>> accrualHistoryList = new List<Map<String, Object>>();
    List<PointResDto.CreditPointResponse> creditPointResponseList = new List<PointResDto.CreditPointResponse>();
    // List<Map<String, Object>> usageExpiryHistoryList = new List<Map<String, Object>>();
    List<PointResDto.DebitPointResponse> debitPointResponseList = new List<PointResDto.DebitPointResponse>();

    // -------------------------------------------------------
    // LoyaltyLedger 조회
    // -------------------------------------------------------
    List<LoyaltyLedger> ledgers = [
      SELECT
        ActivityDate, // 발생일자
        EventType, // Credit / Debit / Expiry
        Points, //포인트 수량
        ExpiryDate, //만료일
        EscrowPointsCreditDate, //에스크로 지급일자
        LoyaltyProgramCurrency.Name, //포인트 이름
        TransactionJournal.OrderId__c, //판매번호
        TransactionJournal.TransactionAmount, //판매금액
        TransactionJournalId,
        TransactionJournal.JournalSubTypeId,
        TransactionJournal.JournalSubType.Name,
        LoyaltyPgmCrcySubtypeId,
        LoyaltyPgmCrcySubtype.Name,
        TransactionJournal.OrderId,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.Order.ActualPaymentAmount__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
      ORDER BY ActivityDate DESC
    ];

    // -------------------------------------------------------
    // Ledger → 적립 / 사용·소멸 분리
    // -------------------------------------------------------
    for (LoyaltyLedger ll : ledgers) {
      Map<String, Object> row = new Map<String, Object>();

      /* ================= 공통 ================= */
      row.put('Month', ll.ActivityDate != null ? ll.ActivityDate.format('yyyy/MM') : null);

      row.put('PointType', ll.LoyaltyProgramCurrency != null ? ll.LoyaltyProgramCurrency.Name : null);

      row.put('EventDate', ll.ActivityDate);
      row.put('ExpiryDate', ll.ExpiryDate);

      if (ll.TransactionJournal != null) {
        row.put('OrderId', ll.TransactionJournal.OrderId__c);
        row.put('TransactionAmount', ll.TransactionJournal.TransactionAmount);
      }

      /* ===================================================
            1️⃣ 적립 내역 (Credit)
                =================================================== */
      if (ll.EventType == 'Credit') {
        row.put('AccrualType', '적립');
        row.put('AccrualDate', ll.ActivityDate);
        row.put('AccruedPoints', ll.Points);

        row.put('ScheduledDate', ll.EscrowPointsCreditDate);
        row.put('ScheduledPoints', ll.EscrowPointsCreditDate != null ? ll.Points : null);

        row.put('ValidFrom', ll.ActivityDate);
        row.put('ValidTo', ll.ExpiryDate);

        row.put('TargetAccrualPoints', ll.Points);
        row.put('DepositedPoints', ll.Points);

        // accrualHistoryList.add(row);
        creditPointResponseList.add(new PointResDto.CreditPointResponse(ll));
      }
      /* ===================================================
            2️⃣ 사용 / 소멸 내역 (Debit / Expiry)
                =================================================== */
      else if (ll.EventType == 'Debit' || ll.EventType == 'Expiry') {
        row.put('UsageExpiryType', ll.EventType == 'Debit' ? '사용' : '소멸');

        row.put('UsageExpiryDate', ll.ActivityDate);
        row.put('Points', Math.abs(ll.Points));

        // usageExpiryHistoryList.add(row);
      }
    }

    // =======================================================
    // 소멸 예정 / 잔여 포인트 요약 (집계)
    // =======================================================
    // List<LoyaltyAggrSubPointExprLedger__c> expirySummary = [
    //   SELECT CurrencySubTypeName__c, AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c, ExpiryDate__c
    //   FROM LoyaltyAggrSubPointExprLedger__c
    //   WHERE LoyaltyProgramMemberId__c = :memberId
    // ];

    List<LoyaltyLedgerTraceability> lltList = [
      SELECT
        Id,
        OwnerId,
        IsDeleted,
        Name,
        CreatedDate,
        CreatedById,
        LastModifiedDate,
        LastModifiedById,
        SystemModstamp,
        LastViewedDate,
        LastReferencedDate,
        CreditLoyaltyLedgerId,
        DebitLoyaltyLedgerId,
        ActionType,
        Points,
        LoyaltyProgramCurrencyId,
        LoyaltyPgmCurrencySubtypeId,
        LoyaltyProgramMemberId,
        LoyaltyPgmCurrencySubtype.Name,
        DebitLoyaltyLedger.ActivityDate,
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.EventType,
        CreditLoyaltyLedger.Points,
        CreditLoyaltyLedger.ActivityDate,
        CreditLoyaltyLedger.TransactionJournal.Order.IsReductionOrder,
        CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c,
        DebitLoyaltyLedger.Points
      FROM LoyaltyLedgerTraceability
      WHERE DebitLoyaltyLedger.EventType = 'Debit' AND LoyaltyProgramMemberId = :memberId
      LIMIT 2000
    ];
    if (!lltList.isEmpty()) {
      for (LoyaltyLedgerTraceability llt : lltList) {
        debitPointResponseList.add(new PointResDto.DebitPointResponse(llt));
      }
    }
    data.put('UserDestoryHistoryList', debitPointResponseList);

    // =======================================================
    // 응답 데이터 세팅
    // =======================================================
    data.put('AccrualHistoryList', creditPointResponseList);
    // data.put('AccrualHistoryList', accrualHistoryList);
    // data.put('UsageExpiryHistoryList', usageExpiryHistoryList);
    // data.put('ExpirySummary', expirySummary);

    // -------------------------------------------------------
    // CS내역 조회 (TransactionJournal)
    // -------------------------------------------------------
    List<TransactionJournal> cslist = [
      SELECT id
      // , CS_CHANNEL1__c, CS_CHANNEL2__c, CS_CHANNEL1_F_CODE__c, CS_CHANNEL2_F_CODE__c, CS_Sentdate__c, CS_CAMP_NAME__c
      FROM TransactionJournal
      WHERE MemberId = :lpm.id AND UsageType__c = 'Campaign'
    ];

    List<CsResDto> csResDtoList = new List<CsResDto>();
    // if (!cslist.isEmpty()) {
    //   for (TransactionJournal tj : cslist) {
    //     CsResDto csResDto = new CsResDto();
    //     csResDto.sentDate = String.valueOf(tj.CS_Sentdate__c).replaceAll('-', '');
    //     csResDto.detailContent = tj.CS_CAMP_NAME__c;

    //     String c1 = String.valueOf(tj.CS_CHANNEL1_F_CODE__c);
    //     String c2 = String.valueOf(tj.CS_CHANNEL2_F_CODE__c);

    //     // 1순위 발송 채널 성공
    //     if (c1 == '0' || c1 == '00') {
    //       //   csResDto.type = tj.CS_CHANNEL1__c;
    //     }
    //     // 2순위 발송 채널 성공
    //     else if (c2 == '0' || c2 == '00') {
    //       //   csResDto.type = tj.CS_CHANNEL2__c;
    //     }
    //     // 모두 실패
    //     else {
    //       //   // csResDto.type = '';
    //       // csResDto.type = tj.CS_CHANNEL1__c;
    //     }

    //     csResDto.type = ''; // CS 구분
    //     csResDto.content = ''; // CS 내역

    //     csResDtoList.add(csResDto);
    //   }
    // }

    data.put('CsList', csResDtoList);

    return ApiResult.ok(200, '회원도움정보 조회 성공', data);
  }
}