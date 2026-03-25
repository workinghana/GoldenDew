@IsTest
private class VoucherDefinitionTriggerTest {
    @IsTest
    static void testTrigger() {
        LoyaltyProgram lp = new LoyaltyProgram(Name = 'Test Program');
        insert lp;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        VoucherCategory__c vc = new VoucherCategory__c(Name = 'Test Category', Code__c = 'TEST');
        insert vc;

        VoucherDefinition vd = new VoucherDefinition(
            Name = 'Test Voucher',
            LoyaltyProgramId = lp.Id,
            IsActive = true,
            ProductId = prod.Id,
            Type = 'ProductOrService',
            ExpirationType = 'FixedDate',
            ExpirationDate = Date.today().addDays(30),
            EffectiveDate = Date.today(),
            VoucherCategoryId__c = vc.Id,
            CouponManNo__c = 'MAN001',
            CouponTypeCode__c = '01',
            ResponsibleDepartment__c = 'Marketing',
            InsertId__c = 'TestUser',
            ResponsiblePerson__c = 'Manager'
        );

        Test.startTest();
        insert vd;
        vd.Name = 'Updated';
        update vd;
        delete vd;
        Test.stopTest();
    }
}