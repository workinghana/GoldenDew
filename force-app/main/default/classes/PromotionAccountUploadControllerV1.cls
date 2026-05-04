public with sharing class PromotionAccountUploadControllerV1 {
  private static final Integer MAX_ROWS = 50000;
  private static final String COL_STORE_CODE = 'StoreCode';

  @AuraEnabled
  public static UploadPreviewResult parseUploadFile(String base64Data, Id promotionId) {
    ParsedUpload parsed = parseCsv(base64Data, promotionId);

    UploadPreviewResult result = new UploadPreviewResult();
    result.previewRows = parsed.previewRows;
    result.errors = parsed.errors;
    result.successCount = parsed.previewRows.size();
    result.failCount = parsed.errors.size();
    return result;
  }

  @AuraEnabled
  public static UploadResult insertPromotionAccounts(String base64Data, Id promotionId) {
    ParsedUpload parsed = parseCsv(base64Data, promotionId);

    UploadResult result = new UploadResult();
    result.success = true;
    result.successCount = 0;
    result.failCount = parsed.errors.size();
    result.insertedIds = new List<Id>();
    result.errors = new List<RowErrorDTO>();
    result.errors.addAll(parsed.errors);

    if (parsed.previewRows.isEmpty()) {
      result.success = false;
      result.errorMessage = 'No valid rows to upload.';
      return result;
    }

    List<PromotionAccount__c> toInsert = new List<PromotionAccount__c>();
    for (PreviewRowDTO row : parsed.previewRows) {
      toInsert.add(new PromotionAccount__c(PromotionId__c = promotionId, AccountId__c = row.accountId, IsActive__c = true));
    }

    Database.SaveResult[] saveResults = Database.insert(toInsert, false);
    for (Integer i = 0; i < saveResults.size(); i++) {
      Database.SaveResult saveResult = saveResults[i];
      PreviewRowDTO row = parsed.previewRows[i];

      if (saveResult.isSuccess()) {
        result.successCount++;
        result.insertedIds.add(saveResult.getId());
        continue;
      }

      result.success = false;
      result.failCount++;
      String message = saveResult.getErrors().isEmpty() ? 'Unknown error' : saveResult.getErrors()[0].getMessage();
      result.errors.add(new RowErrorDTO(row.rowNumber, row.storeCode, row.storeName, message));
    }

    if (!result.errors.isEmpty()) {
      List<String> messages = new List<String>();
      for (RowErrorDTO error : result.errors) {
        messages.add('Row ' + error.rowNumber + ': ' + error.errorReason);
      }
      result.errorMessage = String.join(messages, '\n');
    }

    return result;
  }

  private static ParsedUpload parseCsv(String base64Data, Id promotionId) {
    if (promotionId == null) {
      throw new AuraHandledException('Promotion Id is required.');
    }

    Promotion promotion;
    List<Promotion> promotions = [
      SELECT Id, Name, PromotionNo__c
      FROM Promotion
      WHERE Id = :promotionId
      LIMIT 1
    ];
    if (promotions.isEmpty()) {
      throw new AuraHandledException('Promotion not found.');
    }
    promotion = promotions[0];

    if (String.isBlank(base64Data)) {
      throw new AuraHandledException('File data is required.');
    }

    String text = EncodingUtil.base64Decode(base64Data).toString();
    List<String> lines = text.split('\\r?\\n');

    if (lines.isEmpty() || String.isBlank(lines[0])) {
      throw new AuraHandledException('The file is empty.');
    }

    if (lines.size() - 1 > MAX_ROWS) {
      throw new AuraHandledException('The file can contain up to 50000 rows.');
    }

    List<String> headers = splitCsvLine(lines[0]);
    normalizeHeaders(headers);

    Integer storeCodeIdx = headers.indexOf(COL_STORE_CODE);
    if (storeCodeIdx == -1) {
      throw new AuraHandledException('Required column StoreCode is missing.');
    }

    ParsedUpload parsed = new ParsedUpload();
    List<RawRow> rawRows = new List<RawRow>();
    Set<String> storeCodes = new Set<String>();
    Set<String> seenStoreCodes = new Set<String>();

    for (Integer i = 1; i < lines.size(); i++) {
      if (String.isBlank(lines[i])) {
        continue;
      }

      List<String> cols = splitCsvLine(lines[i]);
      Integer rowNumber = i + 1;
      String storeCode = getColumnValue(cols, storeCodeIdx);

      if (String.isBlank(storeCode)) {
        parsed.errors.add(new RowErrorDTO(rowNumber, storeCode, null, 'StoreCode is required.'));
        continue;
      }

      if (seenStoreCodes.contains(storeCode)) {
        parsed.errors.add(new RowErrorDTO(rowNumber, storeCode, null, 'Duplicate store code in file.'));
        continue;
      }

      seenStoreCodes.add(storeCode);
      storeCodes.add(storeCode);
      rawRows.add(new RawRow(rowNumber, storeCode));
    }

    Map<String, Account> accountByStoreCode = new Map<String, Account>();
    if (!storeCodes.isEmpty()) {
      for (Account accountRecord : [
        SELECT Id, Name, StoreCode__c
        FROM Account
        WHERE StoreCode__c IN :storeCodes
      ]) {
        accountByStoreCode.put(accountRecord.StoreCode__c, accountRecord);
      }
    }

    enrichErrorStoreNames(parsed.errors, accountByStoreCode);

    Set<Id> accountIds = new Set<Id>();
    for (RawRow row : rawRows) {
      Account accountRecord = accountByStoreCode.get(row.storeCode);
      if (accountRecord != null) {
        accountIds.add(accountRecord.Id);
      }
    }

    Set<Id> existingAccountIds = new Set<Id>();
    if (!accountIds.isEmpty()) {
      for (PromotionAccount__c promotionAccount : [
        SELECT AccountId__c
        FROM PromotionAccount__c
        WHERE PromotionId__c = :promotionId AND AccountId__c IN :accountIds
      ]) {
        existingAccountIds.add(promotionAccount.AccountId__c);
      }
    }

    for (RawRow row : rawRows) {
      Account accountRecord = accountByStoreCode.get(row.storeCode);
      if (accountRecord == null) {
        parsed.errors.add(new RowErrorDTO(row.rowNumber, row.storeCode, null, 'Store not found.'));
        continue;
      }

      if (existingAccountIds.contains(accountRecord.Id)) {
        parsed.errors.add(new RowErrorDTO(row.rowNumber, row.storeCode, accountRecord.Name, 'PromotionAccount already exists.'));
        continue;
      }

      parsed.previewRows.add(
        new PreviewRowDTO(
          row.rowNumber,
          promotion.Id,
          promotion.PromotionNo__c,
          promotion.Name,
          accountRecord.Id,
          accountRecord.StoreCode__c,
          accountRecord.Name
        )
      );
    }

    return parsed;
  }

  private static void normalizeHeaders(List<String> headers) {
    for (Integer i = 0; i < headers.size(); i++) {
      headers[i] = headers[i] == null ? '' : headers[i].trim();
    }
  }

  private static List<String> splitCsvLine(String line) {
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
        cols.add(current.trim());
        current = '';
      } else {
        current += ch;
      }
    }

    cols.add(current.trim());
    for (Integer i = 0; i < cols.size(); i++) {
      cols[i] = unquote(cols[i]);
    }
    return cols;
  }

  private static String getColumnValue(List<String> cols, Integer idx) {
    if (idx == null || idx < 0 || idx >= cols.size()) {
      return '';
    }
    return cols[idx] == null ? '' : cols[idx].trim();
  }

  private static String unquote(String value) {
    if (String.isBlank(value)) {
      return '';
    }

    String result = value.trim();
    if (result.startsWith('"') && result.endsWith('"') && result.length() >= 2) {
      result = result.substring(1, result.length() - 1);
    }
    return result.trim();
  }

  private static void enrichErrorStoreNames(List<RowErrorDTO> errors, Map<String, Account> accountByStoreCode) {
    for (RowErrorDTO error : errors) {
      if (error == null || !String.isBlank(error.storeName)) {
        continue;
      }

      Account accountRecord = accountByStoreCode.get(error.storeCode);
      if (accountRecord != null) {
        error.storeName = accountRecord.Name;
      }
    }
  }

  private class ParsedUpload {
    public List<PreviewRowDTO> previewRows = new List<PreviewRowDTO>();
    public List<RowErrorDTO> errors = new List<RowErrorDTO>();
  }

  private class RawRow {
    public Integer rowNumber;
    public String storeCode;

    public RawRow(Integer rowNumber, String storeCode) {
      this.rowNumber = rowNumber;
      this.storeCode = storeCode;
    }
  }

  public class UploadPreviewResult {
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public Integer failCount;
    @AuraEnabled
    public List<PreviewRowDTO> previewRows = new List<PreviewRowDTO>();
    @AuraEnabled
    public List<RowErrorDTO> errors = new List<RowErrorDTO>();
  }

  public class UploadResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public Integer failCount;
    @AuraEnabled
    public String errorMessage;
    @AuraEnabled
    public List<Id> insertedIds;
    @AuraEnabled
    public List<RowErrorDTO> errors;
  }

  public class PreviewRowDTO {
    @AuraEnabled
    public Integer rowNumber;
    @AuraEnabled
    public Id promotionId;
    @AuraEnabled
    public String promotionNo;
    @AuraEnabled
    public String promotionName;
    @AuraEnabled
    public Id accountId;
    @AuraEnabled
    public String storeCode;
    @AuraEnabled
    public String storeName;

    public PreviewRowDTO(
      Integer rowNumber,
      Id promotionId,
      String promotionNo,
      String promotionName,
      Id accountId,
      String storeCode,
      String storeName
    ) {
      this.rowNumber = rowNumber;
      this.promotionId = promotionId;
      this.promotionNo = promotionNo;
      this.promotionName = promotionName;
      this.accountId = accountId;
      this.storeCode = storeCode;
      this.storeName = storeName;
    }
  }

  public class RowErrorDTO {
    @AuraEnabled
    public Integer rowNumber;
    @AuraEnabled
    public String storeCode;
    @AuraEnabled
    public String storeName;
    @AuraEnabled
    public String errorReason;

    public RowErrorDTO(Integer rowNumber, String storeCode, String storeName, String errorReason) {
      this.rowNumber = rowNumber;
      this.storeCode = storeCode;
      this.storeName = storeName;
      this.errorReason = errorReason;
    }
  }
}