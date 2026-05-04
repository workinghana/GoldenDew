public with sharing class IssuePointSubTypeBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual';
  private static final String JOURNAL_SUB_TYPE_NAME_MANUAL = 'Manual Points Credit';

  private Set<Id> memberIds;
  private Id subtypeId;
  private Date issueDate;
  private Decimal pointAmount;
  private Date expireDate;

  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  public IssuePointSubTypeBatch(Set<Id> memberIds, Id subtypeId, Date issueDate, Decimal pointAmount, Date expireDate) {
    this.memberIds = memberIds;
    this.subtypeId = subtypeId;
    this.issueDate = issueDate;
    this.pointAmount = pointAmount;
    this.expireDate = expireDate;
  }

  /* ================= START ================= */

  public Database.QueryLocator start(Database.BatchableContext bc) {
    System.debug('===== Batch START =====');
    System.debug('Batch 대상 memberIds 수 : ' + memberIds.size());

    return Database.getQueryLocator(
      [
        SELECT Id, ProgramId, ContactId, Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id IN :memberIds
      ]
    );
  }

  /* ================= EXECUTE ================= */

  public void execute(Database.BatchableContext bc, List<LoyaltyProgramMember> scope) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);

    logger.logging(IssuePointSubTypeBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();

    try {
      if (scope.isEmpty()) {
        return;
      }

      System.debug('===== 매칭된 회원 수 (scope) : ' + scope.size());

      /* ================= Currency 조회 ================= */

      LoyaltyPgmCurrencySubtype subtype = [
        SELECT Id, Name, LoyaltyProgramCurrencyId
        FROM LoyaltyPgmCurrencySubtype
        WHERE Id = :subtypeId
        LIMIT 1
      ];

      /* ================= JournalType ================= */

      Id journalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);

      JournalSubType journalSubType = [
        SELECT Id, Description
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_MANUAL
        LIMIT 1
      ];
      Id journalSubTypeId = journalSubType.Id;

      /* ================= TransactionJournal 생성 ================= */

      List<TransactionJournal> tjList = new List<TransactionJournal>();

      for (LoyaltyProgramMember m : scope) {
        TransactionJournal tj = new TransactionJournal();

        tj.LoyaltyProgramId = m.ProgramId;
        tj.MemberId = m.Id;
        tj.ActivityDate = issueDate;
        tj.JournalDate = issueDate;
        tj.TransactionAmount = pointAmount;
        tj.JournalTypeId = journalTypeId;
        tj.JournalSubTypeId = journalSubTypeId;
        tj.Status = 'Processed';

        tjList.add(tj);
      }

      Database.SaveResult[] tjResults = Database.insert(tjList, false);

      /* ================= LoyaltyLedger 생성 ================= */

      List<Map<String, Object>> creditReqList = new List<Map<String, Object>>();

      for (Integer i = 0; i < scope.size(); i++) {
        if (!tjResults[i].isSuccess()) {
          failIds.add(String.valueOf(scope[i].Id));
          continue;
        }

        LoyaltyProgramMember m = scope[i];

        Map<String, Object> creditReq = new Map<String, Object>();
        creditReq.put('loyaltyProgramMemberId', m.Id);
        creditReq.put('journalId', tjResults[i].getId());
        creditReq.put('points', Double.valueOf(pointAmount));
        creditReq.put('loyaltyProgramCurrencySubtypeName', subtype.Name);
        creditReq.put('pointsExpirationDate', String.valueOf(expireDate));

        creditReqList.add(creditReq);
      }

      if (!creditReqList.isEmpty()) {
        if (!Test.isRunningTest()) {
          LoyaltyPointService.creditPoints(creditReqList);
        }

        for (Integer i = 0; i < scope.size(); i++) {
          if (tjResults[i].isSuccess()) {
            successIds.add(String.valueOf(scope[i].Id));
          }
        }
      }

      /* ================= ERP 요청 (수정된 부분) ================= */

      List<ErpPointReqDto.CreditRequest> reqList = new List<ErpPointReqDto.CreditRequest>();
      Set<Id> journalIds = new Set<Id>();

      for (Integer i = 0; i < scope.size(); i++) {
        LoyaltyProgramMember m = scope[i];

        if (!tjResults[i].isSuccess()) {
          continue;
        }

        String memberNo;

        if (m.Contact != null) {
          memberNo = m.Contact.MemberNo__c;
        }

        if (String.isBlank(memberNo)) {
          System.debug('ERP 요청 제외 (memberNo 없음) : ' + m.Id);
          failIds.add(String.valueOf(m.Id));
          continue;
        }

        ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();

        req.no_mbr = memberNo;
        req.pt_save = pointAmount;
        req.cd_save_ledger = String.valueOf(tjResults[i].getId());
        req.id_insert = UserInfo.getName();
        req.tx_remark = journalSubType.Description;

        reqList.add(req);
        journalIds.add(tjResults[i].getId());
      }

      System.debug('===== ERP 요청 대상 회원 수 : ' + reqList.size());

      if (!reqList.isEmpty()) {
        System.enqueueJob(new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, reqList, new ErpPointAsyncCallback(), journalIds));
      }

      System.debug('===== 포인트 지급 성공 회원(LPM Id) =====');
      System.debug(successIds);

      System.debug('===== ERP 요청 제외 회원(LPM Id) =====');
      System.debug(failIds);

      logger.setStatus('SUCCESS');
    } catch (Exception e) {
      logger.setStatus('ERROR');
      logger.setErrorMessage(e.getMessage());

      System.debug('Batch Error : ' + e.getMessage());
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      logger.setResponseDatetime(Datetime.now());

      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  /* ================= FINISH ================= */

  public void finish(Database.BatchableContext bc) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);

    logger.logging(IssuePointSubTypeBatch.class.getName());

    logger.setStatus(totalFail.isEmpty() ? 'SUCCESS' : 'PARTIAL');
    logger.setDescription('TOTAL success=' + totalSuccess.size() + ', fail=' + totalFail.size() + ', jobId=' + bc.getJobId());

    System.debug('===== Batch 전체 결과 =====');
    System.debug('총 지급 성공 회원 수 : ' + totalSuccess.size());
    System.debug('총 실패 회원 수 : ' + totalFail.size());

    System.debug('성공 회원 목록 : ' + totalSuccess);
    System.debug('실패 회원 목록 : ' + totalFail);

    logger.addLog();
    ApexLogger.insertLogs();
  }
}