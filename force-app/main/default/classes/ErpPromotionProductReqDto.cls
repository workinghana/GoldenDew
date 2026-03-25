/**
 * ERP Promotion Product API Request DTO
 *
 * @author Changhwan Kim
 * @since 2026-02-04
 */
public class ErpPromotionProductReqDto {
  public ErpPromotionProductReqDto() {
  }

  public class PromotionItem {
    public String no_prom;
    public String cd_item;
    public String id_insert;
    public String id_update;
    public String id_delete;

    public PromotionItem() {
    }

    public PromotionItem(PromotionProduct pp) {
      this.no_prom = pp.Promotion.PromotionNo__c;
      this.cd_item = pp.Product.ProductCode;
    }
  }

  public class CreateRequestList {
    public List<PromotionItem> promotionItemList = new List<PromotionItem>();

    public CreateRequestList() {
    }

    public CreateRequestList(List<PromotionProduct> promotionProducts) {
      if (promotionProducts == null) {
        return;
      }

      for (PromotionProduct pp : promotionProducts) {
        PromotionItem item = new PromotionItem(pp);
        item.id_insert = UserInfo.getUserName();
        this.promotionItemList.add(item);
      }
    }
  }

  public class UpdateRequestList {
    public List<PromotionItem> promotionItemList = new List<PromotionItem>();

    public UpdateRequestList() {
    }

    public UpdateRequestList(List<PromotionProduct> promotionProducts) {
      if (promotionProducts == null) {
        return;
      }

      for (PromotionProduct pp : promotionProducts) {
        PromotionItem item = new PromotionItem(pp);
        item.id_update = UserInfo.getUserName();
        this.promotionItemList.add(item);
      }
    }
  }

  public class DeleteRequestList {
    public List<PromotionItem> promotionItemList = new List<PromotionItem>();

    public DeleteRequestList() {
    }

    public DeleteRequestList(List<PromotionProduct> promotionProducts) {
      if (promotionProducts == null) {
        return;
      }

      for (PromotionProduct pp : promotionProducts) {
        PromotionItem item = new PromotionItem(pp);
        item.id_delete = UserInfo.getUserName();
        this.promotionItemList.add(item);
      }
    }
  }

  public class CreateRequest {
    public String no_prom;
    public String cd_item;
    public String id_insert;

    public CreateRequest() {
    }

    public CreateRequest(PromotionProduct pp) {
      this.no_prom = pp.Promotion.PromotionNo__c;
      this.cd_item = pp.Product.ProductCode;
      this.id_insert = UserInfo.getUserName();
    }
  }

  public class DeleteRequest {
    public String no_prom;
    public String cd_item;
    public String id_delete;

    public DeleteRequest() {
    }

    public DeleteRequest(PromotionProduct pp) {
      this.no_prom = pp.Promotion.PromotionNo__c;
      this.cd_item = pp.Product.ProductCode;
      this.id_delete = UserInfo.getUserName();
    }
  }

  public class UpdateRequest {
    public String no_prom;
    public String cd_item;
    public String id_update;

    public UpdateRequest() {
    }
  }

  public static String dateToYmd(Date d) {
    if (d == null) {
      return '';
    }
    return String.valueOf(d).replaceAll('-', '');
  }

  public static String dtToYmd(Datetime dt) {
    if (dt == null) {
      return '';
    }
    return dt.format('yyyyMMdd', 'Asia/Seoul');
  }

  public static String boolToYn(Boolean b) {
    return (b == true) ? 'Y' : 'N';
  }

  public static String isStrNull(String s) {
    return (String.isBlank(s)) ? '' : s;
  }
}