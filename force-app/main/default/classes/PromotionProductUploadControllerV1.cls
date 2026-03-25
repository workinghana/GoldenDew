public with sharing class PromotionProductUploadControllerV1 {
  private static final Integer MAX_ROWS = 50000;
  private static final Integer INSERT_CHUNK_SIZE = 1000;
  private static final String COL_PRODUCT_CODE = 'ProductCode__c';
  @TestVisible
  private static Integer testChunkSizeOverride;

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
  public static UploadResult insertPromotionProducts(String base64Data, Id promotionId) {
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

    Integer chunkSize = getInsertChunkSize();
    for (Integer startIdx = 0; startIdx < parsed.previewRows.size(); startIdx += chunkSize) {
      Integer endIdx = Math.min(startIdx + chunkSize, parsed.previewRows.size());
      List<PreviewRowDTO> chunkRows = new List<PreviewRowDTO>();
      List<PromotionProduct> toInsert = new List<PromotionProduct>();

      for (Integer i = startIdx; i < endIdx; i++) {
        chunkRows.add(parsed.previewRows[i]);
      }

      for (PreviewRowDTO row : chunkRows) {
        toInsert.add(new PromotionProduct(PromotionId = promotionId, ProductId = row.productId));
      }

      Database.SaveResult[] saveResults = Database.insert(toInsert, false);
      for (Integer i = 0; i < saveResults.size(); i++) {
        Database.SaveResult saveResult = saveResults[i];
        PreviewRowDTO row = chunkRows[i];

        if (saveResult.isSuccess()) {
          result.successCount++;
          result.insertedIds.add(saveResult.getId());
          continue;
        }

        result.success = false;
        result.failCount++;
        String message = saveResult.getErrors().isEmpty() ? 'Unknown error' : saveResult.getErrors()[0].getMessage();
        result.errors.add(new RowErrorDTO(row.rowNumber, row.productCode, row.productName, message));
      }
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

    Integer productCodeIdx = headers.indexOf(COL_PRODUCT_CODE);
    if (productCodeIdx == -1) {
      throw new AuraHandledException('Required column ProductCode__c is missing.');
    }

    ParsedUpload parsed = new ParsedUpload();
    List<RawRow> rawRows = new List<RawRow>();
    Set<String> productCodes = new Set<String>();
    Set<String> seenProductCodes = new Set<String>();

    for (Integer i = 1; i < lines.size(); i++) {
      if (String.isBlank(lines[i])) {
        continue;
      }

      List<String> cols = splitCsvLine(lines[i]);
      Integer rowNumber = i + 1;
      String productCode = getColumnValue(cols, productCodeIdx);

      if (String.isBlank(productCode)) {
        parsed.errors.add(new RowErrorDTO(rowNumber, productCode, null, 'ProductCode__c is required.'));
        continue;
      }

      if (seenProductCodes.contains(productCode)) {
        parsed.errors.add(new RowErrorDTO(rowNumber, productCode, null, 'Duplicate product code in file.'));
        continue;
      }

      seenProductCodes.add(productCode);
      productCodes.add(productCode);
      rawRows.add(new RawRow(rowNumber, productCode));
    }

    Map<String, Product2> productByCode = new Map<String, Product2>();
    if (!productCodes.isEmpty()) {
      for (Product2 product : [
        SELECT Id, Name, ProductCode
        FROM Product2
        WHERE ProductCode IN :productCodes
      ]) {
        productByCode.put(product.ProductCode, product);
      }
    }

    enrichErrorProductNames(parsed.errors, productByCode);

    Set<Id> productIds = new Set<Id>();
    for (RawRow row : rawRows) {
      Product2 product = productByCode.get(row.productCode);
      if (product != null) {
        productIds.add(product.Id);
      }
    }

    Set<Id> existingProductIds = new Set<Id>();
    if (!productIds.isEmpty()) {
      for (PromotionProduct promotionProduct : [
        SELECT ProductId
        FROM PromotionProduct
        WHERE PromotionId = :promotionId AND ProductId IN :productIds
      ]) {
        existingProductIds.add(promotionProduct.ProductId);
      }
    }

    for (RawRow row : rawRows) {
      Product2 product = productByCode.get(row.productCode);
      if (product == null) {
        parsed.errors.add(new RowErrorDTO(row.rowNumber, row.productCode, null, 'Product not found.'));
        continue;
      }

      if (existingProductIds.contains(product.Id)) {
        parsed.errors.add(new RowErrorDTO(row.rowNumber, row.productCode, product.Name, 'PromotionProduct already exists.'));
        continue;
      }

      parsed.previewRows.add(
        new PreviewRowDTO(row.rowNumber, promotion.Id, promotion.PromotionNo__c, promotion.Name, product.Id, product.ProductCode, product.Name)
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

  private static void enrichErrorProductNames(List<RowErrorDTO> errors, Map<String, Product2> productByCode) {
    for (RowErrorDTO error : errors) {
      if (error == null || !String.isBlank(error.productName)) {
        continue;
      }

      Product2 product = productByCode.get(error.productCode);
      if (product != null) {
        error.productName = product.Name;
      }
    }
  }

  private static Integer getInsertChunkSize() {
    if (Test.isRunningTest() && testChunkSizeOverride != null && testChunkSizeOverride > 0) {
      return testChunkSizeOverride;
    }
    return INSERT_CHUNK_SIZE;
  }

  private class ParsedUpload {
    public List<PreviewRowDTO> previewRows = new List<PreviewRowDTO>();
    public List<RowErrorDTO> errors = new List<RowErrorDTO>();
  }

  private class RawRow {
    public Integer rowNumber;
    public String productCode;

    public RawRow(Integer rowNumber, String productCode) {
      this.rowNumber = rowNumber;
      this.productCode = productCode;
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
    public Id productId;
    @AuraEnabled
    public String productCode;
    @AuraEnabled
    public String productName;

    public PreviewRowDTO(
      Integer rowNumber,
      Id promotionId,
      String promotionNo,
      String promotionName,
      Id productId,
      String productCode,
      String productName
    ) {
      this.rowNumber = rowNumber;
      this.promotionId = promotionId;
      this.promotionNo = promotionNo;
      this.promotionName = promotionName;
      this.productId = productId;
      this.productCode = productCode;
      this.productName = productName;
    }
  }

  public class RowErrorDTO {
    @AuraEnabled
    public Integer rowNumber;
    @AuraEnabled
    public String productCode;
    @AuraEnabled
    public String productName;
    @AuraEnabled
    public String errorReason;

    public RowErrorDTO(Integer rowNumber, String productCode, String productName, String errorReason) {
      this.rowNumber = rowNumber;
      this.productCode = productCode;
      this.productName = productName;
      this.errorReason = errorReason;
    }
  }
}
