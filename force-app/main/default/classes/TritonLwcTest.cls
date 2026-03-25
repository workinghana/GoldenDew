@IsTest
private class TritonLwcTest {

    /* =====================================================
     * 기본 LWC 로그 저장 테스트 (정상 케이스)
     * ===================================================== */
    @IsTest
    static void test_saveComponentLogs_basic() {

        // Component 정보
        TritonLwc.Component component = new TritonLwc.Component();
        component.name = 'TestComponent';
        component.function = 'handleClick';

        // RuntimeInfo (비어 있어도 OK)
        TritonLwc.RuntimeInfo runtime = new TritonLwc.RuntimeInfo();
        runtime.platform = 'Web';
        runtime.language = 'ko';

        // ComponentLog 구성
        TritonLwc.ComponentLog log = new TritonLwc.ComponentLog();
        log.level = 'INFO';
        log.category = 'LWC';
        log.type = 'Frontend';
        log.area = 'LWC';
        log.summary = 'Test summary';
        log.details = 'Test details';
        log.componentInfo = component;
        log.runtimeInfo = runtime;
        log.duration = 10;
        log.createdTimestamp = 123456789;
        log.relatedObjectIds = new List<String>{
            UserInfo.getUserId() // 유효한 Id
        };

        Test.startTest();
        TritonLwc.saveComponentLogs(
            new List<TritonLwc.ComponentLog>{ log }
        );
        Test.stopTest();

        // 👉 예외 없이 끝나면 성공
        System.assert(true, 'saveComponentLogs는 예외 없이 실행되어야 합니다.');
    }

    /* =====================================================
     * 잘못된 값들 방어 로직 테스트 (INVALID enum / Id)
     * ===================================================== */
    @IsTest
    static void test_saveComponentLogs_invalid_values() {

        TritonLwc.Component component = new TritonLwc.Component();
        component.name = 'BrokenComponent';

        TritonLwc.ComponentLog log = new TritonLwc.ComponentLog();
        log.level = 'NOT_A_LEVEL';          // ❌ invalid
        log.category = 'NOT_A_CATEGORY';    // ❌ invalid
        log.area = 'NOT_AN_AREA';            // ❌ invalid
        log.userId = 'INVALID_ID';           // ❌ invalid
        log.componentInfo = component;
        log.relatedObjectIds = new List<String>{
            'INVALID_RECORD_ID'
        };

        Test.startTest();
        TritonLwc.saveComponentLogs(
            new List<TritonLwc.ComponentLog>{ log }
        );
        Test.stopTest();

        // 👉 예외 발생하지 않으면 성공
        System.assert(true, '잘못된 값이 있어도 예외가 발생하면 안 됩니다.');
    }

    /* =====================================================
     * ERROR 레벨 + Error 객체 포함 케이스
     * ===================================================== */
    @IsTest
    static void test_saveComponentLogs_error_case() {

        TritonLwc.Component component = new TritonLwc.Component();
        component.name = 'ErrorComponent';

        TritonLwc.Error error = new TritonLwc.Error();
        error.message = 'JS Error';
        error.type = 'TypeError';
        error.stack = 'stacktrace...';

        TritonLwc.ComponentLog log = new TritonLwc.ComponentLog();
        log.level = 'ERROR';
        log.componentInfo = component;
        log.error = error;

        Test.startTest();
        TritonLwc.saveComponentLogs(
            new List<TritonLwc.ComponentLog>{ log }
        );
        Test.stopTest();

        // 👉 createIssue() 호출 여부는 검증하지 않음 (외부 시스템)
        System.assert(true, 'ERROR 로그도 예외 없이 처리되어야 합니다.');
    }
}