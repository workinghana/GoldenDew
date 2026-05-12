public with sharing class GdContactServiceImpl implements GdContactService {
  public GdContactServiceImpl() {
  }

  /**
   * 회원 생성 - Contact insert
   */
  public ApiResult createContact(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      String memberType = ValidationUtil.stringValidationEx(reqData.get('MemberType__c'), 'MemberType__c', false, false); // 회원 구분 코드
      String companyCode = ValidationUtil.stringValidation(reqData.get('AccountId'), 'AccountId', false); // 회사 코드
      String storeRegiCode = ValidationUtil.stringValidationEx(reqData.get('StoreRegi__c'), 'StoreRegi__c', false, false); // 등록 매장 코드
      String storeManaCode = ValidationUtil.stringValidationEx(reqData.get('StoreMana__c'), 'StoreMana__c', false, false); // 관리 매장 코드
      String lastname = ValidationUtil.stringValidationEx(reqData.get('Lastname'), 'Lastname', true, false); // 이름
      Date birthdate = ValidationUtil.dateValidation(reqData.get('Birthdate'), 'Birthdate', false); // 생년월일
      String legalBirthdate = ValidationUtil.stringValidation(reqData.get('LegalBirthdate__c'), 'LegalBirthdate__c', false); // 법정 생년월일 - 26.05.01 GD 추가
      Date memberJoinDate = ValidationUtil.dateValidation(reqData.get('MemberJoinDate__c'), 'MemberJoinDate__c', false); //
      String genderIdentity = ValidationUtil.stringValidation(reqData.get('GenderIdentity'), 'GenderIdentity', false);
      String phone = ValidationUtil.stringValidation(reqData.get('Phone'), 'Phone', false);
      String mobilePhone = ValidationUtil.stringValidation(reqData.get('MobilePhone'), 'MobilePhone', false);
      String email = ValidationUtil.stringValidation(reqData.get('Email'), 'Email', false);
      String grade = ValidationUtil.stringValidation(reqData.get('Grade__c'), 'Grade__c', true);
      Boolean isMarried = ValidationUtil.booleanValidation(reqData.get('IsMarried__c'), 'IsMarried__c', false);
      Date weddingAnniversaryDate = ValidationUtil.dateValidation(reqData.get('WeddingAnniversaryDate__c'), 'WeddingAnniversaryDate__c', false); // 결혼기념일자
      Boolean isEmailAgreed = ValidationUtil.booleanValidation(reqData.get('IsEmailAgreed__c'), 'IsEmailAgreed__c', false); // Email 수신여부 
      Boolean isSMSAgreed = ValidationUtil.booleanValidation(reqData.get('IsSMSAgreed__c'), 'IsSMSAgreed__c', false); // SMS 수신여부
      Boolean isMagazineSubscribed = ValidationUtil.booleanValidation(reqData.get('IsMagazineSubscribed__c'), 'IsMagazineSubscribed__c', false);  // 매거진 구독 여부
      Boolean isMagazineCatalog = ValidationUtil.booleanValidation(reqData.get('IsMagazineCatalog__c'), 'IsMagazineCatalog__c', false); // DM(매거진) == 카탈로그 - 26.05.01 GD 추가
      String magazineSubscriptionSeason = ValidationUtil.stringValidation(reqData.get('MagazineSubscriptionSeason__c'), 'MagazineSubscriptionSeason__c', false); // 매거진 구독 시즌
      Date magazineSubscriptionDate = ValidationUtil.dateValidation(reqData.get('MagazineSubscriptionDate__c'), 'MagazineSubscriptionDate__c', false); // 매거진 구독 일자
      String mailingStreet = ValidationUtil.stringValidation(reqData.get('MailingStreet'), 'MailingStreet', false); // 주소
      String mailingPostalCode = ValidationUtil.stringValidation(reqData.get('MailingPostalCode'), 'MailingPostalCode', false); // 우편번호
      Boolean isMobileVerified = ValidationUtil.booleanValidation(reqData.get('IsMobileVerified__c'), 'IsMobileVerified__c', false); // 휴대폰 인증 여부

      // 회원번호 중복 체크
      if ([SELECT COUNT() FROM Contact WHERE MemberNo__c = :memberNo] > 0) {
        throw new CustomException(400, '중복된 회원번호입니다. ' + memberNo);
      }

      Contact c = new Contact();
      c.MemberNo__c = memberNo;
      c.Lastname = lastname;
      c.Birthdate = birthdate;
      c.LegalBirthdate__c = legalBirthdate; // 26.05.01 GD - 법정 생년월일 추가
      c.GenderIdentity = genderIdentity;
      c.Phone = phone;
      c.MobilePhone = mobilePhone;
      c.Grade__c = grade;
      c.MemberJoinDate__c = memberJoinDate;
      if (memberType != null) {
        c.MemberType__c = memberType;
      }
      if (isMarried != null) {
        c.IsMarried__c = isMarried;
      }
      c.WeddingAnniversaryDate__c = weddingAnniversaryDate;
      if (isEmailAgreed != null) {
        c.IsEmailAgreed__c = isEmailAgreed;
      }
      if (isSMSAgreed != null) {
        c.IsSMSAgreed__c = isSMSAgreed;
      }
      if (isMagazineSubscribed != null) {
        c.IsMagazineSubscribed__c = isMagazineSubscribed;
        if (isMagazineSubscribed) {
          c.MagazineSubscriptionDate__c = Date.today();
        }
      }
      // 26.05.04 CS : 매거진 구독 시즌 필드 추가
      if (magazineSubscriptionSeason != null) {
        c.MagazineSubscriptionSeason__c = magazineSubscriptionSeason;
      }
      // 26.05.04 CS : 매거진 구독 일자 필드 추가
      if (magazineSubscriptionDate != null) {
        c.MagazineSubscriptionDate__c = magazineSubscriptionDate;
      }
      // 26.05.01 GD - DM(매거진) 카탈로그 추가
      if (isMagazineCatalog != null) {
        c.IsMagazineCatalog__c = isMagazineCatalog;
      }
      // 회사 체크
      if (companyCode != null) {
        List<Account> accountList = [SELECT Id FROM Account WHERE CompanyCode__c = :companyCode AND ParentId = NULL LIMIT 1];
        if (accountList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 회사 코드입니다.  ' + companyCode);
        }
        c.AccountId = accountList[0].Id;
      }
      // 등록 매장 체크
      if (storeRegiCode != null) {
        List<Account> storeRegiList = [SELECT Id FROM Account WHERE StoreCode__c = :storeRegiCode LIMIT 1];
        if (storeRegiList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다.  ' + storeRegiCode);
        }
        c.StoreRegi__c = storeRegiList[0].Id;
      }
      // 관리 매장 체크
      if (storeManaCode != null) {
        List<Account> storeManaList = [SELECT Id FROM Account WHERE StoreCode__c = :storeManaCode LIMIT 1];
        if (storeManaList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다.  ' + storeManaCode);
        }
        c.StoreMana__c = storeManaList[0].Id;
      }
      // 이메일 중복 체크
      if (email != null) {
        // if ([SELECT COUNT() FROM Contact WHERE Email = :email] > 0) {
        //   throw new CustomException(400, '중복된 이메일입니다. ' + email);
        // }
        c.Email = email;
      }
      c.MailingStreet = mailingStreet;
      c.MailingPostalCode = mailingPostalCode;
      // 휴대폰 인증 여부
      if (isMobileVerified != null) {
        c.IsMobileVerified__c = isMobileVerified;
      }

      Database.SaveResult result = Database.insert(c);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();

      {
        String picklistValue = c.Grade__c;

        Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

        String labelName;
        for (Schema.PicklistEntry entry : picklistValues) {
          if (entry.getValue() == picklistValue) {
            labelName = entry.getLabel();
            break;
          }
        }

        data.put('TargetTierName', labelName);
      }

      data.put('Contact', c);
      return ApiResult.ok(200, '회원 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 회원 수정 - Contact update
   */
  public ApiResult updateContact(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      String memberType = ValidationUtil.stringValidationEx(reqData.get('MemberType__c'), 'MemberType__c', false, false); // 회원 구분 코드
      String companyCode = ValidationUtil.stringValidation(reqData.get('AccountId'), 'AccountId', false); // 회사 코드
      String storeRegiCode = ValidationUtil.stringValidationEx(reqData.get('StoreRegi__c'), 'StoreRegi__c', false, false); // 등록 매장 코드
      String storeManaCode = ValidationUtil.stringValidationEx(reqData.get('StoreMana__c'), 'StoreMana__c', false, false); // 관리 매장 코드
      String lastname = ValidationUtil.stringValidationEx(reqData.get('Lastname'), 'Lastname', false, false);
      Date birthdate = ValidationUtil.dateValidation(reqData.get('Birthdate'), 'Birthdate', false);
      String legalBirthdate = ValidationUtil.stringValidation(reqData.get('LegalBirthdate__c'), 'LegalBirthdate__c', false); // 법정 생년월일 - 26.05.01 GD 추가
      String genderIdentity = ValidationUtil.stringValidation(reqData.get('GenderIdentity'), 'GenderIdentity', false);
      String phone = ValidationUtil.stringValidation(reqData.get('Phone'), 'Phone', false);
      String mobilePhone = ValidationUtil.stringValidation(reqData.get('MobilePhone'), 'MobilePhone', false);
      String email = ValidationUtil.stringValidation(reqData.get('Email'), 'Email', false);
      String grade = ValidationUtil.stringValidation(reqData.get('Grade__c'), 'Grade__c', false);
      Boolean isMarried = ValidationUtil.booleanValidation(reqData.get('IsMarried__c'), 'IsMarried__c', false);
      Date weddingAnniversaryDate = ValidationUtil.dateValidation(reqData.get('WeddingAnniversaryDate__c'), 'WeddingAnniversaryDate__c', false);
      Boolean isEmailAgreed = ValidationUtil.booleanValidation(reqData.get('IsEmailAgreed__c'), 'IsEmailAgreed__c', false);
      Boolean isSMSAgreed = ValidationUtil.booleanValidation(reqData.get('IsSMSAgreed__c'), 'IsSMSAgreed__c', false);
      Boolean isMagazineSubscribed = ValidationUtil.booleanValidation(reqData.get('IsMagazineSubscribed__c'), 'IsMagazineSubscribed__c', false);
      Boolean isMagazineCatalog = ValidationUtil.booleanValidation(reqData.get('IsMagazineCatalog__c'), 'IsMagazineCatalog__c', false); // DM(매거진) == 카탈로그 - 26.05.01 GD 추가
      String magazineSubscriptionSeason = ValidationUtil.stringValidation(reqData.get('MagazineSubscriptionSeason__c'), 'MagazineSubscriptionSeason__c', false); // 매거진 구독 시즌
      Date magazineSubscriptionDate = ValidationUtil.dateValidation(reqData.get('MagazineSubscriptionDate__c'), 'MagazineSubscriptionDate__c', false); // 매거진 구독 일자
      String mailingStreet = ValidationUtil.stringValidation(reqData.get('MailingStreet'), 'MailingStreet', false);
      String mailingPostalCode = ValidationUtil.stringValidation(reqData.get('MailingPostalCode'), 'MailingPostalCode', false);
      Boolean isMobileVerified = ValidationUtil.booleanValidation(reqData.get('IsMobileVerified__c'), 'IsMobileVerified__c', false); // 휴대폰 인증 여부

      // 회원 체크
      List<Contact> cList = [
        SELECT
          Id,
          Lastname,
          MemberType__c,
          Birthdate,
          LegalBirthdate__c, // 26.05.01 GD - 법정 생년월일 추가
          GenderIdentity,
          Phone,
          MobilePhone,
          Grade__c,
          IsMarried__c,
          WeddingAnniversaryDate__c,
          MemberNo__c,
          IsEmailAgreed__c,
          IsSMSAgreed__c,
          IsMagazineSubscribed__c,
          IsMagazineCatalog__c, // 26.05.01 GD - DM(매거진) 추가
          MagazineSubscriptionDate__c,
          PreviousGrade__c,
          StoreRegi__c,
          StoreMana__c,
          Email
        FROM Contact
        WHERE MemberNo__c = :memberNo
        LIMIT 1
      ];
      if (cList.isEmpty()) {
        throw new CustomException(400, '회원이 존재하지 않습니다. ' + memberNo);
      }

      if (lastname != null) {
        cList[0].Lastname = lastname;
      }
      if (memberType != null) {
        cList[0].MemberType__c = memberType;
      }
      if (birthdate != null) {
        cList[0].Birthdate = birthdate;
      }
      // 26.05.01 법정 생년월일 추가
      if (legalBirthdate != null) {
        cList[0].LegalBirthdate__c = legalBirthdate;
      }
      if (genderIdentity != null) {
        cList[0].GenderIdentity = genderIdentity;
      }
      if (phone != null) {
        cList[0].Phone = phone;
      }
      if (mobilePhone != null) {
        cList[0].MobilePhone = mobilePhone;
      }
      if (grade != null) {
        cList[0].PreviousGrade__c = cList[0].Grade__c;
        cList[0].Grade__c = grade;
      }
      if (isMarried != null) {
        cList[0].IsMarried__c = isMarried;
      }
      if (weddingAnniversaryDate != null) {
        cList[0].WeddingAnniversaryDate__c = weddingAnniversaryDate;
      }
      if (isEmailAgreed != null) {
        cList[0].IsEmailAgreed__c = isEmailAgreed;
      }
      if (isSMSAgreed != null) {
        cList[0].IsSMSAgreed__c = isSMSAgreed;
      }
      // 26.05.04 CS : 매거진 구독 시즌 필드 추가
      if (magazineSubscriptionSeason != null) {
        cList[0].MagazineSubscriptionSeason__c = magazineSubscriptionSeason;
      }
      // 26.05.04 CS : 매거진 구독 일자 필드 추가
      if (magazineSubscriptionDate != null) {
        cList[0].MagazineSubscriptionDate__c = magazineSubscriptionDate;
      }
      if (isMagazineSubscribed != null) {
        if (cList[0].IsMagazineSubscribed__c != isMagazineSubscribed) {
          if (isMagazineSubscribed) {
            cList[0].MagazineSubscriptionDate__c = Date.today();
          } else {
            cList[0].MagazineSubscriptionDate__c = null;
          }
          cList[0].IsMagazineSubscribed__c = isMagazineSubscribed;
        }
      }
      // 26.05.01 GD - DM(매거진) 카탈로그 추가
      if (isMagazineCatalog != null) {
        if (cList[0].IsMagazineCatalog__c != isMagazineCatalog) {
          cList[0].IsMagazineCatalog__c = isMagazineCatalog;
        }
      }
      // 회사 체크
      if (companyCode != null) {
        List<Account> accountList = [SELECT Id FROM Account WHERE CompanyCode__c = :companyCode AND ParentId = NULL LIMIT 1];
        if (accountList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 회사 코드입니다.  ' + companyCode);
        }
        cList[0].AccountId = accountList[0].Id;
      }
      // 등록 매장 체크
      if (storeRegiCode != null) {
        List<Account> storeRegiList = [SELECT Id FROM Account WHERE StoreCode__c = :storeRegiCode LIMIT 1];
        if (storeRegiList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다.  ' + storeRegiCode);
        }
        cList[0].StoreRegi__c = storeRegiList[0].Id;
      }
      // 관리 매장 체크
      if (storeManaCode != null) {
        List<Account> storeManaList = [SELECT Id FROM Account WHERE StoreCode__c = :storeManaCode LIMIT 1];
        if (storeManaList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다.  ' + storeManaCode);
        }
        cList[0].StoreMana__c = storeManaList[0].Id;
      }
      // 다른 회원과 이메일 중복 체크
      if (email != null) {
        // if (String.isNotBlank(email)) {
        //   if ([SELECT COUNT() FROM Contact WHERE Email = :email AND MemberNo__c != :memberNo] > 0) {
        //     throw new CustomException(400, '중복된 이메일입니다. ' + email);
        //   }
        // }
        cList[0].Email = email;
      }
      if (mailingStreet != null) {
        cList[0].MailingStreet = mailingStreet;
      }
      if (mailingPostalCode != null) {
        cList[0].MailingPostalCode = mailingPostalCode;
      }
      // 휴대폰 인증 여부
      if (isMobileVerified != null) {
        cList[0].IsMobileVerified__c = isMobileVerified;
      }
      Database.SaveResult result = Database.update(cList[0]);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      if (grade != null) {
        String picklistValue = cList[0].Grade__c;

        Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

        String labelName;
        for (Schema.PicklistEntry entry : picklistValues) {
          if (entry.getValue() == picklistValue) {
            labelName = entry.getLabel();
            break;
          }
        }
        reqData.put('TargetTierName', labelName);

        List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE ContactId = :cList[0].Id LIMIT 1];
        if (lpmList.isEmpty()) {
          throw new CustomException(400, 'LoyaltyProgramMemberID 값이 없습니다.');
        }
        reqData.put('LoyaltyProgramMemberId', lpmList[0].Id);
      }

      return ApiResult.ok(200, '회원 수정 완료', reqData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
  /* ================= 회원 탈퇴 복원 ================= */

  public ApiResult undeleteContact(Map<String, Object> reqData) {
    try {
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

      List<Contact> cList = [
        SELECT Id, IsWithdrawn__c, MemberDropDate__c, Email
        FROM Contact
        WHERE MemberNo__c = :memberNo
        LIMIT 1
      ];

      if (cList.isEmpty()) {
        throw new CustomException(400, '존재하지 않은 회원입니다. ' + memberNo);
      }

      Contact c = cList[0];

      c.IsWithdrawn__c = false;
      c.MemberDropDate__c = null;
      if (c.Email != null) {
        c.Email = c.Email.replaceFirst('^del_\\d{8}_\\d{6}_', '');
      }

      update c;

      /* LoyaltyProgramMember 복원 */

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, MemberStatus, MembershipEndDate
        FROM LoyaltyProgramMember
        WHERE ContactId = :c.Id
      ];

      if (!lpmList.isEmpty()) {
        for (LoyaltyProgramMember lpm : lpmList) {
          lpm.MemberStatus = 'Active';
          lpm.MembershipEndDate = null;
        }

        update lpmList;
      }

      return ApiResult.ok(200, '회원 복원 완료', reqData);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}