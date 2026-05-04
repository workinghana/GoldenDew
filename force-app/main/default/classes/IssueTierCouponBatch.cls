/**
 * 등급 쿠폰 지급 배치 (로깅/예외/부분성공 기준 정리 버전)
 * - Tier(특정 LoyaltyTier) 대상 회원에게 Voucher 발급
 * - TransactionJournal 선생성(부분성공) → 발급 요청(reqData) → 결과 분석
 * - 발급 성공 Voucher 재조회 → ERP 쿠폰 지급 Job enqueue
 *
 * 로깅 정책
 * - execute(chunk) 단위로: 시작/입력요약/핵심카운트/에러요약 기록
 * - RequestBody는 대량일 수 있으므로 "요약"만 남김(원하면 샘플 N개만)
 * - finish에서 전체 집계(성공/실패) 기록
 *
 * 주의
 * - 본 클래스는 Statefull로 totalSuccess/totalFail 집계
 * - SObjectUtil.findIdByName / LoyaltyVoucherService.issueVoucherV2 / ErpCouponJob 등은 조직 구현에 맞춰 사용
 */
public with sharing class IssueTierCouponBatch implements Database.Batchable<SObject>, Database.Stateful {
  /* ================= Constants ================= */

  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual';
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_ISSUE = 'Manual Coupon Issuance';

  /* ================= Params ================= */

  private Id loyaltyTierId;
  private Id voucherDefinitionId;
  private Date issueDate;

  /* ================= Cached ================= */

  private String voucherDefinitionName;
  private String programName;

  /* ================= Aggregation ================= */

  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  /* ================= Constructor ================= */

  public IssueTierCouponBatch(Id loyaltyTierId, Id voucherDefinitionId, Date issueDate) {
    this.loyaltyTierId = loyaltyTierId;
    this.voucherDefinitionId = voucherDefinitionId;
    this.issueDate = issueDate;
  }

  /* ================= start ================= */

  public Database.QueryLocator start(Database.BatchableContext bc) {
    LoyaltyTier tier = [
      SELECT Name
      FROM LoyaltyTier
      WHERE Id = :loyaltyTierId
      LIMIT 1
    ];

    String gradeValue;

    for (Schema.PicklistEntry entry : Contact.Grade__c.getDescribe().getPicklistValues()) {
      if (entry.getLabel() == tier.Name) {
        gradeValue = entry.getValue(); // API value (01,02,03)
        break;
      }
    }

    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Contact
        WHERE Grade__c = :gradeValue
      ]
    );
  }
  /* ================= execute ================= */

  public void execute(Database.BatchableContext bc, List<Contact> scope) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(IssueTierCouponBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();

    Integer scopeCnt = (scope == null) ? 0 : scope.size();
    Integer memberCnt = 0;

    Integer tjOk = 0;
    Integer tjNg = 0;

    Integer issueOk = 0;
    Integer issueNg = 0;

    Integer erpEnqueueCnt = 0;

    try {
      if (scope == null || scope.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      /* ================= VoucherDefinition 캐시 ================= */

      if (String.isBlank(voucherDefinitionName)) {
        List<VoucherDefinition> vdList = [
          SELECT Id, Name, LoyaltyProgram.Name, IsActive, ExpirationDate
          FROM VoucherDefinition
          WHERE Id = :voucherDefinitionId AND IsActive = TRUE AND (ExpirationDate = NULL OR ExpirationDate >= :Date.today())
          LIMIT 1
        ];

        if (vdList.isEmpty()) {
          logger.setStatus('ERROR');
          logger.setErrorMessage('활성 상태이면서 만료되지 않은 쿠폰만 지급할 수 있습니다.');
          logger.setDescription('voucherDefinitionId=' + voucherDefinitionId + ', today=' + String.valueOf(Date.today()));
          return;
        }

        VoucherDefinition vd = vdList[0];

        voucherDefinitionName = vd.Name;
        programName = vd.LoyaltyProgram.Name;
      }

      /* ================= Contact → LPM 매핑 ================= */

      Set<Id> contactIds = new Set<Id>();

      for (Contact c : scope) {
        contactIds.add(c.Id);
      }

      Map<Id, LoyaltyProgramMember> memberMap = new Map<Id, LoyaltyProgramMember>(
        [
          SELECT Id, ContactId
          FROM LoyaltyProgramMember
          WHERE ContactId IN :contactIds
        ]
      );

      memberCnt = memberMap.size();

      if (memberMap.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('No LoyaltyProgramMember found');
        return;
      }

      /* ================= TransactionJournal 생성 ================= */

      Id journalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);

      Id journalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_ISSUE, true);

      Map<Id, TransactionJournal> tjByMemberId = new Map<Id, TransactionJournal>();

      for (LoyaltyProgramMember m : memberMap.values()) {
        TransactionJournal tj = new TransactionJournal();

        tj.ActivityDate = Date.today();
        tj.JournalDate = Date.today();
        tj.MemberId = m.Id;
        tj.JournalTypeId = journalTypeId;
        tj.JournalSubTypeId = journalSubTypeId;
        tj.Status = 'Processed';

        tjByMemberId.put(m.Id, tj);
      }

      List<TransactionJournal> tjList = tjByMemberId.values();

      Database.SaveResult[] tjResults = Database.insert(tjList, false);

      Set<Id> journalSuccessMemberIdSet = new Set<Id>();

      for (Integer i = 0; i < tjResults.size(); i++) {
        Database.SaveResult sr = tjResults[i];
        TransactionJournal tj = tjList[i];

        if (sr.isSuccess()) {
          tjOk++;
          journalSuccessMemberIdSet.add(tj.MemberId);
        } else {
          tjNg++;
          failIds.add((String) tj.MemberId);
        }
      }

      if (journalSuccessMemberIdSet.isEmpty()) {
        logger.setStatus('ERROR');
        logger.setDescription('All TJ insert failed');

        return;
      }

      /* ================= Voucher Issue 요청 생성 ================= */

      List<Map<String, Object>> reqData = new List<Map<String, Object>>();

      for (Id memberId : journalSuccessMemberIdSet) {
        TransactionJournal tj = tjByMemberId.get(memberId);

        reqData.add(
          new Map<String, Object>{
            'loyaltyProgramMemberId' => memberId,
            'programName' => programName,
            'voucherDefinitionName' => voucherDefinitionName,
            'effectiveDate' => Datetime.newInstance(issueDate, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd'),
            'journalId' => tj.Id
          }
        );
      }

      logger.setRequestBody('req size=' + reqData.size());

      /* ================= Voucher Issue ================= */

      List<LoyaltyManagement.IssueVoucherOutput> results = LoyaltyVoucherService.issueVoucherV2(reqData);

      Set<Id> issuedVoucherIds = new Set<Id>();

      for (Integer i = 0; i < results.size(); i++) {
        LoyaltyManagement.IssueVoucherOutput r = results[i];

        String memberIdStr = String.valueOf(reqData[i].get('loyaltyProgramMemberId'));

        if (r != null && r.isSuccess()) {
          issueOk++;
          successIds.add(memberIdStr);

          String vid = r.getVoucherId();

          if (!String.isBlank(vid)) {
            issuedVoucherIds.add((Id) vid);
          }
        } else {
          issueNg++;
          failIds.add(memberIdStr);
        }
      }

      normalizeIssuedUpgradeVouchers(issuedVoucherIds);

      /* ================= Voucher 재조회 ================= */

      if (!issuedVoucherIds.isEmpty()) {
        List<Voucher> issued = [
          SELECT Id, LoyaltyProgramMember.Contact.MemberNo__c, VoucherDefinition.CouponManNo__c, VoucherCode
          FROM Voucher
          WHERE Id IN :issuedVoucherIds
        ];

        ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();

        couponIssueReq.couponDetailModels = new List<ErpCouponReqDto.CouponDetailModel>();

        Set<Id> voucherIdsForCallback = new Set<Id>();

        for (Voucher v : issued) {
          String couponManNo = v.VoucherDefinition.CouponManNo__c;
          String memberNo = v.LoyaltyProgramMember.Contact.MemberNo__c;
          String voucherCode = v.VoucherCode;

          if (String.isBlank(couponManNo) || String.isBlank(memberNo)) {
            continue;
          }

          couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(couponManNo, voucherCode, memberNo, UserInfo.getName()));

          voucherIdsForCallback.add(v.Id);
        }

        if (!couponIssueReq.couponDetailModels.isEmpty()) {
          System.enqueueJob(
            new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIdsForCallback)
          );

          erpEnqueueCnt = 1;
        }
      }

      /* ================= 상태 집계 ================= */

      failIds.removeAll(successIds);

      if (!failIds.isEmpty() && !successIds.isEmpty())
        logger.setStatus('PARTIAL');
      else if (!failIds.isEmpty())
        logger.setStatus('ERROR');
      else
        logger.setStatus('SUCCESS');

      logger.setDescription('scope=' + scopeCnt + ', members=' + memberCnt + ', TJ ok=' + tjOk + ', issue ok=' + issueOk + ', ERP=' + erpEnqueueCnt);
    } catch (Exception e) {
      logger.setStatus('ERROR');
      logger.setErrorMessage(e.getMessage());
      logger.setStackTrace(e.getStackTraceString());
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();

      ApexLogger.insertLogs();
    }
  }

  /* ================= finish ================= */

  public void finish(Database.BatchableContext bc) {
    totalFail.removeAll(totalSuccess);

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);

    logger.logging(IssueTierCouponBatch.class.getName());

    logger.setStatus(totalFail.isEmpty() ? 'SUCCESS' : 'PARTIAL');

    logger.setDescription('TOTAL done. success=' + totalSuccess.size() + ', fail=' + totalFail.size());

    logger.addLog();

    ApexLogger.insertLogs();
  }

  private void normalizeIssuedUpgradeVouchers(Set<Id> issuedVoucherIds) {
    if (issuedVoucherIds == null || issuedVoucherIds.isEmpty()) {
      return;
    }

    List<Voucher> upgradeVoucherList = [
      SELECT Id, FaceValue, VoucherDefinition.IsUpgrade__c
      FROM Voucher
      WHERE Id IN :issuedVoucherIds AND VoucherDefinition.IsUpgrade__c = TRUE
    ];

    for (Voucher voucher : upgradeVoucherList) {
      voucher.FaceValue = 0;
    }

    if (!upgradeVoucherList.isEmpty()) {
      update upgradeVoucherList;
    }
  }

  public class CustomException extends Exception {
  }
}