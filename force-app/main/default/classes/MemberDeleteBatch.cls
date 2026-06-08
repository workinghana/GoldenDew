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

      /* ================= LoyaltyLedgerTraceability  ================= */

      if (!memberIds.isEmpty()) {
        List<LoyaltyLedgerTraceability> llts = [
          SELECT Id
          FROM LoyaltyLedgerTraceability
          WHERE DebitLoyaltyLedger.LoyaltyProgramMemberId IN :memberIds OR CreditLoyaltyLedger.LoyaltyProgramMemberId IN :memberIds
        ];

        if (!llts.isEmpty()) {
          Database.DeleteResult[] lltResults = Database.delete(llts, false);
          for (Integer i = 0; i < lltResults.size(); i++) {
            if (!lltResults[i].isSuccess()) {
              for (Database.Error err : lltResults[i].getErrors()) {
                failMsgs.add('LoyaltyLedgerTraceability 삭제 실패: Id=' + llts[i].Id + ', msg=' + err.getMessage());
              }
            }
          }
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
          Database.DeleteResult[] ledgerResults = Database.delete(ledgers, false);
          for (Integer i = 0; i < ledgerResults.size(); i++) {
            if (!ledgerResults[i].isSuccess()) {
              for (Database.Error err : ledgerResults[i].getErrors()) {
                failMsgs.add('LoyaltyLedger 삭제 실패: Id=' + ledgers[i].Id + ', msg=' + err.getMessage());
              }
            }
          }
        }
      }

      /* ================= Voucher ================= */

      List<Voucher> vouchers = [
        SELECT Id
        FROM Voucher
        WHERE LoyaltyProgramMemberId IN :memberIds OR ContactId IN :contactIds
      ];

      if (!vouchers.isEmpty()) {
        Database.DeleteResult[] voucherResults = Database.delete(vouchers, false);
        for (Integer i = 0; i < voucherResults.size(); i++) {
          if (!voucherResults[i].isSuccess()) {
            for (Database.Error err : voucherResults[i].getErrors()) {
              failMsgs.add('Voucher 삭제 실패: Id=' + vouchers[i].Id + ', msg=' + err.getMessage());
            }
          }
        }
      }

      /* ================= TransactionJournal ================= */

      if (!memberIds.isEmpty()) {
        List<TransactionJournal> journals = [
          SELECT Id
          FROM TransactionJournal
          WHERE MemberId IN :memberIds
        ];

        if (!journals.isEmpty()) {
          Database.DeleteResult[] journalResults = Database.delete(journals, false);
          for (Integer i = 0; i < journalResults.size(); i++) {
            if (!journalResults[i].isSuccess()) {
              for (Database.Error err : journalResults[i].getErrors()) {
                failMsgs.add('TransactionJournal 삭제 실패: Id=' + journals[i].Id + ', msg=' + err.getMessage());
              }
            }
          }
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
        Database.DeleteResult[] orderResults = Database.delete(orders, false);
        for (Integer i = 0; i < orderResults.size(); i++) {
          if (!orderResults[i].isSuccess()) {
            for (Database.Error err : orderResults[i].getErrors()) {
              failMsgs.add('Order 삭제 실패: Id=' + orders[i].Id + ', msg=' + err.getMessage());
            }
          }
        }
      }

      /* ================= LoyaltyAggrSubPointExprLedger__c ================= */

      if (!memberIds.isEmpty()) {
        List<LoyaltyAggrSubPointExprLedger__c> aggrs = [
          SELECT Id
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE LoyaltyProgramMemberId__c IN :memberIds
        ];

        if (!aggrs.isEmpty()) {
          Database.DeleteResult[] aggrResults = Database.delete(aggrs, false);
          for (Integer i = 0; i < aggrResults.size(); i++) {
            if (!aggrResults[i].isSuccess()) {
              for (Database.Error err : aggrResults[i].getErrors()) {
                failMsgs.add('LoyaltyAggrSubPointExprLedger__c 삭제 실패: Id=' + aggrs[i].Id + ', msg=' + err.getMessage());
              }
            }
          }
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
          Database.DeleteResult[] currencyResults = Database.delete(currencies, false);
          for (Integer i = 0; i < currencyResults.size(); i++) {
            if (!currencyResults[i].isSuccess()) {
              for (Database.Error err : currencyResults[i].getErrors()) {
                failMsgs.add('LoyaltyMemberCurrency 삭제 실패: Id=' + currencies[i].Id + ', msg=' + err.getMessage());
              }
            }
          }
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
          Database.DeleteResult[] tierResults = Database.delete(tiers, false);
          for (Integer i = 0; i < tierResults.size(); i++) {
            if (!tierResults[i].isSuccess()) {
              for (Database.Error err : tierResults[i].getErrors()) {
                failMsgs.add('LoyaltyMemberTier 삭제 실패: Id=' + tiers[i].Id + ', msg=' + err.getMessage());
              }
            }
          }
        }
      }

      /* ================= LoyaltyProgramMember ================= */

      if (!members.isEmpty()) {
        Database.DeleteResult[] memberResults = Database.delete(members, false);
        for (Integer i = 0; i < memberResults.size(); i++) {
          if (!memberResults[i].isSuccess()) {
            for (Database.Error err : memberResults[i].getErrors()) {
              failMsgs.add('LoyaltyProgramMember 삭제 실패: Id=' + members[i].Id + ', msg=' + err.getMessage());
            }
          }
        }
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
      failMsgs.add('Exception: ' + e.getMessage());
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      Boolean hasFailure = !failIds.isEmpty() || !failMsgs.isEmpty();

      if (hasFailure) {
        if (!failIds.isEmpty()) {
          logger.setFailedRecordIds(failIds);
        }
        if (!failMsgs.isEmpty()) {
          logger.setErrorMessage(String.join(failMsgs, ' | '));
        }
        logger.setResponseDatetime(Datetime.now());
        logger.addLog();
        ApexLogger.insertLogs();
      }

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
