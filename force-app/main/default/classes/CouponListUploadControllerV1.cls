/**
 * @author 이하나
 * @since 2026-03-05
 */
public with sharing class CouponListUploadControllerV1 {
  private static final Integer MAX_POLICY_UPLOAD_ROWS = 50000;
  private static final String COL_PRODUCT_CODE = 'ProductCode__c';
  private static final String COL_STORE_CODE = 'StoreCode__c';

  @AuraEnabled
  public static UploadPreviewResult parseCouponFile(String base64Data) {
    System.debug('===== CSV PARSE START =====');

    if (String.isBlank(base64Data)) {
      throw new AuraHandledException('파일 데이터가 없습니다.');
    }

    Blob fileBody = EncodingUtil.base64Decode(base64Data);
    String text = fileBody.toString();

    List<MemberErrorDTO> errorList = new List<MemberErrorDTO>();
    List<Id> successMemberIds = new List<Id>();

    List<String> lines = text.split('\\r?\\n');
    if (lines.isEmpty()) {
      return new UploadPreviewResult();
    }

    if (lines.size() > 50000) {
      throw new AuraHandledException('파일은 최대 5만건까지 가능합니다.');
    }

    List<String> headers = lines[0].split(',');
    for (Integer i = 0; i < headers.size(); i++) {
      headers[i] = headers[i].trim();
    }
    if (!headers.isEmpty()) {
      headers[0] = headers[0].replace('\uFEFF', '');
    }

    Integer memberIdx = headers.indexOf('NO_MBR');
    if (memberIdx == -1) {
      throw new AuraHandledException('NO_MBR 컬럼이 없습니다.');
    }

    Set<String> memberSet = new Set<String>();
    Set<String> memberForQuery = new Set<String>();

    for (Integer i = 1; i < lines.size(); i++) {
      if (String.isBlank(lines[i])) {
        continue;
      }

      List<String> cols = lines[i].split(',');
      String memberNo = '';

      if (cols.size() > memberIdx) {
        memberNo = cols[memberIdx].trim();
      }

      if (String.isBlank(memberNo)) {
        errorList.add(new MemberErrorDTO('', '회원번호 없음'));
        continue;
      }

      if (memberSet.contains(memberNo)) {
        errorList.add(new MemberErrorDTO(memberNo, '중복 회원번호'));
        continue;
      }

      memberSet.add(memberNo);
      memberForQuery.add(memberNo);
    }

    Map<String, Contact> contactMap = new Map<String, Contact>();
    for (Contact contact : [
      SELECT Id, MemberNo__c
      FROM Contact
      WHERE MemberNo__c IN :memberForQuery
    ]) {
      contactMap.put(contact.MemberNo__c, contact);
    }

    Set<Id> contactIds = new Set<Id>();
    for (Contact contact : contactMap.values()) {
      contactIds.add(contact.Id);
    }

    Map<Id, LoyaltyProgramMember> lpmMap = new Map<Id, LoyaltyProgramMember>();
    for (LoyaltyProgramMember member : [
      SELECT Id, ContactId
      FROM LoyaltyProgramMember
      WHERE ContactId IN :contactIds
    ]) {
      lpmMap.put(member.ContactId, member);
    }

    for (String memberNo : memberForQuery) {
      if (!contactMap.containsKey(memberNo)) {
        errorList.add(new MemberErrorDTO(memberNo, 'Contact 없음'));
        continue;
      }

      Contact contact = contactMap.get(memberNo);
      if (!lpmMap.containsKey(contact.Id)) {
        errorList.add(new MemberErrorDTO(memberNo, 'LoyaltyProgramMember 없음'));
        continue;
      }

      successMemberIds.add(lpmMap.get(contact.Id).Id);
    }

    UploadPreviewResult result = new UploadPreviewResult();
    result.errors = errorList;
    result.successCount = successMemberIds.size();
    result.failCount = errorList.size();
    result.successMemberIds = successMemberIds;
    return result;
  }

  @AuraEnabled
  public static PolicyUploadPreviewResult parseProductLimitFile(String base64Data) {
    List<PolicyUploadErrorDTO> errors = new List<PolicyUploadErrorDTO>();
    List<RawPolicyCodeRow> rawRows = parsePolicyCodeRows(base64Data, COL_PRODUCT_CODE, errors, true);
    List<PolicyUploadRowDTO> previewRows = new List<PolicyUploadRowDTO>();

    Set<String> productCodes = new Set<String>();
    for (RawPolicyCodeRow row : rawRows) {
      productCodes.add(row.code);
    }

    Map<String, Product2> productByCode = new Map<String, Product2>();
    if (!productCodes.isEmpty()) {
      for (Product2 product : [SELECT Id, Name, ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
        productByCode.put(product.ProductCode, product);
      }
    }

    enrichProductErrorNames(errors, productByCode);

    for (RawPolicyCodeRow row : rawRows) {
      Product2 product = productByCode.get(row.code);
      if (product == null) {
        errors.add(new PolicyUploadErrorDTO(row.rowNumber, row.code, null, '일치하는 제품을 찾을 수 없습니다.'));
        continue;
      }
      previewRows.add(new PolicyUploadRowDTO(row.rowNumber, product.ProductCode, product.Name));
    }

    return buildPolicyPreviewResult(previewRows, errors);
  }

  @AuraEnabled
  public static PolicyUploadPreviewResult parseStoreLimitFile(String base64Data) {
    List<PolicyUploadErrorDTO> errors = new List<PolicyUploadErrorDTO>();
    List<RawPolicyCodeRow> rawRows = parsePolicyCodeRows(base64Data, COL_STORE_CODE, errors, false);
    List<PolicyUploadRowDTO> previewRows = new List<PolicyUploadRowDTO>();

    Set<String> storeCodes = new Set<String>();
    for (RawPolicyCodeRow row : rawRows) {
      storeCodes.add(row.code);
    }

    Map<String, Account> storeByCode = new Map<String, Account>();
    if (!storeCodes.isEmpty()) {
      for (Account accountRecord : [SELECT Id, Name, StoreCode__c FROM Account WHERE StoreCode__c IN :storeCodes]) {
        storeByCode.put(accountRecord.StoreCode__c, accountRecord);
      }
    }

    enrichStoreErrorNames(errors, storeByCode);

    for (RawPolicyCodeRow row : rawRows) {
      Account accountRecord = storeByCode.get(row.code);
      if (accountRecord == null) {
        errors.add(new PolicyUploadErrorDTO(row.rowNumber, row.code, null, '일치하는 매장을 찾을 수 없습니다.'));
        continue;
      }
      previewRows.add(new PolicyUploadRowDTO(row.rowNumber, accountRecord.StoreCode__c, accountRecord.Name));
    }

    return buildPolicyPreviewResult(previewRows, errors);
  }

  @AuraEnabled
  public static IssueCouponResult issueCoupon(List<Id> memberIds, Id voucherDefinitionId) {
    System.debug('===== COUPON ISSUE START =====');

    if (memberIds == null || memberIds.isEmpty()) {
      throw new AuraHandledException('지급할 회원이 없습니다.');
    }

    VoucherDefinition voucherDefinition = [
      SELECT Id, Name, EffectiveDate, ExpirationDate, LoyaltyProgram.Name
      FROM VoucherDefinition
      WHERE Id = :voucherDefinitionId
      LIMIT 1
    ];

    Date requestedIssueDate = Date.today();
    validateVoucherDefinitionDate(voucherDefinition, requestedIssueDate);

    List<Map<String, Object>> reqData = new List<Map<String, Object>>();
    List<Id> requestMemberIds = new List<Id>();

    for (Id memberId : memberIds) {
      requestMemberIds.add(memberId);
      reqData.add(
        new Map<String, Object>{
          'loyaltyProgramMemberId' => memberId,
          'programName' => voucherDefinition.LoyaltyProgram.Name,
          'voucherDefinitionName' => voucherDefinition.Name,
          'effectiveDate' => String.valueOf(requestedIssueDate),
          'voucherCode' => 'VC' +
          Datetime.now().getTime() +
          String.valueOf(Math.abs(Crypto.getRandomInteger()))
        }
      );
    }

    List<LoyaltyManagement.IssueVoucherOutput> results = LoyaltyVoucherService.issueVoucherV2(reqData);
    if (results == null) {
      throw new AuraHandledException('쿠폰 지급 응답이 없습니다.');
    }

    IssueCouponResult result = new IssueCouponResult();
    result.success = true;
    result.successCount = 0;
    result.failCount = 0;
    result.successMemberIds = new List<Id>();
    result.failedMemberIds = new List<Id>();
    result.messages = new List<String>();

    Set<Id> issuedVoucherIds = new Set<Id>();

    for (Integer i = 0; i < requestMemberIds.size(); i++) {
      Id memberId = requestMemberIds[i];
      LoyaltyManagement.IssueVoucherOutput output = i < results.size() ? results[i] : null;

      if (output != null && output.isSuccess() && !String.isBlank(output.getVoucherId())) {
        result.successCount++;
        result.successMemberIds.add(memberId);
        try {
          issuedVoucherIds.add((Id) output.getVoucherId());
        } catch (Exception ex) {
          result.success = false;
          result.failCount++;
          result.failedMemberIds.add(memberId);
          result.messages.add('회원 ' + String.valueOf(memberId) + ': 잘못된 Voucher Id가 반환되었습니다.');
        }
        continue;
      }

      result.success = false;
      result.failCount++;
      result.failedMemberIds.add(memberId);
      result.messages.add(buildIssueFailureMessage(memberId, output));
    }

    enqueueErpIssueIfNeeded(issuedVoucherIds, result);

    if (!result.messages.isEmpty()) {
      result.errorMessage = String.join(result.messages, '\n');
    }

    if (!result.success) {
      throw new AuraHandledException(result.errorMessage);
    }

    result.message = '쿠폰 지급이 완료되었습니다.';
    return result;
  }

  private static void validateVoucherDefinitionDate(VoucherDefinition voucherDefinition, Date requestedIssueDate) {
    if (voucherDefinition.EffectiveDate != null && requestedIssueDate < voucherDefinition.EffectiveDate) {
      throw new AuraHandledException(
        '선택한 쿠폰은 아직 지급 가능 기간이 아닙니다.' +
          '\n쿠폰명: ' +
          voucherDefinition.Name +
          '\n유효 시작일: ' +
          String.valueOf(voucherDefinition.EffectiveDate) +
          '\n유효 종료일: ' +
          String.valueOf(voucherDefinition.ExpirationDate) +
          '\n요청 지급일: ' +
          String.valueOf(requestedIssueDate)
      );
    }

    if (voucherDefinition.ExpirationDate != null && requestedIssueDate > voucherDefinition.ExpirationDate) {
      throw new AuraHandledException(
        '선택한 쿠폰은 지급 가능 기간이 지났습니다.' +
          '\n쿠폰명: ' +
          voucherDefinition.Name +
          '\n유효 시작일: ' +
          String.valueOf(voucherDefinition.EffectiveDate) +
          '\n유효 종료일: ' +
          String.valueOf(voucherDefinition.ExpirationDate) +
          '\n요청 지급일: ' +
          String.valueOf(requestedIssueDate)
      );
    }
  }

  private static String buildIssueFailureMessage(Id memberId, LoyaltyManagement.IssueVoucherOutput output) {
    String message = '회원 ' + String.valueOf(memberId) + ': 쿠폰 지급에 실패했습니다.';

    if (output == null) {
      return message + ' 응답이 없습니다.';
    }

    if (output.getErrors() != null && !output.getErrors().isEmpty()) {
      String errorMessage = output.getErrors()[0].getMessage();
      String errorCode = output.getErrors()[0].getCode();

      if (!String.isBlank(errorMessage)) {
        message += ' ' + errorMessage;
      }
      if (!String.isBlank(errorCode)) {
        message += ' (' + errorCode + ')';
      }
    }

    return message;
  }

  private static void enqueueErpIssueIfNeeded(Set<Id> issuedVoucherIds, IssueCouponResult result) {
    if (issuedVoucherIds.isEmpty()) {
      return;
    }

    List<Voucher> issuedVouchers = [
      SELECT Id, VoucherCode, LoyaltyProgramMember.Contact.MemberNo__c, VoucherDefinition.CouponManNo__c
      FROM Voucher
      WHERE Id IN :issuedVoucherIds
    ];

    ErpCouponReqDto.IssueRequest couponIssueReq = new ErpCouponReqDto.IssueRequest();
    Set<Id> voucherIdsForCallback = new Set<Id>();

    for (Voucher voucher : issuedVouchers) {
      String couponManNo = voucher.VoucherDefinition.CouponManNo__c;
      String memberNo = voucher.LoyaltyProgramMember.Contact.MemberNo__c;
      String voucherCode = voucher.VoucherCode;

      if (String.isBlank(couponManNo) || String.isBlank(memberNo)) {
        result.success = false;
        result.messages.add('Voucher ' + String.valueOf(voucher.Id) + ': ERP 연동 정보가 부족합니다.');
        continue;
      }

      couponIssueReq.couponDetailModels.add(new ErpCouponReqDto.CouponDetailModel(couponManNo, voucherCode, memberNo, UserInfo.getName()));
      voucherIdsForCallback.add(voucher.Id);
    }

    if (couponIssueReq.couponDetailModels.isEmpty()) {
      return;
    }

    try {
      System.enqueueJob(new ErpCouponJob(ErpCouponJob.Operation.COUPON_ISSUE, couponIssueReq, new ErpCouponAsyncCallback(), voucherIdsForCallback));
    } catch (Exception ex) {
      result.success = false;
      result.messages.add('ERP 연동 작업 등록에 실패했습니다. ' + ex.getMessage());
    }
  }

  private static PolicyUploadPreviewResult buildPolicyPreviewResult(List<PolicyUploadRowDTO> previewRows, List<PolicyUploadErrorDTO> errors) {
    PolicyUploadPreviewResult result = new PolicyUploadPreviewResult();
    result.previewRows = previewRows;
    result.errors = errors;
    result.successCount = previewRows.size();
    result.failCount = errors.size();
    return result;
  }

  private static List<RawPolicyCodeRow> parsePolicyCodeRows(
    String base64Data,
    String requiredColumn,
    List<PolicyUploadErrorDTO> errors,
    Boolean isProduct
  ) {
    if (String.isBlank(base64Data)) {
      throw new AuraHandledException('파일 데이터가 없습니다.');
    }

    String text = EncodingUtil.base64Decode(base64Data).toString();
    List<String> lines = text.split('\\r?\\n');
    if (lines.isEmpty() || String.isBlank(lines[0])) {
      throw new AuraHandledException('파일이 비어 있습니다.');
    }

    if (lines.size() - 1 > MAX_POLICY_UPLOAD_ROWS) {
      throw new AuraHandledException('파일은 최대 50000행까지 업로드할 수 있습니다.');
    }

    List<String> headers = splitPolicyCsvLine(lines[0]);
    for (Integer i = 0; i < headers.size(); i++) {
      headers[i] = headers[i] == null ? '' : headers[i].trim();
    }
    if (!headers.isEmpty()) {
      headers[0] = headers[0].replace('\uFEFF', '');
    }

    Integer codeIdx = headers.indexOf(requiredColumn);
    if (codeIdx == -1) {
      throw new AuraHandledException(requiredColumn + ' 컬럼이 없습니다.');
    }

    Set<String> seenCodes = new Set<String>();
    List<RawPolicyCodeRow> rawRows = new List<RawPolicyCodeRow>();

    for (Integer i = 1; i < lines.size(); i++) {
      if (String.isBlank(lines[i])) {
        continue;
      }

      List<String> cols = splitPolicyCsvLine(lines[i]);
      Integer rowNumber = i + 1;
      String code = codeIdx < cols.size() && cols[codeIdx] != null ? cols[codeIdx].trim() : '';

      if (String.isBlank(code)) {
        errors.add(new PolicyUploadErrorDTO(rowNumber, code, null, isProduct ? '제품 코드가 비어 있습니다.' : '매장 코드가 비어 있습니다.'));
        continue;
      }

      if (seenCodes.contains(code)) {
        errors.add(
          new PolicyUploadErrorDTO(rowNumber, code, null, isProduct ? '파일 내 제품 코드가 중복되었습니다.' : '파일 내 매장 코드가 중복되었습니다.')
        );
        continue;
      }

      seenCodes.add(code);
      rawRows.add(new RawPolicyCodeRow(rowNumber, code));
    }

    return rawRows;
  }

  private static List<String> splitPolicyCsvLine(String line) {
    List<String> cols = new List<String>();
    if (line == null) {
      return cols;
    }

    String current = '';
    Boolean inQuotes = false;
    for (Integer i = 0; i < line.length(); i++) {
      String ch = line.substring(i, i + 1);
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length() && line.substring(i + 1, i + 2) == '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        cols.add(unquotePolicyCsvValue(current));
        current = '';
      } else {
        current += ch;
      }
    }

    cols.add(unquotePolicyCsvValue(current));
    return cols;
  }

  private static String unquotePolicyCsvValue(String value) {
    if (String.isBlank(value)) {
      return '';
    }

    String result = value.trim();
    if (result.startsWith('"') && result.endsWith('"') && result.length() >= 2) {
      result = result.substring(1, result.length() - 1);
    }
    return result.trim();
  }

  private static void enrichProductErrorNames(List<PolicyUploadErrorDTO> errors, Map<String, Product2> productByCode) {
    for (PolicyUploadErrorDTO errorRow : errors) {
      if (errorRow == null || !String.isBlank(errorRow.name)) {
        continue;
      }

      Product2 product = productByCode.get(errorRow.code);
      if (product != null) {
        errorRow.name = product.Name;
      }
    }
  }

  private static void enrichStoreErrorNames(List<PolicyUploadErrorDTO> errors, Map<String, Account> storeByCode) {
    for (PolicyUploadErrorDTO errorRow : errors) {
      if (errorRow == null || !String.isBlank(errorRow.name)) {
        continue;
      }

      Account accountRecord = storeByCode.get(errorRow.code);
      if (accountRecord != null) {
        errorRow.name = accountRecord.Name;
      }
    }
  }

  public class UploadPreviewResult {
    @AuraEnabled
    public Integer successCount;

    @AuraEnabled
    public Integer failCount;

    @AuraEnabled
    public List<MemberErrorDTO> errors;

    @AuraEnabled
    public List<Id> successMemberIds;
  }

  public class IssueCouponResult {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public Integer successCount;

    @AuraEnabled
    public Integer failCount;

    @AuraEnabled
    public String message;

    @AuraEnabled
    public String errorMessage;

    @AuraEnabled
    public List<Id> successMemberIds;

    @AuraEnabled
    public List<Id> failedMemberIds;

    public List<String> messages;
  }

  public class MemberErrorDTO {
    @AuraEnabled
    public String memberNo;

    @AuraEnabled
    public String errorReason;

    public MemberErrorDTO(String memberNo, String errorReason) {
      this.memberNo = memberNo;
      this.errorReason = errorReason;
    }
  }

  private class RawPolicyCodeRow {
    public Integer rowNumber;
    public String code;

    public RawPolicyCodeRow(Integer rowNumber, String code) {
      this.rowNumber = rowNumber;
      this.code = code;
    }
  }

  public class PolicyUploadPreviewResult {
    @AuraEnabled
    public Integer successCount;

    @AuraEnabled
    public Integer failCount;

    @AuraEnabled
    public List<PolicyUploadRowDTO> previewRows;

    @AuraEnabled
    public List<PolicyUploadErrorDTO> errors;
  }

  public class PolicyUploadRowDTO {
    @AuraEnabled
    public Integer rowNumber;

    @AuraEnabled
    public String id;

    @AuraEnabled
    public String code;

    @AuraEnabled
    public String name;

    public PolicyUploadRowDTO(Integer rowNumber, String code, String name) {
      this.rowNumber = rowNumber;
      this.id = code;
      this.code = code;
      this.name = name;
    }
  }

  public class PolicyUploadErrorDTO {
    @AuraEnabled
    public Integer rowNumber;

    @AuraEnabled
    public String code;

    @AuraEnabled
    public String name;

    @AuraEnabled
    public String errorReason;

    public PolicyUploadErrorDTO(Integer rowNumber, String code, String name, String errorReason) {
      this.rowNumber = rowNumber;
      this.code = code;
      this.name = name;
      this.errorReason = errorReason;
    }
  }
}