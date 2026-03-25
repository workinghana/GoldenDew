public with sharing class GdPointServiceImpl implements GdPointService {
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual'; // 포인트/쿠폰 지급
  private static final String JOURNAL_TYPE_NAME_REDEMPTION = 'Redemption'; // 포인트/쿠폰 사용
  private static final String JOURNAL_TYPE_NAME_POINTS_EXPIRATION = 'Points Expiration'; // 포인트 만료
  private static final String JOURNAL_TYPE_NAME_DEPOSIT = 'Deposit'; // 입금/결제
  private static final String JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL = 'Accrual Reversal'; // 포인트/쿠폰 지급 취소
  private static final String JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL = 'Redemption Reversal'; // 포인트/쿠폰 사용 취소
  private static final String JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL = 'Deposit Reversal'; // 입금/결제 취소

  private static final String JOURNAL_SUB_TYPE_NAME_POINT_DEBIT = 'Point Debit'; // 포인트 사용
  private static final String JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL = 'Purchase Accrual'; // 구매 시 포인트 적립
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT = 'Order Deposit'; // 주문 입금
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL = 'Order Deposit Reversal'; // 주문 입금 취소
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT = 'Sale Deposit'; // 판매 입금
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL = 'Sale Deposit Reversal'; // 판매 입금 취소
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel'; // 포인트 사용 취소
  private static final String JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual'; // 구매 시 포인트 적립 취소
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem'; // 쿠폰 사용
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel'; // 쿠폰 사용 취소
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_EXPIRE = 'Api Forced Expire'; // API 요청에 의한 포인트 강제 소멸 처리
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT = 'Api Forced Debit'; // API 요청에 의한 포인트 강제 차감 처리
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT = 'Api Forced Credit'; // API 요청에 의한 포인트 강제 지급(적립) 처리

  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';

  private static final String POINT_SUB_TYPE_NAME = '에코포인트';

  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT = 'Debit'; // 포인트 사용
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation'; // 포인트 사용 취소
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION = 'CreditCancellation'; // 포인트 적립 취소

  /**
   * 포인트 지급
   */
  public ApiResult creditPoint(Map<String, Object> reqData) {
    Map<String, Object> result = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, '요청 body가 비었습니다.');
    }

    try {
      List<Object> pointsList = ValidationUtil.listObjValidation(reqData.get('PointsList'), 'PointsList', true); // 포인트 목록
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false); // 판매 번호
      Date endDate = ValidationUtil.dateValidation(reqData.get('EndDate'), 'EndDate', false); // 판매 일자

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo AND MemberStatus != 'Inactive'
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      Id saleId = null;
      if (String.isNotBlank(saleNo)) {
        List<Order> saleList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
        if (saleList.isEmpty()) {
          throw new CustomException(400, '해당 판매 건을 찾을 수 없습니다. ' + saleNo);
        }
        saleId = saleList[0].Id;
      }

      Map<String, Decimal> pointByTypeMap = new Map<String, Decimal>();
      Decimal totalPoints = 0;
      for (Object v : pointsList) {
        Map<String, Object> vMap = ValidationUtil.mapStrObjValidation(v, 'PointsList', true);
        Decimal point = ValidationUtil.decimalValidation(vMap.get('point'), 'point', true); // 포인트 금액
        String cd_type_point = ValidationUtil.stringValidationEx(vMap.get('cd_type_point'), 'cd_type_point', true, false); // 포인트 구분

        totalPoints += point;

        if (pointByTypeMap.containsKey(cd_type_point)) {
          pointByTypeMap.put(cd_type_point, pointByTypeMap.get(cd_type_point) + point);
        } else {
          pointByTypeMap.put(cd_type_point, point);
        }
      }

      if (totalPoints <= 0) {
        throw new CustomException(400, '지급할 포인트가 0 이하입니다.');
      }

      Date expirationDate = null;

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      tj.MemberId = lpmList[0].Id; // 적립 대상 멤버 Id
      if (endDate != null) {
        tj.JournalDate = TimeUtil.dateToUtcStartOfDay(endDate); // 거래 일자
        tj.ActivityDate = TimeUtil.dateToUtcStartOfDay(endDate); // 활동 일자

        expirationDate = endDate.addYears(2);
      } else {
        tj.JournalDate = Datetime.now(); // 거래 일자
        tj.ActivityDate = Datetime.now(); // 활동 일자
      }
      tj.TransactionAmount = totalPoints; // 지급 포인트
      tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true);
      if (saleId != null) {
        tj.OrderId = saleId;
        tj.SaleId__c = saleId;
      }

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (String cdTypePoint : pointByTypeMap.keySet()) {
        List<LoyaltyPgmCurrencySubtype> lpcsList = [
          SELECT Id, Name
          FROM LoyaltyPgmCurrencySubtype
          WHERE PointTypeCode__c = :cdTypePoint
          LIMIT 1
        ];
        if (lpcsList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 포인트 구분 값 입니다. ' + cdTypePoint);
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', lpmList[0].Id);
        req.put('journalId', tj.Id);
        if ('05'.equals(cdTypePoint)) {
          req.put('loyaltyProgramCurrencySubtypeName', '에코포인트');
          req.put('additionalNotes', '이벤트포인트');
        } else {
          req.put('loyaltyProgramCurrencySubtypeName', lpcsList[0].Name);
        }
        req.put('points', pointByTypeMap.get(cdTypePoint));
        if (expirationDate != null) {
          req.put('pointsExpirationDate', String.valueOf(expirationDate));
        }

        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();

      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1)); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        pcDtoList.add(pcDto);
      }

      result.put('PointCreditList', pcDtoList);

      return ApiResult.ok(200, '포인트 지급 성공', result);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 에코 포인트 지급
   */
  public ApiResult creditEcopoint(Map<String, Object> reqData) {
    Map<String, Object> result = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, '요청 body가 비었습니다.');
    }

    try {
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      Decimal point = ValidationUtil.decimalValidation(reqData.get('point'), 'point', true); // 포인트 금액

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo AND MemberStatus != 'Inactive'
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      if (point <= 0) {
        throw new CustomException(400, '지급할 포인트가 0 이하입니다.');
      }

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      tj.MemberId = lpmList[0].Id; // 적립 대상 멤버 Id
      tj.JournalDate = Datetime.now(); // 거래 일자
      tj.ActivityDate = Datetime.now(); // 활동 일자
      tj.TransactionAmount = point; // 지급 포인트
      tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true);

      insert tj;

      List<LoyaltyPgmCurrencySubtype> lpcsList = [
        SELECT Id, Name
        FROM LoyaltyPgmCurrencySubtype
        WHERE Name = :POINT_SUB_TYPE_NAME
        LIMIT 1
      ];
      if (lpcsList.isEmpty()) {
        throw new CustomException(400, POINT_SUB_TYPE_NAME + '가 존재하지 않습니다.');
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', lpmList[0].Id);
      req.put('journalId', tj.Id);
      req.put('loyaltyProgramCurrencySubtypeName', '에코포인트');
      req.put('additionalNotes', '이벤트포인트');
      req.put('points', point);

      reqList.add(req);

      LoyaltyPointService.creditPoints(reqList);

      return ApiResult.ok(200, '에코포인트 지급 성공', result);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 수정
   */
  public ApiResult updatePoint(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, '요청 body가 비었습니다.');
    }

    try {
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      String type = ValidationUtil.stringValidationEx(reqData.get('type'), 'type', true, false); // 타입 (01:지급 | 02:차감)
      Decimal point = ValidationUtil.decimalValidation(reqData.get('point'), 'point', true); // 포인트 금액
      String cd_type_point = ValidationUtil.stringValidationEx(reqData.get('cd_type_point'), 'cd_type_point', true, false); // 포인트 구분 (01:구매포인트 | 02:기념일포인트 | 03:승급포인트 | 04:기타포인트 | 05:에코포인트 = 이벤트포인트)
      Date expiryDate = ValidationUtil.dateValidation(reqData.get('ExpiryDate__c'), 'ExpiryDate__c', true); // 소멸예정일

      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      if (point <= 0) {
        throw new CustomException(400, '지급할 포인트가 0 이하입니다.');
      }

      if ('01'.equals(type)) {
        // 포인트 지급 로직
        Map<String, Object> creditReqMap = new Map<String, Object>();
        List<Map<String, Object>> pointsList = new List<Map<String, Object>>();
        Map<String, Object> pointMap = new Map<String, Object>();
        creditReqMap.put('MemberNo__c', memberNo);
        pointMap.put('point', point);
        pointMap.put('cd_type_point', cd_type_point);
        pointsList.add(pointMap);
        pointMap.put('PointsList', pointsList);

        return creditPoint(creditReqMap);
      } else if ('02'.equals(type)) {
        // 포인트 차감 로직
        List<LoyaltyAggrSubPointExprLedger__c> laspelList = [
          SELECT Id, AvailablePoints__c, CurrencySubTypeId__r.Name, ExpiryDate__c, CurrencySubTypeId__r.PointTypeCode__c
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE LoyaltyProgramMemberId__c = :lpmList[0].Id AND ExpiryDate__c = :expiryDate AND CurrencySubTypeId__r.PointTypeCode__c = :cd_type_point
          LIMIT 1
        ];
        if (!laspelList.isEmpty()) {
          if (laspelList[0].AvailablePoints__c < point) {
            throw new CustomException(
              400,
              '차감 가능한 포인트가 부족합니다. (종류:' +
                laspelList[0].CurrencySubTypeId__r.Name +
                ' | 만료일자:' +
                laspelList[0].ExpiryDate__c +
                ' | 잔액:' +
                laspelList[0].AvailablePoints__c +
                ')'
            );
          } else {
            // 포인트 차감 로직
            TransactionJournal tj = new TransactionJournal();

            tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
            tj.MemberId = lpmList[0].Id; // 대상 멤버 Id
            tj.JournalDate = Datetime.now(); // 거래 일자
            tj.ActivityDate = Datetime.now(); // 활동 일자
            tj.TransactionAmount = point; // 삭제(소멸) 포인트
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT, true);
            tj.JournalReason__c = '2';

            insert tj;

            List<Map<String, Object>> pointDeleteReqList = new List<Map<String, Object>>();

            // 포인트 차감을 위한 값 설정
            Map<String, Object> pointDeleteReq = new Map<String, Object>();
            pointDeleteReq.put('loyaltyProgramMemberId', lpmList[0].Id);
            pointDeleteReq.put('journalId', tj.Id);
            pointDeleteReq.put('loyaltyProgramCurrencySubtypeName', laspelList[0].CurrencySubTypeId__r.Name);
            pointDeleteReq.put('additionalNotes', '포인트 개별 수정 API를 통한 포인트 차감 처리');
            pointDeleteReq.put('points', point);

            pointDeleteReqList.add(pointDeleteReq);

            // 포인트 사용 처리
            LoyaltyPointService.debitPoints(pointDeleteReqList);

            // 포인트 사용 추적 조회
            List<LoyaltyLedgerTraceability> lltList = [
              SELECT
                LoyaltyPgmCurrencySubtype.Name,
                Points,
                CreditLoyaltyLedger.ExpiryDate,
                LoyaltyProgramMember.Contact.MemberNo__c,
                LastModifiedDate,
                DebitLoyaltyLedgerId,
                LoyaltyPgmCurrencySubtype.PointTypeCode__c
              FROM LoyaltyLedgerTraceability
              WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
              LIMIT 100
            ];
            if (lltList.isEmpty()) {
              throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
            }

            List<PointDebitDTO> pcDtoList = new List<PointDebitDTO>();
            for (LoyaltyLedgerTraceability llt : lltList) {
              PointDebitDTO pcDto = new PointDebitDTO();
              pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId; // 로열티 소멸 키값
              pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c; // 포인트 구분
              pcDto.CD_RESON = tj.JournalReason__c; // 회원 포인트 소진 구분
              pcDto.NO_MBR = memberNo; // 회원 번호
              pcDto.PT_USE = llt.Points; // 소멸된 금액
              pcDto.DTS_INSERT = String.valueOf(tj.CreatedDate); // 등록 일자

              pcDtoList.add(pcDto);
            }
            data.put('PointDeleteList', pcDtoList);
          }
        } else {
          throw new CustomException(400, '차감 가능한 포인트 잔액 정보가 없습니다.');
        }
      } else {
        throw new CustomException(400, 'type 값이 올바르지 않습니다. (01:지급 | 02:차감)');
      }

      return ApiResult.ok(200, '포인트 수정 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 보류
   * 포인트 조회
   */
  public Double getPointList(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);

      return results[0].getPoints();
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * [주문,판매] 포인트 적용 도움창 조회
   * @version V1
   */
  public ApiResult getPointApplyHelp(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false); // 매장 코드
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', false); // 주문 구분 코드
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false); // 프로모션 번호

      if (String.isNotBlank(promotionNo)) {
        List<Promotion> pList = [SELECT Id, IsPointUsageAllowed__c FROM Promotion WHERE PromotionNo__c = :promotionNo LIMIT 1];
        if (pList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 프로모션입니다. ' + promotionNo);
        } else {
          if (!pList[0].IsPointUsageAllowed__c) {
            throw new CustomException(400, '해당 프로모션은 포인트 사용 불가합니다. ' + promotionNo);
          }
        }
      }

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      if (storeCode != null) {
        List<Account> aList = [SELECT Id, StoreTypeFour__c FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
        if (aList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장입니다. ' + storeCode);
        }

        // '01' => 백화점 | '05' => 아울렛 | '20' => 예술의전당
        if ('01'.equals(aList[0].StoreTypeFour__c) || '05'.equals(aList[0].StoreTypeFour__c) || '20'.equals(aList[0].StoreTypeFour__c)) {
          // '05' => 아울렛
          if ('05'.equals(aList[0].StoreTypeFour__c)) {
            if (String.isNotBlank(type)) {
              // '03' => 수선 : 아울렛에서 수선 건에 한해 포인트 사용 가능
              if ('03'.equals(type)) {
                // List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);
                // return results[0].getPoints();
                return getPointApplyHelpV2(reqData);
              }
            }
          } else {
            // List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);
            // return results[0].getPoints();
            return getPointApplyHelpV2(reqData);
          }
        }
      }
      // else {
      // List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);
      // return results[0].getPoints();
      return getPointApplyHelpV2(reqData);
      // }

      // return 0;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * [주문,판매] 포인트 적용 도움창 조회
   * @version V2
   */
  public ApiResult getPointApplyHelpV2(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      List<AggregateResult> arList = [
        SELECT sum(AvailablePoints__c) totalPoints, CurrencySubTypeId__r.PointTypeCode__c pointTypeCode
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE
          AvailablePoints__c > 0
          AND ExpiryDate__c > :Date.today()
          AND LoyaltyProgramMemberId__c = :lpmList[0].Id
          AND CurrencySubTypeId__r.PointTypeCode__c != NULL
        GROUP BY CurrencySubTypeId__r.PointTypeCode__c
      ];

      List<PointResDto.AvailablePointResponse> pointList = new List<PointResDto.AvailablePointResponse>();
      for (AggregateResult ar : arList) {
        PointResDto.AvailablePointResponse item = new PointResDto.AvailablePointResponse(ar);
        pointList.add(item);
      }

      data.put('pointList', pointList);
      return ApiResult.ok(200, '포인트 적용 도움창 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 사용한 포인트 조회
   */
  public ApiResult getDebitPointList(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false); // 판매 번호
      String orderNo = ValidationUtil.stringValidation(reqData.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호

      // 판매번호 있으면 SaleNo__c, 없으면 OrderNo__c 로 조회
      String fieldPath;
      String keyValue;

      if (!String.isBlank(saleNo)) {
        fieldPath = 'SaleNo__c';
        keyValue = saleNo;
      } else if (!String.isBlank(orderNo)) {
        fieldPath = 'OrderNo__c';
        keyValue = orderNo;
      } else {
        throw new CustomException(400, 'SaleNo__c 또는 OrderNo__c 값이 필요합니다.');
      }

      if (!([SELECT COUNT() FROM Order WHERE OrderNo__c = :keyValue OR SaleNo__c = :keyValue LIMIT 1] > 0)) {
        throw new CustomException(400, '존재하지 않는 주문/판매 번호 입니다. ' + keyValue);
      }

      String soql =
        'SELECT ' +
        'CreditLoyaltyLedgerId, DebitLoyaltyLedgerId, LoyaltyPgmCurrencySubtypeId, ActionType, Points, CreatedDate, ' +
        'DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c, DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.Order.IsReductionOrder, LoyaltyProgramMember.Contact.MemberNo__c,' +
        'CreditLoyaltyLedger.ExpiryDate, LoyaltyPgmCurrencySubtype.Name, DebitLoyaltyLedger.TransactionJournal.InsertId__c, DebitLoyaltyLedger.TransactionJournal.DepositNo__c ' +
        'FROM LoyaltyLedgerTraceability ' +
        'WHERE ' +
        'CreditLoyaltyLedger.TransactionJournal.Order.' +
        fieldPath +
        ' = :keyValue ' +
        'OR DebitLoyaltyLedger.TransactionJournal.Order.' +
        fieldPath +
        ' = :keyValue ' +
        'LIMIT 200';

      List<LoyaltyLedgerTraceability> lltList = (List<LoyaltyLedgerTraceability>) Database.query(soql);

      Map<LedgerAggKey, Decimal> usedPointMap = new Map<LedgerAggKey, Decimal>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        // Credit 기준 만료일
        Date expiryDate = llt.CreditLoyaltyLedger.ExpiryDate;

        LedgerAggKey key = new LedgerAggKey(llt);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(key, 0);
        }

        Decimal current = usedPointMap.get(key);

        if (llt.ActionType == 'Debit') {
          // 사용 => +
          current += llt.Points;
        } else if (llt.ActionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
          // 사용 취소 => -
          current -= llt.Points;
        }

        usedPointMap.put(key, current);
      }

      // List<Map<String, Object>> l1 = new List<Map<String, Object>>();
      List<PointDebitDTO> pointDebitList = new List<PointDebitDTO>();
      for (LedgerAggKey key : usedPointMap.keySet()) {
        Decimal used = usedPointMap.get(key);

        // 실제 사용된 포인트만 포함
        if (used > 0) {
          PointDebitDTO pointDebitDto = new PointDebitDTO();

          if (!String.isBlank(key.depositNo)) {
            pointDebitDto.NO_DEPOSIT = key.depositNo.replaceAll('-\\d+$', ''); // 입금 번호
          }
          pointDebitDto.CD_LEDGER = key.debitLoyaltyLedgerId; // 로열티 소멸 키값
          pointDebitDto.CD_JOURNAL = key.creditLoyaltyLedgerId; // key.debitLoyaltyLedgerId; -> key.creditLoyaltyLedgerId; (26.02.03)
          pointDebitDto.CD_TYPE_POINT = key.currencySubtypeId; // 포인트 구분
          pointDebitDto.CD_RESON = '1'; // 회원포인트소진구분
          pointDebitDto.NO_MBR = key.memberNo; // 회원번호
          pointDebitDto.NO_SAL = key.saleNo; // 판매처리된 번호
          pointDebitDto.AM_SAL = key.actualPaymentAmount; // 판매처리된 판매의 금액
          pointDebitDto.PT_USE = used; // 사용처리된 금액
          pointDebitDto.DTS_INSERT = key.createdDate; // 등록일자
          pointDebitDto.ID_INSERT = key.insertId; // 등록자
          if (key.isReductionOrder) {
            pointDebitDto.NO_SAL_RTN = key.saleNo; // 판매 반품 번호
          }

          pointDebitList.add(pointDebitDto);
        }
      }
      data.put('DebitPointList', pointDebitList);

      return ApiResult.ok(200, '사용한 포인트 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 사용
   */
  public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);

      // 저날 하위 유형 체크
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      tj.JournalReason__c = '1'; // 1 : 사용
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      System.debug('lmcList[0].PointsBalance : ' + lmcList[0].PointsBalance);
      System.debug('tj.transactionAmount : ' + tj.transactionAmount);
      tj.PostPointBalance__c = lmcList[0].PointsBalance - tj.transactionAmount;
      System.debug('tj.PostPointBalance__c : ' + tj.PostPointBalance__c);

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      Map<String, Object> req = new Map<String, Object>();

      req.put('loyaltyProgramMemberId', tj.MemberId);
      req.put('points', tj.transactionAmount);
      req.put('journalId', tj.Id);
      reqList.add(req);
      List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      }

      List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // tj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
        if (String.isNotBlank(tj.Order.OrderNo__c)) {
          pcDto.NO_SAL = tj.Order.OrderNo__c; // 주문 번호
        } else if (String.isNotBlank(tj.Order.SaleNo__c)) {
          pcDto.NO_SAL = tj.Order.SaleNo__c; // 판매 번호
        }
        pcDto.PT_USE = llt.Points; // 사용처리된 금액
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 사용처리된 금액

        pdDtoList.add(pcDto);
      }
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 특정 포인트 포인트 차감
   */
  public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);

      // 저날 하위 유형 체크
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      tj.JournalReason__c = '1'; // 1 : 사용
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      Map<String, Object> req = new Map<String, Object>();

      for (LoyaltyLedger ll : llList) {
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('points', ll.Points);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ll.LoyaltyPgmCrcySubtype.Name);
        reqList.add(req);
      }

      List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      }

      List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // tj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
        if (String.isNotBlank(tj.Order.OrderNo__c)) {
          pcDto.NO_SAL = tj.Order.OrderNo__c; // 주문 번호
        } else if (String.isNotBlank(tj.Order.SaleNo__c)) {
          pcDto.NO_SAL = tj.Order.SaleNo__c; // 판매 번호
        }
        pcDto.PT_USE = llt.Points; // 사용처리된 금액
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 사용처리된 금액

        pdDtoList.add(pcDto);
      }
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 구매 시 포인트 지급
   */
  public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
    try {
      if (data.isEmpty()) {
        return null;
      }

      // 저널 유형 체크
      List<JournalType> jtListByCreditPoint = [SELECT Id FROM journalType WHERE Name = :JOURNAL_TYPE_NAME_ACCRUAL LIMIT 1];
      if (jtListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 타입(포인트 지급)이 없습니다. ' + JOURNAL_TYPE_NAME_ACCRUAL);
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstListByCreditPoint = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL AND JournalTypeId = :jtListByCreditPoint[0].Id
        LIMIT 1
      ];
      if (jstListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 하위 타입(포인트 지급)이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
      }

      // 계층 보상 가져오기
      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + data[0].MemberId);
      }

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = Datetime.now();
      tj.JournalDate = Datetime.now();
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = data[0].OrderId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtListByCreditPoint[0].Id;
      tj.JournalSubTypeId = jstListByCreditPoint[0].Id;

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Decimal totalAmount = 0;
      for (TransactionJournal v : data) {
        if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
          continue;
        }
        if (v.TransactionAmount == null || v.TransactionAmount == 0) {
          continue;
        }

        totalAmount += v.TransactionAmount;
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (totalAmount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // 생성(지급)된 레저 ID 전달
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1)); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }
      tj.TransactionAmount = totalPoints;
      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 구매 시 포인트 지급 V2
   */
  public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
    try {
      Savepoint sp1 = Database.setSavepoint();

      if (data.isEmpty()) {
        return null;
      }

      // 저널 유형 체크
      List<JournalType> jtListByCreditPoint = [SELECT Id FROM journalType WHERE Name = :JOURNAL_TYPE_NAME_ACCRUAL LIMIT 1];
      if (jtListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 타입(포인트 지급)이 없습니다. ' + JOURNAL_TYPE_NAME_ACCRUAL);
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstListByCreditPoint = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL AND JournalTypeId = :jtListByCreditPoint[0].Id
        LIMIT 1
      ];
      if (jstListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 하위 타입(포인트 지급)이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
      }

      // 계층 보상 가져오기
      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + data[0].MemberId);
      }

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = Datetime.now();
      tj.JournalDate = Datetime.now();
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = data[0].OrderId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtListByCreditPoint[0].Id;
      tj.JournalSubTypeId = jstListByCreditPoint[0].Id;

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Decimal totalAmount = 0;
      for (TransactionJournal v : data) {
        if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
          continue;
        }
        if (v.TransactionAmount == null || v.TransactionAmount == 0) {
          continue;
        }

        totalAmount += v.TransactionAmount;
      }

      System.debug('totalAmount : ' + totalAmount);
      System.debug('excludeAmount : ' + excludeAmount);
      totalAmount -= excludeAmount;
      if (totalAmount <= 0) {
        Database.rollback(sp1);
        return null;
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (totalAmount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // 생성(지급)된 레저 ID 전달
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1)); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }

      tj.TransactionAmount = totalPoints;
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      tj.PostPointBalance__c = lmcList[0].PointsBalance;

      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * (특정 등급의 비율에 따른) 구매 시 포인트 지급
   */
  public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
    List<PointCreditDTO> result = new List<PointCreditDTO>();
    try {
      String grade = ValidationUtil.stringValidationEx(reqData.get('Grade__c'), 'Grade__c', true, false);
      TransactionJournal tj = (TransactionJournal) ValidationUtil.sObjectValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String additionalNotes = ValidationUtil.stringValidation(reqData.get('AdditionalNotes__c'), 'AdditionalNotes__c', true);
      Decimal adjustAmount = ValidationUtil.decimalValidation(reqData.get('adjustAmount'), 'adjustAmount', false); // 포인트 강제 조정 금액

      // Contact의 Grade__c 필드 PickList 값 Label 조회
      Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

      String labelName;
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.getValue() == grade) {
          labelName = entry.getLabel();
          break;
        }
      }

      // 등급 조회
      List<LoyaltyTier> ltList = [SELECT Id FROM LoyaltyTier WHERE Name = :labelName LIMIT 1];
      if (ltList.isEmpty()) {
        throw new CustomException(400, '해당 등급이 존재하지 않습니다. ' + labelName);
      }

      // 계층 보상 조회
      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c, LoyaltyTierId
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId = :ltList[0].Id
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + tj.MemberId);
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
        return result;
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
        return result;
      }

      TransactionJournal newTj = new TransactionJournal();
      newTj.ActivityDate = Datetime.now();
      newTj.JournalDate = Datetime.now();
      newTj.LoyaltyProgramId = tj.LoyaltyProgramId;
      newTj.RelatedJournalId = tj.Id;
      newTj.MemberId = tj.MemberId;
      newTj.OrderId = tj.OrderId;
      if (String.isNotBlank(tj.SaleId__c)) {
        newTj.SaleId__c = tj.SaleId__c;
      } else if (String.isNotBlank(tj.OrderId__c)) {
        newTj.OrderId__c = tj.OrderId__c;
      }
      newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true);
      newTj.AdditionalNotes__c = additionalNotes;

      insert newTj;

      Decimal amount = (adjustAmount != null) ? adjustAmount : tj.TransactionAmount;
      if (amount <= 0) {
        throw new CustomException(400, '포인트 지급 할 금액이 없습니다. ' + amount);
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', newTj.MemberId);
        req.put('journalId', newTj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (amount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :newTj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1)); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        result.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }
      newTj.TransactionAmount = totalPoints;
      update newTj;

      return result;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * (특정 등급의 비율에 따른) 구매 시 포인트 지급 취소
   */
  public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
    List<PointDebitDTO> result = new List<PointDebitDTO>();
    try {
      String grade = ValidationUtil.stringValidationEx(reqData.get('Grade__c'), 'Grade__c', true, false);
      TransactionJournal tj = (TransactionJournal) ValidationUtil.sObjectValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String additionalNotes = ValidationUtil.stringValidation(reqData.get('AdditionalNotes__c'), 'AdditionalNotes__c', true);
      Decimal adjustAmount = ValidationUtil.decimalValidation(reqData.get('adjustAmount'), 'adjustAmount', false); // 포인트 강제 조정 금액

      // Contact의 Grade__c 필드 PickList 값 Label 조회
      Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

      String labelName;
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.getValue() == grade) {
          labelName = entry.getLabel();
          break;
        }
      }

      // 등급 조회
      List<LoyaltyTier> ltList = [SELECT Id FROM LoyaltyTier WHERE Name = :labelName LIMIT 1];
      if (ltList.isEmpty()) {
        throw new CustomException(400, '해당 등급이 존재하지 않습니다. ' + labelName);
      }

      // 계층 보상 조회
      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c, LoyaltyTierId
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId = :ltList[0].Id
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + tj.MemberId);
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      TransactionJournal newTj = new TransactionJournal();
      newTj.ActivityDate = Datetime.now();
      newTj.JournalDate = Datetime.now();
      newTj.LoyaltyProgramId = tj.LoyaltyProgramId;
      newTj.RelatedJournalId = tj.Id;
      newTj.MemberId = tj.MemberId;
      newTj.OrderId = tj.OrderId;
      if (String.isNotBlank(tj.SaleId__c)) {
        newTj.SaleId__c = tj.SaleId__c;
      } else if (String.isNotBlank(tj.OrderId__c)) {
        newTj.OrderId__c = tj.OrderId__c;
      }
      newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, true);
      newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true);
      newTj.AdditionalNotes__c = additionalNotes;

      insert newTj;

      Decimal amount = (adjustAmount != null) ? adjustAmount : tj.TransactionAmount;
      if (amount <= 0) {
        throw new CustomException(400, '포인트 지급 할 금액이 없습니다. ' + amount);
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', newTj.MemberId);
        req.put('journalId', newTj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (amount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :newTj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + newTj.Id);
      }
      List<LoyaltyLedgerTraceability> newLltList = new List<LoyaltyLedgerTraceability>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        LoyaltyLedgerTraceability newLlt = llt.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
        newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;

        newLltList.add(newLlt);
      }

      // llt.ActionType 필드가 update 불가하여, 새로운 LoyaltyLedgerTraceability insert 후 기존 LoyaltyLedgerTraceability는 삭제
      List<Database.SaveResult> insertResultList = Database.insert(newLltList);

      for (Database.SaveResult insertResult : insertResultList) {
        if (!insertResult.isSuccess()) {
          Database.Error err = insertResult.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      // 기존 LoyaltyLedgerTraceability 삭제
      List<Database.DeleteResult> deleteResultList = Database.delete(lltList);

      for (Database.DeleteResult deleteResult : deleteResultList) {
        if (!deleteResult.isSuccess()) {
          Database.Error err = deleteResult.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Decimal totalPoints = 0;
      for (LoyaltyLedgerTraceability llt : newLltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId; // 로열티 소멸 키값
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // newTj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c; // 포인트 구분
        pcDto.CD_RESON = newTj.JournalReason__c; // 회원 포인트 소진 구분
        pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
        if (String.isNotBlank(newTj.Order.OrderNo__c)) {
          pcDto.NO_SAL = newTj.Order.OrderNo__c; // 주문 번호
        } else if (String.isNotBlank(newTj.Order.SaleNo__c)) {
          pcDto.NO_SAL = newTj.Order.SaleNo__c; // 판매 번호
        }
        pcDto.PT_USE = llt.Points; // 적립 취소된 금액
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 적립 취소된 금액

        result.add(pcDto);

        if (llt.Points > 0) {
          totalPoints += llt.Points;
        }
      }

      newTj.TransactionAmount = totalPoints;
      update newTj;

      return result;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 특정 포인트 지급
   */
  public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
    try {
      Id creditPointJt = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true); // 포인트/쿠폰 지급
      Id purchaseAccrualJt = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true); // 구매 시 포인트 지급

      tj.JournalTypeId = creditPointJt;
      tj.JournalSubTypeId = purchaseAccrualJt;

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
        req.put('points', llt.Points);
        req.put('additionalNotes', llt.DebitLoyaltyLedger.AdditionalNotes);
        req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1)); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }
      tj.TransactionAmount = totalPoints;
      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 사용 취소
   */
  public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
    Map<String, Object> response = new Map<String, Object>();

    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);

      // 저날 하위 유형 체크
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      insert tj;

      // 포인트 마스터 Id
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      List<Order> oList = [SELECT Id FROM Order WHERE Id = :tj.OrderId LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, 'Order is null');
      }

      // 포인트 사용 상세 이력 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          Id,
          CreditLoyaltyLedgerId,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyPgmCurrencySubtype.Name,
          LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          ActionType,
          Points,
          LoyaltyPgmCurrencySubtypeId
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND (CreditLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId
          OR DebitLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId)
          AND ActionType = 'Debit'
          AND Points > 0
        LIMIT 100
      ];

      DebugUtil.pretty('lltList : ', lltList);

      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 내역이 존재하지 않습니다. ' + tj.OrderId);
      }

      // 포인트 사용 건 추출 = 사용('Debit')
      Map<String, UsageBucket> usedPointMap = new Map<String, UsageBucket>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        String creditLoyaltyLedgerId = ValidationUtil.stringValidation(llt.CreditLoyaltyLedgerId, 'CreditLoyaltyLedgerId', true); // 적립 원장 ID
        String debitLoyaltyLedgerId = ValidationUtil.stringValidation(llt.DebitLoyaltyLedgerId, 'DebitLoyaltyLedgerId', true); // 사용 원장 ID
        Date expiryDate = ValidationUtil.dateValidation(llt.CreditLoyaltyLedger.ExpiryDate, 'CreditLoyaltyLedger.ExpiryDate', true); // 적립 원장의 만료일
        String loyaltyPgmCurrencySubtypeName = ValidationUtil.stringValidation( // 포인트 하위 유형 이름
          llt.LoyaltyPgmCurrencySubtype.Name,
          'LoyaltyPgmCurrencySubtype.Name',
          true
        );
        Integer usagePriorityNumber = ValidationUtil.integerValidation( // 포인트 하위 유형 사용 우선 순위
          llt.LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          'LoyaltyPgmCurrencySubtype.UsagePriorityNumber',
          true
        );
        String actionType = ValidationUtil.stringValidation(llt.ActionType, 'ActionType', true); // 사용 유형
        Decimal points = ValidationUtil.decimalValidation(llt.Points, 'Points', true); // 포인트
        String loyaltyPgmCurrencySubtypeId = ValidationUtil.stringValidation(llt.LoyaltyPgmCurrencySubtypeId, 'LoyaltyPgmCurrencySubtypeId', true); // 포인트 하위 유형 ID

        String key = String.valueOf(expiryDate) + '|' + loyaltyPgmCurrencySubtypeName + '|' + String.valueOf(usagePriorityNumber);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(
            key,
            new UsageBucket(
              llt.Id,
              expiryDate,
              loyaltyPgmCurrencySubtypeName,
              usagePriorityNumber,
              loyaltyPgmCurrencySubtypeId,
              creditLoyaltyLedgerId,
              debitLoyaltyLedgerId
            )
          );
        }

        usedPointMap.get(key).usagePoints += points;
      }

      // Map -> List 변환
      List<UsageBucket> ubList = new List<UsageBucket>(usedPointMap.values());

      // 만료일 DESC, 우선순위 DESC 로 정렬
      ubList.sort(new UsageBucketCancelSorter());

      Decimal cancelAmount = tj.TransactionAmount; // 사용 취소 할 금액

      List<CancelPortion> expiredCancelList = new List<CancelPortion>(); // 만료 대상 리스트
      List<CancelPortion> unexpiredCancelList = new List<CancelPortion>(); // 만료 대상 아닌 리스트

      // 사용 취소 할 포인트 선정
      for (UsageBucket ub : ubList) {
        if (cancelAmount <= 0) {
          System.debug('cancelAmount(사용 취소 할 금액) : ' + cancelAmount);
          // cancelAmount : 사용 취소 할 금액
          break;
        }

        // 이 구간에서 취소 가능한 포인트 없음
        if (ub.usagePoints == null || ub.usagePoints <= 0) {
          System.debug('이 구간에서 취소 가능한 포인트 없음');
          continue;
        }

        // 포인트 사용 취소 가능한 최대 금액
        Decimal possible = ub.usagePoints;
        System.debug('possible(포인트 사용 취소 가능한 최대 금액) : ' + possible);

        // ub.usagePoints : 사용한 금액
        Decimal fromThis = (cancelAmount > possible) ? possible : cancelAmount;
        System.debug('fromThis ' + fromThis);
        // 사용 취소 할 금액이 사용한 금액보다 크다면, 사용한 금액으로 입력.
        // 사용 취소 할 금액이 적다면, 사용 취소 할 금액으로 입력.

        // 바로 위에서 사용 취소 할 금액이 0보다 적으면 다음 for문으로 넘어감.
        if (fromThis <= 0) {
          System.debug('사용 취소 할 금액이 0보다 적습니다. continue 실행');
          continue;
        }

        // 만료일자를 지났는지 확인
        System.debug('만료일자 지났는지 확인 ub.expiryDate : ' + ub.expiryDate);
        Boolean isExpired = (ub.expiryDate != null && ub.expiryDate <= Date.today()); // todo : 포인트 만료일자 확인 후 다시 설정 필요

        if (isExpired) {
          System.debug('만료일지가 지난 포인트입니다. fromThis : ' + fromThis);
          // 만료 될 포인트
          expiredCancelList.add(new CancelPortion(ub, fromThis));
        } else {
          System.debug('만료가 아닌 재지급 대상 포인트입니다. fromThis : ' + fromThis);
          // 만료가 아닌 재지급 될 포인트
          unexpiredCancelList.add(new CancelPortion(ub, fromThis));
        }

        // 사용 취소 할 금액만큼 빼준다.
        cancelAmount -= fromThis;
      }

      // ================================================================================================================================
      // 기존 Debit LLT 부분 제거 + 재생성 블록
      List<LoyaltyLedgerTraceability> deleteDebitList = new List<LoyaltyLedgerTraceability>();
      List<LoyaltyLedgerTraceability> insertRemainDebitList = new List<LoyaltyLedgerTraceability>();

      // 어떤 LLT가 얼마나 취소됐는지 집계
      Map<Id, Decimal> cancelSumByLLT = new Map<Id, Decimal>();

      // 만료 처리 할 포인트들을 cancelSumByLLT에 담아준다.
      if (!expiredCancelList.isEmpty()) {
        System.debug('expiredCancelList가 존재합니다.');
        for (CancelPortion cp : expiredCancelList) {
          cancelSumByLLT.put(
            cp.loyaltyLedgerTraceabilityId,
            (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
          );
        }
      }

      // 재지급 처리 할 포인트들을 cancelSumByLLT에 담아준다.
      if (!unexpiredCancelList.isEmpty()) {
        System.debug('unexpiredCancelList가 존재합니다.');
        for (CancelPortion cp : unexpiredCancelList) {
          cancelSumByLLT.put(
            cp.loyaltyLedgerTraceabilityId,
            (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
          );
        }
      }

      if (cancelSumByLLT.isEmpty()) {
        System.debug('취소 대상 금액이 존재하지 않습니다.');
        throw new CustomException(400, '취소 대상 금액이 존재하지 않습니다.');
      }

      //  원본 Debit LLT 다시 조회 (Id 기준으로만)
      List<LoyaltyLedgerTraceability> originalDebitList = [
        SELECT Id, Points, LoyaltyProgramMemberId, LoyaltyPgmCurrencySubtypeId, LoyaltyProgramCurrencyId, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :cancelSumByLLT.keySet()
      ];

      // LLT 하나씩 판단
      for (LoyaltyLedgerTraceability orig : originalDebitList) {
        Decimal originalPts = orig.Points; // 원본 Debit LLT 에서 사용한 포인트
        Decimal cancelledPts = cancelSumByLLT.get(orig.Id); // 취소
        Decimal cancelAmountPts = originalPts - cancelledPts;

        // 기존 LLT는 무조건 delete
        deleteDebitList.add(orig);

        // 남은 포인트가 있으면 새로운 Debit LLT로 생성
        if (cancelAmountPts > 0) {
          LoyaltyLedgerTraceability newDebit = new LoyaltyLedgerTraceability();
          newDebit.LoyaltyProgramMemberId = orig.LoyaltyProgramMemberId;
          newDebit.LoyaltyPgmCurrencySubtypeId = orig.LoyaltyPgmCurrencySubtypeId;
          newDebit.LoyaltyProgramCurrencyId = orig.LoyaltyProgramCurrencyId;
          newDebit.Points = cancelAmountPts;
          newDebit.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
          newDebit.DebitLoyaltyLedgerId = orig.DebitLoyaltyLedgerId;
          newDebit.CreditLoyaltyLedgerId = orig.CreditLoyaltyLedgerId;

          insertRemainDebitList.add(newDebit);
        }
      }

      // (DML 실행 순서 중요)
      if (!deleteDebitList.isEmpty()) {
        System.debug('기존 LLT 삭제합니다.');
        delete deleteDebitList;
      }
      if (!insertRemainDebitList.isEmpty()) {
        System.debug('새로운 Debit LLT를 생성합니다.');
        insert insertRemainDebitList;
      }
      // ================================================================================================================================

      // 포인트 사용 취소 금액이 남아 있는 경우
      if (cancelAmount > 0) {
        System.debug('취소 요청 포인트가 실제 사용 포인트보다 큽니다. ' + cancelAmount);
        throw new CustomException(400, '취소 요청 포인트가 실제 사용 포인트보다 큽니다.');
      }

      // 취소 -> 만료 처리 케이스
      if (!expiredCancelList.isEmpty()) {
        System.debug('취소 -> 만료 처리 케이스 진입하였습니다.');
        List<LoyaltyLedger> expireLedgerList = new List<LoyaltyLedger>();
        List<TraceSeed> traceSeedList = new List<TraceSeed>();

        List<Map<String, Object>> expiredPointList = new List<Map<String, Object>>();

        for (CancelPortion expiredCancel : expiredCancelList) {
          // 사용 취소 원장
          LoyaltyLedger expireLedger = new LoyaltyLedger();
          expireLedger.LoyaltyProgramMemberId = tj.MemberId;
          expireLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
          expireLedger.TransactionJournalId = tj.Id;
          expireLedger.ActivityDate = Datetime.now();
          expireLedger.LoyaltyPgmCrcySubtypeId = expiredCancel.loyaltyPgmCurrencySubtypeId;
          expireLedger.Points = expiredCancel.cancelPoints;
          expireLedger.ExpiryDate = expiredCancel.expiryDate;
          expireLedger.EventType = 'Credit'; // 지급

          expireLedgerList.add(expireLedger);

          // 만료 원장 (사용 취소 원장 복제)
          LoyaltyLedger creditLedger = expireLedger.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
          creditLedger.EventType = 'Expiry'; // 만료
          expireLedgerList.add(creditLedger);

          traceSeedList.add(
            new TraceSeed(
              expiredCancel.debitLoyaltyLedgerId, // 기존 사용(차감) 레저 Id
              creditLedger // 새로 만든 사용취소용 레저(Traceability에서 Credit 쪽으로 볼 대상)
            )
          );

          // return 값 담기
          Map<String, Object> expiredPoint = new Map<String, Object>();
          expiredPoint.put('Point', expiredCancel.cancelPoints);
          expiredPoint.put('Name', expiredCancel.pointSubTypeName);
          expiredPoint.put('ExpiryDate', String.valueOf(expiredCancel.expiryDate));
          expiredPointList.add(expiredPoint);
        }
        response.put('ExpiryPointList', expiredPointList);

        insert expireLedgerList;

        // List<LoyaltyLedgerTraceability> debitCancellationTracebilityList = new List<LoyaltyLedgerTraceability>();

        // for (TraceSeed seed : traceSeedList) {
        //   LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
        //   t.LoyaltyProgramMemberId = tj.MemberId;
        //   t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
        //   t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        //   t.Points = seed.creditLedger.Points;
        //   t.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION;
        //   t.DebitLoyaltyLedgerId = seed.debitLedgerId; // 원래 사용 원장 ID
        //   t.CreditLoyaltyLedgerId = seed.creditLedger.Id; // 지금 만든 취소용 원장 ID

        //   debitCancellationTracebilityList.add(t);
        // }

        // if (!debitCancellationTracebilityList.isEmpty()) {
        //   insert debitCancellationTracebilityList;
        // }
      }

      // 취소 -> 재지급 하는 케이스
      if (!unexpiredCancelList.isEmpty()) {
        System.debug('취소 -> 재지급 하는 케이스 진입');
        List<Map<String, Object>> reqList = new List<Map<String, Object>>();

        List<Map<String, Object>> recreditPointList = new List<Map<String, Object>>();

        Map<String, TraceSeed> traceSeedMap = new Map<String, TraceSeed>();

        for (CancelPortion unexpiredCancel : unexpiredCancelList) {
          Map<String, Object> req = new Map<String, Object>();
          req.put('loyaltyProgramMemberId', tj.MemberId);
          req.put('loyaltyProgramCurrencyId', loyaltyProgramCurrencyId);
          req.put('journalId', tj.Id);
          req.put('loyaltyProgramCurrencySubtypeName', unexpiredCancel.pointSubTypeName);
          req.put('points', unexpiredCancel.cancelPoints);
          req.put('pointsExpirationDate', String.valueOf(unexpiredCancel.expiryDate));
          reqList.add(req);

          String traceKey = String.valueOf(tj.Id) + '|' + unexpiredCancel.pointSubTypeName + '|' + String.valueOf(unexpiredCancel.expiryDate);
          System.debug('traceKey : ' + traceKey);
          traceSeedMap.put(
            traceKey,
            new TraceSeed(
              unexpiredCancel.debitLoyaltyLedgerId, // 기존 사용(차감) 레저 Id
              null
            )
          );

          // return 값 담기
          Map<String, Object> recreditPoint = new Map<String, Object>();
          recreditPoint.put('Point', unexpiredCancel.cancelPoints);
          recreditPoint.put('Name', unexpiredCancel.pointSubTypeName);
          recreditPoint.put('ExpiryDate', String.valueOf(unexpiredCancel.expiryDate));
          recreditPointList.add(recreditPoint);
        }
        response.put('RecreditPointList', recreditPointList);

        // 포인트 재지급
        List<LoyaltyManagement.CreditPointsOutput> creditPointsOutputs = LoyaltyPointService.creditPoints(reqList);

        // List<LoyaltyLedger> creditLedgerList = [
        //   SELECT Id, ExpiryDate, LoyaltyPgmCrcySubtype.Name, TransactionJournalId, Points
        //   FROM LoyaltyLedger
        //   WHERE TransactionJournalId = :tj.Id AND EventType = 'Credit'
        //   LIMIT 100
        // ];

        // for (LoyaltyLedger creditLedger : creditLedgerList) {
        //   String traceKey =
        //     String.valueOf(creditLedger.TransactionJournalId) +
        //     '|' +
        //     creditLedger.LoyaltyPgmCrcySubtype.Name +
        //     '|' +
        //     String.valueOf(creditLedger.ExpiryDate);

        //   if (traceSeedMap.containsKey(traceKey)) {
        //     TraceSeed seed = traceSeedMap.get(traceKey);
        //     seed.creditLedger = creditLedger;
        //   }
        // }

        // LoyaltyLedgerTraceability 생성
        // List<LoyaltyLedgerTraceability> traceList = new List<LoyaltyLedgerTraceability>();

        // for (String key : traceSeedMap.keySet()) {
        //   TraceSeed seed = traceSeedMap.get(key);

        //   if (seed.creditLedger == null) {
        //     throw new CustomException(500, '재지급 원장 매핑 실패 : ' + key);
        //   }

        //   LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
        //   t.LoyaltyProgramMemberId = tj.MemberId;
        //   t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
        //   t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        //   t.Points = seed.creditLedger.Points;
        //   t.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION; // 포인트 사용 취소
        //   t.DebitLoyaltyLedgerId = seed.debitLedgerId; // 원 사용 원장
        //   t.CreditLoyaltyLedgerId = seed.creditLedger.Id; // 재지급 원장

        //   traceList.add(t);
        // }

        // if (!traceList.isEmpty()) {
        //   DebugUtil.pretty('traceList', traceList);
        //   // insert traceList;
        //   List<Database.SaveResult> resultList = Database.insert(traceList);

        //   for (Database.SaveResult result : resultList) {
        //     if (!result.isSuccess()) {
        //       Database.Error err = result.getErrors()[0];
        //       throw new CustomException(400, err.getMessage());
        //     }
        //   }
        // }
      } else {
        tj.Status = 'Processed';
        update tj;
      }
      return response;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 개별 삭제(소멸)
   */
  public ApiResult deletePoint(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      List<Object> pointsList = ValidationUtil.listObjValidation(reqData.get('PointsList'), 'PointsList', true); // 포인트 목록

      if (pointsList.size() > 50) {
        throw new CustomException(400, '포인트 삭제(소멸) 요청 개수가 허용 범위를 초과하였습니다. (최대 50건)');
      }

      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      Map<String, Decimal> pointByTypeMap = new Map<String, Decimal>();
      Decimal totalPoints = 0;

      for (Object v : pointsList) {
        Map<String, Object> vMap = ValidationUtil.mapStrObjValidation(v, 'PointsList', true);

        Decimal point = ValidationUtil.decimalGreaterThanZero(vMap.get('point'), 'point', true); // 포인트 금액
        String cdTypePoint = ValidationUtil.stringValidationEx(vMap.get('cd_type_point'), 'cd_type_point', true, false); // 포인트 구분
        String expiryDateStr = ValidationUtil.stringValidationEx(vMap.get('ExpiryDate__c'), 'ExpiryDate__c', true, false); // 소멸예정일

        String key = cdTypePoint + '|' + expiryDateStr;
        totalPoints += point;

        pointByTypeMap.put(key, (pointByTypeMap.containsKey(key) ? pointByTypeMap.get(key) : 0) + point);
      }

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      tj.MemberId = lpmList[0].Id; // 대상 멤버 Id
      tj.JournalDate = Datetime.now(); // 거래 일자
      tj.ActivityDate = Datetime.now(); // 활동 일자
      tj.TransactionAmount = totalPoints; // 삭제(소멸) 포인트
      tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_POINTS_EXPIRATION, true);
      tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_EXPIRE, true);
      tj.JournalReason__c = '2';

      insert tj;

      List<Map<String, Object>> pointDeleteReqList = new List<Map<String, Object>>();

      for (String key : pointByTypeMap.keySet()) {
        List<String> parts = key.split('\\|');
        String cdTypePoint = parts[0]; // 포인트 구분
        Date expiryDate = ValidationUtil.dateValidation(parts[1], 'expiryDateStr', true); // 만료 일자

        List<LoyaltyAggrSubPointExprLedger__c> laspelList = [
          SELECT
            Id,
            CurrencySubTypeName__c,
            CurrencySubTypeId__r.PointTypeCode__c,
            ExpiryDate__c,
            AccruedPoints__c,
            RedeemedPoints__c,
            ExpiredPoints__c,
            AvailablePoints__c
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE
            LoyaltyProgramMemberId__c = :lpmList[0].Id
            AND CurrencySubTypeId__r.PointTypeCode__c = :cdTypePoint
            AND ExpiryDate__c = :expiryDate
            AND AvailablePoints__c >= :pointByTypeMap.get(key)
            AND AvailablePoints__c > 0
          LIMIT 1
        ];

        if (laspelList.isEmpty()) {
          throw new CustomException(
            400,
            '해당 유형, 만료일자에 해당하는 포인트를 찾을 수 없습니다. (포인트 구분 : ' + cdTypePoint + '| 소멸예정일 : ' + expiryDate + ')'
          );
        }

        // 포인트 차감을 위한 값 설정
        Map<String, Object> pointDeleteReq = new Map<String, Object>();
        pointDeleteReq.put('loyaltyProgramMemberId', lpmList[0].Id);
        pointDeleteReq.put('journalId', tj.Id);
        pointDeleteReq.put('loyaltyProgramCurrencySubtypeName', laspelList[0].CurrencySubTypeName__c);
        pointDeleteReq.put('additionalNotes', '포인트 개별 삭제 API를 통한 포인트 삭제(소멸) 처리');
        pointDeleteReq.put('points', pointByTypeMap.get(key));

        pointDeleteReqList.add(pointDeleteReq);
      }

      // 포인트 사용 처리
      LoyaltyPointService.debitPoints(pointDeleteReqList);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      }

      List<PointDebitDTO> pcDtoList = new List<PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId; // 로열티 소멸 키값
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c; // 포인트 구분
        pcDto.CD_RESON = tj.JournalReason__c; // 회원 포인트 소진 구분
        pcDto.NO_MBR = memberNo; // 회원 번호
        pcDto.PT_USE = llt.Points; // 소멸된 금액
        pcDto.DTS_INSERT = String.valueOf(tj.CreatedDate); // 등록 일자

        pcDtoList.add(pcDto);
      }
      data.put('PointDeleteList', pcDtoList);

      return ApiResult.ok(200, '포인트 개별 삭제 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 구매 시 지급된 포인트 적립 취소
   */
  public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
    Map<String, Object> result = new Map<String, Object>();
    try {
      if (data == null || data.isEmpty()) {
        return null;
      }

      // 환급 할 금액
      Decimal totalCancelAmount = 0;
      for (TransactionJournal tj : data) {
        // 포인트 적립 제외 구분 코드
        if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
          continue;
        }
        if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
          continue;
        }

        totalCancelAmount += tj.TransactionAmount;
      }

      // 포인트 적립 취소 할 금액이 없음.
      if (totalCancelAmount <= 0) {
        return null;
      }

      Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true); // 포인트/쿠폰 지급
      Id accrualReversalJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, true); // 포인트/쿠폰 지급 취소
      Id purchaseAccrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true); // 구매 시 포인트 지급
      Id cancelPurchaseAccrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true); // 구매 시 포인트 지급 취소

      List<LoyaltyLedger> llList = [
        SELECT Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, CreatedDate
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.OrderId = :data[0].OrderId
          AND (TransactionJournal.JournalTypeId = :accrualJtId
          OR TransactionJournal.JournalTypeId = :accrualReversalJtId)
          AND (TransactionJournal.JournalSubTypeId = :purchaseAccrualJstId
          OR TransactionJournal.JournalSubTypeId = :cancelPurchaseAccrualJstId)
        ORDER BY CreatedDate ASC
        LIMIT 100
      ];

      if (llList.isEmpty()) {
        // throw new CustomException(400, '구매 시 적립된 포인트 내역이 존재하지 않습니다. ' + data[0].OrderId);
        return null;
      }

      Map<String, Decimal> netPointMap = new Map<String, Decimal>();

      for (LoyaltyLedger ll : llList) {
        if (String.isBlank(ll.AdditionalNotes)) {
          continue;
        }

        String key = ll.AdditionalNotes;

        if (!netPointMap.containsKey(key)) {
          netPointMap.put(key, 0);
        }

        if (ll.EventType == 'Credit') {
          netPointMap.put(key, netPointMap.get(key) + ll.Points);
        } else if (ll.EventType == 'Debit') {
          netPointMap.put(key, netPointMap.get(key) - ll.Points);
        }
      }

      List<CancelPurchasePoints> cppList = new List<CancelPurchasePoints>();

      for (String key : netPointMap.keySet()) {
        Decimal remainPts = netPointMap.get(key);
        if (remainPts == null || remainPts <= 0) {
          continue;
        }

        List<String> parts = key.split('\\|');

        String subtypeName = parts[0];
        Id subtypeId = (Id) parts[1];
        String rateStr = parts[2];
        Decimal rate = Decimal.valueOf(rateStr);

        cppList.add(new CancelPurchasePoints(remainPts, subtypeId, subtypeName, rate));
      }

      if (cppList.isEmpty()) {
        return null;
      }

      TransactionJournal tj = new TransactionJournal();
      tj.JournalDate = Datetime.now();
      tj.ActivityDate = Datetime.now();
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = data[0].OrderId;
      tj.JournalTypeId = accrualReversalJtId;
      tj.JournalSubTypeId = cancelPurchaseAccrualJstId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }

      if (data[0].JournalSubTypeId == SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true)) {
        tj.JournalReason__c = '6';
      }

      insert tj;

      Map<Id, List<CancelPurchasePoints>> cppGroupMap = new Map<Id, List<CancelPurchasePoints>>();

      for (CancelPurchasePoints cp : cppList) {
        if (!cppGroupMap.containsKey(cp.loyaltyPgmCrcySubtypeId)) {
          cppGroupMap.put(cp.loyaltyPgmCrcySubtypeId, new List<CancelPurchasePoints>());
        }
        cppGroupMap.get(cp.loyaltyPgmCrcySubtypeId).add(cp);
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (Id subtypeId : cppGroupMap.keySet()) {
        // 포인트 별로 환불 원금 다시 시작
        Decimal remainCancelAmountForSubtype = totalCancelAmount; // 환불 할 금액

        List<CancelPurchasePoints> bucketList = cppGroupMap.get(subtypeId);

        // 비율 오름차순 정렬 (1.00 → 2.00 → 3.00 ...)
        bucketList.sort(new CancelRateSorter());

        for (CancelPurchasePoints cp : bucketList) {
          if (remainCancelAmountForSubtype <= 0) {
            break;
          }

          Decimal rateFraction = cp.rate / 100;
          if (rateFraction <= 0) {
            continue;
          }

          // 이 버킷에서 최대 취소 가능한 원금 금액
          // cp.points = 남아있는 포인트
          // cp.points / rateFraction = 해당 포인트가 커버하는 원금
          Decimal maxCancelableAmount = cp.points / rateFraction;

          // 이번 포인트 타입에서 남아있는 환불 원금과 비교
          Decimal useAmountFromThis = (remainCancelAmountForSubtype > maxCancelableAmount) ? maxCancelableAmount : remainCancelAmountForSubtype;

          if (useAmountFromThis <= 0) {
            continue;
          }

          // 실제 취소할 포인트
          Decimal cancelPoints = useAmountFromThis * rateFraction;

          if (cancelPoints > cp.points) {
            cancelPoints = cp.points;
          }

          if (cancelPoints <= 0) {
            continue;
          }

          Map<String, Object> req = new Map<String, Object>();
          req.put('loyaltyProgramMemberId', data[0].MemberId);
          req.put('points', cancelPoints);
          req.put('journalId', tj.Id);
          req.put('additionalNotes', cp.loyaltyPgmCrcySubtypeName + '|' + String.valueOf(cp.loyaltyPgmCrcySubtypeId) + '|' + String.valueOf(cp.rate));
          req.put('loyaltyProgramCurrencySubtypeName', cp.loyaltyPgmCrcySubtypeName);

          reqList.add(req);

          // 이 포인트 타입에서 남아있는 환불 원금 차감
          remainCancelAmountForSubtype -= useAmountFromThis;
        }
      }

      if (!reqList.isEmpty()) {
        // 포인트 적립 취소
        // LoyaltyPointService.debitPoints(reqList);
        List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

        // 포인트 사용 추적 조회
        List<LoyaltyLedgerTraceability> lltList = [
          SELECT
            LoyaltyPgmCurrencySubtype.Name,
            Points,
            CreditLoyaltyLedger.ExpiryDate,
            LoyaltyProgramMember.Contact.MemberNo__c,
            LastModifiedDate,
            DebitLoyaltyLedgerId,
            LoyaltyPgmCurrencySubtype.PointTypeCode__c,
            CreditLoyaltyLedgerId
          FROM LoyaltyLedgerTraceability
          WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
          LIMIT 100
        ];
        if (lltList.isEmpty()) {
          throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
        }
        List<LoyaltyLedgerTraceability> newLltList = new List<LoyaltyLedgerTraceability>();
        for (LoyaltyLedgerTraceability llt : lltList) {
          LoyaltyLedgerTraceability newLlt = llt.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
          newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;

          newLltList.add(newLlt);
        }

        // llt.ActionType 필드가 update 불가하여, 새로운 LoyaltyLedgerTraceability insert 후 기존 LoyaltyLedgerTraceability는 삭제
        List<Database.SaveResult> insertResultList = Database.insert(newLltList);

        for (Database.SaveResult insertResult : insertResultList) {
          if (!insertResult.isSuccess()) {
            Database.Error err = insertResult.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }
        }

        // 기존 LoyaltyLedgerTraceability 삭제
        List<Database.DeleteResult> deleteResultList = Database.delete(lltList);

        for (Database.DeleteResult deleteResult : deleteResultList) {
          if (!deleteResult.isSuccess()) {
            Database.Error err = deleteResult.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }
        }

        Decimal totalPoints = 0;
        List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
        for (LoyaltyLedgerTraceability llt : newLltList) {
          GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
          pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId; // 로열티 소멸 키값
          pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // tj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
          pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c; // 포인트 구분
          pcDto.CD_RESON = tj.JournalReason__c; // 회원 포인트 소진 구분
          pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
          if (String.isNotBlank(tj.Order.OrderNo__c)) {
            pcDto.NO_SAL = tj.Order.OrderNo__c; // 주문 번호
          } else if (String.isNotBlank(tj.Order.SaleNo__c)) {
            pcDto.NO_SAL = tj.Order.SaleNo__c; // 판매 번호
          }
          pcDto.PT_USE = llt.Points; // 적립 취소된 금액
          pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 적립 취소된 금액

          pdDtoList.add(pcDto);

          if (llt.Points > 0) {
            totalPoints += llt.Points;
          }
        }

        tj.TransactionAmount = totalPoints;
        update tj;

        return pdDtoList;
      }
      return null;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // 포인트 사용 취소를 위한 계산용 클래스
  public class UsageBucket {
    public Id loyaltyLedgerTraceabilityId;
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Decimal usagePoints = 0;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId;
    public String debitLoyaltyLedgerId;

    public UsageBucket(Id id, Date e, String s, Integer p, Id lpcsi, String clli, String dlli) {
      loyaltyLedgerTraceabilityId = id;
      expiryDate = e;
      pointSubTypeName = s;
      usagePriority = p;
      loyaltyPgmCurrencySubtypeId = lpcsi;
      creditLoyaltyLedgerId = clli;
      debitLoyaltyLedgerId = dlli;
    }
  }

  // 포인트 사용 취소 할 포인트 정렬 메서드
  public class UsageBucketCancelSorter implements System.Comparator<Object> {
    public Integer compare(Object a, Object b) {
      UsageBucket x = (UsageBucket) a;
      UsageBucket y = (UsageBucket) b;
      // 만료일이 느린 순으로 정렬
      if (x.expiryDate > y.expiryDate) {
        return -1; // x를 먼저
      }
      if (x.expiryDate < y.expiryDate) {
        return 1; // y를 먼저
      }

      // 우선순위 정렬 (사용 우선 순위가 낮은 순서대로 정렬)
      if (x.usagePriority > y.usagePriority) {
        return -1;
      }
      if (x.usagePriority < y.usagePriority) {
        return 1;
      }

      // 최종 (이름 순..)
      return x.pointSubTypeName.toLowerCase().compareTo(y.pointSubTypeName.toLowerCase());
    }
  }

  // 포인트 사용 취소를 위한 클래스
  public class CancelPortion {
    public Id loyaltyLedgerTraceabilityId;
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Decimal cancelPoints;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId;
    public String debitLoyaltyLedgerId;

    public CancelPortion(UsageBucket ub, Decimal cancelPoints) {
      this.loyaltyLedgerTraceabilityId = ub.loyaltyLedgerTraceabilityId;
      this.expiryDate = ub.expiryDate;
      this.pointSubTypeName = ub.pointSubTypeName;
      this.usagePriority = ub.usagePriority;
      this.cancelPoints = cancelPoints;
      this.loyaltyPgmCurrencySubtypeId = ub.loyaltyPgmCurrencySubtypeId;
      this.creditLoyaltyLedgerId = ub.creditLoyaltyLedgerId;
      this.debitLoyaltyLedgerId = ub.debitLoyaltyLedgerId;
    }
  }

  // 포인트 사용 취소를 위한 추적용 클래스
  public class TraceSeed {
    public Id debitLedgerId;
    public LoyaltyLedger creditLedger;

    public TraceSeed(Id debitLedgerId, LoyaltyLedger creditLedger) {
      this.debitLedgerId = debitLedgerId;
      this.creditLedger = creditLedger;
    }
  }

  // 구매 적립 포인트 취소를 위한 클래스
  public class CancelPurchasePoints {
    public Decimal points; // 해당 비율/타입에 대해 남아 있는 순 포인트
    public Id loyaltyPgmCrcySubtypeId; // 포인트 하위 유형 Id
    public String loyaltyPgmCrcySubtypeName; // 포인트 하위 유형 Name
    public Decimal rate;

    public CancelPurchasePoints(Decimal p, Id lpcsi, String lpcsn, Decimal r) {
      this.points = p;
      this.loyaltyPgmCrcySubtypeId = lpcsi;
      this.loyaltyPgmCrcySubtypeName = lpcsn;
      this.rate = r;
    }
  }

  // 구매 적립 포인트 취소를 위한 정렬 메서드
  public class CancelRateSorter implements Comparator<CancelPurchasePoints> {
    public Integer compare(CancelPurchasePoints a, CancelPurchasePoints b) {
      if (a.rate == null && b.rate == null) {
        return 0;
      }
      if (a.rate == null) {
        return 1;
      }
      if (b.rate == null) {
        return -1;
      }

      if (a.rate < b.rate) {
        return -1;
      }
      if (a.rate > b.rate) {
        return 1;
      }
      return 0;
    }
  }

  public class DepositResponseDTO {
    public String CD_TYPE_APPR; // 결제 구분
    public Decimal AM_DEPOSIT; // 금액
    public String NO_COUPON_ALL; // 쿠폰 코드
    public String NM_COUPON; // 쿠폰명
    public Date DT_EXP; // 만료 날짜
    public Integer RT_DISC; // 할인율
    public Decimal AM_DISC; // 할인 금액
    public String TX_REMARK; // 비고
  }

  // 사용한 포인트 집계용 클래스
  public class LedgerAggKey {
    public String memberNo;
    public Id currencySubtypeId;
    public Date expiryDate;
    public String pointSubtypeName;
    public Id debitLoyaltyLedgerId;
    public Id creditLoyaltyLedgerId;
    public String insertId;
    public String createdDate;
    public String saleNo;
    public Decimal actualPaymentAmount;
    public boolean isReductionOrder;
    public String depositNo;

    public LedgerAggKey(LoyaltyLedgerTraceability llt) {
      this.memberNo = llt.LoyaltyProgramMember.Contact.MemberNo__c;
      this.currencySubtypeId = llt.LoyaltyPgmCurrencySubtypeId;
      this.expiryDate = llt.CreditLoyaltyLedger.ExpiryDate;
      this.pointSubtypeName = llt.LoyaltyPgmCurrencySubtype.Name;
      this.debitLoyaltyLedgerId = llt.DebitLoyaltyLedgerId;
      this.creditLoyaltyLedgerId = llt.CreditLoyaltyLedgerId;
      this.insertId = llt.DebitLoyaltyLedger.TransactionJournal.InsertId__c;
      this.createdDate = llt.CreatedDate.format('yyyyMMddHHmmss');
      this.saleNo = llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c;
      this.actualPaymentAmount = llt.DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c;
      this.isReductionOrder = llt.DebitLoyaltyLedger.TransactionJournal.Order.IsReductionOrder;
      this.depositNo = llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c;
    }

    public Boolean equals(Object obj) {
      if (obj == null || !(obj instanceof LedgerAggKey)) {
        return false;
      }
      LedgerAggKey other = (LedgerAggKey) obj;
      return this.currencySubtypeId == other.currencySubtypeId && this.expiryDate == other.expiryDate;
    }

    public Integer hashCode() {
      return (String.valueOf(currencySubtypeId) + '|' + String.valueOf(expiryDate)).hashCode();
    }
  }

  /**
   * 포인트 적립 대상 여부 판단
   */
  public Boolean isAccrualEligible(TransactionJournal tj) {
    if (!('01'.equals(tj.DepositType__c) || '02'.equals(tj.DepositType__c))) {
      return false;
    }

    if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
      return false;
    }

    if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
      return false;
    }

    return true;
  }
}