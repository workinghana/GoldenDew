public class ErpPointJob extends ErpAsyncJob {
  public enum Operation {
    POINT_EXPIRY,
    POINT_CREDIT
  }

  private Operation op;

  public ErpPointJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    super(String.valueOf(op), requestDto, callback, recordId);
    this.op = op;
  }

  public ErpPointJob(Operation op, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
    super(String.valueOf(op), requestDto, callback, recordIds);
    this.op = op;
  }

  public ErpPointJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
    super(String.valueOf(op), requestDto, callback, recordId, o);
    this.op = op;
  }

  protected override ErpApiResponseDto doCallout() {
    switch on op {
      when POINT_EXPIRY {
        System.debug('when POINT_EXPIRY');
        return ErpPointApiClient.expiryPoint((ErpPointReqDto.ExpiryRequest) requestDto);
      }
      when POINT_CREDIT {
        System.debug('when POINT_CREDIT');
        return creditPoint(requestDto);
      }
    }

    throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  }

  private static ErpApiResponseDto creditPoint(Object dto) {
    try {
      List<ErpPointReqDto.CreditRequest> reqList = (List<ErpPointReqDto.CreditRequest>) dto;
      return creditPointOneByOne(reqList);
    } catch (System.TypeException e) {
      return ErpPointApiClient.creditPoint((ErpPointReqDto.CreditRequest) dto);
    }
  }

  private static ErpApiResponseDto creditPointOneByOne(List<ErpPointReqDto.CreditRequest> reqList) {
    if (reqList == null) {
      throw new IllegalArgumentException('Request body is required.');
    }

    Integer successCount = 0;
    Map<Id, String> failureMessagesByJournalId = new Map<Id, String>();

    for (ErpPointReqDto.CreditRequest req : reqList) {
      try {
        ErpApiResponseDto res = ErpPointApiClient.creditPoint(req);
        if (res != null && res.success == false) {
          recordCreditFailure(failureMessagesByJournalId, req, res.message);
        } else {
          successCount++;
        }
      } catch (Exception e) {
        recordCreditFailure(failureMessagesByJournalId, req, e.getMessage());
      }
    }

    updateFailedCreditJournals(failureMessagesByJournalId);

    ErpApiResponseDto out = new ErpApiResponseDto();
    out.success = failureMessagesByJournalId.isEmpty();
    out.message = 'success=' + successCount + ', fail=' + failureMessagesByJournalId.size();
    out.data = new Map<String, Object>{ 'successCount' => successCount, 'failCount' => failureMessagesByJournalId.size() };
    out.info = new ErpApiResponseDto.Info();
    return out;
  }

  private static void recordCreditFailure(Map<Id, String> failureMessagesByJournalId, ErpPointReqDto.CreditRequest req, String message) {
    if (req == null || String.isBlank(req.cd_save_ledger)) {
      return;
    }

    try {
      Id journalId = (Id) req.cd_save_ledger;
      failureMessagesByJournalId.put(journalId, message);
    } catch (Exception e) {
      System.debug('Invalid TransactionJournal Id for ERP point credit failure: ' + req.cd_save_ledger);
    }
  }

  private static void updateFailedCreditJournals(Map<Id, String> failureMessagesByJournalId) {
    if (failureMessagesByJournalId.isEmpty()) {
      return;
    }

    List<TransactionJournal> failedJournals = [
      SELECT Id, ErrorDescription, Status
      FROM TransactionJournal
      WHERE Id IN :failureMessagesByJournalId.keySet()
    ];

    for (TransactionJournal tj : failedJournals) {
      tj.Status = 'Error';
      tj.ErrorDescription = truncate('ERP point credit failed: ' + String.valueOf(failureMessagesByJournalId.get(tj.Id)), 255);
    }

    if (!failedJournals.isEmpty()) {
      Database.update(failedJournals, false);
    }
  }

  private static String truncate(String value, Integer maxLen) {
    if (String.isBlank(value) || value.length() <= maxLen) {
      return value;
    }
    return value.substring(0, maxLen - 3) + '...';
  }
}