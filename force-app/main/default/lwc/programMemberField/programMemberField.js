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
    return this.displayValue(this.member?.mobilePhone);
  }

  get addressText() {
    return this.displayValue(this.member?.address);
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
    return this.formatDate(this.member?.birthdate);
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

  get gradeUpdatedText() {
    const dt = this.grade?.lastUpdatedDate;

    if (!dt) return "정보 없음";

    const d = new Date(dt);

    return `${d.getUTCFullYear()}.${String(d.getUTCMonth() + 1).padStart(2, "0")}.${String(d.getUTCDate()).padStart(2, "0")}`;
  }

  /* ================= 마케팅 ================= */

  get emailConsentLabel() {
    return this.marketing?.emailConsent ? "동의" : "거부";
  }

  get smsConsentLabel() {
    return this.marketing?.smsConsent ? "동의" : "거부";
  }

  get magazinConsentLabel() {
    return this.marketing?.magazineConsent ? "동의" : "거부";
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
}