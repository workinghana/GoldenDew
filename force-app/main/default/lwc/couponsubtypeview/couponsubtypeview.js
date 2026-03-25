import { LightningElement, api, wire, track } from "lwc";
import getSubtype from "@salesforce/apex/LoyaltyPgmCrySubtypeViewControllerV1.getSubtype";
import parsePointFile from "@salesforce/apex/IssuePointSubTypeControllerV1.parsePointFile";
import issuePoint from "@salesforce/apex/IssuePointSubTypeControllerV1.issuePoint";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class LoyaltyPgmCrySubtypeView extends LightningElement {
  @api recordId;

  /* ================= State ================= */

  subtype;
  error;

  @track previewMembers = [];
  @track successMemberIds = [];

  @track isUploadModalOpen = false;
  @track successCount = 0;
  @track failCount = 0;

  /* ================= 포인트 지급 설정 ================= */

  pointAmount = 0;
  expireDate;
  expireType = "auto";

  expireOptions = [
    { label: "기본 설정 (만기 2년)", value: "auto" },
    { label: "직접 설정", value: "manual" }
  ];

  /* ================= 테이블 컬럼 ================= */

  columns = [
    { label: "회원번호", fieldName: "memberNo" },
    { label: "오류 사유", fieldName: "errorReason" }
  ];

  /* ================= 초기 만료일 설정 ================= */

  connectedCallback() {
    this.setDefaultExpire();
  }

  setDefaultExpire() {
    const today = new Date();
    today.setFullYear(today.getFullYear() + 2);
    this.expireDate = today.toISOString().slice(0, 10);
  }

  get isAutoExpire() {
    return this.expireType === "auto";
  }

  handleExpireType(event) {
    this.expireType = event.detail.value;

    if (this.expireType === "auto") {
      this.setDefaultExpire();
    }
  }

  handlePointChange(event) {
    this.pointAmount = Number(event.target.value);
  }

  /* ================= Subtype Data ================= */

  @wire(getSubtype, { recordId: "$recordId" })
  wiredSubtype({ data, error }) {
    if (data) {
      this.subtype = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.subtype = undefined;
      console.error(error);
    }
  }

  /* ================= Excel Upload ================= */

  handleUploadClick() {
    const input = this.template.querySelector(".hidden-file-input");

    if (input) {
      input.click();
    }
  }

  handleFileChange(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();

    reader.onload = () => {
      const base64 = reader.result.split(",")[1];

      parsePointFile({
        base64Data: base64
      })
        .then((result) => {
          console.log("업로드 결과:", result);

          this.previewMembers = result.errors || [];
          this.successMemberIds = result.successMemberIds || [];

          this.successCount = result.successCount || 0;
          this.failCount = result.failCount || 0;

          this.isUploadModalOpen = true;
        })
        .catch((error) => {
          console.error(error);

          this.dispatchEvent(
            new ShowToastEvent({
              title: "파일 업로드 실패",
              message: error.body?.message || "파일 처리 중 오류",
              variant: "error"
            })
          );
        });
    };

    reader.readAsDataURL(file);
  }

  /* ================= 포인트 지급 ================= */

  handleIssuePoint() {
    console.log("🔥 issuePoint 호출");
    console.log("memberIds:", this.successMemberIds);
    console.log("subtypeId:", this.recordId);
    console.log("pointAmount:", this.pointAmount);
    console.log("expireDate:", this.expireDate);
    if (!this.successMemberIds.length) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "지급 대상 없음",
          message: "지급 가능한 회원이 없습니다.",
          variant: "warning"
        })
      );
      return;
    }

    if (!this.pointAmount || this.pointAmount <= 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "포인트 입력 필요",
          message: "지급할 포인트를 입력해주세요.",
          variant: "warning"
        })
      );
      return;
    }

    issuePoint({
      memberIds: this.successMemberIds,
      subtypeId: this.recordId,
      pointAmount: this.pointAmount,
      expireDate: this.expireDate
    })
      .then(() => {
        this.isUploadModalOpen = false;

        this.dispatchEvent(
          new ShowToastEvent({
            title: "포인트 지급 시작",
            message: "포인트 지급 배치가 실행되었습니다.",
            variant: "success"
          })
        );
      })
      .catch((error) => {
        console.error(error);

        this.dispatchEvent(
          new ShowToastEvent({
            title: "포인트 지급 실패",
            message: error.body?.message || "포인트 지급 중 오류",
            variant: "error"
          })
        );
      });
  }

  closeUploadModal() {
    this.isUploadModalOpen = false;
  }

  /* ================= Getter ================= */

  get pointName() {
    return this.subtype?.Name;
  }

  get pointType() {
    return this.subtype?.PointTypeCode__c;
  }

  get priority() {
    return this.subtype?.UsagePriorityNumber;
  }

  get cost() {
    return this.subtype?.CostPerUnit;
  }

  get programName() {
    return this.subtype?.LoyaltyProgramCurrency?.Name;
  }

  get createdBy() {
    return this.subtype?.CreatedBy?.Name;
  }

  get modifiedBy() {
    return this.subtype?.LastModifiedBy?.Name;
  }

  get createdDate() {
    return this.subtype?.CreatedDate;
  }

  get modifiedDate() {
    return this.subtype?.LastModifiedDate;
  }
}