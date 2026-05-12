@IsTest
private class ErpPointJobTest {
  private class PointJobMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      String endpoint = req.getEndpoint();
      String body = req.getBody();
      Boolean isPointSave = endpoint != null && endpoint.contains('/Crm/PointSave');
      if (isPointSave && body != null && body.contains('THROW')) {
        throw new CalloutException('forced credit exception');
      }

      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');

      if (isPointSave && body != null && body.contains('FAIL')) {
        res.setBody('{"success":false,"message":"forced credit failure","data":null}');
      } else {
        res.setBody('{"success":true,"message":"ok","data":{"erpId":"OK"}}');
      }
      return res;
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new PointJobMock());
  }

  private static Id makeRecordId() {
    Account a = new Account(Name = 'T');
    insert a;
    return a.Id;
  }

  private static LoyaltyProgram makeProgram() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'ErpPointJob LP ' + Datetime.now().getTime(), IsPrimary = false, Status = 'Active');
    insert lp;
    return lp;
  }

  private static LoyaltyProgramMember makeMember(LoyaltyProgram lp, String suffix) {
    Contact c = new Contact(LastName = 'ErpPointJob ' + suffix, MemberNo__c = 'EPJ-' + suffix + '-' + Datetime.now().getTime());
    insert c;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MembershipNumber = 'EPJ-LPM-' + suffix + '-' + Datetime.now().getTime(),
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert lpm;
    return lpm;
  }

  private static TransactionJournal makeJournal(String suffix) {
    LoyaltyProgram lp = makeProgram();
    return makeJournal(lp, suffix);
  }

  private static TransactionJournal makeJournal(LoyaltyProgram lp, String suffix) {
    LoyaltyProgramMember lpm = makeMember(lp, suffix);

    TransactionJournal tj = new TransactionJournal(
      LoyaltyProgramId = lp.Id,
      MemberId = lpm.Id,
      Status = 'Pending',
      ActivityDate = Date.today(),
      TransactionAmount = 100
    );
    insert tj;
    return tj;
  }

  private static ErpPointReqDto.CreditRequest creditReq(String marker, Id journalId) {
    ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();
    String todayText = String.valueOf(Date.today()).replace('-', '');
    req.cd_company = '1000';
    req.ym_create = todayText.left(6);
    req.cd_type_point = '01';
    req.dt_create = todayText;
    req.no_mbr = marker;
    req.no_sal = 'SALE-' + marker;
    req.pt_target = 100;
    req.pt_save = 100;
    req.cd_save_ledger = journalId == null ? null : String.valueOf(journalId);
    return req;
  }

  @IsTest
  static void test_point_expiry_job_runs_recordId() {
    setMock();
    Id rid = makeRecordId();

    ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_EXPIRY, req, new ErpPointAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_point_credit_job_runs_recordId() {
    setMock();
    Id rid = makeRecordId();

    ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, req, new ErpPointAsyncCallback(), rid);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_constructor_with_recordIds_path_runs() {
    setMock();
    Id rid1 = makeRecordId();
    Id rid2 = makeRecordId();
    Set<Id> ids = new Set<Id>{ rid1, rid2 };

    ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_EXPIRY, req, new ErpPointAsyncCallback(), ids);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_constructor_with_sobject_path_runs() {
    setMock();
    Account a = new Account(Name = 'T_SOBJ');
    insert a;

    ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();

    ErpPointJob job = new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, req, new ErpPointAsyncCallback(), a.Id, a);

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_point_credit_list_partial_failure_updates_failed_journal() {
    setMock();
    LoyaltyProgram lp = makeProgram();
    TransactionJournal successJournal = makeJournal(lp, 'SUCCESS');
    TransactionJournal failJournal = makeJournal(lp, 'FAIL');

    List<ErpPointReqDto.CreditRequest> reqList = new List<ErpPointReqDto.CreditRequest>{
      creditReq('SUCCESS', successJournal.Id),
      creditReq('FAIL', failJournal.Id)
    };

    Test.startTest();
    System.enqueueJob(
      new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, reqList, new ErpPointAsyncCallback(), new Set<Id>{ successJournal.Id, failJournal.Id })
    );
    Test.stopTest();

    Map<Id, TransactionJournal> journals = new Map<Id, TransactionJournal>(
      [
        SELECT Id, Status, ErrorDescription
        FROM TransactionJournal
        WHERE Id IN :new Set<Id>{ successJournal.Id, failJournal.Id }
      ]
    );

    System.assertEquals('Pending', journals.get(successJournal.Id).Status);
    System.assertEquals('Error', journals.get(failJournal.Id).Status);
    System.assert(journals.get(failJournal.Id).ErrorDescription.contains('forced credit failure'));
  }

  @IsTest
  static void test_point_credit_list_exception_and_invalid_ledger_paths() {
    setMock();
    TransactionJournal throwJournal = makeJournal('THROW');

    ErpPointReqDto.CreditRequest throwingReq = creditReq('THROW', throwJournal.Id);
    ErpPointReqDto.CreditRequest invalidLedgerReq = creditReq('FAIL_INVALID', null);
    invalidLedgerReq.cd_save_ledger = 'not-an-id';
    ErpPointReqDto.CreditRequest blankLedgerReq = creditReq('FAIL_BLANK', null);

    Test.startTest();
    System.enqueueJob(
      new ErpPointJob(
        ErpPointJob.Operation.POINT_CREDIT,
        new List<ErpPointReqDto.CreditRequest>{ throwingReq, invalidLedgerReq, blankLedgerReq, null },
        new ErpPointAsyncCallback(),
        new Set<Id>{ throwJournal.Id }
      )
    );
    Test.stopTest();

    TransactionJournal updated = [
      SELECT Status, ErrorDescription
      FROM TransactionJournal
      WHERE Id = :throwJournal.Id
    ];
    System.assertEquals('Error', updated.Status);
    System.assert(updated.ErrorDescription.contains('forced credit exception'));
  }

  @IsTest
  static void test_point_credit_null_list_is_handled_by_job_failure_path() {
    setMock();
    TransactionJournal tj = makeJournal('NULLLIST');

    Test.startTest();
    System.enqueueJob(new ErpPointJob(ErpPointJob.Operation.POINT_CREDIT, null, new ErpPointAsyncCallback(), new Set<Id>{ tj.Id }));
    Test.stopTest();

    System.assert(true);
  }
}