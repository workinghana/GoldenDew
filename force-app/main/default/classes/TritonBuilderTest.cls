@IsTest
private class TritonBuilderTest {

    /* =====================================================
     * 1. 기본 생성 테스트
     * ===================================================== */
    @IsTest
    static void test_constructor_and_build() {

        TritonBuilder builder = new TritonBuilder();

        pharos__Log__c log = builder.build();

        System.assertNotEquals(null, log, 'Log 객체는 생성되어야 합니다.');
        System.assertEquals(
            true,
            log.get(TritonBuilder.DO_NOT_CREATE_ISSUE),
            '기본적으로 이슈 생성은 false여야 합니다.'
        );
    }

    /* =====================================================
     * 2. Fluent API 체이닝 테스트
     * ===================================================== */
    @IsTest
    static void test_fluent_chaining() {

        TritonBuilder builder = new TritonBuilder()
            .category(TritonTypes.Category.APEX)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.RestAPI)
            .level(TritonTypes.Level.INFO)
            .operation('TestOperation')
            .summary('Summary')
            .details('Details')
            .transactionId('TX-001')
            .duration(123.45);

        pharos__Log__c log = builder.build();

        System.assertEquals(
            'TestOperation',
            log.get(TritonBuilder.APEX_NAME)
        );
        System.assertEquals(
            123.45,
            log.get(TritonBuilder.DURATION)
        );
    }

    /* =====================================================
     * 3. relatedObject / invalid Id 방어
     * ===================================================== */
    @IsTest
    static void test_related_objects() {

        Id userId = UserInfo.getUserId();

        TritonBuilder builder = new TritonBuilder()
            .relatedObject(userId)
            .relatedObject('INVALID_ID'); // 예외 없어야 함

        pharos__Log__c log = builder.build();

        String jsonIds = (String) log.get(TritonBuilder.RELATED_OBJECTS);
        System.assert(jsonIds.contains((String) userId));
    }

    /* =====================================================
     * 4. exception(Exception e) 설정 테스트
     * ===================================================== */
    @IsTest
    static void test_exception_builder() {

        Exception ex;
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ex = e;
        }

        TritonBuilder builder = new TritonBuilder()
            .exception(ex);

        pharos__Log__c log = builder.build();

        System.assertEquals(
            TritonTypes.Level.ERROR.name(),
            log.get(TritonBuilder.LOG_LEVEL),
            'ERROR 레벨이어야 합니다.'
        );

        System.assert(
            String.valueOf(log.get('Summary__c')).contains('Divide'),
            '에러 메시지가 summary에 들어가야 합니다.'
        );
    }

    /* =====================================================
     * 5. cloneBuilder 테스트
     * ===================================================== */
    @IsTest
    static void test_clone_builder() {

        TritonBuilder original = new TritonBuilder()
            .operation('OriginalOp')
            .duration(10);

        TritonBuilder cloned = original.cloneBuilder();

        pharos__Log__c log = cloned.build();

        System.assertEquals(
            'OriginalOp',
            log.get(TritonBuilder.APEX_NAME)
        );
        System.assertEquals(
            10,
            log.get(TritonBuilder.DURATION)
        );
    }

    /* =====================================================
     * 6. limitInfo() 실행 커버
     * ===================================================== */
    @IsTest
    static void test_limit_info() {

        TritonBuilder builder = new TritonBuilder()
            .limitInfo();

        pharos__Log__c log = builder.build();

        System.assertNotEquals(
            null,
            log.get(TritonBuilder.CPU_TIME),
            'Limit 정보는 설정되어야 합니다.'
        );
    }
}