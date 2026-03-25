@IsTest
private class GdMemberTierServiceImplTest {
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
            // 현재 등급 02와 일치하도록 수정
            new LoyaltyMemberTier(
                LoyaltyMemberId = lpmWithPrev.Id,
                LoyaltyTierId = tier.Id,
                Name = '02'
            ),
            new LoyaltyMemberTier(
                LoyaltyMemberId = lpmWithoutPrev.Id,
                LoyaltyTierId = tier.Id,
                Name = '02'
            )
        };
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
    static void resolveAccrualGrade_memberTierNotFound_throws() {
        GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
        Id lpmId = getMemberId('MT-003');

        Boolean thrown = false;

        try {
            svc.resolveAccrualGrade(lpmId, Date.today());
        } catch (Exception e) {
            thrown = true;
            System.assertNotEquals(null, e.getMessage());
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void resolveAccrualGrade_returnsCurrentGrade() {
        GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
        Id lpmId = getMemberId('MT-001');

        Test.startTest();
        String grade = svc.resolveAccrualGrade(lpmId, Date.today());
        Test.stopTest();

        System.assertEquals('02', grade);
    }

    @IsTest
    static void resolveAccrualGrade_returnsPreviousGrade_whenBeforeLastModified() {
        GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
        Id lpmId = getMemberId('MT-001');

        Test.startTest();
        String grade = svc.resolveAccrualGrade(lpmId, Date.today().addDays(-1));
        Test.stopTest();

        System.assertEquals('01', grade);
    }

    @IsTest
    static void resolveAccrualGrade_previousGradeMissing_throws() {
        GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
        Id lpmId = getMemberId('MT-002');

        Boolean thrown = false;

        try {
            svc.resolveAccrualGrade(lpmId, Date.today().addDays(-1));
        } catch (Exception e) {
            thrown = true;
            System.assertNotEquals(null, e.getMessage());
        }

        System.assertEquals(true, thrown);
    }
}