import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import getMemberTierView from "@salesforce/apex/MemberShipUIControllerV1.getMemberTierView";
import issueTierCoupon from "@salesforce/apex/MemberShipUIControllerV1.issueTierCoupon";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getTierCouponOptions from "@salesforce/apex/MemberShipUIControllerV1.getTierCouponOptions";

/* ================= LDS 필드 ================= */
const TIER_FIELDS = ["LoyaltyTier.Name", "LoyaltyTier.Description", "LoyaltyTier.Color"];

export default class Loyaltytierview extends LightningElement {
  @api recordId; // LoyaltyTier Id

  /* ===== LDS 데이터 ===== */
  tier;
  error;

  /* ===== Apex 가공 데이터 ===== */
  benefits = [];
  memberCount;

  /* ================= 모달 상태 (추가) ================= */
  isIssueModalOpen = false;
  selectedVoucherDefinitionId;
  couponSearchTerm = "";

  //쿠폰 리스트
  couponOptions = [];

  /* ================= LoyaltyTier (LDS) ================= */
  @wire(getRecord, { recordId: "$recordId", fields: TIER_FIELDS })
  wiredTier({ data, error }) {
    if (data) {
      this.tier = {
        tierName: data.fields.Name?.value,
        description: data.fields.Description?.value,
        tierColor: data.fields.Color?.value
      };
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.tier = null;
      console.error(error);
    }
  }

  /* ================= Apex (혜택 / 회원 수) ================= */
  @wire(getMemberTierView, { loyaltyTierId: "$recordId" })
  wiredTierExtra({ data, error }) {
    if (data) {
      this.benefits = data.benefits ?? [];
      this.memberCount = data.memberCount;
    } else if (error) {
      console.error(error);
      this.benefits = [];
      this.memberCount = null;
    }
  }

  /* ================= 지급할 쿠폰 리스트================= */
  @wire(getTierCouponOptions, { loyaltyTierId: "$recordId" })
  wiredCouponOptions({ data, error }) {
    if (data) {
      this.couponOptions = data;
    } else if (error) {
      console.error("쿠폰 옵션 조회 실패", error);
      this.couponOptions = [];
    }
  }

  /* ================= Getter ================= */

  get tierName() {
    return this.tier?.tierName ?? "-";
  }

  get description() {
    return this.tier?.description ?? "-";
  }

  get memberCountText() {
    return this.memberCount ?? 0;
  }

  /* ================= 혜택 ================= */

  get benefitViewList() {
    return this.benefits.map((b) => ({
      ...b,
      displayName: this.mapBenefitName(b.benefitName),
      displayValue: this.buildBenefitValue(b)
    }));
  }

  mapBenefitName(rawName) {
    if (!rawName) return "";

    if (rawName.includes("구매포인트")) return "구매 포인트";
    if (rawName.includes("사은포인트")) return "사은 포인트";

    return rawName;
  }

  buildBenefitValue(b) {
    if (b.rate == null) return "";
    return `구매 금액의 ${b.rate}%`;
  }

  /* ================= 별 색상 ================= */

  renderedCallback() {
    const star = this.template.querySelector(".tier-star");
    if (!star) return;
    star.style.color = this.tier?.tierColor || "#9ca3af";
  }

  /* ================= 쿠폰 지급 모달 (추가) ================= */

  handleIssueCoupon() {
    this.isIssueModalOpen = true;
  }

  closeIssueModal() {
    this.isIssueModalOpen = false;
    this.selectedVoucherDefinitionId = null;
    this.couponSearchTerm = "";
  }

  handleCouponSearchChange(event) {
    this.couponSearchTerm = event.detail.value ?? "";
  }

  handleCouponOptionClick(event) {
    this.selectedVoucherDefinitionId = event.currentTarget.dataset.value;
  }

  get filteredCouponOptions() {
    const term = (this.couponSearchTerm ?? "").trim().toLowerCase();
    if (!term) {
      return [];
    }

    return this.couponOptions
      .filter((option) => (option.label ?? "").toLowerCase().includes(term))
      .map((option) => ({
        ...option,
        itemClass: option.value === this.selectedVoucherDefinitionId ? "coupon-option-item coupon-option-item--selected" : "coupon-option-item"
      }));
  }

  get hasFilteredCouponOptions() {
    return this.filteredCouponOptions.length > 0;
  }

  get showNoCouponMatch() {
    return Boolean((this.couponSearchTerm ?? "").trim()) && this.filteredCouponOptions.length === 0;
  }

  get selectedCouponLabel() {
    if (!this.selectedVoucherDefinitionId) {
      return "";
    }
    const found = this.couponOptions.find((option) => option.value === this.selectedVoucherDefinitionId);
    return found?.label ?? "";
  }

  submitIssueCoupon() {
    if (!this.selectedVoucherDefinitionId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "안내",
          message: "지급할 쿠폰을 선택해주세요.",
          variant: "warning"
        })
      );
      return;
    }

    issueTierCoupon({
      loyaltyTierId: this.recordId,
      voucherDefinitionId: this.selectedVoucherDefinitionId
    })
      .then((message) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "성공",
            message,
            variant: "success"
          })
        );
        this.closeIssueModal();
      })
      .catch((error) => {
        console.error(error);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "오류",
            message: error?.body?.message ?? "쿠폰 지급 중 오류가 발생했습니다.",
            variant: "error"
          })
        );
      });
  }
}
