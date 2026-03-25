// ! 사용 X
// @RestResource(urlMapping='/gd/promotion/*')
global with sharing class GdPromotionApiController {
  private static GdPromotionService promotionService;
  private static GdVoucherDefinitionService voucherDefinitionService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setPromotionService(GdPromotionService mock) {
    promotionService = mock;
  }

  private static GdPromotionService getPromotionService() {
    if (promotionService == null)
      promotionService = new GdPromotionServiceImpl();
    return promotionService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherDefinitionService(GdVoucherDefinitionService mock) {
    voucherDefinitionService = mock;
  }

  private static GdVoucherDefinitionService getVoucherDefinitionService() {
    if (voucherDefinitionService == null)
      voucherDefinitionService = new GdVoucherDefinitionServiceImpl();
    return voucherDefinitionService;
  }

  /**
   * 프로모션 등록
   * Promotion 생성
   */
  // @HttpPost
  global static void createPromotion() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Promotion insert
      ApiResult promotionResult = getPromotionService().createPromotion(reqData);
      reqData.put('promotionId', promotionResult.data.get('promotionId'));

      // VoucherLimit__c insert
      ApiResult voucherLimitResult = getVoucherDefinitionService().addVoucherLimitByPromotion(reqData);

      ApiResult result = ApiResult.ok(200, '프로모션 등록 완료.', resData);

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }

  // /**
  // ! 보류
  //  * 프로모션 조회
  //  * 프로모션 상세 조회
  //  */
  // @HttpGet
  // global static void doGet() {
  //   RestRequest req = RestContext.request;
  //   ApiResult result = new ApiResult();
  //   try {
  //     String uri = RestContext.request.requestURI;
  //     String basePath = '/gd/promotion';

  //     String subPath = (uri != null && uri.startsWith(basePath)) ? uri.substring(basePath.length()) : '';

  //     subPath = subPath == null ? '' : subPath.trim();
  //     while (subPath.startsWith('/')) {
  //       subPath = subPath.substring(1);
  //     }

  //     Map<String, Object> resData = new Map<String, Object>();
  //     if (!String.isBlank(subPath)) {
  //       // 프로모션 상세 조회
  //       String promotionNo = subPath;

  //       result = getPromotionService().getPromotionDetail(promotionNo);
  //     } else {
  //       // 프로모션 조회
  //       Map<String, String> paramMap = req.params;

  //       result = getPromotionService().getPromotionList(paramMap);
  //     }

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, null, 500);
  //   }
  // }

  public virtual class PromotionDTO {
    public String id;
    public String promotionNo;
    public String name;
    public String status;
    public String startDate;
    public String endDate;
    public String summary;

    public PromotionDTO(Promotion p) {
      // this.id = (String) p.Id;
      // this.promotionNo = p.Promotion;
      // this.name = p.Name;
      // this.status = p.Status__c;
      // this.startDate = (p.Promotion == null) ? null : p.Promotion.format();
      // this.endDate = (p.Promotion == null) ? null : p.Promotion.format();
      // this.summary = p.Summary__c;
    }
  }

  public class PromotionDetailDTO extends PromotionDTO {
    public String description;
    public Decimal discountRate;
    public Decimal minSalesAmount;

    public PromotionDetailDTO(Promotion p) {
      super(p);
      // this.description = p.Description__c;
      // this.discountRate = p.DiscountRate__c;
      // this.minSalesAmount = p.MinSalesAmount__c;
    }
  }
}