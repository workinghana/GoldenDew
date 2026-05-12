public with sharing class TestMemberInfoHelpViewControllerV1 {
  public class MemberHelpView {
    @AuraEnabled
    public String memberNo;
    @AuraEnabled
    public Decimal totalPointsBalance;
    @AuraEnabled
    public List<Object> accrualHistoryList;
    @AuraEnabled
    public List<Object> userDestoryHistoryList;
  }

  @AuraEnabled(cacheable=false)
  public static MemberHelpView getMemberHelpView(String memberNo) {
    if (String.isBlank(memberNo)) {
      throw new AuraHandledException('회원번호를 입력하세요.');
    }

    Map<String, Object> reqData = new Map<String, Object>{ 'MemberNo__c' => memberNo };

    try {
      ApiResult result = new GdMemberHelpInfoServiceImpl().getMemberHelpInfo(reqData);

      if (result == null || result.success != true || result.data == null) {
        String msg = (result != null && String.isNotBlank(result.message)) ? result.message : '조회에 실패했습니다.';
        throw new AuraHandledException(msg);
      }

      MemberHelpView view = new MemberHelpView();
      view.memberNo = memberNo;
      view.totalPointsBalance = toDecimal(result.data.get('TotalPointsBalance'));
      view.accrualHistoryList = toMapList(result.data.get('AccrualHistoryList'));
      view.userDestoryHistoryList = toMapList(result.data.get('UserDestoryHistoryList'));
      return view;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  private static Decimal toDecimal(Object raw) {
    if (raw == null)
      return null;
    if (raw instanceof Decimal)
      return (Decimal) raw;
    if (raw instanceof Integer)
      return Decimal.valueOf((Integer) raw);
    if (raw instanceof Double)
      return Decimal.valueOf((Double) raw);
    try {
      return Decimal.valueOf(String.valueOf(raw));
    } catch (Exception e) {
      return null;
    }
  }

  // PointResDto 내부 클래스에 @AuraEnabled 가 없어 LWC 로 필드가 전달되지 않으므로
  // JSON 직렬화→역직렬화로 Map<String,Object> 리스트로 변환하여 전체 필드를 노출.
  private static List<Object> toMapList(Object raw) {
    if (raw == null) {
      return new List<Object>();
    }
    String jsonStr = System.JSON.serialize(raw);
    return (List<Object>) System.JSON.deserializeUntyped(jsonStr);
  }

  // 포인트 도움창 응답
  public class PointHelpView {
    @AuraEnabled
    public String memberNo;
    @AuraEnabled
    public Decimal totalPoints;
    @AuraEnabled
    public List<Object> pointList;
    @AuraEnabled
    public String message;
  }

  // 회원 포인트 사용 도움창 — 본 로직 수정 없이 GdPointServiceImpl.getPointApplyHelp() 만 호출.
  // 참고: GdPointHelpApiControllerV1 (REST: /services/apexrest/gd/v1/point/help)
  @AuraEnabled(cacheable=false)
  public static PointHelpView getPointHelp(String memberNo, String storeCode, String promotionNo, String orderDate, String saleNo) {
    if (String.isBlank(memberNo)) {
      throw new AuraHandledException('회원번호를 입력하세요.');
    }

    Map<String, Object> reqData = new Map<String, Object>{
      'StoreCode__c' => storeCode == null ? '' : storeCode,
      'MemberNo__c' => memberNo,
      'PromotionNo__c' => promotionNo == null ? '' : promotionNo,
      'OrderDate' => orderDate == null ? '' : orderDate,
      'SaleNo__c' => saleNo == null ? '' : saleNo
    };

    try {
      ApiResult result = new GdPointServiceImpl().getPointApplyHelp(reqData);

      PointHelpView view = new PointHelpView();
      view.memberNo = memberNo;
      view.message = (result != null) ? result.message : null;

      List<Object> rawPointList = new List<Object>();
      if (result != null && result.data != null && result.data.get('pointList') != null) {
        rawPointList = toMapList(result.data.get('pointList'));
      }
      view.pointList = rawPointList;

      Decimal total = 0;
      for (Object o : rawPointList) {
        Map<String, Object> row = (Map<String, Object>) o;
        Decimal pts = toDecimal(row.get('points'));
        if (pts != null) {
          total += pts;
        }
      }
      view.totalPoints = total;
      return view;
    } catch (CustomException ce) {
      throw new AuraHandledException(ce.message);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // 포인트 개별 지급 결과 (성공/실패만 LWC 로 전달)
  public class CreditPointResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public Integer code;
    @AuraEnabled
    public String message;
  }

  // 포인트 개별 지급 — 본 로직 수정 없이 GdPointServiceImpl.creditPoint() 만 호출.
  // 참고: GdPointCreditApiControllerV1 (REST: /services/apexrest/gd/v1/point/credit)
  @AuraEnabled(cacheable=false)
  public static CreditPointResult creditPoints(String jsonBody) {
    CreditPointResult res = new CreditPointResult();

    if (String.isBlank(jsonBody)) {
      res.success = false;
      res.code = 400;
      res.message = '요청 JSON 이 비었습니다.';
      return res;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      res.success = false;
      res.code = 400;
      res.message = 'JSON 파싱 실패: ' + e.getMessage();
      return res;
    }

    try {
      ApiResult apiResult = new GdPointServiceImpl().creditPoint(reqData);
      res.success = (apiResult != null && apiResult.success == true);
      res.code = (apiResult != null && apiResult.code != null) ? apiResult.code : (res.success ? 200 : 500);
      res.message = (apiResult != null && String.isNotBlank(apiResult.message))
        ? apiResult.message
        : (res.success ? '포인트 지급 성공' : '포인트 지급 실패');
      return res;
    } catch (CustomException ce) {
      res.success = false;
      res.code = ce.code;
      res.message = ce.message;
      return res;
    } catch (Exception e) {
      res.success = false;
      res.code = 500;
      res.message = e.getMessage();
      return res;
    }
  }

  // 사용 가능한 쿠폰 도움창 응답
  public class VoucherHelpView {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public Integer code;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public List<Object> couponList;
  }

  // 사용 가능한 쿠폰 도움창 — 본 로직 수정 없이 GdVoucherServiceImpl.getAvailableCouponList() 만 호출.
  // 참고: GdVoucherHelpApiControllerV1 (REST: /services/apexrest/gd/v1/voucher/help)
  @AuraEnabled(cacheable=false)
  public static VoucherHelpView getAvailableCoupons(String jsonBody) {
    VoucherHelpView view = new VoucherHelpView();

    if (String.isBlank(jsonBody)) {
      view.success = false;
      view.code = 400;
      view.message = '요청 JSON 이 비었습니다.';
      view.couponList = new List<Object>();
      return view;
    }

    Map<String, Object> reqData;
    try {
      reqData = (Map<String, Object>) System.JSON.deserializeUntyped(jsonBody);
    } catch (Exception e) {
      view.success = false;
      view.code = 400;
      view.message = 'JSON 파싱 실패: ' + e.getMessage();
      view.couponList = new List<Object>();
      return view;
    }

    try {
      ApiResult result = new GdVoucherServiceImpl().getAvailableCouponList(reqData);
      view.success = (result != null && result.success == true);
      view.code = (result != null && result.code != null) ? result.code : (view.success ? 200 : 500);
      view.message = (result != null && String.isNotBlank(result.message))
        ? result.message
        : (view.success ? '사용 가능한 쿠폰 조회 성공' : '쿠폰 조회 실패');

      // result.data 안의 쿠폰 리스트를 LWC 가 접근 가능한 형태(Map<String,Object>)로 직렬화
      List<Object> rawList = new List<Object>();
      if (result != null && result.data != null) {
        // 흔히 'couponList' / 'CouponList' / 'voucherList' 등 키로 들어옴 — 모두 시도
        Object listObj = result.data.get('couponList');
        if (listObj == null)
          listObj = result.data.get('CouponList');
        if (listObj == null)
          listObj = result.data.get('voucherList');
        if (listObj == null)
          listObj = result.data.get('VoucherList');
        if (listObj != null) {
          rawList = toMapList(listObj);
        }
      }
      view.couponList = rawList;
      return view;
    } catch (CustomException ce) {
      view.success = false;
      view.code = ce.code;
      view.message = ce.message;
      view.couponList = new List<Object>();
      return view;
    } catch (Exception e) {
      view.success = false;
      view.code = 500;
      view.message = e.getMessage();
      view.couponList = new List<Object>();
      return view;
    }
  }
}