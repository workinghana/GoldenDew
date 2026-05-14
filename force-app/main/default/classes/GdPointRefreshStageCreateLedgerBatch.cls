public without sharing class GdPointRefreshStageCreateLedgerBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';
  private Id runId;
  private Integer journalCount = 0;
  private Integer ledgerCount = 0;
  private Map<String, Id> journalTypeIdByName = new Map<String, Id>();
  private Map<String, Id> journalSubTypeIdByKey = new Map<String, Id>();
  private Boolean autoContinue = false;
  private Boolean cleanupAfterComplete = false;

  public GdPointRefreshStageCreateLedgerBatch(Id runId) {
    this.runId = runId;
  }

  public GdPointRefreshStageCreateLedgerBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    return Database.getQueryLocator([
      SELECT
        Id,
        StageType__c,
        EventType__c,
        EventDate__c,
        EventKey__c,
        SourceKey__c,
        SaleNo__c,
        OriginKey__c,
        PointTypeCode__c,
        Points__c,
        RemainingPoints__c,
        ExpiryDate__c,
        SortKey__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId
      AND StageType__c IN ('PLAN_CREDIT', 'PLAN_DEBIT', 'PLAN_CREDIT_CANCEL_DEBIT')
      ORDER BY SortKey__c
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    GdPointRefreshRun__c run = [
      SELECT Id, MemberId__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    Id memberId = (Id) run.MemberId__c;
    Id loyaltyProgramId = [SELECT ProgramId FROM LoyaltyProgramMember WHERE Id = :memberId LIMIT 1].ProgramId;
    Id currencyId = [SELECT Id FROM LoyaltyProgramCurrency WHERE Name = :LOYALTY_PROGRAM_CURRENCY_NAME LIMIT 1].Id;

    List<GdPointRefreshStage__c> stages = new List<GdPointRefreshStage__c>();
    Set<String> saleNos = new Set<String>();
    Set<String> pointTypeCodes = new Set<String>();
    for (SObject row : scope) {
      GdPointRefreshStage__c stage = (GdPointRefreshStage__c) row;
      stages.add(stage);
      if (String.isNotBlank(stage.SaleNo__c) && stage.SaleNo__c != '-') {
        saleNos.add(stage.SaleNo__c);
      }
      if (String.isNotBlank(stage.PointTypeCode__c) && stage.PointTypeCode__c != '-') {
        pointTypeCodes.add(stage.PointTypeCode__c);
      }
    }

    Map<String, Order> orderBySaleNo = loadOrderBySaleNo(saleNos);
    Map<String, Id> subtypeIdByPointType = loadSubtypeIdByPointType(pointTypeCodes);

    List<TransactionJournal> journals = new List<TransactionJournal>();
    for (GdPointRefreshStage__c stage : stages) {
      journals.add(buildJournal(memberId, loyaltyProgramId, stage, orderBySaleNo));
    }
    insert journals;
    journalCount += journals.size();

    List<LoyaltyLedger> ledgers = new List<LoyaltyLedger>();
    for (Integer i = 0; i < stages.size(); i++) {
      GdPointRefreshStage__c stage = stages[i];
      LoyaltyLedger ll = new LoyaltyLedger();
      ll.EventType = stage.StageType__c == 'PLAN_CREDIT' ? 'Credit' : 'Debit';
      ll.LoyaltyProgramMemberId = memberId;
      ll.LoyaltyProgramCurrencyId = currencyId;
      if (subtypeIdByPointType.containsKey(stage.PointTypeCode__c)) {
        ll.LoyaltyPgmCrcySubtypeId = subtypeIdByPointType.get(stage.PointTypeCode__c);
      }
      ll.Points = stage.Points__c;
      ll.ActivityDate = toStartOfDay(stage.EventDate__c);
      ll.TransactionJournalId = journals[i].Id;
      ll.AdditionalNotes = buildLedgerNotes(stage);
      if (stage.StageType__c == 'PLAN_CREDIT') {
        ll.ExpiryDate = stage.ExpiryDate__c;
      }
      ledgers.add(ll);
    }
    insert ledgers;
    ledgerCount += ledgers.size();

    List<GdPointRefreshStage__c> updates = new List<GdPointRefreshStage__c>();
    for (Integer i = 0; i < stages.size(); i++) {
      updates.add(new GdPointRefreshStage__c(Id = stages[i].Id, TargetJournalId__c = String.valueOf(journals[i].Id), TargetLedgerId__c = String.valueOf(ledgers[i].Id)));
    }
    update updates;
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'LedgersCreated';
    run.CurrentStep__c = 'CREATED_JOURNALS_' + journalCount + '_LEDGERS_' + ledgerCount;
    update run;
    if (autoContinue) {
      Database.executeBatch(new GdPointRefreshStageCreateTraceBatch(runId, true, cleanupAfterComplete), 200);
    }
  }

  private TransactionJournal buildJournal(Id memberId, Id loyaltyProgramId, GdPointRefreshStage__c stage, Map<String, Order> orderBySaleNo) {
    TransactionJournal tj = new TransactionJournal();
    tj.MemberId = memberId;
    tj.LoyaltyProgramId = loyaltyProgramId;
    tj.Status = 'Processed';
    tj.JournalReason__c = '6';
    tj.TransactionAmount = stage.Points__c;
    tj.ActivityDate = toStartOfDay(stage.EventDate__c);
    tj.JournalDate = toStartOfDay(stage.EventDate__c);
    tj.AdditionalNotes__c = buildJournalNotes(stage);

    if (stage.StageType__c == 'PLAN_CREDIT') {
      tj.JournalTypeId = getJournalTypeId('Accrual');
      tj.JournalSubTypeId = getJournalSubTypeId(resolveCreditSubType(stage), tj.JournalTypeId);
    } else if (stage.StageType__c == 'PLAN_CREDIT_CANCEL_DEBIT') {
      tj.JournalTypeId = getJournalTypeId('Accrual Reversal');
      tj.JournalSubTypeId = getJournalSubTypeId(resolveCreditCancelSubType(stage), tj.JournalTypeId);
    } else {
      tj.JournalTypeId = getJournalTypeId('Redemption');
      tj.JournalSubTypeId = getJournalSubTypeId('Point Debit', tj.JournalTypeId);
    }

    Order order = String.isBlank(stage.SaleNo__c) || stage.SaleNo__c == '-' ? null : orderBySaleNo.get(stage.SaleNo__c);
    if (order != null) {
      if (order.IsReductionOrder__c == true) {
        tj.SaleId__c = order.Id;
      } else {
        tj.OrderId = order.Id;
      }
    }
    return tj;
  }

  private static String resolveCreditSubType(GdPointRefreshStage__c stage) {
    String key = String.valueOf(stage.EventKey__c).toUpperCase();
    if (key.startsWith('OPENING_USE_SOURCE:') || key.startsWith('OPENING:')) {
      return 'Api Forced Credit';
    }
    if (key.contains('DEBIT_CANCEL') && key.contains(':RESTORE:')) {
      return 'Point Redeem Cancel';
    }
    if (key.contains('PROMO')) {
      return 'Promotion Point Accrual';
    }
    return stage.SaleNo__c == '-' ? 'Api Forced Credit' : 'Purchase Accrual';
  }

  private static String resolveCreditCancelSubType(GdPointRefreshStage__c stage) {
    String key = String.valueOf(stage.EventKey__c).toUpperCase();
    return key.contains('PROMO') ? 'Promotion Point Accrual Reversal' : 'Cancel Purchase Accrual';
  }

  private static String buildLedgerNotes(GdPointRefreshStage__c stage) {
    String key = String.valueOf(stage.EventKey__c);
    String upperKey = key.toUpperCase();
    if (upperKey.startsWith('OPENING_USE_SOURCE:')) {
      return truncate('Option C credit lump for member ' + parseMemberNoFromOpeningKey(key), 255);
    }
    if (upperKey.startsWith('OPENING_USE:')) {
      return 'Option C use';
    }
    if (upperKey.startsWith('OPENING:')) {
      return truncate('Option C residual lump for ' + parseMemberNoFromOpeningKey(key), 255);
    }

    List<String> parts = new List<String>();
    if (String.isNotBlank(stage.OriginKey__c) && stage.OriginKey__c != '-' && stage.OriginKey__c != stage.EventKey__c) {
      parts.add('ORIGIN_KEY=' + stage.OriginKey__c);
      parts.add('ORIGIN_CREDIT_KEY=' + stage.OriginKey__c);
    }
    return parts.isEmpty() ? null : truncate(String.join(parts, ';'), 255);
  }

  private static String buildJournalNotes(GdPointRefreshStage__c stage) {
    String key = String.valueOf(stage.EventKey__c);
    String upperKey = key.toUpperCase();
    if (upperKey.startsWith('OPENING_USE_SOURCE:')) {
      return truncate('Option C credit lump for member ' + parseMemberNoFromOpeningKey(key) + ' (use_sum=' + formatDecimal(stage.Points__c) + ')', 255);
    }
    if (upperKey.startsWith('OPENING_USE:')) {
      return 'Option C use';
    }
    if (upperKey.startsWith('OPENING:')) {
      return truncate('Option C residual lump for ' + parseMemberNoFromOpeningKey(key) + ' (OpeningPointBalance__c)', 255);
    }
    return truncate('POINT_REFRESH_STAGE:' + stage.StageType__c + ':' + stage.EventKey__c, 255);
  }

  private static String parseMemberNoFromOpeningKey(String key) {
    if (String.isBlank(key)) {
      return '';
    }
    List<String> parts = key.split(':');
    if (parts.size() >= 2) {
      return parts[1];
    }
    return key;
  }

  private static String formatDecimal(Decimal value) {
    return value == null ? '0' : String.valueOf(value.setScale(0));
  }

  private static Map<String, Order> loadOrderBySaleNo(Set<String> saleNos) {
    Map<String, Order> result = new Map<String, Order>();
    if (saleNos == null || saleNos.isEmpty()) {
      return result;
    }
    for (Order order : [SELECT Id, SaleNo__c, IsReductionOrder__c FROM Order WHERE SaleNo__c IN :saleNos]) {
      result.put(order.SaleNo__c, order);
    }
    return result;
  }

  private static Map<String, Id> loadSubtypeIdByPointType(Set<String> pointTypeCodes) {
    Map<String, Id> result = new Map<String, Id>();
    if (pointTypeCodes == null || pointTypeCodes.isEmpty()) {
      return result;
    }
    for (LoyaltyPgmCurrencySubtype subtype : [
      SELECT Id, PointTypeCode__c
      FROM LoyaltyPgmCurrencySubtype
      WHERE PointTypeCode__c IN :pointTypeCodes
    ]) {
      if (!result.containsKey(subtype.PointTypeCode__c)) {
        result.put(subtype.PointTypeCode__c, subtype.Id);
      }
    }
    return result;
  }

  private Id getJournalTypeId(String name) {
    if (!journalTypeIdByName.containsKey(name)) {
      journalTypeIdByName.put(name, [SELECT Id FROM JournalType WHERE Name = :name LIMIT 1].Id);
    }
    return journalTypeIdByName.get(name);
  }

  private Id getJournalSubTypeId(String name, Id journalTypeId) {
    String key = String.valueOf(journalTypeId) + ':' + name;
    if (!journalSubTypeIdByKey.containsKey(key)) {
      journalSubTypeIdByKey.put(
        key,
        [
          SELECT Id
          FROM JournalSubType
          WHERE Name = :name AND JournalTypeId = :journalTypeId
          LIMIT 1
        ].Id
      );
    }
    return journalSubTypeIdByKey.get(key);
  }

  private static Datetime toStartOfDay(Date d) {
    return d == null ? Datetime.now() : TimeUtil.dateToUtcStartOfDay(d);
  }

  private static String truncate(String value, Integer maxLength) {
    if (value == null || maxLength == null || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }
}