import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getSubtype from "@salesforce/apex/LoyaltyPgmCrySubtypeViewControllerV1.getSubtype";
import startPointFileValidation from "@salesforce/apex/IssuePointSubTypeControllerV1.startPointFileValidation";
import getPointFileValidationStatus from "@salesforce/apex/IssuePointSubTypeControllerV1.getPointFileValidationStatus";
import issuePointByUploadJob from "@salesforce/apex/IssuePointSubTypeControllerV1.issuePointByUploadJob";
import getPointIssueProgress from "@salesforce/apex/IssuePointSubTypeControllerV1.getPointIssueProgress";

export default class PointSubtypeView extends LightningElement {
  @api recordId;

  subtype;
  error;
  errorMessage;

  isLoading = true;
  isIssuingPoint = false;
  isIssueCompleted = false;
  issueJobId = "";
  issueStatus = "";
  issueProcessedCount = 0;
  issueSuccessCount = 0;
  issueFailCount = 0;
  issueProgressMessage = "";
  issueProgressTimer = null;
  isPollingValidation = false;

  @track previewMembers = [];
  @track isUploadModalOpen = false;
  @track isIssueErrorModalOpen = false;
  @track successCount = 0;
  @track failCount = 0;
  @track totalCount = 0;

  pointAmount = null;
  uploadFileName = "";
  expireDate;
  expireType = "auto";
  issueErrorMessage = "";
  isUploadDragOver = false;
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

  renderedCallback() {
    if (!this.isUploadModalOpen) {
      return;
    }

    const titleEl = this.template.querySelector(".point-upload-modal-container .slds-modal__header h2");
    if (titleEl) {
      titleEl.textContent = "포인트 지급 업로드";
    }

    const footerButtons = this.template.querySelectorAll(".point-upload-modal-container .slds-modal__footer lightning-button");
    if (footerButtons.length > 0) {
      footerButtons[0].label = "닫기";
    }
  }

  disconnectedCallback() {
    this.stopIssueProgressPolling();
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

  getTodayDateString() {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, "0");
    const day = String(today.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  get minExpireDate() {
    return this.getTomorrowDateString();
  }

  isInvalidManualExpireDate() {
    return this.expireType === "manual" && this.expireDate && this.expireDate <= this.getTodayDateString();
  }

  showInvalidExpireDateModal() {
    this.issueErrorMessage = "만료일은 지급일 다음 날부터 선택할 수 있습니다.";
    this.isIssueErrorModalOpen = true;
  }

  getTomorrowDateString() {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const year = tomorrow.getFullYear();
    const month = String(tomorrow.getMonth() + 1).padStart(2, "0");
    const day = String(tomorrow.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  handleUploadClick() {
    if (this.isUploadModalOpen && this.isValidationProcessing) {
      return;
    }
    this.resetValidationState();
    this.isUploadDragOver = false;
    this.isUploadModalOpen = true;
  }

  handleUploadFileClick() {
    const input = this.template.querySelector(".hidden-file-input");
    if (input) {
      input.click();
    }
  }

  handleUploadDragEnter(event) {
    event.preventDefault();
    this.isUploadDragOver = true;
  }

  handleUploadDragOver(event) {
    event.preventDefault();
    this.isUploadDragOver = true;
  }

  handleUploadDragLeave(event) {
    event.preventDefault();
    const relatedTarget = event.relatedTarget;
    if (!relatedTarget || !event.currentTarget.contains(relatedTarget)) {
      this.isUploadDragOver = false;
    }
  }

  handleUploadDrop(event) {
    event.preventDefault();
    this.isUploadDragOver = false;
    const file = event.dataTransfer?.files?.[0];
    if (!file) {
      return;
    }
    this.processUploadFile(file);
  }

  handleFileChange(event) {
    const file = event.target.files?.[0];
    if (!file) {
      return;
    }
    this.processUploadFile(file);
    event.target.value = null;
  }

  clearUploadFile() {
    if (this.isValidationProcessing || this.isIssueInProgress || this.isIssuingPoint) {
      return;
    }
    this.resetValidationState();
    this.isUploadDragOver = false;
  }

  processUploadFile(file) {
    this.resetValidationState();
    this.isUploadModalOpen = true;
    this.uploadFileName = file.name;
    this.validationStatus = "PENDING";

    this.readFileAsBase64(file)
      .then((base64) =>
        startPointFileValidation({
          base64Data: base64,
          fileName: file.name,
          subtypeId: this.recordId
        })
      )
      .then((result) => {
        this.validationJobId = result?.uploadJobId;
        this.validationStatus = result?.status || "PROCESSING";
        this.pollValidationStatus();
      })
      .catch((error) => {
        this.showToast("파일 업로드 실패", error?.body?.message || error?.message || "파일 처리 중 오류가 발생했습니다.", "error");
      });
  }

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onerror = () => reject(new Error("파일을 읽는 중 오류가 발생했습니다."));
      reader.onload = () => {
        try {
          resolve(this.arrayBufferToBase64(reader.result));
        } catch (error) {
          reject(error);
        }
      };
      reader.readAsArrayBuffer(file);
    });
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    const chunkSize = 0x8000;
    let binary = "";

    for (let index = 0; index < bytes.length; index += chunkSize) {
      const chunk = bytes.subarray(index, index + chunkSize);
      binary += String.fromCharCode(...chunk);
    }

    return btoa(binary);
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
    this.uploadFileName = "";
    this.validationJobId = null;
    this.validationStatus = "";
    this.validationErrorMessage = "";
    this.isIssueCompleted = false;
    this.issueJobId = "";
    this.issueStatus = "";
    this.issueProcessedCount = 0;
    this.issueSuccessCount = 0;
    this.issueFailCount = 0;
    this.issueProgressMessage = "";
    this.stopIssueProgressPolling();
  }

  handlePointChange(event) {
    const nextValue = Number(event.target.value);
    this.pointAmount = Number.isFinite(nextValue) ? nextValue : null;
  }

  handleExpireType(event) {
    this.expireType = event.detail.value;
    if (this.expireType === "auto") {
      this.setDefaultExpireDate();
    } else if (this.expireType === "manual") {
      this.expireDate = this.getTomorrowDateString();
    }
  }

  handleExpireDateChange(event) {
    this.expireDate = event.target.value;
    if (this.isInvalidManualExpireDate()) {
      this.expireDate = null;
      event.target.value = null;
      this.showInvalidExpireDateModal();
    }
  }

  handleIssuePoint() {
    if (this.isIssueCompleted) {
      this.closeUploadModal();
      return;
    }

    if (this.isIssueInProgress) {
      return;
    }

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

    if (this.isInvalidManualExpireDate()) {
      this.showInvalidExpireDateModal();
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
        this.issueJobId = result?.issueJobId || "";
        this.issueStatus = result?.status || "PROCESSING";
        this.issueProcessedCount = result?.processedCount || 0;
        this.issueSuccessCount = result?.successCount || 0;
        this.issueFailCount = result?.failCount || 0;
        this.issueProgressMessage = result?.message || "";
        this.isIssueCompleted = false;
        if (this.issueJobId) {
          this.refreshIssueProgress();
          this.startIssueProgressPolling();
        } else {
          this.issueStatus = "COMPLETED";
          this.issueProcessedCount = this.successCount;
          this.issueSuccessCount = result?.successCount || this.successCount;
          this.issueFailCount = result?.failCount || 0;
          this.isIssueCompleted = true;
        }
      })
      .catch((error) => {
        this.isIssuingPoint = false;
        this.issueStatus = "FAILED";
        this.issueProgressMessage = error?.body?.message || error?.message || "포인트 지급 중 오류가 발생했습니다.";
        this.issueErrorMessage = error?.body?.message || error?.message || "포인트 지급 중 오류가 발생했습니다.";
        this.isIssueErrorModalOpen = true;
      });
  }

  startIssueProgressPolling() {
    this.stopIssueProgressPolling();
    this.issueProgressTimer = window.setInterval(() => {
      this.refreshIssueProgress();
    }, 2000);
  }

  stopIssueProgressPolling() {
    if (this.issueProgressTimer) {
      window.clearInterval(this.issueProgressTimer);
      this.issueProgressTimer = null;
    }
  }

  async refreshIssueProgress() {
    if (!this.issueJobId) {
      return;
    }

    try {
      const result = await getPointIssueProgress({
        issueJobId: this.issueJobId,
        totalCount: this.successCount
      });

      this.issueStatus = result?.status || "PROCESSING";
      this.issueProcessedCount = result?.processedCount || 0;
      this.issueSuccessCount = result?.successCount || 0;
      this.issueFailCount = result?.failCount || 0;
      this.issueProgressMessage = result?.message || "";
      this.isIssueCompleted = !!result?.isCompleted;

      if (result?.isCompleted) {
        this.showToast("지급 완료", "", "success");
        this.stopIssueProgressPolling();
        return;
      }

      if (result?.isFailed) {
        this.issueStatus = "FAILED";
        this.stopIssueProgressPolling();
      }
    } catch (error) {
      this.stopIssueProgressPolling();
      this.issueStatus = "FAILED";
      this.issueProgressMessage = error?.body?.message || error?.message || "지급 진행 상황을 불러오지 못했습니다.";
    }
  }

  closeUploadModal() {
    if (this.isIssuingPoint || this.isValidationProcessing || this.isIssueInProgress) {
      if (this.isValidationProcessing) {
        this.showToast("검증 진행 중", "현재 파일 검증이 진행 중입니다. 완료 전에 창을 닫을 수 없습니다.", "warning");
      } else if (this.isIssueInProgress) {
        this.showToast("지급 진행 중", "현재 포인트 지급이 진행 중입니다. 완료 전에 창을 닫을 수 없습니다.", "warning");
      }
      return;
    }

    this.isUploadModalOpen = false;
    this.isUploadDragOver = false;
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
      "중복 회원번호": "중복 회원번호",
      "회원 정보 또는 멤버십 정보 없음": "회원 정보 또는 멤버십 정보 없음"
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
      return "포인트 지급 대상 검증 중";
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
      return "잠시만 기다려 주세요. 현재 파일 검증이 진행 중입니다. 검증이 끝날 때까지 파일을 다시 업로드하지 마세요.";
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

  get isIssueInProgress() {
    return this.issueStatus === "PROCESSING";
  }

  get hasPreviewErrors() {
    return this.previewMembers.length > 0;
  }

  get isIssueDisabled() {
    return this.isIssuingPoint || this.isIssueInProgress || this.isValidationProcessing || this.isValidationFailed || !this.successCount;
  }

  get showValidationResults() {
    return this.isValidationCompleted || this.isValidationFailed;
  }

  get showValidationPulse() {
    return !!this.validationJobId && this.isValidationProcessing;
  }

  get closeButtonDisabled() {
    return this.isValidationProcessing || this.isIssuingPoint || this.isIssueInProgress;
  }

  get validationLoadingTitle() {
    return "업로드 진행 안내";
  }

  get validationLoadingGuideTitle() {
    return "[업로드 진행 안내]";
  }

  get validationLoadingMessage1() {
    return "현재 파일 업로드가 진행 중입니다.";
  }

  get validationLoadingMessage2() {
    return "업로드가 완료될 때까지 새로운 파일을 업로드할 수 없습니다.";
  }

  get validationLoadingMessage3() {
    return "최대 업로드 권장 건수: 10,000건";
  }

  get validationLoadingMessage4() {
    return "권장 건수 초과 시 처리 시간이 지연될 수 있습니다.";
  }

  get validationLoadingMessage5() {
    return "업로드 완료 후 다시 시도해 주시기 바랍니다.";
  }

  get uploadWarningText() {
    return "최대 1만건만 업로드하세요. 초과 시 업로드가 지연되거나 실패할 수 있습니다.";
  }

  get modalStatusLabel() {
    if (this.isIssueCompleted) {
      return "포인트 지급 완료";
    }
    return this.validationStatusLabel;
  }

  get modalStatusHelp() {
    if (this.isIssueCompleted) {
      return `총 ${this.successCount}명 지급이 완료되었습니다.`;
    }
    return this.validationStatusHelp;
  }

  get showModalResults() {
    return this.showValidationResults || this.isIssueCompleted;
  }

  get modalPrimaryButtonLabel() {
    if (this.isIssueCompleted) {
      return "완료";
    }
    return this.issueButtonLabel;
  }

  get modalPrimaryButtonDisabled() {
    if (this.isIssueCompleted) {
      return false;
    }
    return this.isIssueDisabled;
  }

  get isIssueFailed() {
    return this.issueStatus === "FAILED";
  }

  get modalDisplayStatusLabel() {
    if (this.isIssueInProgress) {
      return "포인트 지급 진행 중";
    }
    if (this.isIssueCompleted) {
      return "포인트 지급 완료";
    }
    if (this.isIssueFailed) {
      return "포인트 지급 실패";
    }
    return this.modalStatusLabel;
  }

  get modalDisplayStatusHelp() {
    if (this.isIssueInProgress) {
      return `총 ${this.successCount}명 중 ${this.issueProcessedCount}명 처리가 완료되었습니다.`;
    }
    if (this.isIssueCompleted) {
      return this.issueFailCount > 0
        ? `성공 ${this.issueSuccessCount}명 / 실패 ${this.issueFailCount}명입니다.`
        : `총 ${this.issueSuccessCount}명 지급이 완료되었습니다.`;
    }
    if (this.isIssueFailed) {
      return this.issueProgressMessage || "지급 중 오류가 발생했습니다.";
    }
    return this.modalStatusHelp;
  }

  get showPointUploadResults() {
    return this.showValidationResults || this.isIssueInProgress || this.isIssueCompleted || this.isIssueFailed;
  }

  get hasIssueStarted() {
    return Boolean(this.issueJobId);
  }

  get issueProgressStatusClass() {
    if (this.isIssueCompleted) {
      return "issue-progress-panel issue-progress-panel--completed";
    }
    if (this.isIssueFailed) {
      return "issue-progress-panel issue-progress-panel--failed";
    }
    return "issue-progress-panel";
  }

  get issueProgressTitle() {
    if (this.isIssueCompleted) {
      return this.issueFailCount > 0 ? "포인트 지급 완료" : "포인트 지급 성공";
    }
    if (this.isIssueFailed) {
      return "포인트 지급 실패";
    }
    return "포인트 지급 진행 중";
  }

  get issueProgressDescription() {
    if (this.isIssueCompleted) {
      if (this.issueFailCount > 0) {
        return `성공 ${this.issueSuccessCount}명 / 실패 ${this.issueFailCount}명입니다.`;
      }
      return `총 ${this.issueSuccessCount}명 지급이 완료되었습니다.`;
    }
    if (this.isIssueFailed) {
      return this.issueProgressMessage || "지급 중 오류가 발생했습니다.";
    }
    return "포인트가 순차적으로 지급되고 있습니다.";
  }

  get issueProgressCountText() {
    const totalCount = this.successCount || 0;
    const processedCount = Math.min(totalCount, this.issueProcessedCount || 0);
    return `${processedCount} / ${totalCount}`;
  }

  get issueProgressPercent() {
    if (!this.successCount) {
      return 0;
    }
    return Math.min(100, Math.round(((this.issueProcessedCount || 0) / this.successCount) * 100));
  }

  get issueProgressSummaryLabel() {
    if (this.isIssueCompleted) {
      return `총 ${this.successCount}명 중 ${this.issueProcessedCount}명 처리가 완료되었습니다.`;
    }
    if (this.isIssueFailed) {
      return this.issueProgressMessage || "지급 처리 중 문제가 발생했습니다.";
    }
    return `총 ${this.successCount}명 중 ${this.issueProcessedCount}명 처리되었습니다.`;
  }

  get issueProgressMetaText() {
    if (this.isIssueCompleted) {
      return `성공 ${this.issueSuccessCount}명 / 실패 ${this.issueFailCount}명`;
    }
    if (this.isIssueFailed) {
      return this.issueProgressMessage || "";
    }
    return `남은 인원 ${Math.max(0, this.successCount - this.issueProcessedCount)}명`;
  }

  get modalDisplayPrimaryButtonLabel() {
    if (this.isIssueCompleted) {
      return "완료";
    }
    if (this.isIssueInProgress) {
      return "지급 진행 중..";
    }
    if (this.isIssueFailed) {
      return "포인트 지급";
    }
    return this.modalPrimaryButtonLabel;
  }

  get modalDisplaySuccessCount() {
    if (this.isIssueInProgress || this.isIssueCompleted || this.isIssueFailed) {
      return this.issueSuccessCount;
    }
    return this.successCount;
  }

  get modalDisplayFailCount() {
    if (this.isIssueInProgress || this.isIssueCompleted || this.isIssueFailed) {
      return this.issueFailCount;
    }
    return this.failCount;
  }

  get uploadDropzoneClass() {
    return this.isUploadDragOver ? "upload-dropzone upload-dropzone--active" : "upload-dropzone";
  }
}