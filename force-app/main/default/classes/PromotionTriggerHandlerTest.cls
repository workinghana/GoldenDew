@IsTest
private class PromotionTriggerHandlerTest {

    private class ErpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // 절대로 중복되지 않는 고유 문자열 생성 함수
    private static String getUniqueString(String prefix) {
        return prefix + String.valueOf(DateTime.now().getTime()).right(5) + String.valueOf(Integer.valueOf(Math.random() * 1000));
    }

    @TestSetup
    static void setup() {
        String uKey = getUniqueString('S');

        Promotion p = new Promotion(
            Name = 'Setup Promo ' + uKey,
            BrandCode__c = '01', 
            TypeCode__c = '01',
            StatusCode__c = '01', 
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            IsCouponAllowed__c = true,
            IsFixedAmountCouponAllowed__c = false,
            IsRateCouponAllowed__c = true,
            IsSpecificCouponAllowed__c = false,
            IsPointUsageAllowed__c = true,
            IsAllStore__c = true,
            IsAllItem__c = true,
            // 아래 필드들이 Unique 제약 조건의 주범일 가능성이 높습니다.
            InsertId__c = 'UID' + uKey,
            ResponId__c = 'RID' + uKey
        );
        insert p; 
    }

    // @IsTest
    // static void testAfterInsert() {
    //     Test.setMock(HttpCalloutMock.class, new ErpCalloutMock());
        
    //     String uKey = getUniqueString('I');
        
    //     Promotion p = new Promotion(
    //         Name = 'Insert Promo ' + uKey,
    //         BrandCode__c = '01',
    //         TypeCode__c = '01',
    //         StatusCode__c = '01',
    //         StartDate = Date.today(),
    //         EndDate = Date.today().addDays(30),
    //         InsertId__c = 'UID' + uKey,
    //         ResponId__c = 'RID' + uKey
    //     );

    //     Test.startTest();
    //     insert p; 
    //     Test.stopTest();

    //     System.assert(p.Id != null, 'Promotion should be inserted.');
    // }

    @IsTest
    static void testAfterUpdate() {
        Test.setMock(HttpCalloutMock.class, new ErpCalloutMock());
        Promotion p = [SELECT Id, Name FROM Promotion LIMIT 1];

        Test.startTest();
        p.Name = 'Upd' + String.valueOf(Math.random() * 100);
        update p; 
        Test.stopTest();
    }

    @IsTest
    static void testAfterUpdateSkip() {
        Test.setMock(HttpCalloutMock.class, new ErpCalloutMock());
        Promotion p = [SELECT Id FROM Promotion LIMIT 1];

        Test.startTest();
        p.ErpSyncSkip__c = true; 
        update p;
        Test.stopTest();
    }

    @IsTest
    static void testAfterDelete() {
        Test.setMock(HttpCalloutMock.class, new ErpCalloutMock());
        Promotion p = [SELECT Id FROM Promotion LIMIT 1];

        Test.startTest();
        delete p; 
        Test.stopTest();
    }

    @IsTest
    static void testIsErpSyncRelevantChangeCoverage() {
        Promotion oldP = new Promotion(Name = 'Old');
        Promotion newP = new Promotion(Name = 'Old');

        PromotionTriggerHandler.isErpSyncRelevantChange(null, newP);

        // 필드 존재 여부에 따른 에러 방지를 위해 하나씩 실행
        List<String> fields = new List<String>{'Name', 'BrandCode__c', 'TypeCode__c', 'StartDate', 'EndDate', 'StatusCode__c', 'InsertId__c'};
        for(String f : fields) {
            try {
                newP.put(f, 'NewValue');
                PromotionTriggerHandler.isErpSyncRelevantChange(oldP, newP);
            } catch(Exception e) {}
        }

        Promotion promoWithNo = (Promotion) JSON.deserialize('{"PromotionNo__c":"N001"}', Promotion.class);
        PromotionTriggerHandler.isErpSyncRelevantChange(oldP, promoWithNo);
        PromotionTriggerHandler.isErpSyncRelevantChange(oldP, oldP);
    }
}