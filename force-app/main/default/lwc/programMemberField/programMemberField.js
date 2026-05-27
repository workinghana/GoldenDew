import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMemberProfile from "@salesforce/apex/ContactUiController.getMemberProfile";
import getMemebrInfo from "@salesforce/apex/MemberDetailUIController.getMemebrInfo";

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
    if (!this.member?.memberStatus) return "정보 없음";

    if (this.member.memberStatus === "Active") return "활성 회원";
    if (this.member.memberStatus === "Inactive") return "탈퇴 회원";

    return this.member.memberStatus;
  }

  get memberStatusClass() {
    if (!this.member?.memberStatus) {
      return "member-status";
    }

    if (this.member.memberStatus === "Active") {
      return "member-status active";
    }

    if (this.member.memberStatus === "Inactive") {
      return "member-status inactive";
    }

    return "member-status";
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
  }

  handleCloseReconcile() {
    this.isReconcileOpen = false;
    this.isVerifyConfirmVisible = false;
    this.isVerifying = false;
    this.isFinalConfirmVisible = false;
  }

  handleStartVerify() {
    this.isVerifyConfirmVisible = true;
  }

  handleConfirmVerify() {
    this.isVerifyConfirmVisible = false;
    this.isVerifying = true;
    // TODO: 실제 포인트 검증 로직 호출 위치
  }

  handleRequestFinalApply() {
    this.isFinalConfirmVisible = true;
  }

  handleCancelFinal() {
    this.isFinalConfirmVisible = false;
  }

  handleApplyFinal() {
    // TODO: 실제 최종 반영(원복) 로직 호출 위치
    this.isFinalConfirmVisible = false;
    this.isReconcileOpen = false;
    this.isVerifying = false;
  }
}
