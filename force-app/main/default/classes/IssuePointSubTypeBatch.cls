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
        SELECT Id, ContactId, Contact.MemberNo__c
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

      Id currencyId = [
        SELECT Id
        FROM LoyaltyProgramCurrency
        WHERE IsPrimary = TRUE
        LIMIT 1
      ]
      .Id;

      /* ================= JournalType ================= */

      Id journalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);

      Id journalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_MANUAL, true);

      /* ================= TransactionJournal 생성 ================= */

      List<TransactionJournal> tjList = new List<TransactionJournal>();

      for (LoyaltyProgramMember m : scope) {
        TransactionJournal tj = new TransactionJournal();

        tj.MemberId = m.Id;
        tj.ActivityDate = issueDate;
        tj.JournalDate = issueDate;
        tj.JournalTypeId = journalTypeId;
        tj.JournalSubTypeId = journalSubTypeId;
        tj.Status = 'Processed';

        tjList.add(tj);
      }

      Database.SaveResult[] tjResults = Database.insert(tjList, false);

      /* ================= LoyaltyLedger 생성 ================= */

      List<LoyaltyLedger> ledgers = new List<LoyaltyLedger>();

      for (Integer i = 0; i < scope.size(); i++) {
        if (!tjResults[i].isSuccess()) {
          failIds.add(String.valueOf(scope[i].Id));
          continue;
        }

        LoyaltyProgramMember m = scope[i];

        LoyaltyLedger ledger = new LoyaltyLedger();

        ledger.TransactionJournalId = tjResults[i].getId();
        ledger.LoyaltyProgramMemberId = m.Id;
        ledger.LoyaltyProgramCurrencyId = currencyId;

        ledger.EventType = 'Credit';
        ledger.Points = pointAmount;
        ledger.LoyaltyPgmCrcySubtypeId = subtypeId;

        ledger.ActivityDate = issueDate;
        ledger.ExpiryDate = expireDate;

        ledgers.add(ledger);

        successIds.add(String.valueOf(m.Id));
      }

      Database.insert(ledgers, false);

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
    logger.setDescription('TOTAL success=' + totalSuccess.size() + ', fail=' + totalFail.size());

    System.debug('===== Batch 전체 결과 =====');
    System.debug('총 지급 성공 회원 수 : ' + totalSuccess.size());
    System.debug('총 실패 회원 수 : ' + totalFail.size());

    System.debug('성공 회원 목록 : ' + totalSuccess);
    System.debug('실패 회원 목록 : ' + totalFail);

    logger.addLog();
    ApexLogger.insertLogs();
  }
}