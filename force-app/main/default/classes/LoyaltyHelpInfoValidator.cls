/**
 * LoyaltyHelpInfoValidator
 *
 * 책임 — § 9 (포인트 적용 도움창) + § 10 (회원정보 도움창) 표시가 의존하는
 *        데이터 무결성 (invariant) 회원 단위 검증.
 *
 * 도움창 서비스 (`GdPointApplicationHelpInfoServiceImpl`, `GdMemberHelpInfoServiceImpl`)
 * 의 표시 정확성은 (a) LL/LLT/TJ 의 FK 무결성, (b) 삭제 상태 반영, (c) 원천 LL 마커
 * 보존 — 이 세 가지에 의존한다. 본 Validator 는 그 invariant 들을 회원 단위로 점검.
 *
 * 검증 invariant:
 *   1. 활성 LL 의 TransactionJournalId 가 null 이거나 가리키는 TJ 가 IsDeleted__c=TRUE
 *      → 도움창 표시 시 판매번호/취소번호 매핑 실패
 *   2. Active Debit LL 인데 LLT 없음
 *      → 사용 흔적 손실 (어느 적립에서 차감되었는지 모름) → 도움창 원천 표시 불가
 *   3. Active LLT 의 CreditLoyaltyLedger 또는 DebitLoyaltyLedger 미존재 (orphan)
 *      → 도움창 chain traversal 실패
 *   4. Point Redeem Cancel TJ 인데 Credit LL 미발행 (Slack alert 누락 + 환원 미실행)
 *      → 사용 취소가 발생했으나 회원 잔액 복원 안 됨
 *   5. 삭제된 TJ (IsDeleted__c=TRUE) 의 LL.IsDeleted=FALSE 상태 잔존
 *      → 도움창에서 삭제된 거래가 표시되는 문제
 *   6. v3 paradigm 인데 Cancel Credit LL 의 AdditionalNotes 에 ORIGIN_CREDIT_LL 토큰 누락
 *      → 도움창 원천 적립 판매 표시 불가 (LoyaltyPointEventValidator.validateOriginCreditLLTrace
 *        가 chain 끝까지 추적하는 반면, 본 검증은 토큰 존재만 점검 — 가벼운 점검)
 */
public without sharing class LoyaltyHelpInfoValidator {
  private static final String JST_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String ORIGIN_CREDIT_LL_TOKEN = 'ORIGIN_CREDIT_LL=';
  private static final Integer MAX_DETAIL_PER_TYPE = 20;

  public class ValidationResult {
    public Boolean isValid;
    public Id memberId;
    public String memberNo;
    public String memberName;
    public Integer llWithoutTjCount = 0;
    public Integer llReferencingDeletedTjCount = 0;
    public Integer debitLLWithoutLLTCount = 0;
    public Integer orphanLLTCount = 0;
    public Integer cancelTjWithoutCreditLLCount = 0;
    public Integer cancelCreditWithoutOriginTokenCount = 0;
    public List<String> details = new List<String>();
    public String summary;
  }

  public static ValidationResult validateMember(Id memberId) {
    if (memberId == null) {
      return invalid('회원 ID가 필요합니다.');
    }
    ValidationResult result = new ValidationResult();
    result.memberId = memberId;
    populateMemberMeta(result, memberId);

    applyLLTjInvariants(result);
    applyDebitLLTInvariants(result);
    applyOrphanLLTInvariants(result);
    applyCancelTjInvariants(result);
    applyOriginTokenSurvey(result);

    finalize(result);
    return result;
  }

  public static ValidationResult validateMemberByNo(String memberNo) {
    if (String.isBlank(memberNo)) {
      return invalid('회원 번호가 필요합니다.');
    }
    List<LoyaltyProgramMember> members = [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo AND MemberStatus = 'Active'
      LIMIT 1
    ];
    if (members.isEmpty()) {
      return invalid('Active LoyaltyProgramMember not found: ' + memberNo);
    }
    return validateMember(members[0].Id);
  }

  public static Boolean validateAndAlert(Id memberId) {
    ValidationResult result = validateMember(memberId);
    if (result.isValid == true) {
      return true;
    }
    return sendValidationAlert(result);
  }

  public static Boolean validateAndAlertByNo(String memberNo) {
    ValidationResult result = validateMemberByNo(memberNo);
    if (result.isValid == true) {
      return true;
    }
    return sendValidationAlert(result);
  }

  // === Invariants ===

  // 1, 5 — LL ↔ TJ 무결성
  private static void applyLLTjInvariants(ValidationResult result) {
    Integer detailLeft = MAX_DETAIL_PER_TYPE;
    for (LoyaltyLedger ll : [
      SELECT Id, EventType, Points, ExpiryDate,
             TransactionJournalId,
             TransactionJournal.IsDeleted__c,
             TransactionJournal.JournalSubType.Name
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :result.memberId
        AND IsDeleted = FALSE
      LIMIT 50000
    ]) {
      if (ll.TransactionJournalId == null) {
        result.llWithoutTjCount++;
        if (detailLeft > 0) {
          result.details.add('LL_NO_TJ: LL=' + ll.Id + ' Type=' + ll.EventType + ' Points=' + ll.Points);
          detailLeft--;
        }
      } else if (ll.TransactionJournal != null && ll.TransactionJournal.IsDeleted__c == true) {
        result.llReferencingDeletedTjCount++;
        if (detailLeft > 0) {
          result.details.add('LL_REFS_DELETED_TJ: LL=' + ll.Id + ' TJ=' + ll.TransactionJournalId);
          detailLeft--;
        }
      }
    }
  }

  // 2 — Active Debit LL 에 LLT 없음 (사용 흔적 손실)
  private static void applyDebitLLTInvariants(ValidationResult result) {
    Set<Id> debitLLIds = new Set<Id>();
    for (LoyaltyLedger ll : [
      SELECT Id
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :result.memberId
        AND EventType = 'Debit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
      LIMIT 50000
    ]) {
      debitLLIds.add(ll.Id);
    }
    if (debitLLIds.isEmpty()) {
      return;
    }
    Set<Id> debitLLIdsWithLLT = new Set<Id>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT DebitLoyaltyLedgerId
      FROM LoyaltyLedgerTraceability
      WHERE DebitLoyaltyLedgerId IN :debitLLIds
        AND IsDeleted = FALSE
    ]) {
      if (llt.DebitLoyaltyLedgerId != null) {
        debitLLIdsWithLLT.add(llt.DebitLoyaltyLedgerId);
      }
    }
    Integer detailLeft = MAX_DETAIL_PER_TYPE;
    for (Id debitLLId : debitLLIds) {
      if (!debitLLIdsWithLLT.contains(debitLLId)) {
        result.debitLLWithoutLLTCount++;
        if (detailLeft > 0) {
          result.details.add('DEBIT_LL_NO_LLT: LL=' + debitLLId);
          detailLeft--;
        }
      }
    }
  }

  // 3 — Active LLT 의 Credit/Debit LL 가 존재하지 않거나 IsDeleted=TRUE
  private static void applyOrphanLLTInvariants(ValidationResult result) {
    Set<Id> referencedLLIds = new Set<Id>();
    List<LoyaltyLedgerTraceability> llts = [
      SELECT Id, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId, ActionType, Points
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :result.memberId
        AND IsDeleted = FALSE
      LIMIT 50000
    ];
    for (LoyaltyLedgerTraceability llt : llts) {
      if (llt.CreditLoyaltyLedgerId != null) referencedLLIds.add(llt.CreditLoyaltyLedgerId);
      if (llt.DebitLoyaltyLedgerId != null) referencedLLIds.add(llt.DebitLoyaltyLedgerId);
    }
    if (referencedLLIds.isEmpty()) {
      return;
    }
    Set<Id> activeLLIds = new Map<Id, LoyaltyLedger>([
      SELECT Id
      FROM LoyaltyLedger
      WHERE Id IN :referencedLLIds AND IsDeleted = FALSE
    ]).keySet();

    Integer detailLeft = MAX_DETAIL_PER_TYPE;
    for (LoyaltyLedgerTraceability llt : llts) {
      Boolean creditOrphan = (llt.CreditLoyaltyLedgerId != null) && !activeLLIds.contains(llt.CreditLoyaltyLedgerId);
      Boolean debitOrphan = (llt.DebitLoyaltyLedgerId != null) && !activeLLIds.contains(llt.DebitLoyaltyLedgerId);
      if (creditOrphan || debitOrphan) {
        result.orphanLLTCount++;
        if (detailLeft > 0) {
          result.details.add('ORPHAN_LLT: LLT=' + llt.Id +
                             (creditOrphan ? ' creditLL=' + llt.CreditLoyaltyLedgerId + '(missing)' : '') +
                             (debitOrphan ? ' debitLL=' + llt.DebitLoyaltyLedgerId + '(missing)' : ''));
          detailLeft--;
        }
      }
    }
  }

  // 4 — Point Redeem Cancel TJ 인데 Credit LL 미발행
  private static void applyCancelTjInvariants(ValidationResult result) {
    Set<Id> cancelTjIds = new Set<Id>();
    for (TransactionJournal tj : [
      SELECT Id
      FROM TransactionJournal
      WHERE MemberId = :result.memberId
        AND JournalSubType.Name = :JST_POINT_REDEEM_CANCEL
        AND IsDeleted__c = FALSE
        AND Status = 'Processed'
      LIMIT 50000
    ]) {
      cancelTjIds.add(tj.Id);
    }
    if (cancelTjIds.isEmpty()) {
      return;
    }
    Set<Id> tjsWithCreditLL = new Set<Id>();
    for (LoyaltyLedger ll : [
      SELECT TransactionJournalId
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :cancelTjIds
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
    ]) {
      if (ll.TransactionJournalId != null) {
        tjsWithCreditLL.add(ll.TransactionJournalId);
      }
    }
    Integer detailLeft = MAX_DETAIL_PER_TYPE;
    for (Id tjId : cancelTjIds) {
      if (!tjsWithCreditLL.contains(tjId)) {
        result.cancelTjWithoutCreditLLCount++;
        if (detailLeft > 0) {
          result.details.add('CANCEL_TJ_NO_CREDIT_LL: TJ=' + tjId + ' (사용 취소 환원 누락)');
          detailLeft--;
        }
      }
    }
  }

  // 6 — Cancel Credit LL 의 AdditionalNotes 에 ORIGIN_CREDIT_LL 토큰 누락 (v3 paradigm 위반 — 정보용)
  //     심층 chain 검증은 LoyaltyPointEventValidator.validateOriginCreditLLTrace 가 담당.
  private static void applyOriginTokenSurvey(ValidationResult result) {
    Integer detailLeft = MAX_DETAIL_PER_TYPE;
    for (LoyaltyLedger ll : [
      SELECT Id, AdditionalNotes
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :result.memberId
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.JournalSubType.Name = :JST_POINT_REDEEM_CANCEL
        AND TransactionJournal.IsDeleted__c = FALSE
      LIMIT 50000
    ]) {
      String notes = ll.AdditionalNotes;
      if (String.isBlank(notes) || !notes.contains(ORIGIN_CREDIT_LL_TOKEN)) {
        result.cancelCreditWithoutOriginTokenCount++;
        if (detailLeft > 0) {
          result.details.add('NO_ORIGIN_TOKEN: LL=' + ll.Id + ' (v2 paradigm 가능, 정보용)');
          detailLeft--;
        }
      }
    }
  }

  // === Helpers ===

  private static ValidationResult invalid(String message) {
    ValidationResult result = new ValidationResult();
    result.isValid = false;
    result.summary = message;
    return result;
  }

  private static void populateMemberMeta(ValidationResult result, Id memberId) {
    List<LoyaltyProgramMember> members = [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE Id = :memberId
      LIMIT 1
    ];
    if (!members.isEmpty()) {
      result.memberNo = members[0].Contact == null ? members[0].MembershipNumber : members[0].Contact.MemberNo__c;
      result.memberName = (members[0].Contact != null && String.isNotBlank(members[0].Contact.Name))
        ? members[0].Contact.Name
        : (members[0].Account != null ? members[0].Account.Name : members[0].MembershipNumber);
    }
  }

  private static void finalize(ValidationResult result) {
    Integer hardErrors = result.llWithoutTjCount
                       + result.llReferencingDeletedTjCount
                       + result.debitLLWithoutLLTCount
                       + result.orphanLLTCount
                       + result.cancelTjWithoutCreditLLCount;
    // cancelCreditWithoutOriginTokenCount 는 v2 paradigm 호환을 위해 hard error 에서 제외 (info only)
    result.isValid = (hardErrors == 0);
    result.summary = result.isValid
      ? '도움창 invariant 정합 (token 누락 ' + result.cancelCreditWithoutOriginTokenCount + '건 — v2 가능, 정보용)'
      : '도움창 invariant 결함: LL미연결TJ=' + result.llWithoutTjCount +
        ', 삭제TJ참조LL=' + result.llReferencingDeletedTjCount +
        ', LLT없는Debit=' + result.debitLLWithoutLLTCount +
        ', orphan LLT=' + result.orphanLLTCount +
        ', CancelTJ미환원=' + result.cancelTjWithoutCreditLLCount +
        ' (origin토큰누락=' + result.cancelCreditWithoutOriginTokenCount + ' 정보용)';
  }

  private static Boolean sendValidationAlert(ValidationResult result) {
    Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
    if (config == null || !config.Is_Active__c || String.isBlank(config.Webhook_URL__c)) {
      System.debug(LoggingLevel.WARN, '[도움창 invariant 검증] Slack 비활성 — ' + result.summary);
      return false;
    }
    HttpRequest req = new HttpRequest();
    req.setEndpoint(config.Webhook_URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(buildSlackBody(result));
    req.setTimeout(10000);
    HttpResponse res = new Http().send(req);
    return res.getStatusCode() >= 200 && res.getStatusCode() < 300;
  }

  private static String buildSlackBody(ValidationResult result) {
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();
    String memberLink = result.memberId == null ? '' : orgUrl + '/' + result.memberId;
    String memberTitle = String.isBlank(memberLink)
      ? String.valueOf(result.memberName)
      : '<' + memberLink + '|' + result.memberName + '>';

    Map<String, Object> msg = new Map<String, Object>{
      'text' => '[골든듀 모니터링] 도움창 invariant 결함',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'header',
          'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => '도움창 invariant 결함' }
        },
        new Map<String, Object>{
          'type' => 'section',
          'fields' => new List<Object>{
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원:*\n' + memberTitle },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원번호:*\n' + String.valueOf(result.memberNo) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*LL미연결TJ / 삭제TJ참조LL:*\n' +
              result.llWithoutTjCount + ' / ' + result.llReferencingDeletedTjCount },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*LLT없는Debit / orphan LLT:*\n' +
              result.debitLLWithoutLLTCount + ' / ' + result.orphanLLTCount },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*CancelTJ미환원:*\n' +
              result.cancelTjWithoutCreditLLCount },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*origin토큰누락(정보):*\n' +
              result.cancelCreditWithoutOriginTokenCount }
          }
        },
        new Map<String, Object>{
          'type' => 'section',
          'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*요약:*\n' + result.summary }
        }
      }
    };
    return JSON.serialize(msg);
  }
}