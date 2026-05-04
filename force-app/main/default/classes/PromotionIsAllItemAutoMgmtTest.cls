/**
 * 프로모션 전체제품적용(IsAllItem__c) 자동 관리 테스트
 *
 * 테스트 시나리오:
 * 1. PromotionProduct = 0 → IsAllItem__c = true (자동)
 * 2. PromotionProduct 1개 추가 → IsAllItem__c = false (자동)
 * 3. PromotionProduct 모두 삭제 → IsAllItem__c = true (자동)
 * 4. 사용자가 IsAllItem__c 수동 변경 시도 → 오류 (차단)
 */
@isTest
public class PromotionIsAllItemAutoMgmtTest {
  private static final String LOYALTY_PROGRAM_NAME = 'Golden Dew';

  /**
   * 테스트 데이터 준비
   */
  @testSetup
  static void setup() {
    // 1) LoyaltyProgram 생성
    LoyaltyProgram lp = new LoyaltyProgram(Name = LOYALTY_PROGRAM_NAME);
    insert lp;

    // 2) Promotion 생성 (IsAllItem__c = true 기본값, 제품 없으므로 전체 적용)
    Promotion promo = new Promotion(
      Name = 'Test Promotion',
      LoyaltyProgramId = lp.Id,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(30)
      // IsAllItem__c = true (기본값, 제품 0개일 때)
    );
    insert promo;

    // 3) Product 생성 (테스트용 제품 3개)
    List<Product2> products = new List<Product2>();
    for (Integer i = 1; i <= 3; i++) {
      products.add(new Product2(
        Name = 'Test Product ' + i,
        ProductCode = 'TEST-PROD-00' + i,
        IsActive = true
      ));
    }
    insert products;
  }

  /**
   * 시나리오 1: 프로모션 생성 후 제품 없음 → IsAllItem__c = true (기본값)
   */
  @isTest
  static void testPromotionCreatedWithoutProducts() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];

    // 초기 상태: PromotionProduct = 0, IsAllItem__c = true (기본값)
    System.assertEquals(true, promo.IsAllItem__c, '프로모션 생성 시 IsAllItem__c 기본값은 true여야 함 (제품 없음 = 전체 적용)');

    Integer productCount = [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :promo.Id];
    System.assertEquals(0, productCount, '제품이 없어야 함');

    System.debug('✅ 시나리오 1 성공: 프로모션 생성 (제품 0개) → IsAllItem__c = true');
  }

  /**
   * 시나리오 2: PromotionProduct 1개 추가 → IsAllItem__c = false (자동)
   */
  @isTest
  static void testAddOneProductAutoSetIsAllItemToFalse() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];
    Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-PROD-001' LIMIT 1];

    // 제품 1개 추가
    PromotionProduct pp = new PromotionProduct(
      PromotionId = promo.Id,
      ProductId = product.Id
    );
    insert pp;

    // 검증: IsAllItem__c가 false로 자동 설정되었는지 확인
    Promotion updatedPromo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(false, updatedPromo.IsAllItem__c,
      '제품 1개 추가 시 IsAllItem__c는 false여야 함 (현재: ' + updatedPromo.IsAllItem__c + ')');

    System.debug('✅ 시나리오 2 성공: 제품 1개 추가 → IsAllItem__c = false');
  }

  /**
   * 시나리오 3: PromotionProduct 여러 개 추가 → IsAllItem__c = false (유지)
   */
  @isTest
  static void testAddMultipleProductsKeepIsAllItemFalse() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 WHERE ProductCode IN ('TEST-PROD-001', 'TEST-PROD-002', 'TEST-PROD-003')];

    // 제품 3개 추가
    List<PromotionProduct> pps = new List<PromotionProduct>();
    for (Product2 product : products) {
      pps.add(new PromotionProduct(PromotionId = promo.Id, ProductId = product.Id));
    }
    insert pps;

    // 검증: IsAllItem__c가 false 유지되는지 확인
    Promotion updatedPromo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(false, updatedPromo.IsAllItem__c,
      '제품 3개 추가 후에도 IsAllItem__c는 false여야 함');

    Integer productCount = [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :promo.Id];
    System.assertEquals(3, productCount, '제품이 3개여야 함');

    System.debug('✅ 시나리오 3 성공: 제품 3개 추가 → IsAllItem__c = false (유지)');
  }

  /**
   * 시나리오 4: PromotionProduct 모두 삭제 → IsAllItem__c = true (자동)
   */
  @isTest
  static void testDeleteAllProductsAutoSetIsAllItemToTrue() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 WHERE ProductCode IN ('TEST-PROD-001', 'TEST-PROD-002')];

    // 제품 2개 추가
    List<PromotionProduct> pps = new List<PromotionProduct>();
    for (Product2 product : products) {
      pps.add(new PromotionProduct(PromotionId = promo.Id, ProductId = product.Id));
    }
    insert pps;

    // 검증: IsAllItem__c = false 설정됨
    Promotion promoAfterAdd = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(false, promoAfterAdd.IsAllItem__c, '제품 추가 시 IsAllItem__c = false');

    // 제품 모두 삭제
    delete pps;

    // 검증: IsAllItem__c가 true로 자동 설정되었는지 확인
    Promotion updatedPromo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(true, updatedPromo.IsAllItem__c,
      '제품 모두 삭제 시 IsAllItem__c는 true여야 함 (현재: ' + updatedPromo.IsAllItem__c + ')');

    Integer productCount = [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :promo.Id];
    System.assertEquals(0, productCount, '제품이 0개여야 함');

    System.debug('✅ 시나리오 4 성공: 제품 모두 삭제 → IsAllItem__c = true');
  }

  /**
   * 시나리오 5: 1개 제품 삭제 후 복구 (제품 개수 변함)
   */
  @isTest
  static void testDeleteOneProductKeepIsAllItemFalse() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 WHERE ProductCode IN ('TEST-PROD-001', 'TEST-PROD-002', 'TEST-PROD-003')];

    // 제품 3개 추가
    List<PromotionProduct> pps = new List<PromotionProduct>();
    for (Product2 product : products) {
      pps.add(new PromotionProduct(PromotionId = promo.Id, ProductId = product.Id));
    }
    insert pps;

    Promotion promoAfterAdd = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(false, promoAfterAdd.IsAllItem__c, '제품 3개 추가 시 IsAllItem__c = false');

    // 1개 제품 삭제 (2개 남음)
    delete new List<PromotionProduct>(new List<PromotionProduct>{pps[0]});

    // 검증: IsAllItem__c가 여전히 false 유지되는지 확인
    Promotion updatedPromo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(false, updatedPromo.IsAllItem__c,
      '1개 제품 삭제해도 제품이 남아있으면 IsAllItem__c는 false 유지');

    Integer productCount = [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :promo.Id];
    System.assertEquals(2, productCount, '제품이 2개 남아있어야 함');

    System.debug('✅ 시나리오 5 성공: 제품 1개 삭제 → IsAllItem__c = false (유지)');
  }

  /**
   * 시나리오 6: 사용자가 IsAllItem__c = true 변경 시도 → 오류 (차단)
   */
  @isTest
  static void testPreventManualIsAllItemChangeWhenProductExists() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];
    Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-PROD-001' LIMIT 1];

    // 제품 1개 추가 (IsAllItem__c = false로 자동 설정)
    PromotionProduct pp = new PromotionProduct(PromotionId = promo.Id, ProductId = product.Id);
    insert pp;

    Promotion promoAfterAdd = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(false, promoAfterAdd.IsAllItem__c, '제품 추가 시 IsAllItem__c = false');

    // 사용자가 IsAllItem__c = true로 변경 시도
    promoAfterAdd.IsAllItem__c = true;

    try {
      update promoAfterAdd;
      System.assert(false, 'IsAllItem__c 변경이 차단되어야 하는데 성공했음 ❌');
    } catch (DmlException e) {
      String errorMessage = e.getMessage();
      System.assert(errorMessage.contains('적용 가능 제품 개수에 따라 자동으로 관리'),
        '올바른 오류 메시지가 아님: ' + errorMessage);
      System.debug('✅ 시나리오 6 성공: IsAllItem__c 변경 차단됨 - ' + errorMessage);
    }
  }

  /**
   * 시나리오 7: 사용자가 IsAllItem__c = false 변경 시도 (제품 0개일 때) → 오류 (차단)
   */
  @isTest
  static void testPreventManualIsAllItemChangeWhenNoProduct() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];

    // 초기 상태: IsAllItem__c = false, 제품 0개
    System.assertEquals(false, promo.IsAllItem__c, '초기 IsAllItem__c = false');

    Integer productCount = [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :promo.Id];
    System.assertEquals(0, productCount, '제품이 0개');

    // 사용자가 IsAllItem__c = true로 변경 시도
    promo.IsAllItem__c = true;

    try {
      update promo;
      System.assert(false, 'IsAllItem__c 변경이 차단되어야 하는데 성공했음 ❌');
    } catch (DmlException e) {
      String errorMessage = e.getMessage();
      System.assert(errorMessage.contains('적용 가능 제품 개수에 따라 자동으로 관리'),
        '올바른 오류 메시지가 아님: ' + errorMessage);
      System.debug('✅ 시나리오 7 성공: IsAllItem__c 변경 차단됨 (제품 0개) - ' + errorMessage);
    }
  }

  /**
   * 시나리오 8: 마지막 제품 삭제 후 IsAllItem__c = true로 복구됨
   */
  @isTest
  static void testDeleteLastProductRecoveryIsAllItemToTrue() {
    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];
    Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-PROD-001' LIMIT 1];

    // 제품 1개 추가
    PromotionProduct pp = new PromotionProduct(PromotionId = promo.Id, ProductId = product.Id);
    insert pp;

    Promotion promoAfterAdd = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(false, promoAfterAdd.IsAllItem__c, '제품 1개 추가 시 IsAllItem__c = false');

    // 마지막 제품 삭제
    delete pp;

    // 검증: IsAllItem__c = true로 복구되었는지 확인
    Promotion updatedPromo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.assertEquals(true, updatedPromo.IsAllItem__c,
      '마지막 제품 삭제 시 IsAllItem__c는 true로 복구되어야 함 (현재: ' + updatedPromo.IsAllItem__c + ')');

    System.debug('✅ 시나리오 8 성공: 마지막 제품 삭제 → IsAllItem__c = true (복구)');
  }

  /**
   * 모든 시나리오 통합 테스트
   */
  @isTest
  static void testCompleteScenario() {
    System.debug('\n========== 통합 테스트 시작 ==========');

    Promotion promo = [SELECT Id, IsAllItem__c FROM Promotion WHERE Name = 'Test Promotion' LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 WHERE ProductCode IN ('TEST-PROD-001', 'TEST-PROD-002', 'TEST-PROD-003')];

    System.debug('1️⃣ 프로모션 생성 (제품 0개): IsAllItem__c = ' + promo.IsAllItem__c);
    System.assertEquals(true, promo.IsAllItem__c, '초기값 = true (기본값, 제품 없음)');

    // 제품 1개 추가
    PromotionProduct pp1 = new PromotionProduct(PromotionId = promo.Id, ProductId = products[0].Id);
    insert pp1;
    Promotion p1 = [SELECT IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.debug('2️⃣ 제품 1개 추가: IsAllItem__c = ' + p1.IsAllItem__c);
    System.assertEquals(false, p1.IsAllItem__c, '제품 추가 후 = false');

    // 제품 2개 더 추가
    List<PromotionProduct> pp2List = new List<PromotionProduct>{
      new PromotionProduct(PromotionId = promo.Id, ProductId = products[1].Id),
      new PromotionProduct(PromotionId = promo.Id, ProductId = products[2].Id)
    };
    insert pp2List;
    Promotion p2 = [SELECT IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.debug('3️⃣ 제품 2개 더 추가 (총 3개): IsAllItem__c = ' + p2.IsAllItem__c);
    System.assertEquals(false, p2.IsAllItem__c, '제품 3개 상태 = false');

    // 제품 1개 삭제 (2개 남음)
    delete pp1;
    Promotion p3 = [SELECT IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.debug('4️⃣ 제품 1개 삭제 (2개 남음): IsAllItem__c = ' + p3.IsAllItem__c);
    System.assertEquals(false, p3.IsAllItem__c, '제품 2개 상태 = false');

    // 제품 모두 삭제
    delete pp2List;
    Promotion p4 = [SELECT IsAllItem__c FROM Promotion WHERE Id = :promo.Id];
    System.debug('5️⃣ 제품 모두 삭제 (0개): IsAllItem__c = ' + p4.IsAllItem__c);
    System.assertEquals(true, p4.IsAllItem__c, '제품 0개 = true로 복구');

    System.debug('========== 통합 테스트 완료 ✅ ==========\n');
  }
}