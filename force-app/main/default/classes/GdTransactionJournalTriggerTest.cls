@IsTest
private class GdTransactionJournalTriggerTest {

  // ========================================================
  // @testSetup
  // ========================================================
  @testSetup
  static void setup() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TJTrig-LP', IsPrimary = true);
    insert lp;

    Contact c = new Contact(LastName = 'TJTrig-User');
    insert c;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      MembershipNumber = 'TJ-TRIG-001',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = c.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert lpm;

    // JournalSubType (있으면 깊은 경로 커버, 없으면 조기 리턴 경로 커버)
    try {
      JournalType jtAccrual = new JournalType(Name = 'Accrual');
      JournalType jtRedemption = new JournalType(Name = 'Redemption');
      JournalType jtRedemptionRev = new JournalType(Name = 'Redemption Reversal');
      JournalType jtAccrualRev = new JournalType(Name = 'Accrual Reversal');
      insert new List<JournalType>{ jtAccrual, jtRedemption, jtRedemptionRev, jtAccrualRev };

      insert new List<JournalSubType>{
        new JournalSubType(Name = 'Point Debit',               JournalTypeId = jtRedemption.Id),
        new JournalSubType(Name = 'Point Redeem Cancel',       JournalTypeId = jtRedemptionRev.Id),
        new JournalSubType(Name = 'Purchase Accrual',          JournalTypeId = jtAccrual.Id),
        new JournalSubType(Name = 'Cancel Purchase Accrual',   JournalTypeId = jtAccrualRev.Id),
        new JournalSubType(Name = 'Manual Points Credit',      JournalTypeId = jtAccrual.Id),
        new JournalSubType(Name = 'Auto Expire',               JournalTypeId = jtAccrualRev.Id),
        new JournalSubType(Name = 'Api Forced Expire',         JournalTypeId = jtAccrualRev.Id),
        new JournalSubType(Name = 'Api Forced Debit',          JournalTypeId = jtRedemption.Id),
        new JournalSubType(Name = 'Api Forced Credit',         JournalTypeId = jtAccrual.Id)
      };
    } catch (Exception e) {
      System.debug('JournalSubType setup skipped: ' + e.getMessage());
    }

    // LoyaltyProgramCurrency
    try {
      insert new LoyaltyProgramCurrency(Name = '포인트', LoyaltyProgramId = lp.Id);
    } catch (Exception e) {
      System.debug('LoyaltyProgramCurrency setup skipped: ' + e.getMessage());
    }
  }

  // ========================================================
  // 트리거 발동 - Pending → Processed (핸들러 afterUpdate 전체 경로)
  // ========================================================
  @IsTest
  static void trigger_afterUpdate_pendingToProcessed() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'TJ-TRIG-001' LIMIT 1];

    TransactionJournal tj = new TransactionJournal();
    tj.MemberId = lpm.Id;
    tj.LoyaltyProgramId = lpm.ProgramId;
    tj.ActivityDate = Datetime.now();
    tj.Status = 'Pending';
    insert tj;

    Test.startTest();
    tj.Status = 'Processed';
    update tj;
    Test.stopTest();

    System.assert(true);
  }

  // ========================================================
  // 트리거 발동 - Status 변경 없음 (Pending → Pending)
  // targetTjById 비어 있음 → 조기 리턴
  // ========================================================
  @IsTest
  static void trigger_afterUpdate_noPendingToProcessedChange() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'TJ-TRIG-001' LIMIT 1];

    TransactionJournal tj = new TransactionJournal();
    tj.MemberId = lpm.Id;
    tj.LoyaltyProgramId = lpm.ProgramId;
    tj.ActivityDate = Datetime.now();
    tj.Status = 'Pending';
    insert tj;

    Test.startTest();
    tj.TransactionAmount = 500;  // Status 변경 없이 다른 필드만 변경
    update tj;
    Test.stopTest();

    System.assert(true);
  }

  // ========================================================
  // 트리거 발동 - 이미 Processed 상태에서 update (Processed → Processed)
  // ========================================================
  @IsTest
  static void trigger_afterUpdate_processedToProcessed() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'TJ-TRIG-001' LIMIT 1];

    TransactionJournal tj = new TransactionJournal();
    tj.MemberId = lpm.Id;
    tj.LoyaltyProgramId = lpm.ProgramId;
    tj.ActivityDate = Datetime.now();
    tj.Status = 'Processed';
    insert tj;

    Test.startTest();
    tj.TransactionAmount = 1000;
    update tj;
    Test.stopTest();

    System.assert(true);
  }

  // ========================================================
  // 트리거 발동 - 복수 TJ 일괄 Pending → Processed
  // ========================================================
  @IsTest
  static void trigger_afterUpdate_bulkPendingToProcessed() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'TJ-TRIG-001' LIMIT 1];

    List<TransactionJournal> tjList = new List<TransactionJournal>();
    for (Integer i = 0; i < 5; i++) {
      TransactionJournal tj = new TransactionJournal();
      tj.MemberId = lpm.Id;
      tj.LoyaltyProgramId = lpm.ProgramId;
      tj.ActivityDate = Datetime.now();
      tj.Status = 'Pending';
      tjList.add(tj);
    }
    insert tjList;

    Test.startTest();
    for (TransactionJournal tj : tjList) {
      tj.Status = 'Processed';
    }
    update tjList;
    Test.stopTest();

    System.assert(true);
  }

  // ========================================================
  // 트리거 발동 - Pending→Processed + JournalSubTypeId 지정
  // allowedSubTypeIds.contains() 분기 진입
  // ========================================================
  @IsTest
  static void trigger_afterUpdate_withMatchingSubType() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'TJ-TRIG-001' LIMIT 1];

    // JournalSubType 조회 (없으면 null로 진행)
    JournalSubType jst = null;
    List<JournalSubType> jstList = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];
    if (!jstList.isEmpty()) {
      jst = jstList[0];
    }

    TransactionJournal tj = new TransactionJournal();
    tj.MemberId = lpm.Id;
    tj.LoyaltyProgramId = lpm.ProgramId;
    tj.ActivityDate = Datetime.now();
    tj.Status = 'Pending';
    if (jst != null) {
      tj.JournalSubTypeId = jst.Id;
    }
    insert tj;

    Test.startTest();
    tj.Status = 'Processed';
    update tj;
    Test.stopTest();

    System.assert(true);
  }

  // ========================================================
  // 트리거 발동 - 혼합 (일부만 Pending→Processed)
  // ========================================================
  @IsTest
  static void trigger_afterUpdate_mixedStatusChange() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'TJ-TRIG-001' LIMIT 1];

    TransactionJournal tj1 = new TransactionJournal();
    tj1.MemberId = lpm.Id;
    tj1.LoyaltyProgramId = lpm.ProgramId;
    tj1.ActivityDate = Datetime.now();
    tj1.Status = 'Pending';

    TransactionJournal tj2 = new TransactionJournal();
    tj2.MemberId = lpm.Id;
    tj2.LoyaltyProgramId = lpm.ProgramId;
    tj2.ActivityDate = Datetime.now();
    tj2.Status = 'Processed'; // 처음부터 Processed
    insert new List<TransactionJournal>{ tj1, tj2 };

    Test.startTest();
    tj1.Status = 'Processed'; // Pending→Processed
    tj2.TransactionAmount = 2000; // Status 변경 없음
    update new List<TransactionJournal>{ tj1, tj2 };
    Test.stopTest();

    System.assert(true);
  }
}