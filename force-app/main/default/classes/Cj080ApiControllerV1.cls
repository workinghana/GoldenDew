@RestResource(urlMapping='/unsubscribe')
global without sharing class Cj080ApiControllerV1 {
  @HttpGet
  global static void createUnsubscribe() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(Cj080ApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String uNumber;
    String rNumber;

    try {
      // ===== Request logging =====
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now());

      // ===== Parse params =====
      uNumber = req.params.get('uNumber');
      rNumber = req.params.get('rNumber');

      if (String.isBlank(uNumber)) {
        throw new CustomException(400, 'uNumber is required.');
      }
      if (String.isBlank(rNumber)) {
        throw new CustomException(400, 'rNumber is required.');
      }

      // String mobilePhone = normalize010WithHyphen(rNumber);
      String mobilePhone = rNumber;
      if (mobilePhone == null) {
        throw new CustomException(400, 'Invalid rNumber. expected 010XXXXXXXX or 010XXXXXXXXX');
      }

      logger.setDescription('unsubscribe request: uNumber=' + uNumber + ', rNumber=' + rNumber + ', mobilePhone=' + mobilePhone);

      // ===== Query =====
      List<Contact> cList = [
        SELECT Id, IsSMSAgreed__c, StoreRegi__r.StoreCode__c, MemberNo__c, LastName, MobilePhone
        FROM Contact
        WHERE
          MobilePhone = :mobilePhone
          AND IsSMSAgreed__c = TRUE
          AND MobilePhone != NULL
          AND StoreRegi__r.StoreCode__c != NULL
          AND MemberNo__c != NULL
        LIMIT 1
      ];

      // ===== No target: idempotent success =====
      if (cList.isEmpty()) {
        String okMsg = 'OK (no target). uNumber=' + uNumber + ', rNumber=' + rNumber + ', mobilePhone=' + mobilePhone;

        writeSuccess(res, okMsg); // 200 + body
        logger.setStatus('SUCCESS');
        logger.setDescription('No Contact found. ' + okMsg);
        finalizeLog(logger, res, okMsg);
        return;
      }

      // ===== Update =====
      cList[0].IsSMSAgreed__c = false;

      Database.SaveResult sr = Database.update(cList[0], false);

      Integer successCnt = 0;
      Integer failCnt = 0;
      List<String> dmlErrs = new List<String>();

      if (sr.isSuccess()) {
        successCnt = 1;

        ErpMemberReqDto.UpdateMemberSmsReceiveRequest reqDto = new ErpMemberReqDto.UpdateMemberSmsReceiveRequest();
        reqDto.P_NO_MBR = cList[0].MemberNo__c; // 회원 번호 (필수)
        reqDto.P_NM_MBR_KOR = cList[0].LastName; // 성함 (필수)
        reqDto.P_CD_STORE_REGI = cList[0].StoreRegi__r.StoreCode__c; // 등록 매장 (필수)
        reqDto.P_NO_CELLPHONE1 = cList[0].MobilePhone; // 휴대폰 (필수)
        reqDto.P_ID_INSERT = 'Milvus'; // 등록자 (필수)
        reqDto.P_YN_RECEIVE_SMS = 'N'; // SMS 수신 거부

        System.debug('enqueueJob 진입 전 reqDto: ' + JSON.serialize(reqDto));
        System.enqueueJob(new ErpMemberJob(ErpMemberJob.Operation.UPDATE_MEMBER_SMS_RECEIVE, reqDto, new ErpMemberAsyncCallback(), cList[0].Id));
      } else {
        failCnt = 1;
        for (Database.Error err : sr.getErrors()) {
          dmlErrs.add('contactId=' + cList[0].Id + ', msg=' + err.getMessage());
        }
      }

      // ===== Decide status & response =====
      // 정책 선택:
      // - 모두 성공: 200
      // - 일부 실패: 207 (Multi-Status) 또는 200으로 통일 가능
      // - 모두 실패: 500 또는 400(요청문제) 등 정책 필요
      Integer httpCode;
      String bodyMsg;

      if (failCnt == 0) {
        httpCode = 200;
        bodyMsg = 'OK. updated=' + successCnt + ', target=' + cList.size();
        logger.setStatus('SUCCESS');
      } else if (successCnt > 0) {
        httpCode = 200; // 부분 성공 표현
        bodyMsg = 'PARTIAL. updated=' + successCnt + ', failed=' + failCnt + ', target=' + cList.size() + ' | errors=' + String.join(dmlErrs, ' | ');
        logger.setStatus('PARTIAL');
      } else {
        httpCode = 500;
        bodyMsg = 'ERROR. update failed. target=' + cList.size() + ' | errors=' + String.join(dmlErrs, ' | ');
        logger.setStatus('ERROR');
      }

      // 로그 필드
      logger.setDescription(
        'uNumber=' + uNumber + ', rNumber=' + rNumber + ', targetCnt=' + cList.size() + ', updateSuccess=' + successCnt + ', updateFail=' + failCnt
      );
      if (!dmlErrs.isEmpty()) {
        logger.setErrorMessage(String.join(dmlErrs, ' | '));
      }

      // ===== Response write =====
      if (httpCode == 200) {
        writeSuccess(res, bodyMsg);
      } else {
        // 스펙: HTTP/1.1 <code> <Error>
        // => <Error>를 response body(plain text)로 내려줌
        writeError(res, httpCode, bodyMsg);
      }

      finalizeLog(logger, res, bodyMsg);
    } catch (CustomException ce) {
      // 스펙에 맞게 상태코드 + 에러 문자열 내려주기
      String errMsg = ce.message + ' (uNumber=' + safe(uNumber) + ', rNumber=' + safe(rNumber) + ')';
      writeError(res, ce.code, errMsg);

      logger.setStatus('ERROR');
      logger.setErrorCode('CUSTOM_EXCEPTION');
      logger.setErrorMessage(ce.message);
      finalizeLog(logger, res, errMsg);
    } catch (Exception e) {
      String errMsg = 'Internal Server Error' + ' (uNumber=' + safe(uNumber) + ', rNumber=' + safe(rNumber) + ')';
      writeError(res, 500, errMsg);

      logger.setStatus('ERROR');
      logger.setErrorCode('EXCEPTION');
      logger.setErrorMessage(e.getMessage());
      finalizeLog(logger, res, errMsg);
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  // =========================
  // Response helpers
  // =========================
  private static void writeSuccess(RestResponse res, String body) {
    res.statusCode = 200;
    res.addHeader('Content-Type', 'text/plain; charset=UTF-8');
    res.responseBody = Blob.valueOf(body);
  }

  private static void writeError(RestResponse res, Integer statusCode, String error) {
    res.statusCode = statusCode;
    res.addHeader('Content-Type', 'text/plain; charset=UTF-8');
    res.responseBody = Blob.valueOf(error);
  }

  private static void finalizeLog(ApexLogger logger, RestResponse res, String responseBodyText) {
    logger.setResponseDatetime(Datetime.now());
    logger.setHttpStatusCode(String.valueOf(res.statusCode));
    // Blob을 그대로 toString() 하면 깨질 수 있어서, 우리가 만든 문자열을 그대로 넣음
    logger.setResponseBody(responseBodyText);
  }

  private static String safe(String s) {
    return (s == null) ? '' : s;
  }

  // =========================
  // Phone normalize
  // =========================
  @TestVisible
  private static String normalize010WithHyphen(String raw) {
    if (String.isBlank(raw))
      return null;

    String d = raw.replaceAll('[^0-9]', '');
    if (!d.startsWith('010'))
      return null;

    if (d.length() == 11) {
      return d.substring(0, 3) + '-' + d.substring(3, 7) + '-' + d.substring(7, 11);
    }
    if (d.length() == 10) {
      return d.substring(0, 3) + '-' + d.substring(3, 6) + '-' + d.substring(6, 10);
    }
    return null;
  }

  // (가정) 기존에 사용 중인 CustomException이 이런 형태라고 전제
  global class CustomException extends Exception {
    public Integer code;
    public String message;
    public CustomException(Integer code, String message) {
      this.code = code;
      this.message = message;
    }
  }
}