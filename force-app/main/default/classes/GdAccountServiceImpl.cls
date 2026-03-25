public with sharing class GdAccountServiceImpl implements GdAccountService {
  public GdAccountServiceImpl() {
  }

  /**
   * 매장 및 회사 등록
   * Account insert
   */
  public ApiResult createAccount(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      Boolean isCompany = ValidationUtil.booleanValidation(reqData.get('isCompany'), 'isCompany', false);
      String name = ValidationUtil.stringValidation(reqData.get('Name'), 'Name', true); // 이름
      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false);
      String companyCode = ValidationUtil.stringValidation(reqData.get('CompanyCode__c'), 'CompanyCode__c', true);
      String brandCode = ValidationUtil.stringValidation(reqData.get('BrandCode__c'), 'BrandCode__c', false);
      String storeType = ValidationUtil.stringValidation(reqData.get('StoreType__c'), 'StoreType__c', false);
      String storeGroupCode = ValidationUtil.stringValidation(reqData.get('StoreGroupCode__c'), 'StoreGroupCode__c', false);
      String phone = ValidationUtil.stringValidation(reqData.get('Phone'), 'Phone', false);
      String phone2 = ValidationUtil.stringValidation(reqData.get('Phone2__c'), 'Phone2__c', false);
      String phone3 = ValidationUtil.stringValidation(reqData.get('Phone3__c'), 'Phone3__c', false);

      Account a = new Account();

      /** 매장,회사 등록 version1 */

      //     // 회사 등록일 경우
      //     if (isCompany != null && isCompany) {
      //       // 회사 코드 중복 검사
      //       if ([SELECT COUNT() FROM Account WHERE CompanyCode__c = :companyCode LIMIT 1] > 0) {
      //         throw new CustomException(400, 'CompanyCode__c is already exists.');
      //       }
      //       a.Name = companyCode;
      //     }

      //     // 매장 등록일 경우
      //     if (!isCompany || isCompany == null) {
      //       // 매장 코드 값 체크
      //       if (String.isBlank(storeCode)) {
      //         throw new CustomException(400, '매장 코드 값이 없습니다.');
      //       }
      //       // 매장 중복 체크
      //       if ([SELECT COUNT() FROM Account WHERE StoreCode__c = :storeCode LIMIT 1] > 0) {
      //         throw new CustomException(400, '이미 존재하는 매장 코드입니다. ' + storeCode);
      //       }
      //       // 회사 존재 여부 체크
      //       List<Account> companyList = [SELECT Id FROM Account WHERE CompanyCode__c = :companyCode AND ParentId = NULL LIMIT 1];
      //       if (companyList.isEmpty()) {
      //         throw new CustomException(400, '존재하지 않는 회사 코드입니다. ' + companyCode);
      //       }

      //       Account company = companyList[0];
      //       a.ParentId = company.Id;
      //       a.StoreCode__c = storeCode;
      //       a.StoreType__c = storeType;
      //       a.StoreGroupCode__c = storeGroupCode;
      //       a.Name = storeCode;
      //     }

      //     a.CompanyCode__c = companyCode;
      //     a.BrandCode__c = brandCode;
      //     a.Phone = phone;
      //     a.Phone2__c = phone2;
      //     a.Phone3__c = phone3;

      //     Database.SaveResult result = Database.insert(a);

      //     if (!result.isSuccess()) {
      //       Database.Error err = result.getErrors()[0];
      //       throw new CustomException(400, err.getMessage());
      //     }

      //     String returnMessage;
      //     if (isCompany != null && isCompany) {
      //       returnMessage = '회사 등록 완료';
      //     } else {
      //       returnMessage = '매장 등록 완료';
      //     }
      //     return ApiResult.ok(200, returnMessage, reqData);
      //   } catch (ValidationException ve) {
      //     throw new CustomException(ve.code, ve.detail);
      //   } catch (Exception e) {
      //     throw e;
      //   }
      // }

      /** 매장, 회사 등록 version 2 */

      //회사 등록
      if (isCompany != null && isCompany) {
        List<Account> existingCompany = [
          SELECT Id, IsDeleted__c
          FROM Account
          WHERE CompanyCode__c = :companyCode AND ParentId = NULL
          LIMIT 1
        ];

        if (!existingCompany.isEmpty()) {
          Account oldCompany = existingCompany[0];

          if (oldCompany.IsDeleted__c == false) {
            throw new CustomException(400, '이미 존재하는 회사 코드입니다.');
          }

          //회사 재등록
          oldCompany.IsDeleted__c = false;

          Database.SaveResult sr = Database.update(oldCompany, false);

          if (!sr.isSuccess()) {
            Database.Error err = sr.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }

          return ApiResult.ok(200, '회사 재등록 완료', reqData);
        }

        a.Name = name;
        a.IsDeleted__c = false;
      }
      // 매장 등록
      if (!isCompany || isCompany == null) {
        if (String.isBlank(storeCode)) {
          throw new CustomException(400, '매장 코드 값이 없습니다.');
        }

        List<Account> existingStore = [
          SELECT Id, IsDeleted__c
          FROM Account
          WHERE StoreCode__c = :storeCode
          LIMIT 1
        ];

        if (!existingStore.isEmpty()) {
          Account oldStore = existingStore[0];

          if (oldStore.IsDeleted__c == false) {
            throw new CustomException(400, '이미 존재하는 매장 코드입니다.');
          }

          //매장 재등록
          oldStore.IsDeleted__c = false;

          Database.SaveResult sr = Database.update(oldStore, false);

          if (!sr.isSuccess()) {
            Database.Error err = sr.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }

          return ApiResult.ok(200, '회사 재등록 완료', reqData);
        }

        List<Account> companyList = [
          SELECT Id
          FROM Account
          WHERE CompanyCode__c = :companyCode AND ParentId = NULL AND IsDeleted__c = FALSE
          LIMIT 1
        ];

        if (companyList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 회사 코드입니다.');
        }

        a.ParentId = companyList[0].Id;
        a.StoreCode__c = storeCode;
        a.StoreType__c = storeType;
        a.StoreGroupCode__c = storeGroupCode;
        a.Name = name;
        a.IsDeleted__c = false;
      }
      a.CompanyCode__c = companyCode;
      a.BrandCode__c = brandCode;
      a.Phone = phone;
      a.Phone2__c = phone2;
      a.Phone3__c = phone3;

      Database.SaveResult result = Database.insert(a);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      String returnMessage;
      if (isCompany != null && isCompany) {
        returnMessage = '회사 등록 완료';
      } else {
        returnMessage = '매장 등록 완료';
      }
      return ApiResult.ok(200, returnMessage, reqData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 매장 및 회사 수정
   * Account update
   */
  public ApiResult updateAccount(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String name = ValidationUtil.stringValidation(reqData.get('Name'), 'Name', false); // 이름
      Boolean isCompany = ValidationUtil.booleanValidation(reqData.get('isCompany'), 'isCompany', false);
      String storeCode = (isCompany != null && isCompany)
        ? ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false)
        : ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', true);
      String companyCode = ValidationUtil.stringValidation(reqData.get('CompanyCode__c'), 'CompanyCode__c', true);
      String brandCode = ValidationUtil.stringValidation(reqData.get('BrandCode__c'), 'BrandCode__c', false);
      String storeType = ValidationUtil.stringValidation(reqData.get('StoreType__c'), 'StoreType__c', false);
      String storeGroupCode = ValidationUtil.stringValidation(reqData.get('StoreGroupCode__c'), 'StoreGroupCode__c', false);
      String phone = ValidationUtil.stringValidation(reqData.get('Phone'), 'Phone', false);
      String phone2 = ValidationUtil.stringValidation(reqData.get('Phone2__c'), 'Phone2__c', false);
      String phone3 = ValidationUtil.stringValidation(reqData.get('Phone3__c'), 'Phone3__c', false);

      Account a = new Account();
      // 회사 수정일 경우
      if (isCompany != null && isCompany) {
        List<Account> aList = [SELECT Id, Name FROM Account WHERE CompanyCode__c = :companyCode AND ParentId = NULL AND IsDeleted__c = FALSE LIMIT 1];
        if (aList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 회사 코드입니다. ' + companyCode);
        }

        if (String.isNotBlank(name)) {
          a.Name = name;
        }
        a = aList[0];
      }
      // 매장 수정일 경우
      else {
        List<Account> aList = [SELECT Id FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
        if (aList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다. 매장 코드 : ' + storeCode);
        }
        a = aList[0];
        List<Account> companyList = [SELECT Id FROM Account WHERE CompanyCode__c = :companyCode AND ParentId = NULL AND IsDeleted__c = FALSE LIMIT 1];
        if (companyList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 회사 코드입니다. ' + companyCode);
        }
        a.ParentId = companyList[0].Id;

        if (String.isNotBlank(name)) {
          a.Name = name;
        }
        if (storeType != null) {
          a.StoreType__c = storeType;
        }
        if (storeGroupCode != null) {
          a.StoreGroupCode__c = storeGroupCode;
        }
      }

      if (brandCode != null) {
        a.BrandCode__c = brandCode;
      }
      if (phone != null) {
        a.Phone = phone;
      }
      if (phone2 != null) {
        a.Phone2__c = phone2;
      }
      if (phone3 != null) {
        a.Phone3__c = phone3;
      }

      Database.SaveResult result = Database.update(a);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      String returnMessage;
      if (isCompany != null && isCompany) {
        returnMessage = '회사 수정 완료';
      } else {
        returnMessage = '매장 수정 완료';
      }
      return ApiResult.ok(200, returnMessage, reqData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /** 매장/회사 삭제 */
  public ApiResult deleteAccount(Map<String, Object> reqData) {
    Savepoint sp = Database.setSavepoint();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      Boolean isCompany = ValidationUtil.booleanValidation(reqData.get('isCompany'), 'isCompany', false);

      String companyCode = ValidationUtil.stringValidationEx(reqData.get('CompanyCode__c'), 'CompanyCode__c', true, false);

      String storeCode = ValidationUtil.stringValidationEx(reqData.get('StoreCode__c'), 'StoreCode__c', false, false);

      Account target;

      // =========================
      // 회사 삭제
      // =========================
      if (isCompany != null && isCompany) {
        List<Account> companies = [
          SELECT Id, IsDeleted__c
          FROM Account
          WHERE CompanyCode__c = :companyCode AND ParentId = NULL
          LIMIT 1
        ];

        if (companies.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 회사 코드입니다.');
        }

        target = companies[0];
      }
      // =========================
      // 매장 삭제
      // =========================
      else {
        if (String.isBlank(storeCode)) {
          throw new CustomException(400, '매장 코드 값이 없습니다.');
        }

        List<Account> stores = [
          SELECT Id, IsDeleted__c
          FROM Account
          WHERE StoreCode__c = :storeCode AND CompanyCode__c = :companyCode
          LIMIT 1
        ];

        if (stores.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다.');
        }

        target = stores[0];
      }

      if (target.IsDeleted__c == true) {
        throw new CustomException(400, '이미 삭제된 데이터입니다.');
      }
      target.IsDeleted__c = true;
      Database.SaveResult result = Database.update(target, false);

      if (!result.isSuccess()) {
        Database.rollback(sp);
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      String returnMessage;
      if (isCompany != null && isCompany) {
        returnMessage = '회사 삭제 완료';
      } else {
        returnMessage = '매장 삭제 완료';
      }

      return ApiResult.ok(200, returnMessage, reqData);
    } catch (QueryException qe) {
      Database.rollback(sp);
      throw new CustomException(400, '존재하지 않는 코드입니다.');
    } catch (Exception e) {
      Database.rollback(sp);
      throw e;
    }
  }
}