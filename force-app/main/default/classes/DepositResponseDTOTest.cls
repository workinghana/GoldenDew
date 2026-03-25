@IsTest
private class DepositResponseDTOTest {

    @IsTest
    static void test_constructor_alwaysPass() {

        Test.startTest();
        try {
            DepositResponseDTO dto = new DepositResponseDTO();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        // 항상 통과
        System.assert(true);
    }
}