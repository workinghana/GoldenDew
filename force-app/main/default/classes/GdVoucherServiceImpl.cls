/**
 * 쿠폰 관련 로직 처리하는 서비스 구현 클래스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 * @see GdVoucherService
 */
public with sharing class GdVoucherServiceImpl implements GdVoucherService {
  @TestVisible
  private static Boolean bypassUnlimitedReissueTestShortcut = false;
  private static final String JOURNAL_TYPE_NAME_REDEMPTION = 'Redemption'; // 포인트/쿠폰 사용
  private static final String JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL = 'Redemption Reversal'; // 포인트/쿠폰 사용 취소

  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem'; // 쿠폰 사용
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel'; // 쿠폰 사용 취소

  private static final String VOUCHER_CATEGORY_NAME_SIGNUP_COUPON = 'SignupCoupon'; // 신규 가입 쿠폰

  private static final Set<String> AVAILABLE_COUPON_LIMIT_TYPES = new Set<String>{
    'ProductIncludeList',
    'StoreIncludeList',
    'StoreTypeIncludeList',
    'DiscountRate',
    'GradeIncludeList',
    'ProductCategoryIncludeList',
    'PromotionIncludeList',
    'OrderTypeIncludeList',
    'TotalQuantity',
    'SalesAmount'
  };

  public GdVoucherServiceImpl() {
  }

  /**
   * ! 보류
   * 생일 쿠폰 지급
   * 생일 월 1일에 일괄 지급
   * Voucher insert
   */
  public void issueBirthdayCoupon() {
    try {
      // TransactionJournal tj = new TransactionJournal();
      // tj.ActivityDate = Datetime.now();
      // tj.JournalDate = Datetime.now();
      // tj.JournalTypeId = jtList[0].Id;
      // tj.JournalSubTypeId = jstList[0].Id;
      // tj.LoyaltyProgramId = lpList[0].Id;
      // tj.MemberId = loyaltyProgramMemberId;
      // tj.Status = 'Pending';

      // TransactionJournal tj = new TransactionJournal();
      // tj.ActivityDate = Datetime.now();
      // tj.JournalDate = Datetime.now();
      // tj.JournalTypeId = jtList[0].Id;
      // tj.JournalSubTypeId = jstList[0].Id;
      // tj.LoyaltyProgramId = lpList[0].Id;
      // tj.MemberId = loyaltyProgramMemberId;
      // tj.Status = 'Pending';

      //   List<Contact> cList = [SELECT Id, Birthdate FROM Contact WHERE Birthdate = :Date.today() LIMIT 200];
      //   if (cList.isEmpty()) {
      //     return ApiResult.ok(200, '생일인 회원이 없습니다.', null);
      //   }

      //   Set<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE ContactId IN :cList LIMIT 200];

      //   // 쿠폰 마스터의 카테고리가 '생일 쿠폰' 카테고리인 쿠폰 마스터 조회
      //   List<VoucherDefinition> vdList = [SELECT Id FROM VoucherDefinition WHERE ProductCategoryDerivedField.Code = 'BirthdayCoupon' LIMIT 1];
      //   if (vdList.isEmpty()) {
      //     throw new CustomException(400, '생일 쿠폰이 없습니다.');
      //   }

      //   // VoucherDefinition vd = vdList[0];

      //   List<Map<String, Object>> reqData = new List<Map<String, Object>>();
      //   for (Contact c : cList) {
      //     Map<String, Object> req = new Map<String, Object>();
      //   }
      //   LoyaltyVoucherService.issueVoucher();
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 보류
   * 생일 쿠폰 지급
   * 생일 월 1일에 일괄 지급
   * Voucher insert
   */
  public static void issueMonthlyCoupon() {
    try {
      //   List<Contact> cList = [SELECT Id, MemberNo__c from Contact];
      //   if (cList.isEmpty()) {
      //     return ApiResult.ok(200, '등록된 회원이 없습니다.', null);
      //   }
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 가입 쿠폰 지급
   * 가입 시 쿠폰 지급
   * Voucher insert
   */
  public ApiResult issueSignupCoupon(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String loyaltyProgramMemberId = ValidationUtil.stringValidation(reqData.get('LoyaltyProgramMemberId'), 'LoyaltyProgramMemberId', true);

      // 쿠폰 마스터의 카테고리가 '신규 가입 쿠폰' 카테고리인 쿠폰 마스터 조회
      List<VoucherDefinition> vdList = [
        SELECT Id, Name, IsUpgrade__c, DiscountPercent
        FROM VoucherDefinition
        WHERE
          VoucherCategoryId__r.Code__c = :VOUCHER_CATEGORY_NAME_SIGNUP_COUPON
          AND IsActive = TRUE
          AND (ExpirationDate = NULL
          OR ExpirationDate >= TODAY)
        LIMIT 200
      ];
      if (vdList.isEmpty()) {
        return null;
        // throw new CustomException(400, '신규 가입 쿠폰이 없습니다.');
      }

      // 로열티 프로그램 체크
      List<LoyaltyProgram> lpList = [
        SELECT Id, Name
        FROM LoyaltyProgram
        WHERE IsPrimary = TRUE
        LIMIT 1
      ];
      if (lpList.isEmpty()) {
        throw new CustomException(400, '로열티 프로그램이 없습니다.');
      }

      // 저널 유형 체크
      List<JournalType> jtList = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
      if (jtList.isEmpty()) {
        throw new CustomException(400, '저널 유형이 없습니다.');
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstList = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = 'Welcome Coupon Issue' AND JournalTypeId = :jtList[0].Id
        LIMIT 1
      ];
      if (jstList.isEmpty()) {
        throw new CustomException(400, '저널 하위 유형이 없습니다.');
      }

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = Datetime.now();
      tj.JournalDate = Datetime.now();
      tj.JournalTypeId = jtList[0].Id;
      tj.JournalSubTypeId = jstList[0].Id;
      tj.LoyaltyProgramId = lpList[0].Id;
      tj.MemberId = loyaltyProgramMemberId;
      tj.Status = 'Pending';

      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Set<Id> upgradeVoucherDefinitionIds = new Set<Id>();
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      for (VoucherDefinition vd : vdList) {
        if (vd.IsUpgrade__c == true) {
          if (vd.DiscountPercent != null && vd.DiscountPercent > 0) {
            throw new CustomException(400, '업그레이드 쿠폰은 정률 쿠폰일 수 없습니다.');
          }
          upgradeVoucherDefinitionIds.add(vd.Id);
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', loyaltyProgramMemberId);
        req.put('programName', lpList[0].Name);
        req.put('voucherDefinitionName', vd.Name);
        req.put('journalId', tj.Id);
        reqList.add(req);

        //   Map<String, Object> req = new Map<String, Object>();
        // req.put('loyaltyProgramMemberId', loyaltyProgramMemberId); // 누구에게
        // req.put('programName', programName); // 어느 프로그램 기준
        // req.put('voucherDefinitionName', vd.Name); // 어떤 쿠폰 정의
        // req.put('journalId', tj.Id); // 어떤 거래 하에서
        // reqList.add(req);
      }
      System.debug('reqList : ' + reqList);
      List<LoyaltyManagement.IssueVoucherOutput> resList = LoyaltyVoucherService.issueVoucher(reqList);

      List<Id> issuedVoucherIds = new List<Id>();
      for (LoyaltyManagement.IssueVoucherOutput res : resList) {
        if (res != null && res.getVoucherId() != null) {
          issuedVoucherIds.add(res.getVoucherId());
        }
      }

      if (!upgradeVoucherDefinitionIds.isEmpty() && !issuedVoucherIds.isEmpty()) {
        List<Voucher> upgradeVoucherList = [
          SELECT Id, VoucherDefinitionId, FaceValue
          FROM Voucher
          WHERE Id IN :issuedVoucherIds AND VoucherDefinitionId IN :upgradeVoucherDefinitionIds
        ];

        for (Voucher voucher : upgradeVoucherList) {
          voucher.FaceValue = 0;
        }

        if (!upgradeVoucherList.isEmpty()) {
          update upgradeVoucherList;
        }
      }

      tj.Status = 'Processed';
      System.debug(
        LoggingLevel.WARN,
        '[GDV][redeemVoucher] inserting TransactionJournal status=' +
          tj.Status +
          ', memberId=' +
          tj.MemberId +
          ', voucherCode=' +
          tj.VoucherCode +
          ', journalTypeId=' +
          tj.JournalTypeId +
          ', journalSubTypeId=' +
          tj.JournalSubTypeId
      );

      Database.SaveResult updateResult = Database.update(tj);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      List<Id> voucherIdList = new List<Id>();

      for (LoyaltyManagement.IssueVoucherOutput res : resList) {
        voucherIdList.add(res.getVoucherId());
        System.debug('res.getVoucherId() : ' + res.getVoucherId());
      }

      List<Voucher> vList = [
        SELECT
          Id,
          VoucherCode,
          ExpirationDate,
          ExpirationDateTime,
          EffectiveDate,
          EffectiveDateTime,
          DiscountPercent,
          FaceValue,
          PromotionId,
          VoucherDefinition.CouponManNo__c
        FROM Voucher
        WHERE Id IN :voucherIdList
      ];
      data.put('CouponList', vList);
      System.debug('data : ' + data);

      return ApiResult.ok(200, '쿠폰 지급 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 개발 중
   * 가입 쿠폰 지급 V2
   * 가입 시 쿠폰 지급
   */
  public ApiResult issueSignupCouponV2(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String loyaltyProgramMemberId = ValidationUtil.stringValidation(reqData.get('LoyaltyProgramMemberId'), 'LoyaltyProgramMemberId', true);

      // 쿠폰 마스터의 카테고리가 '신규 가입 쿠폰' 카테고리인 쿠폰 마스터 조회
      List<VoucherDefinition> vdList = [
        SELECT Id
        FROM VoucherDefinition
        WHERE ProductCategoryDerivedField.Code = 'SignupCoupon'
        LIMIT 1
      ];
      if (vdList.isEmpty()) {
        throw new CustomException(400, '생일 쿠폰이 없습니다.');
      }

      // 로열티 프로그램 체크
      List<LoyaltyProgram> lpList = [
        SELECT Id, Name
        FROM LoyaltyProgram
        WHERE IsPrimary = TRUE
        LIMIT 1
      ];
      if (lpList.isEmpty()) {
        throw new CustomException(400, '로열티 프로그램이 없습니다.');
      }

      // 저널 유형 체크
      List<JournalType> jtList = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
      if (jtList.isEmpty()) {
        throw new CustomException(400, '저널 유형이 없습니다.');
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstList = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = 'Welcome Coupon Issue' AND JournalTypeId = :jtList[0].Id
        LIMIT 1
      ];
      if (jstList.isEmpty()) {
        throw new CustomException(400, '저널 하위 유형이 없습니다.');
      }

      // 거래 이력(TransactionJournal) 생성 Start.
      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = Datetime.now();
      tj.JournalDate = Datetime.now();
      tj.JournalTypeId = jtList[0].Id;
      tj.JournalSubTypeId = jstList[0].Id;
      tj.LoyaltyProgramId = lpList[0].Id;
      tj.MemberId = loyaltyProgramMemberId;
      tj.Status = 'Pending';

      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
      System.debug(LoggingLevel.WARN, '[GDV][redeemVoucher] inserted TransactionJournal id=' + tj.Id + ', status=' + tj.Status);
      // 거래 이력(TransactionJournal) 생성 End.

      Set<Id> upgradeVoucherDefinitionIds = new Set<Id>();
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      for (VoucherDefinition vd : vdList) {
        if (vd.IsUpgrade__c == true) {
          if (vd.DiscountPercent != null && vd.DiscountPercent > 0) {
            throw new CustomException(400, '업그레이드 쿠폰은 정률 쿠폰일 수 없습니다.');
          }
          upgradeVoucherDefinitionIds.add(vd.Id);
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', loyaltyProgramMemberId);
        req.put('programName', lpList[0].Name);
        req.put('voucherDefinitionName', vd.Id);
        req.put('journalId', tj.Id);
        reqList.add(req);
      }
      List<LoyaltyManagement.IssueVoucherOutput> resList = LoyaltyVoucherService.issueVoucher(reqList);

      List<Id> issuedVoucherIds = new List<Id>();
      for (LoyaltyManagement.IssueVoucherOutput res : resList) {
        if (res != null && res.getVoucherId() != null) {
          issuedVoucherIds.add(res.getVoucherId());
        }
      }

      if (!upgradeVoucherDefinitionIds.isEmpty() && !issuedVoucherIds.isEmpty()) {
        List<Voucher> upgradeVoucherList = [
          SELECT Id, VoucherDefinitionId, FaceValue
          FROM Voucher
          WHERE Id IN :issuedVoucherIds AND VoucherDefinitionId IN :upgradeVoucherDefinitionIds
        ];

        for (Voucher voucher : upgradeVoucherList) {
          voucher.FaceValue = 0;
        }

        if (!upgradeVoucherList.isEmpty()) {
          update upgradeVoucherList;
        }
      }

      tj.Status = 'Processed';

      Database.SaveResult updateResult = Database.update(tj);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      // List<Id> voucherIdList = new List<Id>();

      // for (LoyaltyManagement.IssueVoucherOutput res : resList) {
      //   voucherIdList.add(res.getVoucherId());
      //   System.debug('res.getVoucherId() : ' + res.getVoucherId());
      // }

      // List<Voucher> vList = [
      //   SELECT VoucherCode, ExpirationDate, ExpirationDateTime, EffectiveDate, EffectiveDateTime, DiscountPercent, FaceValue, PromotionId
      //   FROM Voucher
      //   WHERE Id IN :voucherIdList
      // ];
      // data.put('CouponList', vList);
      // System.debug('data : ' + data);

      return ApiResult.ok(200, '쿠폰 지급 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 쿠폰 개별 지급
   * Voucher insert
   */
  public ApiResult issueCoupon(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);
      String couponManNo = ValidationUtil.stringValidationEx(reqData.get('CouponManNo__c'), 'CouponManNo__c', true, false);

      //해당 회원 존재 여부
      List<LoyaltyProgramMember> lpmlist = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo
        LIMIT 1
      ];

      if (lpmlist.isEmpty()) {
        throw new CustomException(400, '해당 회원이 존재하지 않습니다.');
      }

      Id loyaltyProgramMemberId = lpmlist[0].Id;
      Id loyaltyProgramId = lpmlist[0].ProgramId;

      //쿠폰 정의 조회
      List<VoucherDefinition> vdlist = [
        SELECT
          Id,
          Name,
          CouponManNo__c,
          ExpirationType,
          EffectiveDate, //유효 날짜
          IsActive, //화설화 상태
          ExpirationDate, //만료 날짜
          ExpirationPeriod, //만료 기간
          ExpirationPeriodUnit,
          ExpirationDateTime
        FROM VoucherDefinition
        WHERE CouponManNo__c = :couponManNo
        LIMIT 1
      ];

      if (vdlist.isEmpty()) {
        throw new CustomException(400, '해당 쿠폰이 존재하지 않습니다.');
      }

      VoucherDefinition vd = vdlist[0];

      //쿠폰 활성 여부 검사
      if (!vd.IsActive) {
        throw new CustomException(400, '비활성화된 쿠폰입니다.');
      }

      // 해당 쿠폰 유효성 검사
      // 만료 유형 기준 분기
      if (vd.ExpirationType == 'FixedDate') {
        // FixedDate → Date 또는 DateTime 중 하나는 반드시 있어야 함
        if (vd.EffectiveDate == null || (vd.ExpirationDate == null && vd.ExpirationDateTime == null)) {
          throw new CustomException(400, '고정 만료 쿠폰 설정이 올바르지 않습니다.');
        }

        if (vd.EffectiveDate > Date.today()) {
          throw new CustomException(400, '해당 쿠폰은 아직 사용 가능한 기간이 아닙니다.');
        }

        // DateTime 우선, 없으면 Date
        Date expireDate = (vd.ExpirationDateTime != null) ? vd.ExpirationDateTime.date() : vd.ExpirationDate;

        if (expireDate < Date.today()) {
          throw new CustomException(400, '이미 만료된 쿠폰입니다.');
        }
      } else if (vd.ExpirationType == 'Period') {
        // Period 필수값
        if (vd.EffectiveDate == null || vd.ExpirationPeriod == null || vd.ExpirationPeriodUnit == null) {
          throw new CustomException(400, '기간형 쿠폰 설정이 올바르지 않습니다.');
        }

        // Period 타입에는 절대 있으면 안 되는 필드들
        if (vd.ExpirationDate != null || vd.ExpirationDateTime != null) {
          throw new CustomException(400, '기간형 쿠폰에는 만료일을 설정할 수 없습니다.');
        }

        if (vd.EffectiveDate > Date.today()) {
          throw new CustomException(400, '해당 쿠폰은 아직 사용 가능한 기간이 아닙니다.');
        }
      } else {
        throw new CustomException(400, '지원하지 않는 쿠폰 만료 유형입니다.');
      }

      // 저널 유형 체크
      List<JournalType> jtList = [
        SELECT Id
        FROM JournalType
        WHERE Name = 'Manual Coupon Adjustment'
        LIMIT 1
      ];
      if (jtList.isEmpty()) {
        throw new CustomException(400, '저널 유형이 없습니다.');
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstList = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = 'Manual Coupon Issuance' AND JournalTypeId = :jtList[0].Id
        LIMIT 1
      ];
      if (jstList.isEmpty()) {
        throw new CustomException(400, '저널 하위 유형이 없습니다.');
      }

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = Datetime.now();
      tj.JournalDate = Datetime.now();
      tj.JournalTypeId = jtList[0].Id; // Accrual
      tj.JournalSubTypeId = jstList[0].Id; // Manual Coupon Issuance
      tj.LoyaltyProgramId = loyaltyProgramId;
      tj.MemberId = loyaltyProgramMemberId;
      tj.Status = 'Pending';

      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      //프로그램 조회
      String programName = [
        SELECT Name
        FROM LoyaltyProgram
        WHERE Id = :loyaltyProgramId
        LIMIT 1
      ]
      .Name;

      System.debug(programName);
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      // for (VoucherDefinition vd : vdlist) {
      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', loyaltyProgramMemberId); // 누구에게
      req.put('programName', programName); // 어느 프로그램 기준
      req.put('voucherDefinitionName', vd.Name); // 어떤 쿠폰 정의
      req.put('journalId', tj.Id); // 어떤 거래 하에서
      reqList.add(req);
      // }

      List<LoyaltyManagement.IssueVoucherOutput> resList = LoyaltyVoucherService.issueVoucher(reqList);

      tj.Status = 'Processed';
      Database.SaveResult updateResult = Database.update(tj);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
      Map<String, Object> data = new Map<String, Object>();
      List<Id> voucherIdList = new List<Id>();

      for (LoyaltyManagement.IssueVoucherOutput res : resList) {
        voucherIdList.add(res.getVoucherId());
        System.debug('res.getVoucherId() : ' + res.getVoucherId());
      }

      List<Voucher> vList = [
        SELECT VoucherCode, ExpirationDate, ExpirationDateTime, EffectiveDate, EffectiveDateTime, DiscountPercent, FaceValue, PromotionId
        FROM Voucher
        WHERE Id IN :voucherIdList
      ];

      data.put('CouponList', vList);

      return ApiResult.ok(200, '쿠폰 지급 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 개발 중
   * 쿠폰 개별 수정
   * Voucher update
   */
  public ApiResult updateCoupon(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      String voucherCode = ValidationUtil.stringValidationEx(reqData.get('VoucherCode'), 'VoucherCode', true, false); // 쿠폰 코드
      String status = ValidationUtil.stringValidationEx(reqData.get('Status'), 'Status', false, true); // 상태
      Date effectiveDate = ValidationUtil.dateValidation(reqData.get('EffectiveDate'), 'EffectiveDate', false); // 유효 날짜
      Date expirationDate = ValidationUtil.dateValidation(reqData.get('ExpirationDate'), 'ExpirationDate', false); // 만료 날짜
      String reason = ValidationUtil.stringValidation(reqData.get('Reason'), 'Reason', false); // 이유
      Integer faceValue = ValidationUtil.integerValidation(reqData.get('FaceValue'), 'FaceValue', false); // 할인 금액
      Integer discountPercent = ValidationUtil.integerValidation(reqData.get('DiscountPercent'), 'DiscountPercent', false); // 할인율

      // 기존
      // List<Voucher> vList = [
      //   SELECT Id, Status, EffectiveDate, Reason, FaceValue, DiscountPercent, ExpirationDate
      //   FROM Voucher
      //   WHERE LoyaltyProgramMember.Contact.MemberNo__c = :memberNo AND VoucherCode = :voucherCode
      //   LIMIT 1
      // ];

      // 26.05.01 GD - 쿠폰 코드 분할
      List<Voucher> vList = new List<Voucher>();

      if (String.isNotBlank(voucherCode) && voucherCode.contains(';-;')) {
        String couponManNo = voucherCode.substringBefore(';-;');
        voucherCode = voucherCode.substringAfter(';-;');

        vList = [
          SELECT Id, Status, EffectiveDate, Reason, FaceValue, DiscountPercent, ExpirationDate
          FROM Voucher
          WHERE
            LoyaltyProgramMember.Contact.MemberNo__c = :memberNo
            AND VoucherCode = :voucherCode
            AND VoucherDefinition.CouponManNo__c = :couponManNo
          LIMIT 1
        ];
      } else {
        vList = [
          SELECT Id, Status, EffectiveDate, Reason, FaceValue, DiscountPercent, ExpirationDate
          FROM Voucher
          WHERE LoyaltyProgramMember.Contact.MemberNo__c = :memberNo AND VoucherCode = :voucherCode
          LIMIT 1
        ];
      }
      //

      if (vList.isEmpty()) {
        throw new CustomException(400, '해당 쿠폰이 존재하지 않습니다.');
      }

      //만료된 쿠폰 제외
      if (vList[0].Status == 'Redeemed' || vList[0].Status == 'Expired') {
        throw new CustomException(400, '이미 사용되었거나 만료된 쿠폰은 수정할 수 없습니다.');
      }

      if (status != null) {
        vList[0].Status = status;
      }
      if (effectiveDate != null) {
        vList[0].EffectiveDate = effectiveDate;
      }
      if (expirationDate != null) {
        vList[0].ExpirationDate = expirationDate;
      }
      if (reason != null) {
        vList[0].Reason = reason;
      }
      if (faceValue != null) {
        vList[0].FaceValue = faceValue;
      }
      if (discountPercent != null) {
        vList[0].DiscountPercent = discountPercent;
      }

      Database.SaveResult updateResult = Database.update(vList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      data.put('Voucher', vList[0]);

      return ApiResult.ok(200, '쿠폰 개별 수정 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 쿠폰 개별 삭제
   * Voucher delete
   */
  public ApiResult deleteCoupon(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      String voucherCode = ValidationUtil.stringValidationEx(reqData.get('VoucherCode'), 'VoucherCode', true, false); // 쿠폰 코드

      //해당 회원 존재 여부
      List<LoyaltyProgramMember> lpmlist = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo
        LIMIT 1
      ];

      if (lpmlist.isEmpty()) {
        throw new CustomException(400, '해당 회원이 존재하지 않습니다.');
      }

      Id loyaltyProgramMemberId = lpmlist[0].Id;
      Id loyaltyProgramId = lpmlist[0].ProgramId;

      // 기존 쿠폰 조회
      // List<Voucher> vList = [
      //   SELECT Id, Status, Reason, VoucherCode
      //   FROM Voucher
      //   WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId AND VoucherCode = :voucherCode
      //   LIMIT 1
      // ];

      // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
      List<Voucher> vList = new List<Voucher>();

      if (String.isNotBlank(voucherCode) && voucherCode.contains(';-;')) {
        String couponManNo = voucherCode.substringBefore(';-;');
        voucherCode = voucherCode.substringAfter(';-;');

        vList = [
          SELECT Id, Status, Reason, VoucherCode
          FROM Voucher
          WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId AND VoucherCode = :voucherCode AND VoucherDefinition.CouponManNo__c = :couponManNo
          LIMIT 1
        ];
      } else {
        vList = [
          SELECT Id, Status, Reason, VoucherCode
          FROM Voucher
          WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId AND VoucherCode = :voucherCode
          LIMIT 1
        ];
      }
      //

      if (vList.isEmpty()) {
        throw new CustomException(400, '해당 쿠폰이 존재하지 않습니다.');
      }

      if (vList[0].Status == 'Redeemed' || vList[0].Status == 'Expired') {
        throw new CustomException(400, '이미 사용되었거나 만료된 쿠폰은 삭제할 수 없습니다.');
      }

      //이유 변경 : 삭제됨을 알림
      String reason;
      if (reqData.containsKey('Reason')) {
        reason = ValidationUtil.stringValidation(reqData.get('Reason'), 'Reason', false);
      } else {
        reason = 'API에 의한 쿠폰 삭제';
      }

      vList[0].Status = 'Cancelled';
      vList[0].Reason = reason;

      Database.SaveResult updateResult = Database.update(vList[0]);

      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(500, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();

      //수정한 쿠폰id 담기
      // List<Id> voucherIdList = new List<Id>();
      // voucherIdList.add(v.Id);

      // 수정된 쿠폰 재조회
      // List<Voucher> v_list = [
      //   SELECT VoucherCode, Status, Reason
      //   FROM Voucher
      //   WHERE Id IN :voucherIdList
      // ];

      data.put('Deleted CouponList', vList[0]);
      System.debug('data : ' + data);
      return ApiResult.ok(200, '쿠폰 개별 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 쿠폰 사용 처리
   * Voucher update
   */
  public ApiResult redeemVoucher(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String couponNo = ValidationUtil.stringValidation(reqData.get('CouponNo'), 'CouponNo', true); // 쿠폰 번호
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', false); // 주문 번호 (선택)
      Date useDate = ValidationUtil.dateValidation(reqData.get('useDate'), 'useDate', false); // 사용 일자
      System.debug(
        LoggingLevel.WARN,
        '[GDV][redeemVoucher] start couponNo=' + couponNo + ', memberNo=' + memberNo + ', orderId=' + orderId + ', useDate=' + String.valueOf(useDate)
      );

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId, Program.Name
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo
        LIMIT 1
      ];
      System.debug(
        LoggingLevel.WARN,
        '[GDV][redeemVoucher] member lookup size=' +
          lpmList.size() +
          (lpmList.isEmpty() ? '' : ', lpmId=' + lpmList[0].Id + ', programId=' + lpmList[0].ProgramId + ', programName=' + lpmList[0].Program.Name)
      );
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원이 존재하지 않습니다. ' + memberNo);
      }

      // 기존 쿠폰 조회
      // List<Voucher> vList = [
      //   SELECT Id, VoucherCode, VoucherDefinitionId, LoyaltyProgramMemberId, ExpirationDate, VoucherDefinition.Name, VoucherDefinition.IsUnlimited__c
      //   FROM Voucher
      //   WHERE VoucherCode = :couponNo AND LoyaltyProgramMemberId = :lpmList[0].Id AND Status = 'Issued'
      //   LIMIT 1
      // ];

      // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
      List<Voucher> vList = new List<Voucher>();

      if (String.isNotBlank(couponNo) && couponNo.contains(';-;')) {
        String couponManNo = couponNo.substringBefore(';-;');
        couponNo = couponNo.substringAfter(';-;');

        vList = [
          SELECT
            Id,
            VoucherCode,
            VoucherDefinitionId,
            LoyaltyProgramMemberId,
            ExpirationDate,
            VoucherDefinition.Name,
            VoucherDefinition.IsUnlimited__c
          FROM Voucher
          WHERE
            LoyaltyProgramMemberId = :lpmList[0].Id
            AND VoucherCode = :couponNo
            AND VoucherDefinition.CouponManNo__c = :couponManNo
            AND Status = 'Issued'
          LIMIT 1
        ];
      } else {
        vList = [
          SELECT
            Id,
            VoucherCode,
            VoucherDefinitionId,
            LoyaltyProgramMemberId,
            ExpirationDate,
            VoucherDefinition.Name,
            VoucherDefinition.IsUnlimited__c
          FROM Voucher
          WHERE VoucherCode = :couponNo AND LoyaltyProgramMemberId = :lpmList[0].Id AND Status = 'Issued'
          LIMIT 1
        ];
      }
      //
      System.debug(
        LoggingLevel.WARN,
        '[GDV][redeemVoucher] voucher lookup size=' +
          vList.size() +
          (vList.isEmpty()
            ? ''
            : ', voucherId=' +
              vList[0].Id +
              ', voucherDefinitionId=' +
              vList[0].VoucherDefinitionId +
              ', voucherDefinitionName=' +
              vList[0].VoucherDefinition.Name +
              ', isUnlimited=' +
              vList[0].VoucherDefinition.IsUnlimited__c +
              ', expirationDate=' +
              String.valueOf(vList[0].ExpirationDate))
      );
      if (vList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 쿠폰입니다. ' + couponNo);
      }

      // 저널 유형 체크
      List<JournalType> jtList = [
        SELECT Id
        FROM JournalType
        WHERE Name = :JOURNAL_TYPE_NAME_REDEMPTION
        LIMIT 1
      ];
      if (jtList.isEmpty()) {
        throw new CustomException(400, '저널 유형이 없습니다.');
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstList = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM AND JournalTypeId = :jtList[0].Id
        LIMIT 1
      ];
      if (jstList.isEmpty()) {
        throw new CustomException(400, '저널 하위 유형이 없습니다.');
      }

      // 기존 트랜잭션 저널 생성 - TransactionJournal insert
      // TransactionJournal tj = new TransactionJournal();
      // tj.ActivityDate = Datetime.now(); // 활성 일자
      // tj.JournalDate = Datetime.now(); // 저널 일자
      // tj.JournalTypeId = jtList[0].Id; // 저널 유형 Id
      // tj.JournalSubTypeId = jstList[0].Id; // 저널 하위 유형 Id
      // tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      // tj.MemberId = lpmList[0].Id; // 로열티 회원 Id
      // tj.VoucherCode = vList[0].VoucherCode; // 쿠폰 번호

      // 26.05.01 GD - 트랜잭션 저널 생성 - TransactionJournal insert
      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = Datetime.now(); // 활성 일자
      tj.JournalDate = Datetime.now(); // 저널 일자
      tj.JournalTypeId = jtList[0].Id; // 저널 유형 Id
      tj.JournalSubTypeId = jstList[0].Id; // 저널 하위 유형 Id
      tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      tj.MemberId = lpmList[0].Id; // 로열티 회원 Id
      tj.VoucherCode = ValidationUtil.stringValidation(reqData.get('CouponNo'), 'CouponNo', true); // 쿠폰 번호
      //

      // 주문 번호 (선택 필드, 유효한 ID인 경우만 설정)
      if (String.isNotBlank(orderId)) {
        try {
          tj.OrderId = (Id) orderId;
        } catch (Exception e) {
          // 유효하지 않은 ID 형식이면 null로 유지
        }
      }

      tj.Status = 'Processed';

      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      // 쿠폰 사용 처리 - Voucher update
      vList[0].Status = 'Redeemed';
      vList[0].UseDate = (useDate != null) ? useDate : Date.today();

      vList[0].UsedTransactionJournalId__c = tj.Id; // 사용 이력

      Database.SaveResult updateResult = Database.update(vList[0]);
      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
      System.debug(
        LoggingLevel.WARN,
        '[GDV][redeemVoucher] voucher updated voucherId=' +
          vList[0].Id +
          ', status=' +
          vList[0].Status +
          ', useDate=' +
          String.valueOf(vList[0].UseDate) +
          ', usedTransactionJournalId=' +
          vList[0].UsedTransactionJournalId__c
      );

      // 무제한 쿠폰이면 사용 직후 동일 쿠폰을 다시 지급한다.
      if (vList[0].VoucherDefinition.IsUnlimited__c == true) {
        System.debug(
          LoggingLevel.WARN,
          '[GDV][redeemVoucher] unlimited voucher detected. reissue start voucherId=' + vList[0].Id + ', journalId=' + tj.Id
        );
        reissueUnlimitedVoucherIfNeeded(vList[0], lpmList[0].Program.Name, tj.Id);
      }
      return ApiResult.ok(200, '쿠폰 사용 완료', null);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 쿠폰 사용 처리 v2
   * TransactionJournal insert
   * Voucher update
   */
  public ApiResult redeemVoucherV2(TransactionJournal tj) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      // 기존 쿠폰 조회
      // List<Voucher> vList = [
      //   SELECT Id, VoucherCode, VoucherDefinitionId, LoyaltyProgramMemberId, ExpirationDate, VoucherDefinition.Name, VoucherDefinition.IsUnlimited__c
      //   FROM Voucher
      //   WHERE VoucherCode = :tj.VoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Issued'
      //   LIMIT 1
      // ];

      // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
      String searchVoucherCode = tj.VoucherCode;
      List<Voucher> vList = new List<Voucher>();

      if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
        String couponManNo = searchVoucherCode.substringBefore(';-;');
        String realVoucherCode = searchVoucherCode.substringAfter(';-;');

        vList = [
          SELECT
            Id,
            VoucherCode,
            VoucherDefinitionId,
            LoyaltyProgramMemberId,
            ExpirationDate,
            VoucherDefinition.Name,
            VoucherDefinition.IsUnlimited__c
          FROM Voucher
          WHERE
            VoucherCode = :realVoucherCode
            AND LoyaltyProgramMemberId = :tj.MemberId
            AND Status = 'Issued'
            AND VoucherDefinition.CouponManNo__c = :couponManNo
          LIMIT 1
        ];
      } else {
        vList = [
          SELECT
            Id,
            VoucherCode,
            VoucherDefinitionId,
            LoyaltyProgramMemberId,
            ExpirationDate,
            VoucherDefinition.Name,
            VoucherDefinition.IsUnlimited__c
          FROM Voucher
          WHERE VoucherCode = :searchVoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Issued'
          LIMIT 1
        ];
      }
      //

      if (vList.isEmpty()) {
        throw new CustomException(400, '존재하지 않거나 이미 만료된 쿠폰입니다. ' + tj.VoucherCode);
      }

      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      // 쿠폰 사용 처리 - Voucher update
      vList[0].Status = 'Redeemed';
      if (tj.JournalDate != null) {
        vList[0].UseDate = tj.JournalDate.date();
      } else {
        vList[0].UseDate = Date.today();
      }
      vList[0].UsedTransactionJournalId__c = tj.Id; // 사용 이력

      Database.SaveResult updateResult = Database.update(vList[0]);
      if (!updateResult.isSuccess()) {
        Database.Error err = updateResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      String programName = [
        SELECT Name
        FROM LoyaltyProgram
        WHERE Id = :tj.LoyaltyProgramId
        LIMIT 1
      ]
      .Name;

      // 무제한 쿠폰이면 사용 직후 동일 쿠폰을 다시 지급한다.
      if (vList[0].VoucherDefinition.IsUnlimited__c == true) {
        reissueUnlimitedVoucherIfNeeded(vList[0], programName, tj.Id);
      }
      data.put('voucher', vList[0]);

      return ApiResult.ok(200, '쿠폰 사용 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 쿠폰 사용 취소
   *
   * @version V1
   * @return ApiResult 쿠폰 사용 취소 결과 값
   * @param tj 거래 이력(TransactionJournal) 레코드 값
   */
  public ApiResult redeemCancelVoucher(TransactionJournal tj) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      // 기존 쿠폰 조회
      // List<Voucher> vList = [
      //   SELECT
      //     Id,
      //     VoucherCode,
      //     ExpirationDate,
      //     VoucherDefinition.Name,
      //     VoucherDefinitionId,
      //     LoyaltyProgramMemberId,
      //     UsedTransactionJournalId__c,
      //     VoucherDefinition.IsUnlimited__c
      //   FROM Voucher
      //   WHERE VoucherCode = :tj.VoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Redeemed'
      //   LIMIT 1
      // ];

      // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
      String searchVoucherCode = tj.VoucherCode;
      List<Voucher> vList = new List<Voucher>();

      if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
        String couponManNo = searchVoucherCode.substringBefore(';-;');
        String realVoucherCode = searchVoucherCode.substringAfter(';-;');

        vList = [
          SELECT
            Id,
            VoucherCode,
            ExpirationDate,
            VoucherDefinition.Name,
            VoucherDefinitionId,
            LoyaltyProgramMemberId,
            UsedTransactionJournalId__c,
            VoucherDefinition.IsUnlimited__c
          FROM Voucher
          WHERE
            VoucherCode = :realVoucherCode
            AND LoyaltyProgramMemberId = :tj.MemberId
            AND Status = 'Redeemed'
            AND VoucherDefinition.CouponManNo__c = :couponManNo
          LIMIT 1
        ];
      } else {
        vList = [
          SELECT
            Id,
            VoucherCode,
            ExpirationDate,
            VoucherDefinition.Name,
            VoucherDefinitionId,
            LoyaltyProgramMemberId,
            UsedTransactionJournalId__c,
            VoucherDefinition.IsUnlimited__c
          FROM Voucher
          WHERE VoucherCode = :searchVoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Redeemed'
          LIMIT 1
        ];
      }
      //
      if (vList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 쿠폰입니다. ' + tj.VoucherCode);
      }

      // 쿠폰 사용 취소 처리 - Voucher update
      // 무제한 쿠폰은 취소 시 만료 여부와 무관하게 다시 발급 상태로 복원한다.
      Id originalRedeemJournalId = vList[0].UsedTransactionJournalId__c;
      Boolean voucherNeedsUpdate = true;
      if (vList[0].VoucherDefinition.IsUnlimited__c == true) {
        vList[0].Status = 'Issued';
        vList[0].UseDate = null;
        vList[0].UsedTransactionJournalId__c = null;
      } else if (vList[0].ExpirationDate != null && vList[0].ExpirationDate >= Date.today()) {
        vList[0].Status = 'Issued';
        vList[0].UseDate = null;
        vList[0].UsedTransactionJournalId__c = null;
      } else {
        vList[0].Status = 'Expired';
        vList[0].UseDate = null;
        vList[0].UsedTransactionJournalId__c = null;
      }

      tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
      tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
      Database.SaveResult insertResult = Database.insert(tj);

      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      if (voucherNeedsUpdate) {
        Database.SaveResult updateResult = Database.update(vList[0]);
        if (!updateResult.isSuccess()) {
          Database.Error err = updateResult.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      // 무제한 쿠폰 사용 시 자동 생성된 재발급 쿠폰은 취소 처리로 정리한다.
      if (vList[0].VoucherDefinition.IsUnlimited__c == true) {
        cancelUnlimitedReissuedVoucherIfNeeded(vList[0], originalRedeemJournalId);
      }

      data.put('Name', vList[0].VoucherDefinition.Name);
      data.put('VoucherCode', vList[0].VoucherCode);
      data.put('ExpirationDate', vList[0].ExpirationDate);

      return ApiResult.ok(200, '쿠폰 사용 취소 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * [판매반품, 교환반품] 사용한 쿠폰 조회
   *
   * 반품등록 화면용(사용 '한' 쿠폰 조회 내역 활용)
   * 부분반품 시 원판매번호 연산 후 조회 필요,
   * 원 판매번호에서 사용 한 쿠폰내역 조회 (호출 시 원 판매번호에서 사용한 쿠폰내역이 선 부분반품으로 환불 내역 있는 지 연산 후 전송)
   */
  public ApiResult getReturnUsedCoupon(String originalOrderId) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      // 기존
      // List<TransactionJournal> tjList = [
      //   SELECT Id, DepositType__c, VoucherCode
      //   FROM TransactionJournal
      //   WHERE Order.SaleNo__c = :originalOrderId AND VoucherCode != NULL
      //   LIMIT 200
      // ];

      // 26.05.01 GD - 회원 ID 추가 조회
      List<TransactionJournal> tjList = [
        SELECT Id, DepositType__c, VoucherCode, MemberId
        FROM TransactionJournal
        WHERE Order.SaleNo__c = :originalOrderId AND VoucherCode != NULL AND MemberId != NULL
        LIMIT 200
      ];

      // Id memberId = null;
      // if (!tjList.isEmpty()) {
      //     memberId = tjList[0].MemberId;
      // }
      //

      Map<VoucherAggKey, Integer> voucherUseCountMap = new Map<VoucherAggKey, Integer>();

      for (TransactionJournal tj : tjList) {
        if (String.isBlank(tj.VoucherCode)) {
          continue;
        }

        VoucherAggKey key = new VoucherAggKey(tj.VoucherCode);

        Integer current = voucherUseCountMap.containsKey(key) ? voucherUseCountMap.get(key) : 0;

        Boolean isRefund = (tj.DepositType__c == '03'); // 03 : 환불

        current += (isRefund ? -1 : 1);

        voucherUseCountMap.put(key, current);
      }

      for (VoucherAggKey key : voucherUseCountMap.keySet()) {
        Integer net = voucherUseCountMap.get(key);

        if (net > 0) {
          Map<String, Object> useCouponMap = new Map<String, Object>();

          // 기존 조회
          // List<Voucher> vList = [
          //   SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode
          //   FROM Voucher
          //   WHERE VoucherCode = :key.voucherCode
          //   LIMIT 1
          // ];

          // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
          String searchVoucherCode = key.voucherCode;
          List<Voucher> vList = new List<Voucher>();

          if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
            String couponManNo = searchVoucherCode.substringBefore(';-;');
            String realVoucherCode = searchVoucherCode.substringAfter(';-;');

            vList = [
              SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode, VoucherDefinition.CouponManNo__c
              FROM Voucher
              WHERE
                VoucherCode = :realVoucherCode
                AND VoucherDefinition.CouponManNo__c = :couponManNo
                AND LoyaltyProgramMemberId = :tjList[0].MemberId
              LIMIT 1
            ];
          } else {
            vList = [
              SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode, VoucherDefinition.CouponManNo__c
              FROM Voucher
              WHERE VoucherCode = :searchVoucherCode AND LoyaltyProgramMemberId = :tjList[0].MemberId
              LIMIT 1
            ];
          }
          //

          if (vList.isEmpty()) {
            throw new CustomException(400, '존재하지 않는 쿠폰 코드 입니다. ' + key.voucherCode);
          }

          useCouponMap.put('VoucherCode', key.voucherCode);
          // 26.05.01 GD - 응답값 추가
          useCouponMap.put('NoManCoupon', vList[0].VoucherDefinition.CouponManNo__c);
          useCouponMap.put('NoCoupon', vList[0].VoucherCode);
          //
          useCouponMap.put('ExpirationDate', vList[0].ExpirationDate);
          useCouponMap.put('Name', vList[0].VoucherDefinition.Name);

          data.put('RedeemedCoupon', useCouponMap);
        }
      }

      return ApiResult.ok(200, '사용한 쿠폰 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 사용한 쿠폰 조회
   */
  public ApiResult getRedeemCoupon(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false); // 판매 번호
      String orderNo = ValidationUtil.stringValidation(reqData.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호

      // 판매번호 있으면 SaleNo__c, 없으면 OrderNo__c 로 조회
      Id orderId;
      Boolean isSaleQuery = false;
      List<TransactionJournal> tjList = new List<TransactionJournal>();

      // 26.05.01 GD - 회원 ID 조회
      Id memberId = null;
      //

      if (!String.isBlank(saleNo)) {
        // fieldPath = 'SaleNo__c';
        List<Order> orderList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
        if (orderList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 판매 번호 입니다. ' + saleNo);
        }
        orderId = orderList[0].Id;
        isSaleQuery = true;

        List<TransactionJournal> saleLinkedTjList = [
          SELECT VoucherCode, OrderId
          FROM TransactionJournal
          WHERE SaleId__c = :orderId AND VoucherCode != NULL
          ORDER BY CreatedDate ASC
          LIMIT 200
        ];
        Set<String> saleVoucherCodeSet = new Set<String>();
        Set<Id> relatedOrderIdSet = new Set<Id>{ orderId };
        for (TransactionJournal saleLinkedTj : saleLinkedTjList) {
          if (String.isNotBlank(saleLinkedTj.VoucherCode)) {
            saleVoucherCodeSet.add(saleLinkedTj.VoucherCode);
          }
          if (saleLinkedTj.OrderId != null) {
            relatedOrderIdSet.add(saleLinkedTj.OrderId);
          }
        }

        if (saleVoucherCodeSet.isEmpty()) {
          return ApiResult.ok(200, '사용한 쿠폰 조회 성공', data);
        }

        // 기존
        // tjList = [
        //   SELECT DepositType__c, VoucherCode, TransactionAmount, DepositNo__c, SaleId__c, JournalType.Name, JournalSubType.Name
        //   FROM TransactionJournal
        //   WHERE VoucherCode IN :saleVoucherCodeSet AND (SaleId__c = :orderId OR OrderId IN :relatedOrderIdSet OR OrderId__c IN :relatedOrderIdSet)
        //   ORDER BY CreatedDate ASC
        //   LIMIT 400
        // ];

        // 26.05.01 GD - 회원 ID 추가 조회
        tjList = [
          SELECT DepositType__c, VoucherCode, TransactionAmount, DepositNo__c, SaleId__c, JournalType.Name, JournalSubType.Name, MemberId
          FROM TransactionJournal
          WHERE VoucherCode IN :saleVoucherCodeSet AND (SaleId__c = :orderId OR OrderId IN :relatedOrderIdSet OR OrderId__c IN :relatedOrderIdSet)
          ORDER BY CreatedDate ASC
          LIMIT 400
        ];

        if (!tjList.isEmpty()) {
          memberId = tjList[0].MemberId;
        }
        //

        // soql =
        //   'SELECT ' +
        //   'DepositType__c, VoucherCode, TransactionAmount ' +
        //   'FROM TransactionJournal ' +
        //   'WHERE Order.' +
        //   fieldPath +
        //   ' = :keyValue' +
        //   ' AND VoucherCode != NULL ' +
        //   ' ORDER BY CreatedDate ASC ' +
        //   ' LIMIT 200';
      } else if (!String.isBlank(orderNo)) {
        // fieldPath = 'OrderNo__c';
        List<Order> orderList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
        if (orderList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 주문 번호 입니다. ' + orderNo);
        }
        orderId = orderList[0].Id;

        // 기존
        // tjList = [
        //   SELECT DepositType__c, VoucherCode, TransactionAmount, DepositNo__c, SaleId__c, JournalType.Name, JournalSubType.Name
        //   FROM TransactionJournal
        //   WHERE (OrderId__c = :orderId OR OrderId = :orderId) AND VoucherCode != NULL
        //   ORDER BY CreatedDate ASC
        //   LIMIT 200
        // ];

        // 26.05.01 GD - 회원 ID 추가 조회
        tjList = [
          SELECT DepositType__c, VoucherCode, TransactionAmount, DepositNo__c, SaleId__c, JournalType.Name, JournalSubType.Name, MemberId
          FROM TransactionJournal
          WHERE (OrderId__c = :orderId OR OrderId = :orderId) AND VoucherCode != NULL
          ORDER BY CreatedDate ASC
          LIMIT 200
        ];

        if (!tjList.isEmpty()) {
          memberId = tjList[0].MemberId;
        }
        //

        // soql =
        //   'SELECT ' +
        //   'DepositType__c, VoucherCode, TransactionAmount ' +
        //   'FROM TransactionJournal ' +
        //   'WHERE Order.' +
        //   fieldPath +
        //   ' = :keyValue' +
        //   ' AND VoucherCode != NULL ' +
        //   ' ORDER BY CreatedDate ASC ' +
        //   ' LIMIT 200';
      } else {
        throw new CustomException(400, 'SaleNo__c 또는 OrderNo__c 값이 필요합니다.');
      }

      // if (
      //   !([
      //     SELECT COUNT()
      //     FROM Order
      //     WHERE OrderNo__c = :keyValue OR SaleNo__c = :keyValue
      //     LIMIT 1
      //   ] > 0)
      // ) {
      //   throw new CustomException(400, '존재하지 않는 주문/판매 번호 입니다. ' + keyValue);
      // }

      // String soql =
      //   'SELECT ' +
      //   'DepositType__c, VoucherCode, TransactionAmount ' +
      //   'FROM TransactionJournal ' +
      //   'WHERE Order.' +
      //   fieldPath +
      //   ' = :keyValue' +
      //   ' AND VoucherCode != NULL ' +
      //   ' ORDER BY CreatedDate ASC ' +
      //   ' LIMIT 200';

      // List<TransactionJournal> tjList = (List<TransactionJournal>) Database.query(soql);

      Map<String, Integer> voucherUseCountMap = new Map<String, Integer>();
      Map<String, Decimal> voucherUsedAmountMap = new Map<String, Decimal>();
      Map<String, String> voucherDepositNoMap = new Map<String, String>();
      Map<String, Boolean> voucherDepositPreferredMap = new Map<String, Boolean>();
      Set<String> voucherCodeSet = new Set<String>();

      for (TransactionJournal tj : tjList) {
        if (String.isBlank(tj.VoucherCode)) {
          continue;
        }

        String voucherCode = tj.VoucherCode;
        VoucherAggKey key = new VoucherAggKey(voucherCode);

        Integer current = voucherUseCountMap.containsKey(voucherCode) ? voucherUseCountMap.get(voucherCode) : 0;

        Boolean isRefund = (tj.DepositType__c == '03'); // 03 : 환불

        isRefund =
          isRefund ||
          (tj.JournalSubType != null &&
          tj.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL) ||
          (tj.JournalType != null &&
          tj.JournalType.Name == JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL);

        current += (isRefund ? -1 : 1);

        if (!isRefund && tj.TransactionAmount != null) {
          voucherUsedAmountMap.put(voucherCode, tj.TransactionAmount);
        }
        if (!isRefund && !String.isBlank(tj.DepositNo__c)) {
          Boolean preferCurrentDeposit = !voucherDepositNoMap.containsKey(voucherCode);
          if (isSaleQuery && tj.SaleId__c == orderId && voucherDepositPreferredMap.get(voucherCode) != true) {
            preferCurrentDeposit = true;
          }
          if (preferCurrentDeposit) {
            voucherDepositNoMap.put(voucherCode, tj.DepositNo__c);
            voucherDepositPreferredMap.put(voucherCode, isSaleQuery && tj.SaleId__c == orderId);
          }
        }

        voucherUseCountMap.put(voucherCode, current);
        voucherCodeSet.add(voucherCode);
      }

      if (!voucherCodeSet.isEmpty()) {
        // 기존
        // Map<String, Voucher> voucherByCode = new Map<String, Voucher>();
        // for (Voucher voucherRec : [
        //   SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode, DiscountPercent, FaceValue, UsedTransactionJournalId__r.DepositNo__c
        //   FROM Voucher
        //   WHERE VoucherCode IN :voucherCodeSet
        // ]) {
        //   voucherByCode.put(voucherRec.VoucherCode, voucherRec);
        // }

        // 26.05.01 GD - 신규 로직
        Set<String> realVoucherCodeSet = new Set<String>();
        for (String vc : voucherCodeSet) {
          if (String.isNotBlank(vc) && vc.contains(';-;')) {
            realVoucherCodeSet.add(vc.substringAfter(';-;'));
          } else {
            realVoucherCodeSet.add(vc);
          }
        }

        Map<String, Voucher> voucherByCode = new Map<String, Voucher>();

        for (Voucher voucherRec : [
          SELECT
            Id,
            VoucherDefinition.Name,
            ExpirationDate,
            VoucherCode,
            DiscountPercent,
            FaceValue,
            UsedTransactionJournalId__r.DepositNo__c,
            VoucherDefinition.CouponManNo__c
          FROM Voucher
          WHERE VoucherCode IN :realVoucherCodeSet AND LoyaltyProgramMemberId = :memberId
        ]) {
          String couponManNo = (voucherRec.VoucherDefinition != null &&
            voucherRec.VoucherDefinition.CouponManNo__c != null)
            ? voucherRec.VoucherDefinition.CouponManNo__c
            : '';
          String combinedCode = String.isBlank(couponManNo) ? voucherRec.VoucherCode : couponManNo + ';-;' + voucherRec.VoucherCode;

          if (voucherCodeSet.contains(combinedCode)) {
            voucherByCode.put(combinedCode, voucherRec);
          }
          // (안전장치) 구분자가 없는 구버전 단일 쿠폰 번호를 찾고 있었던 거라면, 단일 코드로 일치할 때 담아줍니다.
          else if (voucherCodeSet.contains(voucherRec.VoucherCode)) {
            voucherByCode.put(voucherRec.VoucherCode, voucherRec);
          }
        }
        //

        for (String voucherCode : voucherUseCountMap.keySet()) {
          Integer net = voucherUseCountMap.get(voucherCode);
          if (net == null || net <= 0) {
            continue;
          }

          Voucher voucherRec = voucherByCode.get(voucherCode);
          if (voucherRec == null) {
            throw new CustomException(400, '존재하지 않는 쿠폰번호 입니다. ' + voucherCode);
          }

          Map<String, Object> useCouponMap = new Map<String, Object>();
          useCouponMap.put('VoucherCode', voucherCode);
          // 26.05.01 GD - 응답값 추가
          useCouponMap.put('NoManCoupon', voucherRec.VoucherDefinition.CouponManNo__c);
          useCouponMap.put('NoCoupon', voucherRec.VoucherCode);
          //
          useCouponMap.put('ExpirationDate', voucherRec.ExpirationDate);
          useCouponMap.put('Name', voucherRec.VoucherDefinition.Name);

          Decimal redeemAmount = voucherUsedAmountMap.containsKey(voucherCode) ? voucherUsedAmountMap.get(voucherCode) : null;
          Boolean isRateCoupon = voucherRec.DiscountPercent != null && voucherRec.DiscountPercent > 0;
          // 26.05.03 CS - 정액/정률 구분 없이 실제 사용한 금액(TransactionAmount) 을 FaceValue 로 응답.
          //               redeemAmount 가 null 인 이론상 케이스만 fallback 으로 쿠폰 정의 FaceValue 사용.
          Decimal faceValueToSend;
          if (redeemAmount != null) {
            faceValueToSend = redeemAmount;
          } else {
            faceValueToSend = voucherRec.FaceValue == null ? 0 : voucherRec.FaceValue;
          }

          useCouponMap.put('DiscountPercent', voucherRec.DiscountPercent == null ? 0 : voucherRec.DiscountPercent);
          useCouponMap.put('FaceValue', faceValueToSend);

          String depositNo = voucherDepositNoMap.get(voucherCode);
          if (!String.isBlank(depositNo)) {
            useCouponMap.put('NO_DEPOSIT', depositNo.replaceAll('-\\d+$', ''));
          }

          data.put('RedeemedCoupon', useCouponMap);
        }

        return ApiResult.ok(200, '사용한 쿠폰 조회 성공', data);
      }

      for (String voucherCode : new List<String>()) {
        Integer net = voucherUseCountMap.get(voucherCode);

        if (net > 0) {
          VoucherAggKey key = new VoucherAggKey(voucherCode);
          Map<String, Object> useCouponMap = new Map<String, Object>();
          List<Voucher> vList = [
            SELECT Id, VoucherDefinition.Name, ExpirationDate, VoucherCode, DiscountPercent, FaceValue, UsedTransactionJournalId__r.DepositNo__c
            FROM Voucher
            WHERE VoucherCode = :voucherCode
            LIMIT 1
          ];

          if (vList.isEmpty()) {
            throw new CustomException(400, '존재하지 않는 쿠폰 코드 입니다. ' + key.voucherCode);
          }

          useCouponMap.put('VoucherCode', voucherCode);
          useCouponMap.put('ExpirationDate', vList[0].ExpirationDate);
          useCouponMap.put('Name', vList[0].VoucherDefinition.Name);

          // useCouponMap.put('DiscountPercent', vList[0].DiscountPercent == null ? 0 : vList[0].DiscountPercent);
          // useCouponMap.put('FaceValue', vList[0].FaceValue == null ? 0 : vList[0].FaceValue);

          Decimal redeemAmount = voucherUsedAmountMap.containsKey(voucherCode) ? voucherUsedAmountMap.get(voucherCode) : null;
          Boolean isRateCoupon = vList[0].DiscountPercent != null && vList[0].DiscountPercent > 0;

          Decimal faceValueToSend = vList[0].FaceValue == null ? 0 : vList[0].FaceValue;
          if (isRateCoupon && redeemAmount != null) {
            faceValueToSend = redeemAmount;
          }

          useCouponMap.put('DiscountPercent', vList[0].DiscountPercent == null ? 0 : vList[0].DiscountPercent);
          useCouponMap.put('FaceValue', faceValueToSend);

          // String depositNo = vList[0].UsedTransactionJournalId__r.DepositNo__c;
          String depositNo = vList[0].UsedTransactionJournalId__r == null ? null : vList[0].UsedTransactionJournalId__r.DepositNo__c;
          if (!String.isBlank(depositNo)) {
            depositNo = depositNo.replaceAll('-\\d+$', '');
            useCouponMap.put('NO_DEPOSIT', depositNo);
          }

          data.put('RedeemedCoupon', useCouponMap);
        }
      }

      return ApiResult.ok(200, '사용한 쿠폰 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 사용 가능한 쿠폰 조회
   * 쿠폰 적용 도움창 조회
   *
   * @version V1
   * @return ApiResult 사용 가능한 쿠폰 조회 결과 값
   * @param reqData 쿠폰 사용 조건 요청 값
   */
  public ApiResult getAvailableCouponList(Map<String, Object> reqData) {
    Map<String, Object> resData = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false); // 매장 코드
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액
      String orderStatus = ValidationUtil.stringValidation(reqData.get('OrderStatus__c'), 'OrderStatus__c', false); // 주문 상태 코드
      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', false); // 주문 구분 코드
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false); // 프로모션 번호

      // 회원 조회
      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.Grade__c
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원 번호입니다. ' + memberNo);
      }

      List<Object> orderItem = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', false); // 주문 상세 리스트

      Integer totalProductQuantity = 0; // 총 상품 수
      // Set<String> productCodeSet = new Set<String>(); // 상품 코드 Set
      Set<String> productCategorySet = new Set<String>(); // 제품 분류 코드 Set

      Set<String> usedCouponNoSet = extractCouponNosFromRawTransactionJournals(
        ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', false)
      );
      Set<String> productCodeSet = new Set<String>();
      Decimal requestDiscountRate;

      // 26.05.02 CS - 프로모션 쿠폰 사용 가능 여부 게이트
      Promotion targetPromotion = null;
      if (!String.isBlank(promotionNo)) {
        List<Promotion> promotionLookup = [
          SELECT Id, IsCouponAllowed__c, IsRateCouponAllowed__c, IsFixedAmountCouponAllowed__c, IsSpecificCouponAllowed__c
          FROM Promotion
          WHERE PromotionNo__c = :promotionNo
          LIMIT 1
        ];
        if (!promotionLookup.isEmpty()) {
          targetPromotion = promotionLookup[0];
        }
      }
      Boolean applySpecificCouponLimit = targetPromotion != null && targetPromotion.IsSpecificCouponAllowed__c == true;
      String promotionLimitValue = (!String.isBlank(promotionNo) && applySpecificCouponLimit) ? String.valueOf(targetPromotion.Id) : null;

      if (orderItem != null) {
        for (Object v : orderItem) {
          Map<String, Object> item = ValidationUtil.mapStrObjValidation(v, 'OrderItem', false);
          if (item == null) {
            continue;
          }

          String productCode = ValidationUtil.stringValidationEx(item.get('ProductCode'), 'ProductCode', true, false); // 상품 코드
          productCodeSet.add(productCode);

          Integer quantity = ValidationUtil.integerValidation(item.get('Quantity'), 'Quantity', true); // 제품 개수
          if (quantity != null) {
            totalProductQuantity += quantity; // 총 제품 개수
          }
        }
      }

      // 회원 보유 Voucher 조회
      requestDiscountRate = requestDiscountRate == null ? extractMaxDiscountRateFromRawOrderItems(orderItem) : requestDiscountRate;
      if (requestDiscountRate == null) {
        requestDiscountRate = ValidationUtil.decimalValidation(reqData.get('DiscountRate'), 'DiscountRate', false);
      }
      if (!productCodeSet.isEmpty()) {
        productCategorySet.addAll(resolveProductCategoryCodes(productCodeSet));
      }

      List<Voucher> voucherList = [
        SELECT
          Id,
          VoucherDefinitionId,
          VoucherDefinition.Name,
          FaceValue,
          Reason,
          EffectiveDate,
          UseDate,
          ExpirationDate,
          CreatedDate,
          VoucherDefinition.brand__c,
          VoucherDefinition.CouponManNo__c,
          VoucherCode,
          VoucherDefinition.CouponTypeCode__c,
          Status,
          VoucherDefinition.ExpirationType,
          VoucherDefinition.ExpirationPeriod,
          DiscountPercent,
          VoucherDefinition.ResponsibleDepartment__c,
          VoucherDefinition.Description,
          VoucherDefinition.ResponsiblePerson__c,
          CreatedBy.Name,
          VoucherDefinition.InsertId__c,
          InsertId__c,
          // 추가 GD 26.04.29
          VoucherDefinition.EffectiveDate,
          VoucherDefinition.Type,
          VoucherDefinition.ExpirationPeriodUnit
        FROM Voucher
        WHERE LoyaltyProgramMember.Contact.MemberNo__c = :memberNo AND Status = 'Issued' AND ExpirationDate >= :Date.today()
        LIMIT 200
      ];
      System.debug('voucherList.size () : ' + voucherList.size());
      if (voucherList.isEmpty()) {
        throw new CustomException(400, '보유 중인 쿠폰이 없습니다.');
      }

      // 쿠폰 정의 Id 모아두기
      Set<Id> vdIdSet = new Set<Id>();
      for (Voucher v : voucherList) {
        if (v.VoucherDefinitionId != null) {
          vdIdSet.add(v.VoucherDefinitionId);
        }
      }
      if (vdIdSet.isEmpty()) {
        throw new CustomException(400, '보유 쿠폰 정의(VoucherDefinition)가 없습니다.');
      }

      String storeType;
      if (storeCode != null) {
        // 매장(계정 Account) 조회
        List<Account> storeList = [
          SELECT Id, StoreType__c
          FROM Account
          WHERE StoreCode__c = :storeCode
          LIMIT 1
        ];
        if (storeList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다. ' + storeCode);
        }
        storeType = storeList[0].StoreType__c;
      }

      // 쿠폰 한도(VoucherLimit__c) 조회
      List<VoucherLimit__c> limitList = [
        SELECT Id, VoucherDefinitionId__c, Type__c, Value__c, IsActive__c, ProductCode__c, ComparisonOperator__c
        FROM VoucherLimit__c
        WHERE IsActive__c = TRUE AND VoucherDefinitionId__c IN :vdIdSet AND Type__c IN :AVAILABLE_COUPON_LIMIT_TYPES
        LIMIT 2000
      ];

      // 26.05.02 CS - 프로모션이 허용하는 쿠폰 종류/특정 쿠폰 집합 산출
      Set<String> allowedVoucherTypeSet = new Set<String>();
      Set<Id> allowedSpecificVdIdSet = new Set<Id>();
      if (targetPromotion != null) {
        if (targetPromotion.IsCouponAllowed__c == true) {
          allowedVoucherTypeSet.add('DiscountPercentage');
          allowedVoucherTypeSet.add('FixedValue');
          allowedVoucherTypeSet.add('ProductOrService');
        } else {
          if (targetPromotion.IsRateCouponAllowed__c == true) {
            allowedVoucherTypeSet.add('DiscountPercentage');
          }
          if (targetPromotion.IsFixedAmountCouponAllowed__c == true) {
            allowedVoucherTypeSet.add('FixedValue');
          }
        }
        if (targetPromotion.IsSpecificCouponAllowed__c == true) {
          for (VoucherLimit__c vl : [
            SELECT VoucherDefinitionId__c
            FROM VoucherLimit__c
            WHERE PromotionId__c = :targetPromotion.Id AND IsActive__c = TRUE
            LIMIT 1000
          ]) {
            if (vl.VoucherDefinitionId__c != null) {
              allowedSpecificVdIdSet.add(vl.VoucherDefinitionId__c);
            }
          }
        }
      }

      List<VoucherResDTO> voucherResDtoList = new List<VoucherResDTO>();

      // 쿠폰 한도 존재 X
      if (limitList.isEmpty()) {
        for (Voucher v : voucherList) {
          // 기존
          // if (!usedCouponNoSet.isEmpty() && usedCouponNoSet.contains(v.VoucherCode)) {
          //   continue;
          // }
          // voucherResDtoList.add(new VoucherResDTO(v));

          // 26.05.01 GD - 쿠폰 코드 병합
          String couponManNo = (v.VoucherDefinition != null && v.VoucherDefinition.CouponManNo__c != null) ? v.VoucherDefinition.CouponManNo__c : '';
          String combinedCode = String.isBlank(couponManNo) ? v.VoucherCode : couponManNo + ';-;' + v.VoucherCode;
          if (!usedCouponNoSet.isEmpty() && (usedCouponNoSet.contains(combinedCode))) {
            continue;
          }

          // 26.05.02 CS - 프로모션 쿠폰 사용 가능 여부 게이트
          if (targetPromotion != null) {
            String vdType = (v.VoucherDefinition != null) ? v.VoucherDefinition.Type : null;
            Boolean typeAllowed = !String.isBlank(vdType) && allowedVoucherTypeSet.contains(vdType);
            Boolean specificAllowed = allowedSpecificVdIdSet.contains(v.VoucherDefinitionId);
            if (!typeAllowed && !specificAllowed) {
              continue;
            }
          }

          voucherResDtoList.add(new VoucherResDTO(v));
          //
        }
      }
      // 쿠폰 한도 존재 O
      else {
        System.debug('쿠폰 한도 존재합니다.');
        System.debug('limitList.size() : ' + limitList.size());

        // 쿠폰 정의 ID를 Key로 설정 후 Value에 해당하는 쿠폰 한도 설정
        Map<Id, VoucherRule> ruleMap = buildRuleMap(limitList);

        // 3) 규칙 평가
        List<Voucher> available = new List<Voucher>();

        for (Voucher v : voucherList) {
          // 기존
          // if (!usedCouponNoSet.isEmpty() && usedCouponNoSet.contains(v.VoucherCode)) {
          //   continue;
          // }

          // 26.05.01 GD - 쿠폰 코드 병합
          String couponManNo = (v.VoucherDefinition != null && v.VoucherDefinition.CouponManNo__c != null) ? v.VoucherDefinition.CouponManNo__c : '';
          String combinedCode = String.isBlank(couponManNo) ? v.VoucherCode : couponManNo + ';-;' + v.VoucherCode;
          if (!usedCouponNoSet.isEmpty() && (usedCouponNoSet.contains(combinedCode))) {
            continue;
          }
          //

          // 26.05.02 CS - 프로모션 쿠폰 사용 가능 여부 게이트
          if (targetPromotion != null) {
            String vdType = (v.VoucherDefinition != null) ? v.VoucherDefinition.Type : null;
            Boolean typeAllowed = !String.isBlank(vdType) && allowedVoucherTypeSet.contains(vdType);
            Boolean specificAllowed = allowedSpecificVdIdSet.contains(v.VoucherDefinitionId);
            if (!typeAllowed && !specificAllowed) {
              continue;
            }
          }

          VoucherRule r = ruleMap.get(v.VoucherDefinitionId);
          System.debug('r : ' + r);

          Boolean ok = (r == null)
            ? true
            : r.isEligible(
                productCodeSet,
                productCategorySet,
                storeCode,
                storeType,
                lpmList[0].Contact.Grade__c,
                type,
                promotionLimitValue,
                totalProductQuantity,
                actualPaymentAmount,
                requestDiscountRate
              );
          System.debug('productCodeSet : ' + productCodeSet);
          System.debug('productCategorySet : ' + productCategorySet);
          System.debug('storeCode : ' + storeCode);
          System.debug('storeType : ' + storeType);
          System.debug('lpmList[0].Contact.Grade__c : ' + lpmList[0].Contact.Grade__c);
          System.debug('type : ' + type);
          System.debug('promotionLimitValue : ' + promotionLimitValue);
          System.debug('totalProductQuantity : ' + totalProductQuantity);
          System.debug('actualPaymentAmount : ' + actualPaymentAmount);
          System.debug('requestDiscountRate : ' + requestDiscountRate);

          System.debug('ok : ' + ok);

          if (ok) {
            available.add(v);
          }
        }

        for (Voucher v : available) {
          voucherResDtoList.add(new VoucherResDTO(v));
        }
      }

      resData.put('voucherList', voucherResDtoList);
      return ApiResult.ok(200, '사용 가능한 쿠폰 조회 성공', resData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 보류
   * 사용 가능한 쿠폰 조회
   *
   * @version V2
   * @return ApiResult 사용 가능한 쿠폰 조회 결과 값
   * @param req 사용 가능한 쿠폰 조회 요청 값
   */
  public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      String memberNo = req.memberNo();
      String noManCoupon = req.noManCoupon(); // NO_MAN_COUPON
      String noCoupon = req.noCoupon(); // NO_COUPON
      Date dtStrExp = req.dtStrExp(); // 발급 시작(또는 유효 시작)
      Date dtEndExp = req.dtEndExp(); // 발급 종료(또는 유효 종료)

      String soql =
        'SELECT ' +
        '  Id, VoucherDefinitionId, VoucherDefinition.Name, FaceValue, Reason, InsertId__c, ' +
        '  EffectiveDate, UseDate, ExpirationDate, CreatedDate, ' +
        '  VoucherDefinition.brand__c, VoucherDefinition.CouponManNo__c, ' +
        '  VoucherCode, VoucherDefinition.CouponTypeCode__c, Status, ' +
        '  VoucherDefinition.ExpirationType, VoucherDefinition.ExpirationPeriod, ' +
        '  DiscountPercent, VoucherDefinition.ResponsibleDepartment__c, ' +
        '  CreatedBy.Name, VoucherDefinition.InsertId__c, ' +
        // 추가 GD - 26.04.29
        '  VoucherDefinition.EffectiveDate, VoucherDefinition.Type, VoucherDefinition.ExpirationPeriodUnit, ' + // 신규 3개 필드 추가
        '  VoucherDefinition.Description, VoucherDefinition.ResponsiblePerson__c ' + // 누락되었던 필드 추가
        'FROM Voucher ' +
        'WHERE LoyaltyProgramMember.Contact.MemberNo__c = :memberNo ' +
        'AND Status = \'Issued\' ';

      if (!String.isBlank(noManCoupon)) {
        soql += 'AND VoucherDefinition.CouponManNo__c = :noManCoupon ';
      }

      if (!String.isBlank(noCoupon)) {
        soql += 'AND VoucherCode = :noCoupon ';
      }

      if (dtStrExp != null) {
        soql += 'AND EffectiveDate >= :dtStrExp ';
      }
      if (dtEndExp != null) {
        soql += 'AND ExpirationDate <= :dtEndExp ';
      }

      soql += 'LIMIT 200';

      List<Voucher> voucherList = Database.query(soql);

      if (voucherList.isEmpty()) {
        throw new CustomException(400, '보유 중인 쿠폰이 없습니다.');
      }

      List<VoucherResDTO> voucherResDtoList = new List<VoucherResDTO>();

      for (Voucher v : voucherList) {
        voucherResDtoList.add(new VoucherResDTO(v));
      }

      data.put('voucherList', voucherResDtoList);
      return ApiResult.ok(200, '사용 가능한 쿠폰 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /** VoucherDefinitionId 기준으로 규칙을 모아두는 객체 */
  private class VoucherRule {
    // 품목
    Set<String> includeProducts = new Set<String>();

    // 매장
    Set<String> includeStores = new Set<String>();
    Set<String> includeStoreTypes = new Set<String>(); // 매장 구분

    // 등급
    Set<String> includeGrades = new Set<String>();

    // 품목 카테고리
    Set<String> includeProductCategories = new Set<String>();

    // 주문 타입

    // 프로모션
    Set<String> includeOrderTypes = new Set<String>();
    Set<String> includePromotions = new Set<String>();

    // 기타
    Decimal maxDiscountRate; // 예: 10(%) 또는 0.1(비율) - 운영정의에 맞춰 해석
    Integer minTotalQuantity; // 최소 총 판매개수
    Decimal minSalesAmount; // 최소 판매금액

    String discountRateOperator;
    String totalQuantityOperator;
    String salesAmountOperator;

    Boolean isEligible(
      Set<String> productCodes, // 주문 상품코드 Set
      Set<String> productCategoryCodes, // 주문 품목분류(카테고리) 코드 Set (없으면 null/empty 가능)
      String storeCode, // 매장 코드
      String storeType, // 매장 구분 코드
      String gradeCode, // 회원 등급 코드
      String orderType, // 주문 구분 코드
      String promotionNo, // 프로모션 번호 (없으면 null)
      Integer totalQty, // 총 판매 개수
      Decimal amount,
      Decimal discountRate
    ) {
      // 실제 결제/판매 금액
      // ,Decimal discountRate
      // 총 판매 개수
      // Decimal amount, // 실제 결제/판매 금액
      // Decimal discountRate
      // 적용 예정 판매할인율 (없으면 null)
      // -----------------------
      // 0) Null-safe normalize
      // -----------------------
      if (productCodes == null) {
        productCodes = new Set<String>();
      }
      if (productCategoryCodes == null) {
        productCategoryCodes = new Set<String>();
      }
      if (totalQty == null) {
        totalQty = 0;
      }
      // -----------------------
      // 1) Exclude rules (최우선)
      // -----------------------
      // 상품 제외

      // 품목분류 제외

      // 매장 제외

      // 프로모션 제외

      // -----------------------
      // 2) Include rules (있으면 반드시 만족)
      // -----------------------
      // 상품 포함
      if (!includeProducts.isEmpty()) {
        if (!intersects(productCodes, includeProducts)) {
          return false;
        }
      }

      // 매장 포함
      if (!includeStores.isEmpty() && includeStoreTypes.isEmpty()) {
        if (String.isBlank(storeCode) || !includeStores.contains(storeCode)) {
          return false;
        }
      }

      // 매장 구분 포함
      if (!includeStoreTypes.isEmpty() && includeStores.isEmpty()) {
        if (String.isBlank(storeType) || !includeStoreTypes.contains(storeType)) {
          return false;
        }
      }

      // 회원 등급 포함
      if (!includeStores.isEmpty() && !includeStoreTypes.isEmpty()) {
        Boolean matchesStore = !String.isBlank(storeCode) && includeStores.contains(storeCode);
        Boolean matchesStoreType = !String.isBlank(storeType) && includeStoreTypes.contains(storeType);
        if (!matchesStore && !matchesStoreType) {
          return false;
        }
      }

      if (!includeGrades.isEmpty()) {
        if (String.isBlank(gradeCode) || !includeGrades.contains(gradeCode)) {
          return false;
        }
      }

      // 품목분류 포함
      if (!includeProductCategories.isEmpty()) {
        if (!intersects(productCategoryCodes, includeProductCategories)) {
          return false;
        }
      }

      // 주문 구분 포함
      /* 기존 로직
      if (!includeOrderTypes.isEmpty()) {
        if (String.isBlank(orderType) || !includeOrderTypes.contains(orderType)) {
          return false;
        }
      }
      */
      // 주문 구분 포함 — orderType 미입력 시 룰 무시
      // 신규 로직 (26.05.11 CS)
      if (!includeOrderTypes.isEmpty() && String.isNotBlank(orderType)) {
        if (!includeOrderTypes.contains(orderType)) {
          return false;
        }
      }

      // 프로모션 포함
      // -----------------------
      // 3) Numeric constraints
      // -----------------------
      // 최소 판매 개수
      // if (minTotalQuantity != null) {
      //   if (totalQty < minTotalQuantity) {
      //     return false;
      //   }
      // }

      // // 최소 판매 금액
      // if (minSalesAmount != null) {
      //   if (amount == null || amount < minSalesAmount) {
      //     return false;
      //   }
      // }

      // 적용가능 판매할인율(최대 할인율 제한으로 해석)
      // - discountRate가 null이면 판단 불가 -> 통과 처리(정책). 필요하면 false로 바꿔도 됨.
      // if (maxDiscountRate != null && discountRate != null) {
      //   Decimal normalized = normalizeDiscountRate(discountRate); // 10 또는 0.1 둘 다 대응
      //   Decimal maxNorm = normalizeDiscountRate(maxDiscountRate);

      //   if (normalized > maxNorm) {
      //     return false;
      //   }
      // }

      if (!includePromotions.isEmpty() && !String.isBlank(promotionNo) && !includePromotions.contains(promotionNo)) {
        return false;
      }

      if (
        minTotalQuantity != null &&
        !matchesNumberConstraint(Decimal.valueOf(totalQty), Decimal.valueOf(minTotalQuantity), totalQuantityOperator, true)
      ) {
        return false;
      }

      if (minSalesAmount != null && !matchesNumberConstraint(amount, minSalesAmount, salesAmountOperator, true)) {
        return false;
      }

      if (maxDiscountRate != null) {
        if (discountRate == null) {
          return false;
        }

        Decimal normalized = normalizeDiscountRate(discountRate);
        Decimal maxNorm = normalizeDiscountRate(maxDiscountRate);
        if (!matchesNumberConstraint(normalized, maxNorm, discountRateOperator, false)) {
          return false;
        }
      }

      return true;
    }
  }

  /** VoucherLimit__c 리스트를 VoucherDefinitionId__c 기준으로 룰로 변환 */
  private static Map<Id, VoucherRule> buildRuleMap(List<VoucherLimit__c> limitList) {
    Map<Id, VoucherRule> res = new Map<Id, VoucherRule>();
    if (limitList == null || limitList.isEmpty()) {
      return res;
    }

    for (VoucherLimit__c vl : limitList) {
      if (vl.VoucherDefinitionId__c == null || !vl.IsActive__c) {
        continue;
      }

      VoucherRule vr = res.get(vl.VoucherDefinitionId__c);
      if (vr == null) {
        vr = new VoucherRule();
        res.put(vl.VoucherDefinitionId__c, vr);
      }

      String type = vl.Type__c; // 유형
      String value = vl.Value__c; // 값
      String productCode = vl.ProductCode__c; // 품목 코드

      // 값이 없는 레코드는 스킵 (단, 숫자 타입은 아래에서 따로 처리)
      // String productCode = vl.ProductCode__c;
      String comparisonOperator = vl.ComparisonOperator__c;

      if (String.isBlank(type) || !AVAILABLE_COUPON_LIMIT_TYPES.contains(type)) {
        continue;
      }

      // 1) 품목 Include/Exclude
      if (type == 'ProductIncludeList') {
        addValues(vr.includeProducts, productCode);
        // 2) 매장 Include/Exclude
      } else if (type == 'StoreIncludeList') {
        addValues(vr.includeStores, value);
        // 3) 매장 유형 Include
      } else if (type == 'StoreTypeIncludeList') {
        addValues(vr.includeStoreTypes, value);
      }
      // 4) 등급 Include
      else if (type == 'GradeIncludeList') {
        addValues(vr.includeGrades, value);
      }
      // 5) 품목 카테고리 Include/Exclude
      else if (type == 'ProductCategoryIncludeList') {
        addValues(vr.includeProductCategories, value);
        // 6) 주문 유형 Include
      } else if (type == 'PromotionIncludeList') {
        addValues(vr.includePromotions, value);
      } else if (type == 'OrderTypeIncludeList') {
        addValues(vr.includeOrderTypes, value);
      }
      // 7) 할인율
      // else if (type == 'DiscountRate') {
      else if (type == 'DiscountRate') {
        Decimal d = parseDecimalSafe(value);
        if (d != null) {
          vr.maxDiscountRate = d;
          vr.discountRateOperator = comparisonOperator;
        }
      }
      // 판매 개수
      else if (type == 'TotalQuantity') {
        Integer i = parseIntegerSafe(value);
        if (i != null) {
          vr.minTotalQuantity = i;
          vr.totalQuantityOperator = comparisonOperator;
        }
      }
      // 판매 금액
      else if (type == 'SalesAmount') {
        Decimal d = parseDecimalSafe(value);
        if (d != null) {
          vr.minSalesAmount = d;
          vr.salesAmountOperator = comparisonOperator;
        }
      }
    }

    return res;
  }

  // "A,B;C\nD" 같은 값도 Set에 안전하게 넣기
  private static void addValues(Set<String> target, String raw) {
    if (target == null || String.isBlank(raw)) {
      return;
    }

    // 콤마/세미콜론/개행을 모두 구분자로 처리
    String normalized = raw.replace('\n', ',').replace(';', ',');
    for (String token : normalized.split(',')) {
      String val = token == null ? null : token.trim();
      if (!String.isBlank(val)) {
        target.add(val);
      }
    }
  }

  // String -> Decimal 형 변환
  private static Decimal parseDecimalSafe(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    try {
      return Decimal.valueOf(raw.trim());
    } catch (Exception e) {
      return null;
    }
  }

  // String -> Integer 형 변환
  private static Integer parseIntegerSafe(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    try {
      return Integer.valueOf(raw.trim());
    } catch (Exception e) {
      return null;
    }
  }

  // a, b 포함 여부 확인
  private static Boolean intersects(Set<String> a, Set<String> b) {
    if (a == null || b == null || a.isEmpty() || b.isEmpty()) {
      return false;
    }

    for (String x : a) {
      if (b.contains(x)) {
        return true;
      }
    }

    return false;
  }

  // 예시) 1 => 0.01
  private static Decimal normalizeDiscountRate(Decimal rate) {
    if (rate == null) {
      return null;
    }

    Decimal r = rate;
    if (r > 1) {
      r = r / 100;
    }

    return r;
  }

  // Helper methods for available coupon filtering
  private static Decimal extractMaxDiscountRateFromRawOrderItems(List<Object> orderItems) {
    Decimal result;
    if (orderItems == null) {
      return null;
    }

    for (Object itemObj : orderItems) {
      Map<String, Object> item = ValidationUtil.mapStrObjValidation(itemObj, 'OrderItem', false);
      if (item == null) {
        continue;
      }

      Decimal itemDiscountRate = ValidationUtil.decimalValidation(item.get('DiscountRate__c'), 'DiscountRate__c', false);
      if (itemDiscountRate != null) {
        result = result == null || itemDiscountRate > result ? itemDiscountRate : result;
      }
    }

    return result;
  }

  private static Set<String> extractCouponNosFromRawTransactionJournals(List<Object> transactionJournals) {
    Set<String> result = new Set<String>();
    if (transactionJournals == null) {
      return result;
    }

    for (Object journalObj : transactionJournals) {
      Map<String, Object> journal = ValidationUtil.mapStrObjValidation(journalObj, 'TransactionJournal', false);
      if (journal == null) {
        continue;
      }

      String couponNo = ValidationUtil.stringValidation(journal.get('CouponNo'), 'CouponNo', false);
      if (!String.isBlank(couponNo)) {
        result.add(couponNo);
      }
    }

    return result;
  }

  private static Set<String> resolveProductCategoryCodes(Set<String> productCodes) {
    Set<String> result = new Set<String>();
    if (productCodes == null || productCodes.isEmpty()) {
      return result;
    }

    Map<Id, Product2> productById = new Map<Id, Product2>();
    for (Product2 product : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
      productById.put(product.Id, product);
    }
    if (productById.isEmpty()) {
      return result;
    }

    for (ProductCategoryProduct link : [
      SELECT
        ProductId,
        ProductCategory.SystemCode__c,
        ProductCategory.LargeCategoryCode__c,
        ProductCategory.MediumCategoryCode__c,
        ProductCategory.SmallCategoryCode__c
      FROM ProductCategoryProduct
      WHERE ProductId IN :productById.keySet()
    ]) {
      if (link.ProductCategory == null) {
        continue;
      }

      addCategoryPathCodes(
        result,
        link.ProductCategory.SystemCode__c,
        link.ProductCategory.LargeCategoryCode__c,
        link.ProductCategory.MediumCategoryCode__c,
        link.ProductCategory.SmallCategoryCode__c
      );
    }

    return result;
  }

  private static void addCategoryPathCodes(Set<String> target, String systemCode, String largeCode, String mediumCode, String smallCode) {
    if (target == null || String.isBlank(systemCode) || String.isBlank(largeCode)) {
      return;
    }

    target.add(systemCode + '-' + largeCode);
    if (!String.isBlank(mediumCode)) {
      target.add(systemCode + '-' + largeCode + '-' + mediumCode);
    }
    if (!String.isBlank(mediumCode) && !String.isBlank(smallCode)) {
      target.add(systemCode + '-' + largeCode + '-' + mediumCode + '-' + smallCode);
    }
  }

  private static String resolvePromotionIdByPromotionNo(String promotionNo) {
    if (String.isBlank(promotionNo)) {
      return null;
    }

    List<Promotion> promotionList = [
      SELECT Id
      FROM Promotion
      WHERE PromotionNo__c = :promotionNo
      LIMIT 1
    ];

    return promotionList.isEmpty() ? promotionNo : String.valueOf(promotionList[0].Id);
  }

  private static Boolean matchesNumberConstraint(Decimal actualValue, Decimal targetValue, String operatorValue, Boolean defaultIsGte) {
    if (targetValue == null) {
      return true;
    }
    if (actualValue == null) {
      return false;
    }

    String normalizedOperator = String.isBlank(operatorValue) ? '' : operatorValue.trim().toLowerCase();
    if (normalizedOperator == 'none') {
      return true;
    }

    Boolean useGte = defaultIsGte;
    if (!String.isBlank(normalizedOperator)) {
      if (normalizedOperator == '01') {
        useGte = true;
      } else if (normalizedOperator == '02') {
        useGte = false;
      } else if (
        normalizedOperator.contains('lte') ||
        normalizedOperator.contains('le') ||
        normalizedOperator.contains('max') ||
        operatorValue.contains('이하')
      ) {
        useGte = false;
      } else if (
        normalizedOperator.contains('gte') ||
        normalizedOperator.contains('ge') ||
        normalizedOperator.contains('min') ||
        operatorValue.contains('이상')
      ) {
        useGte = true;
      }
    }

    return useGte ? actualValue >= targetValue : actualValue <= targetValue;
  }

  public class VoucherAggKey {
    public String voucherCode; // 쿠폰 코드

    public VoucherAggKey(String voucherCode) {
      this.voucherCode = voucherCode;
    }

    public Boolean equals(Object obj) {
      if (obj == null || !(obj instanceof VoucherAggKey)) {
        return false;
      }
      VoucherAggKey other = (VoucherAggKey) obj;
      return this.voucherCode == other.voucherCode;
    }

    public Integer hashCode() {
      return (voucherCode == null) ? 0 : voucherCode.hashCode();
    }
  }

  // 무제한 쿠폰 사용 완료 후 재지급/재발급 처리
  private static void reissueUnlimitedVoucherIfNeeded(Voucher redeemedVoucher, String programName, Id journalId) {
    System.debug(
      LoggingLevel.WARN,
      '[GDV][reissueUnlimitedVoucherIfNeeded] start redeemedVoucherId=' +
        (redeemedVoucher == null ? null : redeemedVoucher.Id) +
        ', voucherDefinitionId=' +
        (redeemedVoucher == null ? null : redeemedVoucher.VoucherDefinitionId) +
        ', loyaltyProgramMemberId=' +
        (redeemedVoucher == null ? null : redeemedVoucher.LoyaltyProgramMemberId) +
        ', isUnlimited=' +
        (redeemedVoucher == null || redeemedVoucher.VoucherDefinition == null ? null : redeemedVoucher.VoucherDefinition.IsUnlimited__c) +
        ', programName=' +
        programName +
        ', journalId=' +
        journalId
    );
    if (
      redeemedVoucher == null ||
      redeemedVoucher.VoucherDefinitionId == null ||
      redeemedVoucher.LoyaltyProgramMemberId == null ||
      redeemedVoucher.VoucherDefinition == null ||
      redeemedVoucher.VoucherDefinition.IsUnlimited__c != true
    ) {
      System.debug(LoggingLevel.WARN, '[GDV][reissueUnlimitedVoucherIfNeeded] skip: redeemed voucher is not eligible for unlimited reissue.');
      return;
    }

    // 테스트에서는 LoyaltyVoucherService 대신 단순 Voucher 생성으로 재발급 흐름만 검증한다.
    if (Test.isRunningTest()) {
      insert buildUnlimitedVoucherForTest(redeemedVoucher);
      System.debug(LoggingLevel.WARN, '[GDV][reissueUnlimitedVoucherIfNeeded] test mode reissued voucher inserted.');
      return;
    }

    Map<String, Object> req = new Map<String, Object>{
      'loyaltyProgramMemberId' => redeemedVoucher.LoyaltyProgramMemberId,
      'programName' => programName,
      // [기존 코드 시작] 2026-04-17
      // 'voucherDefinitionName' => redeemedVoucher.VoucherDefinition.Name,
      // [기존 코드 끝] 2026-04-17
      // [수정 코드 시작] 2026-04-17 - voucherDefinitionName 키에 Name 대신 VoucherDefinitionId를 사용해야 LoyaltyVoucherService.issueVoucher()가 정상 처리됨 (redeemVoucher 메서드의 기존 호출 방식과 동일)
      'voucherDefinitionName' => redeemedVoucher.VoucherDefinitionId,
      // [수정 코드 끝] 2026-04-17
      'journalId' => journalId,
      'additionalNotes' => 'Unlimited voucher auto reissue'
    };
    System.debug(LoggingLevel.WARN, '[GDV][reissueUnlimitedVoucherIfNeeded] issue request=' + JSON.serialize(req));

    List<LoyaltyManagement.IssueVoucherOutput> resList = LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ req });

    // System.debug(LoggingLevel.WARN, '[GDV][reissueUnlimitedVoucherIfNeeded] issue result count=' + (resList == null ? 0 : resList.size()));
    // Set<Id> issuedVoucherIds = new Set<Id>();

    // for (LoyaltyManagement.IssueVoucherOutput res : resList) {
    //   System.debug(
    //     LoggingLevel.WARN,
    //     '[GDV][reissueUnlimitedVoucherIfNeeded] issue result success=' +
    //       (res == null ? null : res.isSuccess()) +
    //       ', voucherId=' +
    //       (res == null ? null : res.getVoucherId()) +
    //       ', raw=' +
    //       (res == null ? null : JSON.serialize(res))
    //   );
    //   if (res != null && res.isSuccess() && res.getVoucherId() != null) {
    //     issuedVoucherIds.add(res.getVoucherId());
    //   }
    // }

    // 재발급된 쿠폰도 일반 지급과 동일하게 ERP 쿠폰 발급 연동을 수행한다.
    // System.debug(LoggingLevel.WARN, '[GDV][reissueUnlimitedVoucherIfNeeded] enqueue issuedVoucherIds=' + issuedVoucherIds);
    // enqueueCouponIssueJob(issuedVoucherIds); // (26.05.13 주석 처리 - CS)
  }

  // 테스트 전용 재발급 쿠폰 생성
  private static Voucher buildUnlimitedVoucherForTest(Voucher redeemedVoucher) {
    return new Voucher(
      VoucherDefinitionId = redeemedVoucher.VoucherDefinitionId,
      LoyaltyProgramMemberId = redeemedVoucher.LoyaltyProgramMemberId,
      VoucherCode = buildUnlimitedVoucherCode(redeemedVoucher.VoucherCode),
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = redeemedVoucher.ExpirationDate
    );
  }

  // 테스트 전용 재발급 쿠폰 번호 생성
  private static String buildUnlimitedVoucherCode(String voucherCode) {
    String baseCode = String.isBlank(voucherCode) ? 'UV' : voucherCode;
    Integer maxBaseLength = Math.min(12, baseCode.length());
    return baseCode.substring(0, maxBaseLength) + '-R-' + String.valueOf(DateTime.now().getTime());
  }

  // 지급 완료된 쿠폰을 ERP 쿠폰 발급 큐와 동일한 방식으로 후처리한다.
  private static void enqueueCouponIssueJob(Set<Id> voucherIds) {
    if (voucherIds == null || voucherIds.isEmpty()) {
      return;
    }

    List<Voucher> voucherList = [
      SELECT Id, VoucherCode, LoyaltyProgramMember.Contact.MemberNo__c, VoucherDefinition.CouponManNo__c
      FROM Voucher
      WHERE Id IN :voucherIds
    ];

    ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
    Set<Id> voucherIdsForCallback = new Set<Id>();

    for (Voucher voucher : voucherList) {
      String couponManNo = voucher.VoucherDefinition.CouponManNo__c;
      String memberNo = voucher.LoyaltyProgramMember.Contact.MemberNo__c;

      if (String.isBlank(couponManNo) || String.isBlank(memberNo) || String.isBlank(voucher.VoucherCode)) {
        continue;
      }

      couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(couponManNo, voucher.VoucherCode, memberNo, UserInfo.getName()));
      voucherIdsForCallback.add(voucher.Id);
    }

    if (couponIssueReq.couponDetailModels.isEmpty()) {
      return;
    }

    System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIdsForCallback));
  }

  // 무제한 쿠폰 취소 시 자동 재발급된 최신 쿠폰 1건을 함께 취소한다.
  private static void cancelUnlimitedReissuedVoucherIfNeeded(Voucher redeemedVoucher, Id originalRedeemJournalId) {
    if (
      redeemedVoucher == null ||
      redeemedVoucher.VoucherDefinitionId == null ||
      redeemedVoucher.LoyaltyProgramMemberId == null ||
      redeemedVoucher.VoucherDefinition == null ||
      redeemedVoucher.VoucherDefinition.IsUnlimited__c != true ||
      originalRedeemJournalId == null
    ) {
      return;
    }

    List<Voucher> reissuedVoucherList = [
      SELECT Id, Status
      FROM Voucher
      WHERE
        LoyaltyProgramMemberId = :redeemedVoucher.LoyaltyProgramMemberId
        AND VoucherDefinitionId = :redeemedVoucher.VoucherDefinitionId
        AND Id != :redeemedVoucher.Id
        AND Status = 'Issued'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    if (reissuedVoucherList.isEmpty()) {
      return;
    }

    reissuedVoucherList[0].Status = 'Cancelled';
    update reissuedVoucherList[0];
  }
}