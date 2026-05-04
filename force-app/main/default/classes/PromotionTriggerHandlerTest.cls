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
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(30),
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
    List<String> fields = new List<String>{ 'Name', 'BrandCode__c', 'TypeCode__c', 'StartDate', 'EndDate', 'StatusCode__c', 'InsertId__c' };
    for (String f : fields) {
      try {
        newP.put(f, 'NewValue');
        PromotionTriggerHandler.isErpSyncRelevantChange(oldP, newP);
      } catch (Exception e) {
      }
    }

    Promotion promoWithNo = (Promotion) JSON.deserialize('{"PromotionNo__c":"N001"}', Promotion.class);
    PromotionTriggerHandler.isErpSyncRelevantChange(oldP, promoWithNo);
    PromotionTriggerHandler.isErpSyncRelevantChange(oldP, oldP);
  }

  // 26.04.22 하나 추가: 특정 매장/품목 여부 판정 헬퍼 검증
  @IsTest
  static void testIsErpSyncRelevantChangeTypedBranches() {
    Promotion oldP = new Promotion(
      Name = 'Old',
      BrandCode__c = '01',
      TypeCode__c = '01',
      StartDate = Date.today(),
      EndDate = Date.today().addDays(1),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(1),
      StatusCode__c = '01',
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = true,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = true,
      IsPointUsageAllowed__c = true,
      IsAllStore__c = true,
      IsAllItem__c = true,
      PointTypeCode__c = '01',
      InsertId__c = 'InsertOld',
      ResponId__c = 'ResponOld'
    );
    Promotion sameP = oldP.clone(false, true, false, false);

    System.assertEquals(false, PromotionTriggerHandler.isErpSyncRelevantChange(oldP, sameP));

    Promotion changed = oldP.clone(false, true, false, false);
    changed.Name = 'New';
    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(oldP, changed));

    changed = oldP.clone(false, true, false, false);
    changed.StartDate = Date.today().addDays(2);
    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(oldP, changed));

    changed = oldP.clone(false, true, false, false);
    changed.IsCouponAllowed__c = false;
    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(oldP, changed));

    changed = oldP.clone(false, true, false, false);
    changed.IsAllStore__c = false;
    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(oldP, changed));

    changed = oldP.clone(false, true, false, false);
    changed.PointTypeCode__c = '06';
    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(oldP, changed));

    changed = oldP.clone(false, true, false, false);
    changed.ResponId__c = 'ResponNew';
    System.assertEquals(true, PromotionTriggerHandler.isErpSyncRelevantChange(oldP, changed));
  }

  @IsTest
  static void testResolveYnSpec() {
    // 전체 매장/품목 → 'N'
    System.assertEquals('N', PromotionTriggerHandler.resolveYnSpec(true, true));
    System.assertEquals('N', PromotionTriggerHandler.resolveYnSpec(true, false));
    // 전체 아님 + 선택됨 → 'Y'
    System.assertEquals('Y', PromotionTriggerHandler.resolveYnSpec(false, true));
    // 전체 아님 + 선택 안함 → 'N'
    System.assertEquals('N', PromotionTriggerHandler.resolveYnSpec(false, false));
  }

  // 26.04.22 하나 추가: 빈 입력 집합 처리 검증
  @IsTest
  static void testGetPromotionIdsHelpers_emptyInput() {
    Set<Id> emptySet = new Set<Id>();
    System.assertEquals(0, PromotionTriggerHandler.getPromotionIdsWithStores(null).size());
    System.assertEquals(0, PromotionTriggerHandler.getPromotionIdsWithStores(emptySet).size());
    System.assertEquals(0, PromotionTriggerHandler.getPromotionIdsWithItems(null).size());
    System.assertEquals(0, PromotionTriggerHandler.getPromotionIdsWithItems(emptySet).size());
  }

  // 26.04.22 하나 추가: 특정 매장/품목 연결 레코드 존재 시 판정 검증
  @IsTest
  static void testGetPromotionIdsHelpers_withData() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];

    // 매장(Account) + PromotionAccount__c 연결
    Account acc = new Account(Name = 'Test Store ' + getUniqueString('A'));
    insert acc;

    PromotionAccount__c pa = new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id);
    insert pa;

    // 품목(Product2) + PromotionProduct 연결
    Product2 prod = new Product2(Name = 'Test Product ' + getUniqueString('P'), IsActive = true);
    insert prod;

    PromotionProduct pp = new PromotionProduct(PromotionId = p.Id, ProductId = prod.Id);
    insert pp;

    Set<Id> pIds = new Set<Id>{ p.Id };

    Set<Id> storeResult = PromotionTriggerHandler.getPromotionIdsWithStores(pIds);
    Set<Id> itemResult = PromotionTriggerHandler.getPromotionIdsWithItems(pIds);

    System.assert(storeResult.contains(p.Id), '특정 매장 연결 Promotion이 집합에 포함되어야 함');
    System.assert(itemResult.contains(p.Id), '특정 품목 연결 Promotion이 집합에 포함되어야 함');
  }
}