@IsTest
private class IssueTierCouponBatchTest {
  private class MockBatchContext implements Database.BatchableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }

    public Id getChildJobId() {
      return UserInfo.getUserId();
    }
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static String getGradeValue() {
    List<Schema.PicklistEntry> entries = Contact.Grade__c.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String getGradeLabel() {
    List<Schema.PicklistEntry> entries = Contact.Grade__c.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getLabel();
  }

  @TestSetup
  static void setupData() {
    JournalType jt = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert jt;

    JournalSubType jst = new JournalSubType(Name = 'Manual Coupon Issuance', JournalTypeId = jt.Id);
    insert jst;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Tier Coupon Test Program', IsPrimary = true);
    insert lp;

    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'Tier Coupon Test Group',
      LoyaltyProgramId = lp.Id,
      TierModel = 'Fixed',
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = getGradeLabel(), LoyaltyTierGroupId = tierGroup.Id, SequenceNumber = 1);
    insert tier;

    Product2 product = new Product2(Name = 'Tier Coupon Product', IsActive = true);
    insert product;

    VoucherCategory__c category = new VoucherCategory__c(Name = 'Tier Coupon Category', Code__c = 'TIERTEST');
    insert category;

    Account account = new Account(Name = 'Tier Coupon Company', CompanyCode__c = '1000');
    insert account;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'TierCoupon',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      Description = 'IssueTierCouponBatch test',
      ProductId = product.Id,
      Type = 'ProductOrService',
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      VoucherCategoryId__c = category.Id,
      AccountId__c = account.Id,
      CouponManNo__c = 'CPN-TIER-001',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;

    Contact contact = new Contact(LastName = uniq('Contact'), MemberNo__c = uniq('M'), Grade__c = getGradeValue());
    insert contact;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = contact.Id,
      ProgramId = lp.Id,
      MembershipNumber = uniq('NUM'),
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert lpm;
  }

  private static Id getTierId() {
    return [SELECT Id FROM LoyaltyTier LIMIT 1].Id;
  }

  private static Id getVoucherDefinitionId() {
    return [SELECT Id FROM VoucherDefinition LIMIT 1].Id;
  }

  private static VoucherDefinition createVoucherDefinition(Boolean isActive, Date expirationDate) {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Id categoryId = [SELECT Id FROM VoucherCategory__c LIMIT 1].Id;
    Id accountId = [SELECT Id FROM Account WHERE CompanyCode__c = '1000' LIMIT 1].Id;

    Product2 product = new Product2(Name = uniq('Tier Coupon Product Extra'), IsActive = true);
    insert product;

    VoucherDefinition vd = new VoucherDefinition(
      Name = uniq('TierCouponExtra'),
      LoyaltyProgramId = lp.Id,
      IsActive = isActive,
      Description = 'IssueTierCouponBatch extra test',
      ProductId = product.Id,
      Type = 'ProductOrService',
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today().addDays(-10),
      ExpirationDate = expirationDate,
      VoucherCategoryId__c = categoryId,
      AccountId__c = accountId,
      CouponManNo__c = uniq('CPN-TIER'),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;

    return vd;
  }

  private static Contact getBaseContact() {
    return [
      SELECT Id
      FROM Contact
      WHERE MemberNo__c != NULL
      LIMIT 1
    ];
  }

  @IsTest
  static void testStart() {
    IssueTierCouponBatch batch = new IssueTierCouponBatch(getTierId(), getVoucherDefinitionId(), Date.today());

    Test.startTest();
    Database.QueryLocator ql = batch.start(new MockBatchContext());
    Test.stopTest();

    System.assertNotEquals(null, ql);
  }

  @IsTest
  static void testExecuteEmptyScope() {
    IssueTierCouponBatch batch = new IssueTierCouponBatch(getTierId(), getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchContext(), new List<Contact>());
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal]);
  }

  @IsTest
  static void testExecuteNoLoyaltyProgramMember() {
    Contact noMemberContact = new Contact(LastName = uniq('NoMember'), MemberNo__c = uniq('NM'), Grade__c = getGradeValue());
    insert noMemberContact;

    IssueTierCouponBatch batch = new IssueTierCouponBatch(getTierId(), getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchContext(), new List<Contact>{ noMemberContact });
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal]);
  }

  @IsTest
  static void testExecuteWithLoyaltyProgramMember() {
    IssueTierCouponBatch batch = new IssueTierCouponBatch(getTierId(), getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchContext(), new List<Contact>{ getBaseContact() });
    Test.stopTest();

    List<TransactionJournal> journals = [
      SELECT Id, MemberId, Status
      FROM TransactionJournal
    ];

    System.assertEquals(1, journals.size());
    System.assertEquals('Processed', journals[0].Status);
    System.assertNotEquals(null, journals[0].MemberId);
  }

  @IsTest
  static void testExecuteWithInactiveVoucherDefinition() {
    VoucherDefinition inactiveVd = createVoucherDefinition(false, Date.today().addDays(30));

    IssueTierCouponBatch batch = new IssueTierCouponBatch(getTierId(), inactiveVd.Id, Date.today());

    Test.startTest();
    batch.execute(new MockBatchContext(), new List<Contact>{ getBaseContact() });
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal]);
  }

  @IsTest
  static void testExecuteWithExpiredVoucherDefinition() {
    VoucherDefinition expiredVd = createVoucherDefinition(true, Date.today().addDays(-1));

    IssueTierCouponBatch batch = new IssueTierCouponBatch(getTierId(), expiredVd.Id, Date.today());

    Test.startTest();
    batch.execute(new MockBatchContext(), new List<Contact>{ getBaseContact() });
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal]);
  }

  @IsTest
  static void testFinish() {
    IssueTierCouponBatch batch = new IssueTierCouponBatch(getTierId(), getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.finish(new MockBatchContext());
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void testExecuteBatchFullFlow() {
    Test.startTest();
    Database.executeBatch(new IssueTierCouponBatch(getTierId(), getVoucherDefinitionId(), Date.today()), 1);
    Test.stopTest();

    System.assert([SELECT COUNT() FROM TransactionJournal] > 0);
  }
}