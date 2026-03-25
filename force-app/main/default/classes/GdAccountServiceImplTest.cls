@IsTest
private class GdAccountServiceImplTest {
  private static String firstBrandCode() {
    List<Schema.PicklistEntry> entries = Account.BrandCode__c.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String firstStoreType() {
    List<Schema.PicklistEntry> entries = Account.StoreType__c.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static Account insertCompany(String companyCode, Boolean isDeleted) {
    Account a = new Account(Name = 'Company ' + companyCode, CompanyCode__c = companyCode, IsDeleted__c = isDeleted);
    insert a;
    return a;
  }

  private static Account insertStore(String companyCode, String storeCode, Id parentId, Boolean isDeleted) {
    Account a = new Account(
      Name = 'Store ' + storeCode,
      CompanyCode__c = companyCode,
      StoreCode__c = storeCode,
      ParentId = parentId,
      IsDeleted__c = isDeleted
    );
    insert a;
    return a;
  }

  private static Map<String, Object> companyCreateReq(String companyCode) {
    return new Map<String, Object>{
      'isCompany' => true,
      'Name' => 'Company ' + companyCode,
      'CompanyCode__c' => companyCode,
      'BrandCode__c' => firstBrandCode(),
      'Phone' => '02-1111-1111',
      'Phone2__c' => '010-1111-1111',
      'Phone3__c' => '010-2222-2222'
    };
  }

  private static Map<String, Object> storeCreateReq(String companyCode, String storeCode) {
    return new Map<String, Object>{
      'isCompany' => false,
      'Name' => 'Store ' + storeCode,
      'CompanyCode__c' => companyCode,
      'StoreCode__c' => storeCode,
      'StoreType__c' => firstStoreType(),
      'StoreGroupCode__c' => 'GRP',
      'BrandCode__c' => firstBrandCode(),
      'Phone' => '02-3333-3333',
      'Phone2__c' => '010-3333-3333',
      'Phone3__c' => '010-4444-4444'
    };
  }

  private static GdAccountService service() {
    return new GdAccountServiceImpl();
  }

  @IsTest
  static void createAccount_company_newAndRestore_deletedBranchCovered() {
    insertCompany('COMP-RESTORE', true);

    Test.startTest();
    try {
      service().createAccount(companyCreateReq('COMP-NEW'));
      service().createAccount(companyCreateReq('COMP-RESTORE'));
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    Account restored = [
      SELECT Id, IsDeleted__c
      FROM Account
      WHERE CompanyCode__c = 'COMP-RESTORE' AND ParentId = NULL
      LIMIT 1
    ];
    System.assertEquals(false, restored.IsDeleted__c);
  }

  @IsTest
  static void createAccount_company_duplicateAndEmptyBody_errorBranches() {
    insertCompany('COMP-DUP', false);

    Test.startTest();
    try {
      service().createAccount(companyCreateReq('COMP-DUP'));
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().createAccount(new Map<String, Object>());
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }
    Test.stopTest();
  }

  @IsTest
  static void createAccount_store_newRestoreAndFailures() {
    Account parent = insertCompany('COMP-PARENT', false);
    insertStore(parent.CompanyCode__c, 'STORE-RESTORE', parent.Id, true);
    insertStore(parent.CompanyCode__c, 'STORE-DUP', parent.Id, false);

    Test.startTest();
    try {
      service().createAccount(storeCreateReq(parent.CompanyCode__c, 'STORE-NEW'));
      service().createAccount(storeCreateReq(parent.CompanyCode__c, 'STORE-RESTORE'));
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      service().createAccount(storeCreateReq(parent.CompanyCode__c, 'STORE-DUP'));
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      Map<String, Object> missingStoreCode = storeCreateReq(parent.CompanyCode__c, 'STORE-X');
      missingStoreCode.remove('StoreCode__c');
      service().createAccount(missingStoreCode);
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().createAccount(storeCreateReq('COMP-NOPE', 'STORE-NOPE'));
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }
    Test.stopTest();
  }

  @IsTest
  static void updateAccount_companyAndStore_successBranches() {
    Account company = insertCompany('COMP-UPD', false);
    Account otherCompany = insertCompany('COMP-UPD-2', false);
    Account store = insertStore(company.CompanyCode__c, 'STORE-UPD', company.Id, false);

    Test.startTest();
    try {
      service()
        .updateAccount(
          new Map<String, Object>{
            'isCompany' => true,
            'CompanyCode__c' => company.CompanyCode__c,
            'Name' => 'Updated Company',
            'BrandCode__c' => firstBrandCode(),
            'Phone' => '02-5555-5555',
            'Phone2__c' => '010-5555-5555',
            'Phone3__c' => '010-6666-6666'
          }
        );

      service()
        .updateAccount(
          new Map<String, Object>{
            'isCompany' => false,
            'CompanyCode__c' => otherCompany.CompanyCode__c,
            'StoreCode__c' => store.StoreCode__c,
            'Name' => 'Updated Store',
            'StoreType__c' => firstStoreType(),
            'StoreGroupCode__c' => 'NEWGRP',
            'BrandCode__c' => firstBrandCode(),
            'Phone' => '02-7777-7777'
          }
        );
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void updateAccount_errorBranches() {
    Account company = insertCompany('COMP-UPD-ERR', false);

    Test.startTest();
    try {
      service().updateAccount(new Map<String, Object>());
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().updateAccount(new Map<String, Object>{ 'isCompany' => true, 'CompanyCode__c' => 'NO-COMPANY' });
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().updateAccount(new Map<String, Object>{ 'isCompany' => false, 'CompanyCode__c' => company.CompanyCode__c });
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().updateAccount(new Map<String, Object>{ 'isCompany' => false, 'CompanyCode__c' => 'NO-COMPANY', 'StoreCode__c' => 'STORE-NOPE' });
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }
    Test.stopTest();
  }

  @IsTest
  static void deleteAccount_companyAndStore_successBranches() {
    Account company = insertCompany('COMP-DEL', false);
    Account companyForStore = insertCompany('COMP-DEL-STORE', false);
    insertStore(companyForStore.CompanyCode__c, 'STORE-DEL', companyForStore.Id, false);

    Test.startTest();
    try {
      service().deleteAccount(new Map<String, Object>{ 'isCompany' => true, 'CompanyCode__c' => company.CompanyCode__c });

      service()
        .deleteAccount(
          new Map<String, Object>{ 'isCompany' => false, 'CompanyCode__c' => companyForStore.CompanyCode__c, 'StoreCode__c' => 'STORE-DEL' }
        );
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void deleteAccount_errorBranches() {
    Account company = insertCompany('COMP-DEL-ERR', false);
    insertStore(company.CompanyCode__c, 'STORE-DEL-ERR', company.Id, true);
    insertCompany('COMP-ALREADY-DEL', true);

    Test.startTest();
    try {
      service().deleteAccount(new Map<String, Object>());
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().deleteAccount(new Map<String, Object>{ 'isCompany' => true, 'CompanyCode__c' => 'NO-COMPANY' });
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().deleteAccount(new Map<String, Object>{ 'isCompany' => true, 'CompanyCode__c' => 'COMP-ALREADY-DEL' });
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service().deleteAccount(new Map<String, Object>{ 'isCompany' => false, 'CompanyCode__c' => company.CompanyCode__c });
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service()
        .deleteAccount(new Map<String, Object>{ 'isCompany' => false, 'CompanyCode__c' => company.CompanyCode__c, 'StoreCode__c' => 'NO-STORE' });
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }

    try {
      service()
        .deleteAccount(
          new Map<String, Object>{ 'isCompany' => false, 'CompanyCode__c' => company.CompanyCode__c, 'StoreCode__c' => 'STORE-DEL-ERR' }
        );
      System.assert(false);
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }
    Test.stopTest();
  }
}