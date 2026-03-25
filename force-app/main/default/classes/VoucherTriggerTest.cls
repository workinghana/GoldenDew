@IsTest
private class VoucherTriggerTest {

    @TestSetup
    static void setupTestData() {
        // 필수 연관 데이터 세팅
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
        insert vd;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id, MemberNo__c = 'M001');
        insert con;

        // 테스트용 Voucher 생성
        Voucher v = new Voucher(
            VoucherDefinitionId = vd.Id,
            ContactId = con.Id,
            Status = 'Issued', 
            EffectiveDate = Date.today(),
            ExpirationDate = Date.today().addDays(30)
        );
        insert v;
    }

    @IsTest
    static void testVoucherTriggerExecution() {
        // Given: 생성된 Voucher를 가져옵니다.
        Voucher testVoucher = [SELECT Id, Status FROM Voucher LIMIT 1];
        
        Test.startTest();
        
        // When: Voucher를 업데이트하여 VoucherTrigger(after update)를 강제로 실행시킵니다.
        testVoucher.Status = 'Expired'; 
        update testVoucher; 
        
        Test.stopTest();
        
        // Then: 트리거가 에러 없이 정상적으로 실행(update 성공)되었는지 검증합니다.
        Voucher updatedVoucher = [SELECT Id, Status FROM Voucher WHERE Id = :testVoucher.Id];
    }
}