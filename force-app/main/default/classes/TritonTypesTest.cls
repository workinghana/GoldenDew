@IsTest
private class TritonTypesTest {

    /* =====================================================
     * Area enum 테스트
     * ===================================================== */
    @IsTest
    static void test_area_enum() {

        // valueOf
        TritonTypes.Area area = TritonTypes.Area.valueOf('LWC');
        System.assertEquals(TritonTypes.Area.LWC, area);

        // name
        System.assertEquals('Flow', TritonTypes.Area.Flow.name());

        // values
        System.assert(TritonTypes.Area.values().size() > 0);
    }

    /* =====================================================
     * Category enum 테스트
     * ===================================================== */
    @IsTest
    static void test_category_enum() {

        TritonTypes.Category cat = TritonTypes.Category.valueOf('Apex');
        System.assertEquals(TritonTypes.Category.Apex, cat);

        System.assertEquals('Integration', TritonTypes.Category.Integration.name());

        System.assert(TritonTypes.Category.values().size() > 0);
    }

    /* =====================================================
     * Level enum 테스트
     * ===================================================== */
    @IsTest
    static void test_level_enum() {

        TritonTypes.Level level = TritonTypes.Level.valueOf('ERROR');
        System.assertEquals(TritonTypes.Level.ERROR, level);

        // ordinal 순서 검증 (로그 레벨 비교에 중요)
        System.assert(
            TritonTypes.Level.ERROR.ordinal() <
            TritonTypes.Level.INFO.ordinal()
        );

        System.assert(TritonTypes.Level.values().size() >= 3);
    }

    /* =====================================================
     * Type enum 테스트
     * ===================================================== */
    @IsTest
    static void test_type_enum() {

        TritonTypes.Type type = TritonTypes.Type.valueOf('Backend');
        System.assertEquals(TritonTypes.Type.Backend, type);

        System.assertEquals('Frontend', TritonTypes.Type.Frontend.name());

        System.assert(TritonTypes.Type.values().size() > 0);
    }
}