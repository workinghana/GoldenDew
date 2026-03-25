import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getSubtype from "@salesforce/apex/LoyaltyPgmCrySubtypeViewControllerV1.getSubtype";
import startPointFileValidation from "@salesforce/apex/IssuePointSubTypeControllerV1.startPointFileValidation";
import getPointFileValidationStatus from "@salesforce/apex/IssuePointSubTypeControllerV1.getPointFileValidationStatus";
import issuePointByUploadJob from "@salesforce/apex/IssuePointSubTypeControllerV1.issuePointByUploadJob";

export default class PointSubtypeView extends LightningElement {
  @api recordId;

  subtype;
  error;
  errorMessage;

  isLoading = true;
  isIssuingPoint = false;

  @track previewMembers = [];
  @track isUploadModalOpen = false;
  @track isIssueErrorModalOpen = false;
  @track successCount = 0;
  @track failCount = 0;
  @track totalCount = 0;

  pointAmount = null;
  expireDate;
  expireType = "auto";
  issueErrorMessage = "";
  isPollingValidation = false;
  validationJobId;
  validationStatus = "";
  validationErrorMessage = "";

  columns = [
    { label: "회원번호", fieldName: "memberNo" },
    { label: "오류 사유", fieldName: "errorReason" }
  ];

  expireOptions = [
    { label: "기본 설정(2년)", value: "auto" },
    { label: "직접 설정", value: "manual" }
  ];

  connectedCallback() {
    this.setDefaultExpireDate();
  }

  @wire(getSubtype, { recordId: "$recordId" })
  wiredSubtype({ data, error }) {
    this.isLoading = false;

    if (data) {
      this.subtype = data;
      this.error = undefined;
      this.errorMessage = undefined;
      return;
    }

    if (error) {
      this.subtype = null;
      this.error = error;
      this.errorMessage = error?.body?.message || error?.message || "알 수 없는 오류";
    }
  }

  setDefaultExpireDate() {
    const today = new Date();
    today.setFullYear(today.getFullYear() + 2);
    this.expireDate = today.toISOString().slice(0, 10);
  }

  handleUploadClick() {
    if (this.isUploadModalOpen && this.isValidationProcessing) {
      return;
    }
    const input = this.template.querySelector(".hidden-file-input");
    if (input) {
      input.click();
    }
  }

  handleFileChange(event) {
    const file = event.target.files[0];
    if (!file) {
      return;
    }

    this.resetValidationState();
    this.isUploadModalOpen = true;
    this.validationStatus = "PENDING";

    const reader = new FileReader();
    reader.onload = () => {
      const base64 = reader.result.split(",")[1];

      startPointFileValidation({
        base64Data: base64,
        fileName: file.name,
        subtypeId: this.recordId
      })
        .then((result) => {
          this.validationJobId = result?.uploadJobId;
          this.validationStatus = result?.status || "PROCESSING";
          this.pollValidationStatus();
        })
        .catch((error) => {
          this.isUploadModalOpen = false;
          this.showToast("파일 업로드 실패", error?.body?.message || "파일 처리 중 오류가 발생했습니다.", "error");
        });
    };

    reader.readAsDataURL(file);
    event.target.value = null;
  }

  handleValidationPulse() {
    this.pollValidationStatus();
  }

  pollValidationStatus() {
    if (!this.validationJobId || this.isPollingValidation) {
      return;
    }

    this.isPollingValidation = true;

    getPointFileValidationStatus({ uploadJobId: this.validationJobId })
      .then((result) => {
        this.validationStatus = result?.status || "";
        this.totalCount = result?.totalCount || 0;
        this.successCount = result?.successCount || 0;
        this.failCount = result?.failCount || 0;
        this.validationErrorMessage = result?.errorMessage || "";
        this.previewMembers = this.normalizePreviewErrors(result?.errors || []);

        if (result?.isFailed && this.validationErrorMessage) {
          this.showToast("검증 실패", this.validationErrorMessage, "error");
        }
      })
      .catch((error) => {
        this.validationErrorMessage = error?.body?.message || error?.message || "검증 상태를 불러오지 못했습니다.";
        this.validationStatus = "FAILED";
        this.showToast("검증 실패", this.validationErrorMessage, "error");
      })
      .finally(() => {
        this.isPollingValidation = false;
      });
  }

  resetValidationState() {
    this.previewMembers = [];
    this.totalCount = 0;
    this.successCount = 0;
    this.failCount = 0;
    this.validationJobId = null;
    this.validationStatus = "";
    this.validationErrorMessage = "";
  }

  handlePointChange(event) {
    const nextValue = Number(event.target.value);
    this.pointAmount = Number.isFinite(nextValue) ? nextValue : null;
  }

  handleExpireType(event) {
    this.expireType = event.detail.value;
    if (this.expireType === "auto") {
      this.setDefaultExpireDate();
    }
  }

  handleExpireDateChange(event) {
    this.expireDate = event.target.value;
  }

  handleIssuePoint() {
    if (!this.validationJobId || !this.successCount) {
      this.showToast("지급 대상 없음", "지급 가능한 회원이 없습니다.", "warning");
      return;
    }

    if (!this.pointAmount || this.pointAmount <= 0) {
      this.issueErrorMessage = "지급 포인트를 입력해 주세요.";
      this.isIssueErrorModalOpen = true;
      return;
    }

    if (!this.expireDate) {
      this.issueErrorMessage = "만료일을 확인해 주세요.";
      this.isIssueErrorModalOpen = true;
      return;
    }

    this.isIssuingPoint = true;

    issuePointByUploadJob({
      uploadJobId: this.validationJobId,
      subtypeId: this.recordId,
      pointAmount: this.pointAmount,
      expireDate: this.expireDate
    })
      .then((result) => {
        this.isIssuingPoint = false;
        this.isUploadModalOpen = false;
        this.resetValidationState();
        this.showToast("지급 완료", result?.message || "포인트 지급이 시작되었습니다.", "success");
      })
      .catch((error) => {
        this.isIssuingPoint = false;
        this.issueErrorMessage = error?.body?.message || error?.message || "포인트 지급 중 오류가 발생했습니다.";
        this.isIssueErrorModalOpen = true;
      });
  }

  closeUploadModal() {
    if (this.isIssuingPoint || this.isValidationProcessing) {
      if (this.isValidationProcessing) {
        this.showToast("검증 진행 중", "지금 데이터를 업로드 중입니다. 새로운 데이터를 또 올릴 수 없습니다.", "warning");
      }
      return;
    }
    this.isUploadModalOpen = false;
    this.resetValidationState();
  }

  closeIssueErrorModal() {
    this.issueErrorMessage = "";
    this.isIssueErrorModalOpen = false;
  }

  normalizePreviewErrors(errors) {
    return (errors || []).map((item) => ({
      ...item,
      errorReason: this.getErrorReasonLabel(item?.errorReason)
    }));
  }

  getErrorReasonLabel(reason) {
    const labelMap = {
      "Contact 없음": "회원 정보 없음",
      "LoyaltyProgramMember 없음": "멤버십 정보 없음",
      "Loyalty 회원 없음": "멤버십 정보 없음",
      "회원 없음": "회원 정보 없음",
      "회원번호 없음": "회원번호 없음",
      "중복 회원번호": "중복 회원번호"
    };

    return labelMap[reason] || reason || "확인 필요";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  get hasSubtype() {
    return !!this.subtype;
  }

  get hasError() {
    return !!this.error;
  }

  get isAutoExpire() {
    return this.expireType === "auto";
  }

  get pointName() {
    return this.subtype?.name || "";
  }

  get priorityText() {
    return this.subtype?.usagePriorityNumber ?? "정보 없음";
  }

  get costText() {
    const cost = this.subtype?.costPerUnit;
    return cost === null || cost === undefined ? "해당 설정 없음" : cost;
  }

  get hasBenefits() {
    return this.benefits.length > 0;
  }

  get benefits() {
    return (this.subtype?.benefits || []).map((benefit) => ({
      ...benefit,
      selectionText: benefit.isBenefitSelectionAllowed ? "직접 선택 가능" : "자동 적용",
      descriptionText: benefit.description || "보상 설명이 없습니다.",
      statusLabel: benefit.isActive ? "활성" : "비활성",
      statusClass: benefit.isActive ? "reward-status reward-status--active" : "reward-status reward-status--inactive"
    }));
  }

  get issueButtonLabel() {
    return this.isIssuingPoint ? "지급 중..." : "포인트 지급";
  }

  get validationStatusLabel() {
    if (this.isValidationProcessing) {
      return "포인트 지급 회원 검증중";
    }
    if (this.isValidationFailed) {
      return "검증 실패";
    }
    if (this.isValidationCompleted) {
      return "검증 완료";
    }
    return "대기 중";
  }

  get validationStatusHelp() {
    if (this.isValidationProcessing) {
      return "잠시만 기다려주세요. 현재 파일을 업로드 중입니다. 새 파일을 업로드 하지 마십시오.";
    }
    if (this.isValidationFailed) {
      return this.validationErrorMessage || "검증 중 오류가 발생했습니다.";
    }
    if (this.isValidationCompleted) {
      return "검증이 완료되었습니다. 결과를 확인한 뒤 포인트를 지급할 수 있습니다.";
    }
    return "";
  }

  get isValidationProcessing() {
    return this.validationStatus === "PENDING" || this.validationStatus === "PROCESSING";
  }

  get isValidationCompleted() {
    return this.validationStatus === "COMPLETED";
  }

  get isValidationFailed() {
    return this.validationStatus === "FAILED";
  }

  get hasPreviewErrors() {
    return this.previewMembers.length > 0;
  }

  get isIssueDisabled() {
    return this.isIssuingPoint || this.isValidationProcessing || this.isValidationFailed || !this.successCount;
  }

  get showValidationResults() {
    return this.isValidationCompleted || this.isValidationFailed;
  }

  get showValidationPulse() {
    return !!this.validationJobId && this.isValidationProcessing;
  }

  get closeButtonDisabled() {
    return this.isValidationProcessing || this.isIssuingPoint;
  }
}
