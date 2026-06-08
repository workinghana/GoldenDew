import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMemberProfile from "@salesforce/apex/ContactUiController.getMemberProfile";
import getMemebrInfo from "@salesforce/apex/MemberDetailUIController.getMemebrInfo";
import rebuildAndValidate from "@salesforce/apex/LoyaltyPointValidationUIController.rebuildAndValidate";
import validateIntegrity from "@salesforce/apex/LoyaltyPointValidationUIController.validateIntegrity";

export default class ProgramMemberField extends LightningElement {
  @api recordId;

  member;
  benefit;
  grade;
  marketing;

  @track isFlowOpen = false;
  @track flowApiName;
  @track flowTitle;
  @track flowInputVariables = [];

  @track isReconcileOpen = false;
  @track isVerifyConfirmVisible = false;
  @track isVerifying = false;
  @track isFinalConfirmVisible = false;
  @track isVerificationResultModalOpen = false;
  @track verificationResult = null;
  @track isRebuilding = false;
  @track isRebuildResultModalOpen = false;
  @track rebuildResult = null;

  // 심층 검증(3차) 흐름
  @track isDeepConfirmVisible = false;
  @track isIntegrityVerifying = false;
  @track isIntegrityResultModalOpen = false;
  @track integrityResult = null;

  wiredMemberResult;
  wiredMemberInfoResult;

  displayValue(value) {
    if (value === null || value === undefined || value === "") {
      return "정보 없음";
    }
    return value;
  }

  /* ================= 회원 기본 정보 ================= */

  @wire(getMemberProfile, { loyaltyProgramMemberId: "$recordId" })
  wiredMember(result) {
    this.wiredMemberResult = result;
    const { data, error } = result;

    if (data) {
      this.member = data;
    }

    if (error) {
      console.error(error);
    }
  }

  /* ================= 혜택 / 등급 / 마케팅 ================= */

  @wire(getMemebrInfo, { loyaltyProgramMemberId: "$recordId" })
  wiredMemberInfo(result) {
    this.wiredMemberInfoResult = result;
    const { data, error } = result;

    if (data) {
      this.benefit = data.benefit;
      this.grade = data.grade;
      this.marketing = data.marketing;
    }

    if (error) {
      console.error(error);
    }
  }

  /** 이메일 줄바꿈 */
  get emailText() {
    const email = this.member?.email;

    if (!email) {
      return "정보 없음";
    }

    // 삭제 prefix 패턴 찾기
    const regex = /(del_\d{8}_\d{6}_)/g;

    const matches = email.match(regex);

    if (!matches) {
      // 일반 이메일이면 그대로
      return email;
    }

    // prefix 부분 제거해서 실제 이메일 추출
    let remaining = email;
    let formatted = "";

    matches.forEach((m) => {
      formatted += m + "\n";
      remaining = remaining.replace(m, "");
    });

    // 마지막 실제 이메일
    formatted += remaining;

    return formatted;
  }

  get memberNumberText() {
    return this.displayValue(this.member?.memberNumber);
  }

  get mobilePhoneText() {
    const raw = this.member?.mobilePhone;
    if (!raw) {
      return this.displayValue(raw);
    }

    const digits = raw.replace(/\D/g, "");
    if (digits.length === 11) {
      return digits.replace(/(\d{3})(\d{4})(\d{4})/, "$1-$2-$3");
    }
    if (digits.length === 10) {
      return digits.replace(/(\d{3})(\d{3})(\d{4})/, "$1-$2-$3");
    }

    return raw;
  }

  get addressText() {
    const raw = this.member?.address;
    if (!raw) {
      return this.displayValue(raw);
    }
    // 끝의 " 호" / " 동" 같은 짧은 토큰이 줄바꿈으로 떨어지지 않도록 비분리 공백으로 묶음
    const sanitized = raw.replace(/\s+(호|동|층|번지)\s*$/, " $1");
    return this.displayValue(sanitized);
  }

  get addressDetailText() {
    return this.displayValue(this.member?.addressDetail);
  }

  get storeNameText() {
    return this.displayValue(this.member?.storeName);
  }

  get signupStoreText() {
    return this.displayValue(this.member?.signupStore);
  }

  /* ================= 현재 등급 ================= */

  get currentGrade() {
    const grade = this.member?.grade || this.grade?.currentGrade;

    if (!grade) {
      return "멤버십 미가입";
    }

    return grade;
  }

  /* ================= 등급 Badge ================= */

  get gradeClass() {
    const g = this.member?.grade || this.grade?.currentGrade;

    if (!g) return "badge grade";

    const grade = g.toUpperCase();

    if (grade.includes("GIP")) return "badge grade gip";
    if (grade.includes("VIP") && !grade.includes("SVIP")) return "badge grade vip";
    if (grade.includes("VVIP")) return "badge grade vvip";
    if (grade.includes("SVIP")) return "badge grade svip";

    return "badge grade";
  }

  /* ================= 회원 상태 ================= */

  get memberStatusLabel() {
    if (!this.member) return "정보 없음";
    return this.member.isWithdrawn === true ? "탈퇴 회원" : "활성 회원";
  }

  get memberStatusClass() {
    if (!this.member) {
      return "member-status";
    }
    return this.member.isWithdrawn === true ? "member-status inactive" : "member-status active";
  }

  get showWithdrawDate() {
    return this.member?.isWithdrawn === true && this.member?.withdrawDate;
  }

  get withdrawDateText() {
    if (!this.member?.withdrawDate) return "정보 없음";

    const d = new Date(this.member.withdrawDate);

    return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")}`;
  }

  formatDate(value) {
    if (!value) return "정보 없음";

    const d = new Date(value);

    return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")}`;
  }

  get birthdateText() {
    const raw = this.member?.legalBirthdate;
    if (!raw || typeof raw !== "string" || raw.length !== 6) {
      return "정보 없음";
    }

    const yy = raw.substring(0, 2);
    const mm = raw.substring(2, 4);
    const dd = raw.substring(4, 6);
    const yyNum = parseInt(yy, 10);
    if (Number.isNaN(yyNum)) {
      return "정보 없음";
    }

    const fullYear = yyNum <= 29 ? 2000 + yyNum : 1900 + yyNum;
    return `${fullYear}.${mm}.${dd}`;
  }

  get weddingDateText() {
    return this.formatDate(this.member?.weddingAnniversaryDate);
  }

  get enrollmentDateText() {
    return this.formatDate(this.member?.enrollmentDate);
  }

  get marriedText() {
    if (this.member?.isMarried === true) return "기혼";
    if (this.member?.isMarried === false) return "미혼";

    return "정보 없음";
  }

  get mobileVerifiedText() {
    if (this.member?.isMobileVerified === true) return "인증";
    if (this.member?.isMobileVerified === false) return "미인증";

    return "정보 없음";
  }

  get memberTypeText() {
    return this.displayValue(this.member?.memberType);
  }

  /* ================= 혜택 ================= */

  get ownedCouponText() {
    return this.benefit?.ownedCoupon || 0;
  }

  get ownedPointText() {
    return this.benefit?.ownedPoint || 0;
  }

  /* ================= 구매 금액 ================= */

  get totalPurchaseText() {
    const value = this.grade?.totalPurchaseAmount;

    if (!value || value === 0) {
      return "구매 내역 없음";
    }

    return new Intl.NumberFormat("ko-KR").format(value);
  }

  get tierQualifyingSpendText() {
    const value = this.member?.tierQualifyingSpend3Y;

    if (!value || value === 0) {
      return "구매 내역 없음";
    }

    return new Intl.NumberFormat("ko-KR").format(value);
  }

  get gradeUpdatedText() {
    const dt = this.grade?.lastUpdatedDate;

    if (!dt) return "정보 없음";

    const d = new Date(dt);

    return `${d.getUTCFullYear()}.${String(d.getUTCMonth() + 1).padStart(2, "0")}.${String(d.getUTCDate()).padStart(2, "0")}`;
  }

  /* ================= 마케팅 ================= */

  get emailConsentLabel() {
    return this.marketing?.emailConsent ? "동의" : "미동의";
  }

  get smsConsentLabel() {
    return this.marketing?.smsConsent ? "동의" : "미동의";
  }

  get magazinConsentLabel() {
    return this.marketing?.magazineConsent ? "동의" : "미동의";
  }

  get magazineCatalogLabel() {
    return this.marketing?.magazineCatalogConsent ? "동의" : "미동의";
  }

  get magazineConsentDateText() {
    const dt = this.marketing?.magazineUpdatedDate;

    if (!dt) return "정보 없음";

    const d = new Date(dt);

    return `${d.getUTCFullYear()}.${String(d.getUTCMonth() + 1).padStart(2, "0")}.${String(d.getUTCDate()).padStart(2, "0")}`;
  }

  /* ================= 쿠폰 발급 ================= */

  handleIssueCoupon() {
    this.flowTitle = "쿠폰 발급";
    this.flowApiName = "SCF_Issue_Coupon";

    this.flowInputVariables = [
      {
        name: "recordId",
        type: "String",
        value: this.recordId
      }
    ];

    this.isFlowOpen = true;
  }

  /* ================= 포인트 지급 ================= */

  handleCreditPoints() {
    this.flowTitle = "포인트 지급";
    this.flowApiName = "SCF_Credit_Point";

    this.flowInputVariables = [
      {
        name: "recordId",
        type: "String",
        value: this.recordId
      }
    ];

    this.isFlowOpen = true;
  }

  handleFlowStatusChange(event) {
    const status = event.detail.status;

    if (status === "FINISHED" || status === "FINISHED_SCREEN") {
      this.closeFlow();

      refreshApex(this.wiredMemberResult);
      refreshApex(this.wiredMemberInfoResult);
    }
  }

  closeFlow() {
    this.isFlowOpen = false;
    this.flowApiName = null;
    this.flowInputVariables = [];
  }

  /* ================= 포인트 재정합 ================= */

  handleOpenReconcile() {
    this.isReconcileOpen = true;
    this.isVerifyConfirmVisible = false;
    this.isVerifying = false;
    this.isFinalConfirmVisible = false;
    this.isVerificationResultModalOpen = false;
    this.verificationResult = null;
    this.isRebuilding = false;
    this.isRebuildResultModalOpen = false;
    this.rebuildResult = null;
    this.isDeepConfirmVisible = false;
    this.isIntegrityVerifying = false;
    this.isIntegrityResultModalOpen = false;
    this.integrityResult = null;
  }

  handleCloseReconcile() {
    this.isReconcileOpen = false;
    this.isVerifyConfirmVisible = false;
    this.isVerifying = false;
    this.isFinalConfirmVisible = false;
    this.isVerificationResultModalOpen = false;
    this.verificationResult = null;
    this.isRebuilding = false;
    this.isRebuildResultModalOpen = false;
    this.rebuildResult = null;
    this.isDeepConfirmVisible = false;
    this.isIntegrityVerifying = false;
    this.isIntegrityResultModalOpen = false;
    this.integrityResult = null;
  }

  handleStartVerify() {
    this.isVerifyConfirmVisible = true;
  }

  handleCancelVerify() {
    this.isVerifyConfirmVisible = false;
  }

  /* 확인 다이얼로그 [계속 진행] → 포인트 재정합(검증) 실행 */
  async handleConfirmVerify() {
    this.isVerifyConfirmVisible = false;
    this.isRebuilding = true;
    this.isRebuildResultModalOpen = false;

    try {
      const memberNo = this.member?.memberNumber;
      if (!memberNo) {
        throw new Error("회원번호를 확인할 수 없습니다.");
      }

      this.rebuildResult = await rebuildAndValidate({ memberNo });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("포인트 재정합 실패", error);
      this.rebuildResult = {
        success: false,
        message: error?.body?.message || error?.message || "재정합 중 오류가 발생했습니다.",
        beforeResult: null,
        afterResult: null
      };
    } finally {
      this.isRebuilding = false;
      this.isRebuildResultModalOpen = true;
    }
  }

  handleCloseVerificationResult() {
    this.isVerificationResultModalOpen = false;
  }

  /* 1차 검증 결과 모달에서 "계속 진행" 클릭 시 → 재정합 실행 */
  async handleProceedToFinalReconcile() {
    this.isVerificationResultModalOpen = false;
    this.isRebuilding = true;

    try {
      const memberNo = this.member?.memberNumber;
      if (!memberNo) {
        throw new Error("회원번호를 확인할 수 없습니다.");
      }

      const result = await rebuildAndValidate({ memberNo });
      this.rebuildResult = result;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("포인트 재정합 실패", error);
      this.rebuildResult = {
        success: false,
        message: error?.body?.message || error?.message || "재정합 중 오류가 발생했습니다.",
        beforeResult: null,
        afterResult: null
      };
    } finally {
      this.isRebuilding = false;
      this.isRebuildResultModalOpen = true;
    }
  }

  /* 재정합 결과 모달에서 "계속 진행" 클릭 시 → 최종 반영 경고 다이얼로그 */
  handleProceedToFinalApply() {
    this.isRebuildResultModalOpen = false;
    this.isFinalConfirmVisible = true;
  }

  /* 재정합 결과 모달에서 "취소" 클릭 → 결과 모달만 닫음 (재정합 모달은 유지) */
  handleCancelRebuildResult() {
    this.isRebuildResultModalOpen = false;
  }

  /* ================= 포인트 검증 → 1차(계산) 실행 ================= */
  /* 일치하면 모달 없이 곧장 심층 검증까지 자동 진행, 불일치하면 결과 모달 + [심층 검증] */
  async handlePointVerify() {
    this.isRebuilding = true;
    this.isRebuildResultModalOpen = false;

    let rebuildFailed = false;
    try {
      const memberNo = this.member?.memberNumber;
      if (!memberNo) {
        throw new Error("회원번호를 확인할 수 없습니다.");
      }

      this.rebuildResult = await rebuildAndValidate({ memberNo });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("포인트 검증 실패", error);
      rebuildFailed = true;
      this.rebuildResult = {
        success: false,
        message: error?.body?.message || error?.message || "검증 중 오류가 발생했습니다.",
        beforeResult: null,
        afterResult: null
      };
    } finally {
      this.isRebuilding = false;
    }

    // 1차 계산 일치 → 모달 없이 곧장 심층 검증까지 자동 진행
    if (!rebuildFailed && this.isRebuildSuccess) {
      await this.runIntegrityVerify();
    } else {
      // 불일치(또는 오류) → 결과 모달 (불일치 시 [심층 검증] 버튼 노출)
      this.isRebuildResultModalOpen = true;
    }
  }

  /* ================= 심층 검증(3차) 흐름 ================= */
  /* 2차 결과 모달 → [심층 검증] → 확인 다이얼로그 */
  handleStartDeepVerify() {
    this.isDeepConfirmVisible = true;
  }

  handleCancelDeepVerify() {
    this.isDeepConfirmVisible = false;
  }

  /* 확인 다이얼로그 [확인] → 심층 검증 실행 (불일치 수동 경로) */
  async handleConfirmDeepVerify() {
    this.isDeepConfirmVisible = false;
    await this.runIntegrityVerify();
  }

  /* 심층 검증(validateIntegrity) 실행 공통 — 자동(일치 후)·수동(불일치 후) 경로 공용 */
  async runIntegrityVerify() {
    this.isRebuildResultModalOpen = false;
    this.isDeepConfirmVisible = false;
    this.isIntegrityVerifying = true;

    try {
      const memberNo = this.member?.memberNumber;
      if (!memberNo) {
        throw new Error("회원번호를 확인할 수 없습니다.");
      }

      this.integrityResult = await validateIntegrity({ memberNo });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("심층 검증 실패", error);
      this.integrityResult = {
        isValid: false,
        summary: error?.body?.message || error?.message || "심층 검증 중 오류가 발생했습니다."
      };
    } finally {
      this.isIntegrityVerifying = false;
      this.isIntegrityResultModalOpen = true;
    }
  }

  handleCloseIntegrityResult() {
    this.isIntegrityResultModalOpen = false;
    this.isReconcileOpen = false;
    this.integrityResult = null;
    this.rebuildResult = null;
    refreshApex(this.wiredMemberResult);
    refreshApex(this.wiredMemberInfoResult);
  }

  /* ===== 3차(심층 검증) 결과 표시 getter ===== */
  get isIntegrityValid() {
    return this.integrityResult?.isValid === true;
  }

  get integrityResultTitle() {
    if (this.isIntegrityValid) {
      return this.isRebuildSuccess ? "포인트 검증이 완료되었습니다" : "거래 이력 검증을 통과했습니다";
    }
    return "거래 이력에서 불일치가 발견되었습니다";
  }

  get integritySummary() {
    if (!this.integrityResult) return "";
    if (this.isIntegrityValid) {
      if (this.isRebuildSuccess) {
        return "포인트 계산 결과가 일치했습니다.\n심층(거래 이력) 검증까지 일치하는 것으로 확인되었습니다.";
      }
      return "거래 이력 심층 검증 결과,\n회원 포인트가 일치합니다.";
    }
    return "거래 이력을 다시 계산한 결과,\n회원 포인트와 맞지 않는 부분이 있습니다.\n아래 차이 내역을 확인하고\n담당자에게 보정을 요청해 주세요.";
  }

  get integrityIconName() {
    return this.isIntegrityValid ? "utility:success" : "utility:warning";
  }

  get integrityIconWrapClass() {
    return this.isIntegrityValid
      ? "reconcile-result-dialog__icon-wrap reconcile-result-dialog__icon-wrap--success"
      : "reconcile-result-dialog__icon-wrap reconcile-result-dialog__icon-wrap--warning";
  }

  get integrityIconClass() {
    return this.isIntegrityValid ? "reconcile-result-dialog__icon--success" : "reconcile-result-dialog__icon--warning";
  }

  get hasIntegrityDifference() {
    return !this.isIntegrityValid;
  }

  get integrityExpectedText() {
    const n = this.integrityResult?.finalExpectedBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get integrityActualText() {
    const n = this.integrityResult?.finalActualBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get integrityDiffText() {
    const n = this.integrityResult?.finalBalanceDifference ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get integrityMismatchCountText() {
    return `${this.integrityResult?.mismatchCount ?? 0}건`;
  }

  get isVerificationValid() {
    return this.verificationResult?.isValid === true;
  }

  get verificationResultMessage() {
    if (!this.verificationResult) return "";
    if (this.verificationResult.isValid === true) {
      return "회원 포인트 내역이 정상적으로 일치합니다.";
    }
    return "회원 포인트 내역이 일치하지 않습니다.\n포인트 재정합을 진행하시겠습니까?";
  }

  /* 검증 결과 상세 — 박스 안 3행 표시용 */
  get lmcBalanceText() {
    const n = this.verificationResult?.lmcBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get calculatedBalanceText() {
    const n = this.verificationResult?.calculatedBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get differenceText() {
    const n = this.verificationResult?.difference ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get verificationResultIconName() {
    return this.verificationResult?.isValid ? "utility:success" : "utility:warning";
  }

  get verificationResultIconWrapClass() {
    return this.verificationResult?.isValid
      ? "reconcile-result-dialog__icon-wrap reconcile-result-dialog__icon-wrap--success"
      : "reconcile-result-dialog__icon-wrap reconcile-result-dialog__icon-wrap--warning";
  }

  get verificationResultIconClass() {
    return this.verificationResult?.isValid ? "reconcile-result-dialog__icon--success" : "reconcile-result-dialog__icon--warning";
  }

  get hasVerificationDifference() {
    if (!this.verificationResult || this.verificationResult.isValid === true) {
      return false;
    }
    return (
      this.verificationResult.difference !== undefined && this.verificationResult.difference !== null && this.verificationResult.difference !== 0
    );
  }

  get verificationDifferenceDetail() {
    if (!this.verificationResult) return "";
    const lmc = this.verificationResult.lmcBalance ?? 0;
    const calc = this.verificationResult.calculatedBalance ?? 0;
    const diff = this.verificationResult.difference ?? 0;
    const fmt = (n) => new Intl.NumberFormat("ko-KR").format(n);
    return `시스템 잔액 ${fmt(lmc)}P · 계산 잔액 ${fmt(calc)}P · 차이 ${fmt(diff)}P`;
  }

  handleRequestFinalApply() {
    this.isFinalConfirmVisible = true;
  }

  handleCancelFinal() {
    this.isFinalConfirmVisible = false;
  }

  /* 최종 반영 — 재정합은 이미 완료된 상태이므로 모달 정리 + 회원 데이터 새로고침 */
  handleApplyFinal() {
    this.isFinalConfirmVisible = false;
    this.isRebuildResultModalOpen = false;
    this.isReconcileOpen = false;
    this.verificationResult = null;
    this.rebuildResult = null;
    refreshApex(this.wiredMemberResult);
    refreshApex(this.wiredMemberInfoResult);
  }

  handleCloseRebuildResult() {
    this.isRebuildResultModalOpen = false;
    this.isReconcileOpen = false;
    this.rebuildResult = null;
    this.verificationResult = null;
    refreshApex(this.wiredMemberResult);
    refreshApex(this.wiredMemberInfoResult);
  }

  /* ================= 진행 중 패널 — 검증/재정합 공용 ================= */
  get isProgressing() {
    return this.isRebuilding || this.isIntegrityVerifying;
  }

  get progressingTitle() {
    return this.isIntegrityVerifying ? "거래 이력 기반 정합성 검증을 진행하고 있습니다" : "포인트 재정합을 진행하고 있습니다";
  }

  get progressingWarningText() {
    return this.isRebuilding
      ? "재정합 도중 다른 작업을 수행하시면 데이터 정합성에 오차가 발생할 수 있습니다.\n완료 알림이 표시될 때까지 잠시만 기다려 주십시오."
      : "검증 도중 다른 작업을 수행하시면 데이터 정합성에 오차가 발생할 수 있습니다.\n완료 알림이 표시될 때까지 잠시만 기다려 주십시오.";
  }

  /* ================= 재정합 결과 표시 getter ================= */
  get isRebuildSuccess() {
    return this.rebuildResult?.success === true;
  }

  get rebuildResultTitle() {
    return "포인트 재정합 결과";
  }

  get rebuildResultMessage() {
    if (!this.rebuildResult) return "";
    return this.isRebuildSuccess ? "계산된 포인트가 일치합니다." : "계산된 포인트가 일치하지 않습니다.";
  }

  /* 일치 = 파란색, 불일치 = 빨간색 */
  get rebuildResultMessageClass() {
    return this.isRebuildSuccess
      ? "reconcile-confirm-dialog__message reconcile-result-msg--match"
      : "reconcile-confirm-dialog__message reconcile-result-msg--mismatch";
  }

  get rebuildResultIconName() {
    return this.isRebuildSuccess ? "utility:success" : "utility:warning";
  }

  get rebuildResultIconWrapClass() {
    return this.isRebuildSuccess
      ? "reconcile-result-dialog__icon-wrap reconcile-result-dialog__icon-wrap--success"
      : "reconcile-result-dialog__icon-wrap reconcile-result-dialog__icon-wrap--warning";
  }

  get rebuildResultIconClass() {
    return this.isRebuildSuccess ? "reconcile-result-dialog__icon--success" : "reconcile-result-dialog__icon--warning";
  }

  get hasRebuildComparison() {
    return this.rebuildResult?.beforeResult && this.rebuildResult?.afterResult;
  }

  get rebuildBeforeBalanceText() {
    const n = this.rebuildResult?.beforeResult?.lmcBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get rebuildAfterBalanceText() {
    const n = this.rebuildResult?.afterResult?.lmcBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get rebuildBeforeDifferenceText() {
    const n = this.rebuildResult?.beforeResult?.difference ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get rebuildAfterDifferenceText() {
    const n = this.rebuildResult?.afterResult?.difference ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  /* 재정합 결과 모달의 시스템/계산 잔액 (after 기준) */
  get rebuildAfterSystemBalanceText() {
    const n = this.rebuildResult?.afterResult?.lmcBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  get rebuildAfterCalculatedBalanceText() {
    const n = this.rebuildResult?.afterResult?.calculatedBalance ?? 0;
    return `${new Intl.NumberFormat("ko-KR").format(n)}P`;
  }

  /* after 결과 존재 여부 */
  get hasRebuildAfterResult() {
    return !!this.rebuildResult?.afterResult;
  }

  /* 차이가 0이면 성공 강조 클래스 (초록 톤) */
  get isRebuildDifferenceZero() {
    return (this.rebuildResult?.afterResult?.difference ?? 0) === 0;
  }

  get rebuildDifferenceRowClass() {
    return this.isRebuildDifferenceZero
      ? "reconcile-result-dialog__detail-row reconcile-result-dialog__detail-row--diff reconcile-result-dialog__detail-row--diff-zero"
      : "reconcile-result-dialog__detail-row reconcile-result-dialog__detail-row--diff";
  }
}
