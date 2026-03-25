@IsTest
private class GdMemberDashboardControllerTest {

    @testSetup
    static void setupData() {
        Contact cWithPrev = new Contact(
            LastName = 'TierUser1',
            Grade__c = '02',
            PreviousGrade__c = '01',
            MemberNo__c = 'MT-001'
        );
        Contact cWithoutPrev = new Contact(
            LastName = 'TierUser2',
            Grade__c = '02',
            MemberNo__c = 'MT-002'
        );
        Contact cNoTier = new Contact(
            LastName = 'TierUser3',
            Grade__c = '02',
            PreviousGrade__c = '02',
            MemberNo__c = 'MT-003'
        );
        insert new List<Contact>{ cWithPrev, cWithoutPrev, cNoTier };

        LoyaltyProgram lp = new LoyaltyProgram(
            Name = 'TierProgram',
            IsPrimary = true
        );
        insert lp;

        LoyaltyProgramMember lpmWithPrev = new LoyaltyProgramMember(
            MembershipNumber = 'MT-001',
            MemberStatus = 'Active',
            MemberType = 'Individual',
            ContactId = cWithPrev.Id,
            EnrollmentDate = Date.today(),
            ProgramId = lp.Id
        );
        LoyaltyProgramMember lpmWithoutPrev = new LoyaltyProgramMember(
            MembershipNumber = 'MT-002',
            MemberStatus = 'Active',
            MemberType = 'Individual',
            ContactId = cWithoutPrev.Id,
            EnrollmentDate = Date.today(),
            ProgramId = lp.Id
        );
        LoyaltyProgramMember lpmNoTier = new LoyaltyProgramMember(
            MembershipNumber = 'MT-003',
            MemberStatus = 'Active',
            MemberType = 'Individual',
            ContactId = cNoTier.Id,
            EnrollmentDate = Date.today(),
            ProgramId = lp.Id
        );
        insert new List<LoyaltyProgramMember>{
            lpmWithPrev,
            lpmWithoutPrev,
            lpmNoTier
        };

        LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
            Name = 'Test Tier Group',
            LoyaltyProgramId = lp.Id,
            QpResetPeriod = 'Years',
            QpResetDate = Date.today(),
            QpResetFrequency = 1
        );
        insert tierGroup;

        LoyaltyTier tier = new LoyaltyTier(
            Name = 'Tier-Gold',
            LoyaltyTierGroupId = tierGroup.Id
        );
        insert tier;

        insert new List<LoyaltyMemberTier>{
            new LoyaltyMemberTier(
                LoyaltyMemberId = lpmWithPrev.Id,
                LoyaltyTierId = tier.Id,
                Name = '02',
                EffectiveDate = Date.today()
            ),
            new LoyaltyMemberTier(
                LoyaltyMemberId = lpmWithoutPrev.Id,
                LoyaltyTierId = tier.Id,
                Name = '02',
                EffectiveDate = Date.today()
            )
        };

        // 쿠폰 데이터
        insert new Voucher(
            LoyaltyProgramMemberId = lpmWithPrev.Id,
            Status = 'Issued',
            ExpirationDateTime = System.now().addDays(10),
            EffectiveDateTime = System.now(),
            EffectiveDate = Date.today()
        );
    }

    private static Id getMemberId(String memberNo) {
        return [
            SELECT Id
            FROM LoyaltyProgramMember
            WHERE MembershipNumber = :memberNo
            LIMIT 1
        ].Id;
    }

    @IsTest
    static void getMemberInfo_success() {

        Id lpmId = getMemberId('MT-001');

        Test.startTest();
        GdMemberDashboardController.MemberInfoDto result =
            GdMemberDashboardController.getMemebrInfo(lpmId);
        Test.stopTest();

        System.assertNotEquals(null, result);

        // benefit 검증
        System.assertEquals(0, result.benefit.ownedPoint);
        System.assertEquals(1, result.benefit.ownedCoupon);

        // grade 검증
        System.assertEquals('Tier-Gold', result.grade.currentGrade);
        System.assertEquals(0, result.grade.totalPurchaseAmount);
        System.assertNotEquals(null, result.grade.lastUpdatedDate);

        // marketing DTO 존재 확인
        System.assertNotEquals(null, result.marketing);
    }

    @IsTest
    static void getMemberInfo_noTierMember() {

        Id lpmId = getMemberId('MT-003');

        Boolean thrown = false;

        try {
            Test.startTest();
            GdMemberDashboardController.getMemebrInfo(lpmId);
            Test.stopTest();
        } catch (Exception e) {
            thrown = true;
        }

        System.assertEquals(true, thrown);
    }

}