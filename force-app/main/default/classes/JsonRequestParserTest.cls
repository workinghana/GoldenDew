@IsTest
private class JsonRequestParserTest {
    @IsTest
    static void parseToMap_success_returnsMap() {
        String body = '{"name":"Alice","age":20,"nested":{"k":"v"}}';

        Map<String, Object> result = JsonRequestParser.parseToMap(body);

        System.assertNotEquals(null, result);
        System.assertEquals('Alice', (String) result.get('name'));
        System.assertEquals(20, (Integer) result.get('age'));
        Map<String, Object> nested = (Map<String, Object>) result.get('nested');
        System.assertEquals('v', (String) nested.get('k'));
    }

    @IsTest
    static void parseToMap_blank_throwsValidationException() {
        Boolean thrown = false;

        try {
            JsonRequestParser.parseToMap('   ');
        } catch (ValidationException ve) {
            thrown = true;
            System.assertEquals('JsonRequestParser.parseToMap()', ve.methodName);
            System.assertEquals('Request body is empty.', ve.detail);
            System.assertEquals(400, ve.code);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void parseToMap_arrayBody_throwsValidationException() {
        Boolean thrown = false;

        try {
            JsonRequestParser.parseToMap('[{"a":1}]');
        } catch (ValidationException ve) {
            thrown = true;
            System.assertEquals('JsonRequestParser.parseToMap()', ve.methodName);
            System.assertEquals('Request body must be a JSON object.', ve.detail);
            System.assertEquals(400, ve.code);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void parseToMap_invalidJson_throwsValidationException() {
        Boolean thrown = false;

        try {
            JsonRequestParser.parseToMap('{"a":1');
        } catch (ValidationException ve) {
            thrown = true;
            System.assertEquals('JsonRequestParser.parseToMap()', ve.methodName);
            System.assert(ve.detail != null && ve.detail.startsWith('JSON 역직렬화 실패: '));
            System.assertEquals(400, ve.code);
        }

        System.assertEquals(true, thrown);
    }
}