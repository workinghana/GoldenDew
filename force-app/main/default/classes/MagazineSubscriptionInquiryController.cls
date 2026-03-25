/**
 * 매거진 구독 정보 페이지 컨트롤러
 * @author Changhwan Kim
 * @since 2026-02-26
 */
public with sharing class MagazineSubscriptionInquiryController {
  public class SearchResult {
    @AuraEnabled
    public List<Map<String, Object>> records;
    @AuraEnabled
    public Integer total;
    @AuraEnabled
    public Integer pageNumber;
    @AuraEnabled
    public Integer pageSize;

    public SearchResult(List<Map<String, Object>> records, Integer total, Integer pageNumber, Integer pageSize) {
      this.records = records;
      this.total = total;
      this.pageNumber = pageNumber;
      this.pageSize = pageSize;
    }
  }

  @AuraEnabled(cacheable=true)
  public static SearchResult search(
    String keyword,
    Date fromDate,
    Date toDate,
    String storeManaCode,
    String isSubscribed,
    Integer pageSize,
    Integer pageNumber,
    String sortBy,
    String sortDirection
  ) {
    if (pageSize == null || pageSize <= 0) {
      pageSize = 20;
    }
    if (pageSize > 200) {
      pageSize = 200;
    }
    if (pageNumber == null || pageNumber < 1) {
      pageNumber = 1;
    }

    String safeSortBy = String.isBlank(sortBy) ? 'Magazine_Response_Time__c' : sortBy;
    String dir = (sortDirection != null && sortDirection.toUpperCase() == 'ASC') ? 'ASC' : 'DESC';

    Set<String> allowedSort = new Set<String>{
      'Magazine_Response_Time__c',
      'Magazine_ApplicationDate__c',
      'Magazine_SentDate__c',
      'Magazine_Thisyear__c',
      'Magazine_StoreMana__c',
      'Magazine_A_Name__c',
      'CreatedDate'
    };
    if (!allowedSort.contains(safeSortBy)) {
      safeSortBy = 'Magazine_Response_Time__c';
    }

    List<String> whereParts = new List<String>();
    whereParts.add('UsageType__c = \'Magazine\'');

    if (fromDate != null) {
      whereParts.add('Magazine_ApplicationDate__c >= :fromDate');
    }
    if (toDate != null) {
      whereParts.add('Magazine_ApplicationDate__c <= :toDate');
    }
    if (!String.isBlank(storeManaCode)) {
      whereParts.add('Magazine_StoreMana__c = :storeManaCode');
    }
    if (!String.isBlank(isSubscribed)) {
      whereParts.add('Magazine_Ismagazinesubscribed__c = :isSubscribed');
    }

    String kw = keyword == null ? '' : keyword.trim();
    if (!String.isBlank(kw)) {
      String likeExpr = '%' + String.escapeSingleQuotes(kw) + '%';
      whereParts.add(
        '(' +
          'Magazine_A_Name__c LIKE :likeExpr OR ' +
          'Magazine_A_MobilePhone__c LIKE :likeExpr OR ' +
          'Magazine_A_ZIP_Code__c LIKE :likeExpr OR ' +
          'Magazine_uuid__c LIKE :likeExpr OR ' +
          'Magazine_Address__c LIKE :likeExpr' +
          ')'
      );
    }

    String whereClause = ' WHERE ' + String.join(whereParts, ' AND ');
    Integer offsetVal = (pageNumber - 1) * pageSize;

    String selectClause =
      'SELECT Id,' +
      ' Magazine_A_sns_YN__c,' +
      ' Magazine_A_Name__c,' +
      ' Magazine_A_account_YN__c,' +
      ' Magazine_StoreMana__c,' +
      ' Magazine_Season__c,' +
      ' Magazine_ApplicationDate__c,' +
      ' Magazine_Ismagazinesubscribed__c,' +
      ' Magazine_EXI_SUB_YN__c,' +
      ' Magazine_Thisyear__c,' +
      ' Magazine_SentDate__c,' +
      ' Magazine_A_Birthdate__c,' +
      ' Magazine_uuid__c,' +
      ' Magazine_IsUpdated__c,' +
      ' Magazine_A_ZIP_Code__c,' +
      ' Magazine_Response_Time__c,' +
      ' Magazine_A_Sub_Reason__c,' +
      ' Magazine_Address__c,' +
      ' Magazine_PUR_10YEAR_YN__c,' +
      ' Magazine_YN_NEWJOIN__c,' +
      ' Magazine_MemberType__c,' +
      ' Magazine_Grade__c,' +
      ' Magazine_A_MobilePhone__c,' +
      ' CreatedDate,' +
      ' MemberId,' +
      ' TYPEOF Member WHEN LoyaltyProgramMember THEN Contact.MemberNo__c, ContactId END' +
      ' FROM TransactionJournal';

    String soql = selectClause + whereClause + ' ORDER BY ' + safeSortBy + ' ' + dir + ' NULLS LAST' + ' LIMIT ' + pageSize + ' OFFSET ' + offsetVal;

    String countSoql = 'SELECT COUNT() FROM TransactionJournal' + whereClause;

    Integer total = (Integer) Database.countQuery(countSoql);
    List<TransactionJournal> rows = Database.query(soql);
    rows = (List<TransactionJournal>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();

    return new SearchResult(toRows(rows), total, pageNumber, pageSize);
  }

  private static List<Map<String, Object>> toRows(List<TransactionJournal> journals) {
    List<Map<String, Object>> results = new List<Map<String, Object>>();

    for (TransactionJournal journal : journals) {
      Map<String, Object> row = new Map<String, Object>();
      row.put('Id', journal.Id);
      row.put('Magazine_A_sns_YN__c', journal.Magazine_A_sns_YN__c);
      row.put('Magazine_A_Name__c', journal.Magazine_A_Name__c);
      row.put('Magazine_A_account_YN__c', journal.Magazine_A_account_YN__c);
      row.put('Magazine_StoreMana__c', journal.Magazine_StoreMana__c);
      row.put('Magazine_Season__c', journal.Magazine_Season__c);
      row.put('Magazine_ApplicationDate__c', journal.Magazine_ApplicationDate__c);
      row.put('Magazine_Ismagazinesubscribed__c', journal.Magazine_Ismagazinesubscribed__c);
      row.put('Magazine_EXI_SUB_YN__c', journal.Magazine_EXI_SUB_YN__c);
      row.put('Magazine_Thisyear__c', journal.Magazine_Thisyear__c);
      row.put('Magazine_SentDate__c', journal.Magazine_SentDate__c);
      row.put('Magazine_A_Birthdate__c', journal.Magazine_A_Birthdate__c);
      row.put('Magazine_uuid__c', journal.Magazine_uuid__c);
      row.put('Magazine_IsUpdated__c', journal.Magazine_IsUpdated__c);
      row.put('Magazine_A_ZIP_Code__c', journal.Magazine_A_ZIP_Code__c);
      row.put('Magazine_Response_Time__c', journal.Magazine_Response_Time__c);
      row.put('Magazine_A_Sub_Reason__c', journal.Magazine_A_Sub_Reason__c);
      row.put('Magazine_Address__c', journal.Magazine_Address__c);
      row.put('Magazine_PUR_10YEAR_YN__c', journal.Magazine_PUR_10YEAR_YN__c);
      row.put('Magazine_YN_NEWJOIN__c', journal.Magazine_YN_NEWJOIN__c);
      row.put('Magazine_MemberType__c', journal.Magazine_MemberType__c);
      row.put('Magazine_Grade__c', journal.Magazine_Grade__c);
      row.put('Magazine_A_MobilePhone__c', journal.Magazine_A_MobilePhone__c);
      row.put('CreatedDate', journal.CreatedDate);
      row.put('Magazine_MemberNo__c', extractMemberNo(journal));
      row.put('Magazine_MemberContactId__c', extractMemberRecordId(journal));
      results.add(row);
    }

    return results;
  }

  private static String extractMemberNo(TransactionJournal journal) {
    SObject memberRecord = journal.getSObject('Member');
    if (memberRecord == null || memberRecord.getSObjectType() != LoyaltyProgramMember.SObjectType) {
      return null;
    }

    SObject contactRecord = memberRecord.getSObject('Contact');
    return contactRecord == null ? null : (String) contactRecord.get('MemberNo__c');
  }

  private static Id extractMemberRecordId(TransactionJournal journal) {
    SObject memberRecord = journal.getSObject('Member');
    if (memberRecord == null || memberRecord.getSObjectType() != LoyaltyProgramMember.SObjectType) {
      return null;
    }

    Object memberIdValue = memberRecord.get('Id');
    return memberIdValue == null ? null : (Id) memberIdValue;
  }
}