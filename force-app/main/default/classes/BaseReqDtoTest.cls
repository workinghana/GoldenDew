@IsTest
private class BaseReqDtoTest {
    private class TestReqDto extends BaseReqDto {
        TestReqDto(Map<String, Object> raw) {
            super(raw);
        }

        public String getS(String key, String fieldName, Boolean required) {
            return s(key, fieldName, required);
        }

        public String getSEx(String key, String fieldName, Boolean required, Boolean allowBlank) {
            return sEx(key, fieldName, required, allowBlank);
        }

        public Boolean getB(String key, String fieldName, Boolean required) {
            return b(key, fieldName, required);
        }

        public Date getDt(String key, String fieldName, Boolean required) {
            return dt(key, fieldName, required);
        }

        public Datetime getDttm(String key, String fieldName, Boolean required) {
            return dttm(key, fieldName, required);
        }

        public Integer getI(String key, String fieldName, Boolean required) {
            return i(key, fieldName, required);
        }

        public Decimal getD(String key, String fieldName, Boolean required) {
            return d(key, fieldName, required);
        }

        public Map<String, Object> getM(String key, String fieldName, Boolean required) {
            return m(key, fieldName, required);
        }

        public List<Object> getL(String key, String fieldName, Boolean required) {
            return l(key, fieldName, required);
        }

        public Map<String, Object> getAsMap(Object v, String fieldName, Boolean required) {
            return asMap(v, fieldName, required);
        }
    }

    @IsTest
    static void test_constructor_and_getRaw() {
        TestReqDto dto = new TestReqDto(null);

        System.assertNotEquals(null, dto.getRaw());
        System.assertEquals(0, dto.getRaw().size());
    }

    @IsTest
    static void test_primitive_and_collection_getters_success() {
        Date today = Date.today();
        Datetime nowDt = Datetime.newInstance(2026, 1, 2, 3, 4, 5);

        Map<String, Object> nestedMap = new Map<String, Object>{ 'k1' => 'v1' };
        List<Object> listVal = new List<Object>{ 'x', 1 };

        Map<String, Object> raw = new Map<String, Object>{
            'sKey' => 'abc',
            'sExKey' => '',
            'bKey' => true,
            'dtKey' => String.valueOf(today),
            'dttmKey' => '2026-01-02 03:04:05',
            'iFromDecimal' => 12.9,
            'iFromString' => '34',
            'dFromInt' => 5,
            'dFromString' => '12.34',
            'mKey' => nestedMap,
            'lKey' => listVal,
            'objMap' => new Map<String, Object>{ 'a' => 'b' }
        };

        TestReqDto dto = new TestReqDto(raw);

        System.assertEquals('abc', dto.getS('sKey', 'sKey', true));
        System.assertEquals('', dto.getSEx('sExKey', 'sExKey', true, true));
        System.assertEquals(true, dto.getB('bKey', 'bKey', true));
        System.assertEquals(today, dto.getDt('dtKey', 'dtKey', true));
        System.assertEquals(nowDt, dto.getDttm('dttmKey', 'dttmKey', true));

        System.assertEquals(12, dto.getI('iFromDecimal', 'iFromDecimal', true));
        System.assertEquals(34, dto.getI('iFromString', 'iFromString', true));

        System.assertEquals(Decimal.valueOf('5'), dto.getD('dFromInt', 'dFromInt', true));
        System.assertEquals(Decimal.valueOf('12.34'), dto.getD('dFromString', 'dFromString', true));

        System.assertEquals('v1', (String) dto.getM('mKey', 'mKey', true).get('k1'));
        System.assertEquals(2, dto.getL('lKey', 'lKey', true).size());
        System.assertEquals('b', (String) dto.getAsMap(raw.get('objMap'), 'objMap', true).get('a'));
    }

    @IsTest
    static void test_optional_null_returns_null() {
        TestReqDto dto = new TestReqDto(new Map<String, Object>());

        System.assertEquals(null, dto.getS('missing', 'missing', false));
        System.assertEquals(null, dto.getB('missing', 'missing', false));
        System.assertEquals(null, dto.getDt('missing', 'missing', false));
        System.assertEquals(null, dto.getDttm('missing', 'missing', false));
        System.assertEquals(null, dto.getI('missing', 'missing', false));
        System.assertEquals(null, dto.getD('missing', 'missing', false));
        System.assertEquals(null, dto.getM('missing', 'missing', false));
        System.assertEquals(null, dto.getL('missing', 'missing', false));
    }

    @IsTest
    static void test_i_and_d_invalid_type_throw() {
        TestReqDto dto = new TestReqDto(
            new Map<String, Object>{ 'badInt' => Date.today(), 'badDecimal' => Date.today() }
        );

        try {
            dto.getI('badInt', 'badInt', true);
            System.assert(false, 'ValidationException expected for i() invalid type.');
        } catch (ValidationException e) {
            System.assert(true);
        }

        try {
            dto.getD('badDecimal', 'badDecimal', true);
            System.assert(false, 'ValidationException expected for d() invalid type.');
        } catch (ValidationException e) {
            System.assert(true);
        }
    }
}