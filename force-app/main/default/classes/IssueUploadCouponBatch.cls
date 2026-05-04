public with sharing class IssueUploadCouponBatch implements Database.Batchable<Id>, Database.Stateful {
  @TestVisible
  private static Boolean forceIssueVoucherException = false;

  @TestVisible
  private static Boolean forceIssueVoucherNullResult = false;

  private Set<Id> memberIds;
  private Id voucherDefinitionId;
  private Date issueDate;
  private Date voucherEffectiveDate;
  private Date voucherExpirationDate;

  private String voucherDefinitionName;
  private String programName;
  private String requestToken;

  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  public IssueUploadCouponBatch(Set<Id> memberIds, Id voucherDefinitionId, Date issueDate) {
    this(memberIds, voucherDefinitionId, issueDate, null);
  }

  public IssueUploadCouponBatch(Set<Id> memberIds, Id voucherDefinitionId, Date issueDate, String requestToken) {
    this.memberIds = memberIds;
    this.voucherDefinitionId = voucherDefinitionId;
    this.issueDate = issueDate;
    this.requestToken = requestToken;

    VoucherDefinition vd = [
      SELECT Id, Name, LoyaltyProgram.Name, EffectiveDate, ExpirationDate
      FROM VoucherDefinition
      WHERE Id = :voucherDefinitionId
      LIMIT 1
    ];

    this.voucherDefinitionName = vd.Name;
    this.programName = vd.LoyaltyProgram.Name;
    this.voucherEffectiveDate = vd.EffectiveDate;
    this.voucherExpirationDate = vd.ExpirationDate;

    System.debug('VoucherDefinitionName : ' + voucherDefinitionName);
    System.debug('ProgramName : ' + programName);
  }

  public Iterable<Id> start(Database.BatchableContext bc) {
    return memberIds;
  }

  @TestVisible
  private static List<LoyaltyManagement.IssueVoucherOutput> invokeIssueVoucherV2(List<Map<String, Object>> reqData) {
    if (Test.isRunningTest() && forceIssueVoucherException) {
      throw new CustomException(500, 'Forced issueVoucherV2 exception');
    }
    if (Test.isRunningTest() && forceIssueVoucherNullResult) {
      return null;
    }
    return LoyaltyVoucherService.issueVoucherV2(reqData);
  }

  public void execute(Database.BatchableContext bc, List<Id> scope) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(IssueUploadCouponBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    if (scope == null || scope.isEmpty()) {
      logger.setStatus('SUCCESS');
      logger.setDescription('scope is empty');
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
      return;
    }

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();
    Set<String> scopedIds = new Set<String>();
    Date requestedEffectiveDate = issueDate;
    for (Id memberId : scope) {
      scopedIds.add(String.valueOf(memberId));
    }
    logger.setScopedIds(scopedIds);

    if (voucherEffectiveDate != null && requestedEffectiveDate < voucherEffectiveDate) {
      requestedEffectiveDate = voucherEffectiveDate;
    }

    if (voucherExpirationDate != null && requestedEffectiveDate > voucherExpirationDate) {
      for (Id memberId : scope) {
        failIds.add(String.valueOf(memberId));
      }

      logger.setStatus('ERROR');
      logger.setErrorCode('DATE_OUT_OF_RANGE');
      logger.setFailedRecordIds(failIds);
      logger.setErrorMessage(
        '선택한 쿠폰은 지급 가능 기간이 지났습니다. ' +
          '유효 시작일=' +
          String.valueOf(voucherEffectiveDate) +
          ', 유효 종료일=' +
          String.valueOf(voucherExpirationDate) +
          ', 요청 지급일=' +
          String.valueOf(issueDate)
      );
      logger.setDescription(
        'chunkSize=' +
          scope.size() +
          ', requestToken=' +
          requestToken +
          ', voucherDefinitionId=' +
          voucherDefinitionId +
          ', voucherDefinitionName=' +
          voucherDefinitionName +
          ', programName=' +
          programName +
          ', adjustedEffectiveDate=' +
          String.valueOf(requestedEffectiveDate)
      );
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
      totalFail.addAll(failIds);
      return;
    }

    List<Map<String, Object>> reqData = new List<Map<String, Object>>();

    for (Id memberId : scope) {
      String voucherCode = 'VC' + Datetime.now().getTime() + String.valueOf(Math.abs(Crypto.getRandomInteger()));

      Map<String, Object> req = new Map<String, Object>{
        'loyaltyProgramMemberId' => memberId,
        'programName' => programName,
        'voucherDefinitionName' => voucherDefinitionName,
        'effectiveDate' => String.valueOf(requestedEffectiveDate),
        'voucherCode' => voucherCode
      };

      System.debug('REQ MAP >>> ' + JSON.serializePretty(req));

      reqData.add(req);
    }

    List<LoyaltyManagement.IssueVoucherOutput> results;

    try {
      results = invokeIssueVoucherV2(reqData);
    } catch (Exception e) {
      System.debug('Voucher Issue ERROR >>> ' + e.getMessage());
      System.debug(e.getStackTraceString());
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      for (Id memberId : scope) {
        failIds.add(String.valueOf(memberId));
      }
      failMsgs.add('issueVoucherV2 exception: ' + e.getMessage());
      logger.setFailedRecordIds(failIds);
      logger.setErrorMessage(String.join(failMsgs, ' | '));
      logger.setDescription(
        'chunkSize=' +
          scope.size() +
          ', requestToken=' +
          requestToken +
          ', voucherDefinitionId=' +
          voucherDefinitionId +
          ', voucherDefinitionName=' +
          voucherDefinitionName +
          ', programName=' +
          programName +
          ', requestedEffectiveDate=' +
          String.valueOf(issueDate) +
          ', adjustedEffectiveDate=' +
          String.valueOf(requestedEffectiveDate)
      );
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
      totalFail.addAll(failIds);
      return;
    }

    if (results == null) {
      for (Id memberId : scope) {
        failIds.add(String.valueOf(memberId));
      }
      logger.setStatus('ERROR');
      logger.setErrorCode('NULL_RESULT');
      logger.setErrorMessage('LoyaltyVoucherService.issueVoucherV2 returned null.');
      logger.setFailedRecordIds(failIds);
      logger.setDescription(
        'chunkSize=' +
          scope.size() +
          ', requestToken=' +
          requestToken +
          ', voucherDefinitionId=' +
          voucherDefinitionId +
          ', voucherDefinitionName=' +
          voucherDefinitionName +
          ', programName=' +
          programName +
          ', requestedEffectiveDate=' +
          String.valueOf(issueDate) +
          ', adjustedEffectiveDate=' +
          String.valueOf(requestedEffectiveDate)
      );
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
      totalFail.addAll(failIds);
      return;
    }

    Set<Id> issuedVoucherIds = new Set<Id>();
    Integer loyaltyFailCnt = 0;

    for (Integer i = 0; i < results.size(); i++) {
      LoyaltyManagement.IssueVoucherOutput r = results[i];
      Id memberId = (Id) reqData[i].get('loyaltyProgramMemberId');

      if (r != null && r.isSuccess()) {
        successIds.add(String.valueOf(memberId));

        String vid = r.getVoucherId();

        if (!String.isBlank(vid)) {
          try {
            issuedVoucherIds.add((Id) vid);
          } catch (Exception ex) {
            failIds.add(String.valueOf(memberId));
            successIds.remove(String.valueOf(memberId));
            loyaltyFailCnt++;
            failMsgs.add('Invalid voucherId returned. memberId=' + memberId + ', voucherId=' + vid);
          }
        }
      } else {
        failIds.add(String.valueOf(memberId));
        loyaltyFailCnt++;
        String errMsg = 'Voucher issue failed. memberId=' + memberId;
        if (r == null) {
          errMsg += ', response is null';
        } else if (r.getErrors() != null && !r.getErrors().isEmpty()) {
          if (!String.isBlank(r.getErrors()[0].getCode())) {
            errMsg += ', errorCode=' + r.getErrors()[0].getCode();
          }
          if (!String.isBlank(r.getErrors()[0].getMessage())) {
            errMsg += ', errorMessage=' + r.getErrors()[0].getMessage();
          }
        }
        failMsgs.add(errMsg);
      }
    }

    if (!issuedVoucherIds.isEmpty()) {
      List<Voucher> issued = [
        SELECT Id, VoucherCode, EffectiveDate, LoyaltyProgramMemberId, LoyaltyProgramMember.Contact.MemberNo__c, VoucherDefinition.CouponManNo__c
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
          failMsgs.add('ERP mapping missing. voucherId=' + v.Id);
          continue;
        }

        couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(couponManNo, voucherCode, memberNo, UserInfo.getName()));

        voucherIdsForCallback.add(v.Id);
      }

      if (!couponIssueReq.couponDetailModels.isEmpty()) {
        try {
          System.enqueueJob(
            new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIdsForCallback)
          );
        } catch (Exception e) {
          failMsgs.add('ERP enqueue failed: ' + e.getMessage());
        }
      }
    }

    failIds.removeAll(successIds);

    totalSuccess.addAll(successIds);
    totalFail.addAll(failIds);

    Boolean hasAnyFail = !failIds.isEmpty() || loyaltyFailCnt > 0;
    Boolean hasAnySuccess = !successIds.isEmpty();

    if (hasAnyFail && hasAnySuccess) {
      logger.setStatus('PARTIAL');
    } else if (hasAnyFail) {
      logger.setStatus('ERROR');
    } else {
      logger.setStatus('SUCCESS');
    }

    logger.setDescription(
      'chunkSize=' +
        scope.size() +
        ', requestToken=' +
        requestToken +
        ', voucherDefinitionId=' +
        voucherDefinitionId +
        ', voucherDefinitionName=' +
        voucherDefinitionName +
        ', programName=' +
        programName +
        ', requestedEffectiveDate=' +
        String.valueOf(issueDate) +
        ', adjustedEffectiveDate=' +
        String.valueOf(requestedEffectiveDate) +
        ', voucherSuccess=' +
        successIds.size() +
        ', voucherFail=' +
        failIds.size() +
        ', loyaltyFailCnt=' +
        loyaltyFailCnt +
        ', issuedVoucherIds=' +
        issuedVoucherIds.size()
    );

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
  }

  public void finish(Database.BatchableContext bc) {
    totalFail.removeAll(totalSuccess);

    System.debug('TOTAL SUCCESS : ' + totalSuccess.size());
    System.debug('TOTAL FAIL : ' + totalFail.size());

    String status;
    if (!totalFail.isEmpty() && !totalSuccess.isEmpty()) {
      status = 'PARTIAL';
    } else if (!totalFail.isEmpty()) {
      status = 'ERROR';
    } else {
      status = 'SUCCESS';
    }

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(IssueUploadCouponBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + totalSuccess.size() + ', fail=' + totalFail.size() + ', requestToken=' + requestToken);
    if (!totalSuccess.isEmpty()) {
      logger.setSuccessRecordIds(totalSuccess);
    }
    if (!totalFail.isEmpty()) {
      logger.setFailedRecordIds(totalFail);
    }
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();
  }
}