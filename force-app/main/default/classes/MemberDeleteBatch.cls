public with sharing class MemberDeleteBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  /* ================= START ================= */

  public Database.QueryLocator start(Database.BatchableContext bc) {
    Date targetDate = Date.today().addDays(-31);

    System.debug('================ START =================');
    System.debug('Batch Job Id = ' + bc.getJobId());
    System.debug('targetDate = ' + targetDate);

    return Database.getQueryLocator(
      [
        SELECT Id, MemberNo__c, MemberDropDate__c
        FROM Contact
        WHERE IsWithdrawn__c = TRUE AND IsDeleted = FALSE AND MemberDropDate__c != NULL AND MemberDropDate__c <= :targetDate
      ]
    );
  }

  /* ================= EXECUTE ================= */

  public void execute(Database.BatchableContext bc, List<Contact> scope) {
    System.debug('================ EXECUTE START =================');
    System.debug('scope size = ' + scope.size());

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(MemberDeleteBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (scope == null || scope.isEmpty()) {
        return;
      }

      /* ================= Contact 정보 ================= */

      Set<Id> contactIds = new Set<Id>();
      Set<String> memberNos = new Set<String>();

      for (Contact c : scope) {
        contactIds.add(c.Id);

        if (c.MemberNo__c != null) {
          memberNos.add(c.MemberNo__c);
        }
      }

      /* ================= LoyaltyProgramMember ================= */

      List<LoyaltyProgramMember> members = [
        SELECT Id, ContactId
        FROM LoyaltyProgramMember
        WHERE ContactId IN :contactIds
      ];

      Set<Id> memberIds = new Set<Id>();

      for (LoyaltyProgramMember m : members) {
        memberIds.add(m.Id);
      }

      /* ================= LoyaltyLedgerTraceability (LL보다 먼저) ================= */

      if (!memberIds.isEmpty()) {
        List<LoyaltyLedgerTraceability> llts = [
          SELECT Id
          FROM LoyaltyLedgerTraceability
          WHERE DebitLoyaltyLedger.LoyaltyProgramMemberId IN :memberIds OR CreditLoyaltyLedger.LoyaltyProgramMemberId IN :memberIds
        ];

        if (!llts.isEmpty()) {
          delete llts;
          System.debug('LoyaltyLedgerTraceability 삭제 완료');
        }
      }

      /* ================= LoyaltyLedger ================= */

      if (!memberIds.isEmpty()) {
        List<LoyaltyLedger> ledgers = [
          SELECT Id
          FROM LoyaltyLedger
          WHERE LoyaltyProgramMemberId IN :memberIds
        ];

        if (!ledgers.isEmpty()) {
          delete ledgers;
          System.debug('LoyaltyLedger 삭제 완료');
        }
      }

      /* ================= Voucher ================= */

      List<Voucher> vouchers = [
        SELECT Id
        FROM Voucher
        WHERE LoyaltyProgramMemberId IN :memberIds OR ContactId IN :contactIds
      ];

      if (!vouchers.isEmpty()) {
        delete vouchers;
        System.debug('Voucher 삭제 완료');
      }

      /* ================= TransactionJournal (Order보다 먼저) ================= */

      if (!memberIds.isEmpty()) {
        List<TransactionJournal> journals = [
          SELECT Id
          FROM TransactionJournal
          WHERE MemberId IN :memberIds
        ];

        if (!journals.isEmpty()) {
          delete journals;
          System.debug('TransactionJournal 삭제 완료');
        }
      }

      /* ================= Order ================= */

      List<Order> orders = new List<Order>();

      if (!memberNos.isEmpty()) {
        orders = [
          SELECT Id
          FROM Order
          WHERE MemberNo__c IN :memberNos
        ];
      }

      if (!orders.isEmpty()) {
        delete orders;
        System.debug('Order 삭제 완료');
      }

      /* ================= LoyaltyAggrSubPointExprLedger__c ================= */

      if (!memberIds.isEmpty()) {
        List<LoyaltyAggrSubPointExprLedger__c> aggrs = [
          SELECT Id
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE LoyaltyProgramMemberId__c IN :memberIds
        ];

        if (!aggrs.isEmpty()) {
          delete aggrs;
          System.debug('LoyaltyAggrSubPointExprLedger__c 삭제 완료');
        }
      }

      /* ================= LoyaltyMemberCurrency ================= */

      if (!memberIds.isEmpty()) {
        List<LoyaltyMemberCurrency> currencies = [
          SELECT Id
          FROM LoyaltyMemberCurrency
          WHERE LoyaltyMemberId IN :memberIds
        ];

        if (!currencies.isEmpty()) {
          delete currencies;
          System.debug('LoyaltyMemberCurrency 삭제 완료');
        }
      }

      /* ================= LoyaltyMemberTier ================= */

      if (!memberIds.isEmpty()) {
        List<LoyaltyMemberTier> tiers = [
          SELECT Id
          FROM LoyaltyMemberTier
          WHERE LoyaltyMemberId IN :memberIds
        ];

        if (!tiers.isEmpty()) {
          delete tiers;
          System.debug('LoyaltyMemberTier 삭제 완료');
        }
      }

      /* ================= LoyaltyProgramMember ================= */

      if (!members.isEmpty()) {
        delete members;
        System.debug('LoyaltyProgramMember 삭제 완료');
      }

      /* ================= Contact ================= */

      Database.DeleteResult[] results = Database.delete(scope, false);

      for (Integer i = 0; i < results.size(); i++) {
        String memberNo = scope[i].MemberNo__c;

        if (results[i].isSuccess()) {
          successIds.add(memberNo);
          System.debug('Contact 삭제 성공 : ' + memberNo);
        } else {
          failIds.add(memberNo);

          for (Database.Error err : results[i].getErrors()) {
            String msg = 'Delete 실패: memberNo=' + memberNo + ', msg=' + err.getMessage();
            System.debug(msg);
            failMsgs.add(msg);
          }
        }
      }

      failIds.removeAll(successIds);

      Boolean hasFail = !failIds.isEmpty();
      Boolean hasSuccess = !successIds.isEmpty();

      if (hasFail && hasSuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription('chunkSize=' + scope.size() + ', success=' + successIds.size() + ', fail=' + failIds.size());
    } catch (Exception e) {
      System.debug('Exception 발생=' + e.getMessage());

      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      if (!successIds.isEmpty()) {
        logger.setSuccessRecordIds(successIds);
      }

      if (!failIds.isEmpty()) {
        logger.setFailedRecordIds(failIds);
      }

      if (!failMsgs.isEmpty()) {
        logger.setErrorMessage(String.join(failMsgs, ' | '));
      }

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();

      ApexLogger.insertLogs();

      System.debug('EXECUTE 종료');
    }
  }

  /* ================= FINISH ================= */

  public void finish(Database.BatchableContext bc) {
    System.debug('================ FINISH =================');

    totalFail.removeAll(totalSuccess);

    Integer successCnt = totalSuccess.size();
    Integer failCnt = totalFail.size();

    String status;

    if (failCnt > 0 && successCnt > 0) {
      status = 'PARTIAL';
    } else if (failCnt > 0) {
      status = 'ERROR';
    } else {
      status = 'SUCCESS';
    }

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);

    logger.logging(MemberDeleteBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();

    ApexLogger.insertLogs();

    System.debug('Batch FINISH 완료');
  }
}
