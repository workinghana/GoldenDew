/**
 * MceEventReqDto 테스트 클래스
 * 커버리지 100% 목표
 */
@isTest
private class MceEventReqDtoTest {

    @isTest
    static void testSuccessScenario() {
        // 1. 정상적인 데이터 세팅 및 toMap 검증
        Map<String, Object> testData = new Map<String, Object>{
            'key1' => 'value1',
            'key2' => 100
        };

        Test.startTest();
        MceEventReqDto dto = new MceEventReqDto();
        dto.setContactKey('CONT_001');
        dto.setEventDefinitionKey('EVENT_KEY_ABC');
        dto.Data = testData;

        Map<String, Object> resultMap = dto.toMap();
        Test.stopTest();

        // 검증
        Assert.areEqual('CONT_001', resultMap.get('ContactKey'));
        Assert.areEqual('EVENT_KEY_ABC', resultMap.get('EventDefinitionKey'));
        Assert.areEqual(testData, resultMap.get('Data'));
    }

    @isTest
    static void testConstructorAndValidationExceptions() {
        // 2. 생성자 및 유효성 검사 실패 케이스 (Exception 커버)
        
        // 데이터 인자 생성자 테스트
        MceEventReqDto dtoWithData = new MceEventReqDto(new Map<String, Object>{'Test' => 'Val'});
        
        // Case A: ContactKey 누락
        try {
            dtoWithData.setEventDefinitionKey('EK');
            dtoWithData.toMap();
            Assert.fail('ContactKey가 없으면 예외가 발생해야 합니다.');
        } catch (MceApiClient.MceApiException e) {
            Assert.areEqual('ContactKey is required.', e.getMessage());
        }

        // Case B: EventDefinitionKey 누락
        try {
            MceEventReqDto dto2 = new MceEventReqDto();
            dto2.setContactKey('CK').toMap();
            Assert.fail('EventDefinitionKey가 없으면 예외가 발생해야 합니다.');
        } catch (MceApiClient.MceApiException e) {
            Assert.areEqual('EventDefinitionKey is required.', e.getMessage());
        }

        // Case C: Data 누락 (Null or Empty)
        try {
            MceEventReqDto dto3 = new MceEventReqDto();
            dto3.setContactKey('CK').setEventDefinitionKey('EK').toMap();
            Assert.fail('Data가 비어있으면 예외가 발생해야 합니다.');
        } catch (MceApiClient.MceApiException e) {
            Assert.areEqual('Data is required.', e.getMessage());
        }
    }

    @isTest
    static void testUtilityMethods() {
        // 3. buildPk 유틸리티 메서드 테스트
        String memberNo = 'MEM123';
        
        Test.startTest();
        String pk = MceEventReqDto.buildPk(memberNo);
        Test.stopTest();

        Assert.isTrue(pk.startsWith(memberNo), 'PK는 회원번호로 시작해야 합니다.');
        Assert.isTrue(pk.length() > memberNo.length(), 'PK에는 타임스탬프가 포함되어야 합니다.');
    }

    @isTest
    static void testInnerClasses() {
        // 4. 내부 클래스(CreditPoint, DebitPoint) 커버리지
        
        // CreditPoint 테스트 (단순 필드 할당)
        MceEventReqDto.CreditPoint cp = new MceEventReqDto.CreditPoint();
        cp.accountNumber = 'ACC001';
        cp.patronName = '홍길동';
        Assert.areEqual('ACC001', cp.accountNumber);

        // DebitPoint 테스트 (Map 기반 동작)
        MceEventReqDto.DebitPoint dp = new MceEventReqDto.DebitPoint();
        // payload가 private이므로 toMap/toJson을 통해 간접 검증
        Map<String, Object> dpMap = dp.toMap();
        Assert.isNotNull(dpMap);
        
        String jsonStr = dp.toJson();
        Assert.isNotNull(jsonStr);
    }
}