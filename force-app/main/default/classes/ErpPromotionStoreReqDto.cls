public class ErpPromotionStoreReqDto {
  public ErpPromotionStoreReqDto() {
  }

  public class CreateRequest {
    public String cd_company;
    public String no_prom;
    public String cd_store;
    public String nm_store;
    public String id_insert;

    public CreateRequest() {
    }

    public CreateRequest(PromotionAccount__c ps) {
      this.cd_company = ps.AccountId__r.CompanyCode__c;
      this.no_prom = ps.PromotionId__r.PromotionNo__c;
      this.cd_store = ps.AccountId__r.StoreCode__c;
      this.nm_store = ps.AccountId__r.Name;
      this.id_insert = UserInfo.getUserName();
    }

    public CreateRequest(String companyCode, String promotionNo, String storeCode, String storeName, String insertId) {
      this.cd_company = companyCode;
      this.no_prom = promotionNo;
      this.cd_store = storeCode;
      this.nm_store = storeName;
      this.id_insert = insertId;
    }
  }

  public class CreateRequestList {
    public List<CreateRequest> promotionStoreList = new List<CreateRequest>();

    public CreateRequestList() {
    }

    public CreateRequestList(List<PromotionAccount__c> promotionAccounts) {
      if (promotionAccounts == null) {
        return;
      }

      for (PromotionAccount__c pa : promotionAccounts) {
        this.promotionStoreList.add(new CreateRequest(pa));
      }
    }
  }

  public class DeleteRequest {
    public String no_prom;
    public String cd_store;
    public String id_delete;

    public DeleteRequest() {
    }

    public DeleteRequest(PromotionAccount__c ps) {
      this.no_prom = ps.PromotionId__r.PromotionNo__c;
      this.cd_store = ps.AccountId__r.StoreCode__c;
      this.id_delete = UserInfo.getUserName();
    }

    public DeleteRequest(String promotionNo, String storeCode, String deleteId) {
      this.no_prom = promotionNo;
      this.cd_store = storeCode;
      this.id_delete = deleteId;
    }
  }

  public class DeleteRequestList {
    public List<DeleteRequest> promotionStoreList = new List<DeleteRequest>();

    public DeleteRequestList() {
    }

    public DeleteRequestList(List<PromotionAccount__c> promotionAccounts) {
      if (promotionAccounts == null) {
        return;
      }

      for (PromotionAccount__c pa : promotionAccounts) {
        this.promotionStoreList.add(new DeleteRequest(pa));
      }
    }
  }

  public class UpdateRequest {
    public String cd_company;
    public String no_prom;
    public String cd_store;
    public String nm_store;
    public String id_update;

    public UpdateRequest() {
    }

    public UpdateRequest(PromotionAccount__c ps) {
      this.cd_company = ps.AccountId__r.CompanyCode__c;
      this.no_prom = ps.PromotionId__r.PromotionNo__c;
      this.cd_store = ps.AccountId__r.StoreCode__c;
      this.nm_store = ps.AccountId__r.Name;
      this.id_update = UserInfo.getUserName();
    }

    public UpdateRequest(String companyCode, String promotionNo, String storeCode, String storeName, String updateId) {
      this.cd_company = companyCode;
      this.no_prom = promotionNo;
      this.cd_store = storeCode;
      this.nm_store = storeName;
      this.id_update = updateId;
    }
  }

  public class UpdateRequestList {
    public List<UpdateRequest> promotionStoreList = new List<UpdateRequest>();

    public UpdateRequestList() {
    }

    public UpdateRequestList(List<PromotionAccount__c> promotionAccounts) {
      if (promotionAccounts == null) {
        return;
      }

      for (PromotionAccount__c pa : promotionAccounts) {
        this.promotionStoreList.add(new UpdateRequest(pa));
      }
    }
  }

  public static String boolToYn(Boolean b) {
    return (b == true) ? 'Y' : 'N';
  }

  public static String isStrNull(String s) {
    return String.isBlank(s) ? '' : s;
  }
}
