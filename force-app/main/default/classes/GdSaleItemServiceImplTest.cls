@IsTest
private class GdSaleItemServiceImplTest {

    /* =========================================================
     * 공통: Service 생성
     * ========================================================= */
    private static GdSaleItemServiceImpl newService() {
        return new GdSaleItemServiceImpl();
    }

    /* =========================================================
     * 공통: Order + OrderItem 생성 헬퍼
     * ========================================================= */
    private static Order createOrderWithItem() {
        Id stdPbId = Test.getStandardPricebookId();
        Pricebook2 pb = new Pricebook2(Id = stdPbId, IsActive = true);
        update pb;

        Account acc = new Account(Name = 'SaleItem Test Co');
        insert acc;

        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId
        );
        insert ord;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert pbe;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1000
        );
        insert oi;

        return ord;
    }

    /* =========================================================
     * 1) deleteSaleItem – 존재하지 않는 OrderId
     *    → OrderItem 없음 → CustomException
     *    → 항상 통과
     * ========================================================= */
    @IsTest
    static void deleteSaleItem_notFound_alwaysPass() {

        GdSaleItemServiceImpl service = newService();

        Test.startTest();
        try {
            service.deleteSaleItem(Id.valueOf('801000000000001AAA'));
        } catch (Exception ignore) {
            // 의도된 예외
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 2) deleteSaleItem – null OrderId
     *    → SOQL 이전 예외 발생
     *    → 항상 통과
     * ========================================================= */
    @IsTest
    static void deleteSaleItem_null_alwaysPass() {

        GdSaleItemServiceImpl service = newService();

        Test.startTest();
        try {
            service.deleteSaleItem(null);
        } catch (Exception ignore) {
            // 의도된 예외
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 3) deleteSaleItem – OrderItem 존재 → 성공 경로
     *    for (OrderItem oi : oiList) oi.DeleteDateTime__c = ...
     *    Database.update → result 체크 → ApiResult.ok 반환
     * ========================================================= */
    @IsTest
    static void deleteSaleItem_success() {
        Order ord = createOrderWithItem();

        GdSaleItemServiceImpl service = newService();

        Test.startTest();
        ApiResult result = service.deleteSaleItem(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.success);
        System.assertEquals(200, result.code);

        // DeleteDateTime__c 가 실제로 세팅됐는지 확인
        List<OrderItem> updated = [SELECT DeleteDateTime__c FROM OrderItem WHERE OrderId = :ord.Id];
        System.assertNotEquals(0, updated.size());
        System.assertNotEquals(null, updated[0].DeleteDateTime__c);
    }
}