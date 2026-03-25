/**
 * ERP 쿠폰 도메인 후처리 콜백
 * - 공통 이벤트 발행(ErpAsyncFailure__e)은 ErpAsyncCallbackPublisher가 담당
 * - 이 클래스는 "쿠폰 관련 레코드 상태 변경" 같은 도메인 후처리만 담당
 *
 * @author Changhwan Kim
 * @since 2026-01-15
 */
public with sharing class ErpCouponAsyncCallback implements ErpAsyncCallback {
  // 필요하면 apiName 상수화 (프로젝트 네이밍에 맞춰 수정)
  public static final String API_COUPON_ISSUE = 'COUPON_ISSUE';
  public static final String API_COUPON_UPDATE = 'COUPON_UPDATE';
  public static final String API_CREATE_MASTER = 'CREATE_MASTER';
  public static final String API_UPDATE_MASTER = 'UPDATE_MASTER';
  public static final String API_DELETE_MASTER = 'DELETE_MASTER';

  public ErpCouponAsyncCallback() {
  }

  /**
   * 성공 시 후처리 (원하면 구현)
   * - 예: 쿠폰 상태 ISSUED로 변경 등
   */
  public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
    // 지금 요구사항은 "실패 시 상태 변경"이므로 일단 비워둬도 됩니다.
    // 필요하면 apiName 별로 성공 후처리 추가 가능
  }

  /**
   * 실패 시 후처리 (쿠폰 상태 변경)
   * - HttpErrorException.responseBody에서 message 추출해서 실패 사유 저장 가능
   */
  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId) {
    // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
    if (isCouponApi(apiName)) {
      if (recordId == null) {
        return;
      }
      List<Voucher> vList = [
        SELECT Id, Status, ProcessResult__c
        FROM Voucher
        WHERE Id = :recordId
        LIMIT 1
      ];
      if (!vList.isEmpty()) {
        vList[0].Status = 'Cancelled';
        vList[0].ProcessResult__c = 'ISSUE_FAILED';
        update vList[0];
      } else {
        System.debug('쿠폰 레코드를 찾을 수 없습니다. Id=' + recordId);
      }
    } else if (isCouponMasterApi(apiName)) {
      if (API_DELETE_MASTER.equals(apiName)) {
        if (recordId == null) {
          return;
        }
        List<VoucherDefinition> vdList = [
          SELECT Id
          FROM VoucherDefinition
          WHERE Id = :recordId AND IsDeleted = TRUE
          LIMIT 1
          ALL ROWS
        ];
        if (!vdList.isEmpty()) {
          undelete vdList[0];
          System.debug('쿠폰 마스터 삭제 실패 => 복원 성공');
        } else {
          System.debug('쿠폰 레코드를 찾을 수 없습니다. Id=' + recordId);
        }
      }
    } else {
      return;
    }
  }

  /**
   * 실패 시 후처리 (쿠폰 이전 값으로 원복)
   */
  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject o) {
    // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
    if (isCouponMasterApi(apiName)) {
      if (API_UPDATE_MASTER.equals(apiName)) {
        if (o == null) {
          // 알림 필요 할 듯
          return;
        }
        VoucherDefinition vdOld;
        try {
          vdOld = (VoucherDefinition) o;
        } catch (Exception castEx) {
          // 알림 필요 할 듯
        }

        // 원복: 업데이트할 필드만 명시적으로 세팅
        VoucherDefinition rollbackVd = new VoucherDefinition(Id = recordId);

        // 트리거 enqueue 방지 플래그
        rollbackVd.ErpSyncSkip__c = true;
        rollbackVd.AccountId__c = vdOld.AccountId__c;
        rollbackVd.CouponManNo__c = vdOld.CouponManNo__c;
        rollbackVd.Name = vdOld.Name;
        rollbackVd.brand__c = vdOld.brand__c;
        rollbackVd.CouponTypeCode__c = vdOld.CouponTypeCode__c;
        rollbackVd.CodePrefix = vdOld.CodePrefix;
        rollbackVd.CodeSuffix = vdOld.CodeSuffix;
        rollbackVd.ExpirationType = vdOld.ExpirationType;
        rollbackVd.EffectiveDate = vdOld.EffectiveDate;
        rollbackVd.ExpirationDate = vdOld.ExpirationDate;
        rollbackVd.ExpirationPeriod = vdOld.ExpirationPeriod;
        rollbackVd.Description = vdOld.Description;
        rollbackVd.DiscountPercent = vdOld.DiscountPercent;
        rollbackVd.FaceValue = vdOld.FaceValue;
        rollbackVd.ResponsibleDepartment__c = vdOld.ResponsibleDepartment__c;
        rollbackVd.ResponsiblePerson__c = vdOld.ResponsiblePerson__c;
        rollbackVd.InsertId__c = vdOld.InsertId__c;

        // 원복 실행
        update rollbackVd;

        // ERP Callout 스킵 여부 해제
        rollbackVd.ErpSyncSkip__c = false;
        update rollbackVd;

        return;
      }
    } else {
      return;
    }
  }

  /**
   * (옵션) 문자열/스택으로 넘어오는 실패 후처리도 받을 수 있게 비워둠
   */
  public void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace) {
    // 필요 시: recordId를 여기서 못 받으니 일반 로그용으로만 사용하거나,
    // requestDto에 recordId가 포함되어 있으면 파싱해서 업데이트하는 방식도 가능
  }

  public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
  }

  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) {
    System.debug('onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) 진입');

    // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
    if (isCouponApi(apiName)) {
      if (recordIds.isEmpty()) {
        return;
      }

      List<Voucher> vList = [
        SELECT Id, Status, ProcessResult__c
        FROM Voucher
        WHERE Id IN :recordIds
      ];

      if (vList.isEmpty()) {
        return;
      }

      if (API_COUPON_ISSUE.equals(apiName)) {
        for (Voucher v : vList) {
          v.Status = 'Cancelled';
          v.ProcessResult__c = 'ISSUE_FAILED'; // 지급 실패
        }
        update vList;
      } else if (API_COUPON_UPDATE.equals(apiName)) {
        for (Voucher v : vList) {
          v.ProcessResult__c = 'EXPIRE_FAILED'; // 소멸 실패
        }
        update vList;
      }
    }
  }

  public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {
    // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
    if (isCouponApi(apiName)) {
      if (recordIds.isEmpty()) {
        return;
      }
      List<Voucher> vList = [
        SELECT Id, Status, ProcessResult__c
        FROM Voucher
        WHERE Id IN :recordIds
      ];
      if (!vList.isEmpty()) {
        for (Voucher v : vList) {
          v.Status = 'Cancelled';
          v.ProcessResult__c = 'ISSUE_FAILED';
        }
        update vList;
      } else {
        System.debug('쿠폰 레코드 리스트를 찾을 수 없습니다.');
      }
    }
  }

  public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
    // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
    if (isCouponApi(apiName)) {
      if (recordId == null) {
        return;
      }
      List<Voucher> vList = [
        SELECT Id, Status, ProcessResult__c
        FROM Voucher
        WHERE Id = :recordId
        LIMIT 1
      ];
      if (!vList.isEmpty()) {
        vList[0].Status = 'Cancelled';
        vList[0].ProcessResult__c = 'ISSUE_FAILED';
        update vList[0];
      } else {
        System.debug('쿠폰 레코드를 찾을 수 없습니다. Id=' + recordId);
      }
    } else if (isCouponMasterApi(apiName)) {
    } else {
      return;
    }
  }

  // ---------- helpers ----------

  private static Boolean isCouponApi(String apiName) {
    return apiName == API_COUPON_ISSUE || apiName == API_COUPON_UPDATE;
  }

  private static Boolean isCouponMasterApi(String apiName) {
    return apiName == API_CREATE_MASTER || apiName == API_UPDATE_MASTER || apiName == API_DELETE_MASTER;
  }

  /** ERP 표준 응답 { success, message, data } 에서 message만 추출 */
  @TestVisible
  private static String extractMessage(String responseBody) {
    if (String.isBlank(responseBody)) {
      return null;
    }

    try {
      Object obj = JSON.deserializeUntyped(responseBody);
      if (obj instanceof Map<String, Object>) {
        Map<String, Object> m = (Map<String, Object>) obj;
        Object msg = m.get('message');
        if (msg != null) {
          return String.valueOf(msg);
        }
      }
    } catch (Exception e) {
      // JSON 파싱 실패 시 원문 그대로 사용
      return responseBody;
    }

    return responseBody; // 최후의 안전망
  }
}