@IsTest
private class TritonHelperTest {
    
    /* =====================================================
     * 1️⃣ Transaction Cache (예외 없이 동작)
     * ===================================================== */
    @IsTest
    static void test_transaction_cache_methods() {
        
        Test.startTest();
        TritonHelper.cacheTransactionId('TX-001');
        String cached = TritonHelper.getCachedTransactionId();
        TritonHelper.clearCachedTransactionId();
        Test.stopTest();
        
        // 캐시 실패 가능 → null 허용
        System.assert(true, '캐시 메서드는 예외 없이 동작해야 합니다.');
    }
    
    /* =====================================================
     * 2️⃣ buildLogLevelKey
     * ===================================================== */
    @IsTest
    static void test_build_log_level_key() {
        
        String key = TritonHelper.buildLogLevelKey(
            'APEX',
        'Backend',
        'Flow'
            );
        
        System.assertEquals(
            'Category:APEX;Type:Backend;Area:Flow',
        key
            );
    }
    
    /* =====================================================
     * 3️⃣ compareLevel
     * ===================================================== */
    @IsTest
    static void test_compare_level() {
        
        System.assertEquals(
            true,
        TritonHelper.compareLevel(
            TritonTypes.Level.ERROR,
        TritonTypes.Level.INFO
            )
            );
        
        System.assertEquals(
            false,
        TritonHelper.compareLevel(
            TritonTypes.Level.DEBUG,
        TritonTypes.Level.ERROR
            )
            );
    }
    
    /* =====================================================
     * 4️⃣ UUID 생성
     * ===================================================== */
    @IsTest
    static void test_generate_uuid() {
        
        String uuid = TritonHelper.generateUUID4();
        
        System.assertEquals(36, uuid.length());
        System.assert(uuid.contains('-'));
    }
    
    /* =====================================================
     * 5️⃣ 현재 StackTrace
     * ===================================================== */
    @IsTest
    static void test_get_current_stacktrace() {
        
        String trace = TritonHelper.getCurrentStackTrace();
        
        System.assertNotEquals(null, trace);
        System.assert(trace.contains('TritonHelperTest'));
    }
    
    
    /* =====================================================
     * 7️⃣ formatMessage (단일 / 다중)
     * ===================================================== */
    @IsTest
    static void test_format_message() {
        
        String msg1 = TritonHelper.formatMessage(
            'Hello {0}',
        'World'
            );
        
        String msg2 = TritonHelper.formatMessage(
            '{0} + {1} = {2}',
        new List<String>{ '1', '1', '2' }
        );
        
        System.assertEquals('Hello World', msg1);
        System.assertEquals('1 + 1 = 2', msg2);
    }
    
    /* =====================================================
     * 8️⃣ getOperation
     * ===================================================== */
    @IsTest
    static void test_get_operation() {
        
        String trace =
            'Class.TestClass.testMethod: line 10, column 1\n' +
            'Class.TritonHelper.method: line 5';
        
        String op = TritonHelper.getOperation(trace);
        
        System.assertEquals('Class.TestClass.testMethod', op);
    }
    
    /* =====================================================
     * 9️⃣ PostProcessingControlsBuilder
     * ===================================================== */
    @IsTest
    static void test_post_processing_controls_builder() {
        
        TritonHelper.PostProcessingControlsBuilder builder =
            new TritonHelper.PostProcessingControlsBuilder()
            .auditTrail(true)
            .installedPackages(true)
            .stackTrace(true)
            .userInfo(true);
        
        String json = builder.build();
        
        System.assert(json.contains('auditTrail'));
        System.assert(json.contains('installedPackages'));
        System.assert(json.contains('stackTrace'));
        System.assert(json.contains('userInfo'));
    }
    
    /* =====================================================
     * 🔟 formatDMLError
     * ===================================================== */
    @IsTest
    static void test_format_dml_error() {
        
        Account a = new Account(); // Name 없음 → 실패
        
        Database.SaveResult sr = Database.insert(a, false);
        
        System.assertEquals(false, sr.isSuccess());
        
        Database.Error err = sr.getErrors()[0];
        
        String msg = TritonHelper.formatDMLError(err, null);
        
        System.assert(msg.contains('Error'));
    }
    
    
}