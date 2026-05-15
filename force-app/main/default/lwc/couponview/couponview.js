import { LightningElement, api, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCouponDetail from "@salesforce/apex/CouponUIControllerV1.getCouponDetail";
import getCouponPolicyConfig from "@salesforce/apex/CouponUIControllerV1.getCouponPolicyConfig";
import searchCouponPolicyTargets from "@salesforce/apex/CouponUIControllerV1.searchCouponPolicyTargets";
import saveCouponPolicy from "@salesforce/apex/CouponUIControllerV1.saveCouponPolicy";
import parseCouponFile from "@salesforce/apex/CouponListUploadControllerV1.parseCouponFile";
import parseProductLimitFile from "@salesforce/apex/CouponListUploadControllerV1.parseProductLimitFile";
import parseStoreLimitFile from "@salesforce/apex/CouponListUploadControllerV1.parseStoreLimitFile";
import issueCoupon from "@salesforce/apex/CouponListUploadControllerV1.issueCoupon";
import getIssueCouponProgress from "@salesforce/apex/CouponListUploadControllerV1.getIssueCouponProgress";

const OPERATOR_NONE = "NONE";

const SECTION_DEFS = [
  {
    key: "productIncludeItems",
    title: "사용 가능 제품",
    targetType: "PRODUCT",
    placeholder: "제품명 또는 제품코드 검색",
    canUpload: true,
    uploadLabel: "제품 일괄 등록"
  },
  {
    key: "storeIncludeItems",
    title: "사용 가능 매장",
    targetType: "STORE",
    placeholder: "매장명 또는 매장코드 검색",
    canUpload: true,
    uploadLabel: "매장 일괄 등록"
  },
  {
    key: "gradeIncludeItems",
    title: "사용 가능 회원 등급",
    targetType: "GRADE",
    placeholder: "등급명 또는 코드 검색",
    canUpload: false,
    uploadLabel: ""
  },
  {
    key: "productCategoryIncludeItems",
    title: "사용 가능 제품 분류",
    targetType: "CATEGORY",
    placeholder: "제품 분류 검색",
    isCategorySection: true,
    canUpload: false,
    uploadLabel: ""
  }
];

const LIMIT_CODE_HEADERS = {
  ProductIncludeList: "Code",
  StoreIncludeList: "매장 코드",
  GradeIncludeList: "Code",
  ProductCategoryIncludeList: "Code",
  StoreTypeIncludeList: "Code",
  OrderTypeIncludeList: "Code",
  DiscountRate: "Rule",
  TotalQuantity: "Rule",
  SalesAmount: "Rule"
};

const LIMIT_NAME_HEADERS = {
  ProductIncludeList: "Name",
  StoreIncludeList: "매장 이름",
  GradeIncludeList: "Name",
  ProductCategoryIncludeList: "Name",
  StoreTypeIncludeList: "매장 구분",
  OrderTypeIncludeList: "Value",
  DiscountRate: "Value",
  TotalQuantity: "Value",
  SalesAmount: "Value"
};

const LIMIT_DISPLAY_ORDER = [
  { type: "ProductIncludeList", label: "사용 가능 제품" },
  { type: "StoreIncludeList", label: "사용 가능 매장" },
  { type: "StoreTypeIncludeList", label: "사용 가능 매장 구분" },
  { type: "DiscountRate", label: "적용 가능 판매 할인율" },
  { type: "GradeIncludeList", label: "사용 가능 회원 등급" },
  { type: "ProductCategoryIncludeList", label: "사용 가능 제품 분류" },
  { type: "OrderTypeIncludeList", label: "사용 가능 주문 구분" },
  { type: "TotalQuantity", label: "사용 가능 판매 개수" },
  { type: "SalesAmount", label: "사용 가능 판매 금액" }
];

export default class Couponview extends LightningElement {
  @api recordId;

  @track couponDetail;
  @track policySections = [];
  @track policyStoreTypeOptions = [];
  @track policyOrderTypeOptions = [];
  @track policyForm = this.createEmptyPolicyForm();
  @track previewMembers = [];
  @track selectedLimitItems = [];
  @track policyUploadPreviewRows = [];
  @track policyUploadErrors = [];

  isLoading = false;
  hasLoaded = false;
  errorMessage = "";
  isPolicyModalOpen = false;
  isPolicyLoading = false;
  isPolicySaving = false;
  isPolicyErrorModalOpen = false;
  policyErrorMessage = "";
  isPolicyUploadModalOpen = false;
  isPolicyUploadLoading = false;
  isLimitModalOpen = false;
  selectedLimitLabel = "";
  selectedLimitType = "";
  limitPage = 1;
  limitPageSize = 10;
  isUploadModalOpen = false;
  isIssueLoading = false;
  isUploadProcessing = false;
  isIssueErrorModalOpen = false;
  issueErrorMessage = "";
  successCount = 0;
  failCount = 0;
  successMemberIds = [];
  uploadFileName = "";
  isUploadDragOver = false;
  issueJobId = "";
  issueRequestToken = "";
  issueStatus = "";
  issueProcessedCount = 0;
  issueSuccessCount = 0;
  issueFailCount = 0;
  issueProgressMessage = "";
  issueProgressTimer = null;
  policyUploadType = "";
  policyUploadTitle = "";
  policyUploadFileName = "";
  isPolicyUploadDragOver = false;

  columns = [
    { label: "회원번호", fieldName: "memberNo" },
    { label: "오류 사유", fieldName: "errorReason" }
  ];

  policyUploadErrorColumns = [
    { label: "행", fieldName: "rowNumber" },
    { label: "오류 사유", fieldName: "errorReason" }
  ];

  comparisonOperatorOptions = [
    { label: "적용 안함", value: OPERATOR_NONE },
    { label: "이상", value: "01" },
    { label: "이하", value: "02" }
  ];

  @wire(CurrentPageReference)
  setPageRef(pageRef) {
    if (this.recordId || !pageRef || !pageRef.state) {
      return;
    }
    const recordIdFromPage = pageRef.state.recordId || pageRef.state.c__recordId;
    if (recordIdFromPage) {
      this.loadPageData(recordIdFromPage);
    }
  }

  connectedCallback() {
    this.policySections = this.createPolicySections();
    if (this.recordId) {
      this.loadPageData();
    }
  }

  disconnectedCallback() {
    this.stopIssueProgressPolling();
  }

  renderedCallback() {
    const warningEls = this.template.querySelectorAll(".policy-upload-warning-text");
    if (!warningEls.length) {
      return;
    }

    const warningText = this.isUploadModalOpen
      ? "최대 1만건만 업로드하세요. 초과 시 업로드가 지연되거나 실패할 수 있습니다."
      : "최대 5천건만 업로드하세요. 초과 시 업로드가 지연되거나 실패할 수 있습니다.";

    warningEls.forEach((el) => {
      el.textContent = warningText;
    });

    if (this.isUploadModalOpen) {
      const titleEl = this.template.querySelector(".coupon-upload-modal-container .slds-modal__header h2");
      if (titleEl) {
        titleEl.textContent = "쿠폰 지급 업로드";
      }

      const closeButton = this.template.querySelector(".coupon-upload-modal-container .slds-modal__footer lightning-button");
      if (closeButton) {
        closeButton.label = "닫기";
        closeButton.disabled = this.closeUploadButtonDisabled;
      }
    }
  }

  createEmptyPolicyForm() {
    return {
      discountRateOperator: OPERATOR_NONE,
      discountRate: null,
      totalQuantityOperator: OPERATOR_NONE,
      totalQuantity: null,
      salesAmountOperator: OPERATOR_NONE,
      salesAmount: null
    };
  }

  createPolicySections() {
    return SECTION_DEFS.map((section) =>
      this.decorateSection({
        ...section,
        keyword: "",
        selectedItems: [],
        results: [],
        resultTree: [],
        hasSearched: false
      })
    );
  }

  decorateSection(section) {
    const hasResultTree = Boolean(section.isCategorySection && section.resultTree && section.resultTree.length);
    const hasFlatResults = Boolean(section.results && section.results.length);
    return {
      ...section,
      selectedClass: section.isCategorySection ? "policy-selected-list policy-selected-list--category" : "policy-selected-list",
      hasSelectedItems: Boolean(section.selectedItems && section.selectedItems.length),
      hasResultTree,
      hasFlatResults,
      hasNoResult: Boolean(section.hasSearched && !hasResultTree && !hasFlatResults)
    };
  }

  async loadPageData(overrideRecordId) {
    const targetRecordId = overrideRecordId || this.recordId;
    if (!targetRecordId || this.hasLoaded) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = "";
    try {
      this.couponDetail = await getCouponDetail({ voucherDefinitionId: targetRecordId });
      this.hasLoaded = true;
    } catch (error) {
      this.errorMessage = this.getErrorMessage(error);
    } finally {
      this.isLoading = false;
    }
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get hasCoupon() {
    return Boolean(this.couponDetail);
  }

  get voucherDefinitionName() {
    return this.couponDetail ? this.couponDetail.voucherDefinitionName : "";
  }

  get voucherdescription() {
    return this.couponDetail ? this.couponDetail.description : "";
  }

  get couponNumText() {
    return this.couponDetail && this.couponDetail.couponNum ? this.couponDetail.couponNum : "-";
  }

  get couponStatus() {
    return this.couponDetail && this.couponDetail.status ? "활성화" : "비활성화";
  }

  get couponStatusClass() {
    return `status-badge ${this.couponDetail && this.couponDetail.status ? "status-badge--active" : "status-badge--inactive"}`;
  }

  get couponTypeLabel() {
    const typeValue = this.couponDetail && this.couponDetail.couponType ? this.couponDetail.couponType : "";
    const typeLabelMap = {
      FixedPrice: "정액 쿠폰",
      FixedAmount: "정액 쿠폰",
      Amount: "정액 쿠폰",
      DiscountAmount: "정액 쿠폰",
      FlatAmount: "정액 쿠폰",
      FixedValue: "정액 쿠폰",
      Percent: "정률 쿠폰",
      Percentage: "정률 쿠폰",
      Rate: "정률 쿠폰",
      DiscountPercent: "정률 쿠폰",
      DiscountPercentage: "정률 쿠폰",
      PercentageDiscount: "정률 쿠폰",
      FreeShipping: "무료배송 쿠폰",
      Shipping: "배송 쿠폰",
      ShippingDiscount: "배송 쿠폰"
    };
    return typeLabelMap[typeValue] || typeValue || "-";
  }

  get vouchervalue() {
    if (!this.couponDetail) {
      return "-";
    }
    const typeValue = this.couponDetail.couponType || "";
    const percentTypes = new Set(["Percent", "Percentage", "Rate", "DiscountPercent", "DiscountPercentage", "PercentageDiscount"]);
    const amountTypes = new Set(["FixedPrice", "FixedAmount", "Amount", "DiscountAmount", "FlatAmount", "FixedValue"]);

    if (percentTypes.has(typeValue) && this.couponDetail.discountPercent !== null && this.couponDetail.discountPercent !== undefined) {
      return `${this.couponDetail.discountPercent}%`;
    }
    if (amountTypes.has(typeValue) && this.couponDetail.couponvalue !== null && this.couponDetail.couponvalue !== undefined) {
      return `${this.couponDetail.couponvalue}원`;
    }
    if (this.couponDetail.discountPercent !== null && this.couponDetail.discountPercent !== undefined) {
      return `${this.couponDetail.discountPercent}%`;
    }
    if (this.couponDetail.couponvalue !== null && this.couponDetail.couponvalue !== undefined) {
      return `${this.couponDetail.couponvalue}원`;
    }
    return "-";
  }

  get couponPeriodText() {
    if (!this.couponDetail) {
      return "-";
    }
    if (this.couponDetail.expirationDate) {
      return this.couponDetail.expirationDate;
    }
    if (this.couponDetail.expirationPeriod) {
      return `${this.couponDetail.expirationPeriod} ${this.couponDetail.expirationPeriodUnit || ""}`.trim();
    }
    return "-";
  }

  get limitItems() {
    const summaryList = this.couponDetail && this.couponDetail.limitSummaryList ? this.couponDetail.limitSummaryList : [];
    const summaryByType = new Map();

    summaryList.forEach((item) => {
      summaryByType.set(item.type, item);
    });

    return LIMIT_DISPLAY_ORDER.map((meta) => {
      const item = summaryByType.get(meta.type);
      const values = item
        ? (item.valueDetailList || []).length
          ? item.valueDetailList.map((detail, index) => ({
              key: `${meta.type}-${index}`,
              code: detail.code || "",
              name: detail.name || detail.code || ""
            }))
          : (item.valueList || []).map((value, index) => ({
              key: `${meta.type}-${index}`,
              code: value,
              name: value
            }))
        : [];

      return {
        type: meta.type,
        label: item && item.label ? item.label : meta.label,
        values,
        displayText: values.length
          ? values
              .slice(0, 3)
              .map((entry) => this.formatLimitSummaryEntry(meta.type, entry))
              .join(", ")
          : "정보 없음",
        hasMore: values.length > 3,
        valueClass: values.length ? "detail-value detail-value--filled" : "detail-value detail-value--empty"
      };
    });
  }

  formatLimitSummaryEntry(type, entry) {
    if (type === "DiscountRate" || type === "TotalQuantity" || type === "SalesAmount") {
      return entry.code ? `${entry.name} ${entry.code}` : entry.name;
    }
    return entry.name;
  }

  get policySaveButtonLabel() {
    return this.isPolicySaving ? "저장 중..." : "저장";
  }

  get issueButtonLabel() {
    if (this.isIssueCompleted || this.isIssueFailed) {
      return "완료";
    }
    return this.isIssueLoading ? "지급 중..." : "지급";
  }

  get hasPreviewMembers() {
    return this.previewMembers.length > 0;
  }

  get isIssueActionDisabled() {
    if (this.isIssueCompleted || this.isIssueFailed) {
      return false;
    }
    return this.isUploadProcessing || this.isIssueLoading || this.isIssueInProgress || !this.successMemberIds.length;
  }

  get hasIssueStarted() {
    return Boolean(this.issueJobId);
  }

  get isIssueInProgress() {
    return this.issueStatus === "PROCESSING";
  }

  get isIssueCompleted() {
    return this.issueStatus === "COMPLETED";
  }

  get isIssueFailed() {
    return this.issueStatus === "FAILED";
  }

  get uploadDropzoneClass() {
    return this.isUploadDragOver ? "policy-upload-dropzone policy-upload-dropzone--active" : "policy-upload-dropzone";
  }

  get shouldShowCouponUploadEntry() {
    return !this.hasIssueStarted;
  }

  get closeUploadButtonDisabled() {
    return this.isUploadProcessing || this.isIssueLoading || this.isIssueInProgress;
  }

  get showCouponUploadResults() {
    return !this.isUploadProcessing && (this.successCount > 0 || this.failCount > 0 || this.hasIssueStarted);
  }

  get couponUploadStatusLabel() {
    if (this.isUploadProcessing) {
      return "쿠폰 지급 대상 검증 중";
    }
    if (this.isIssueInProgress) {
      return "쿠폰 지급 진행 중";
    }
    if (this.isIssueCompleted) {
      return "쿠폰 지급 완료";
    }
    if (this.isIssueFailed) {
      return "쿠폰 지급 실패";
    }
    if (this.showCouponUploadResults) {
      return "검증 완료";
    }
    return "대기 중";
  }

  get couponUploadStatusHelp() {
    if (this.isUploadProcessing) {
      return "현재 파일 검증이 진행 중입니다. 완료 전에는 창을 닫거나 새 파일을 업로드하지 마세요.";
    }
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
    if (this.showCouponUploadResults) {
      return "검증이 완료되었습니다. 결과를 확인한 뒤 쿠폰을 지급할 수 있습니다.";
    }
    return "";
  }

  get couponValidationLoadingTitle() {
    return "업로드 진행 안내";
  }

  get couponValidationLoadingGuideTitle() {
    return "[업로드 진행 안내]";
  }

  get couponValidationLoadingMessage1() {
    return "현재 파일 업로드가 진행 중입니다.";
  }

  get couponValidationLoadingMessage2() {
    return "업로드가 완료될 때까지 새로운 파일을 업로드할 수 없습니다.";
  }

  get couponValidationLoadingMessage3() {
    return "최대 업로드 권장 건수: 10,000건";
  }

  get couponValidationLoadingMessage4() {
    return "권장 건수 초과 시 처리 시간이 지연될 수 있습니다.";
  }

  get couponValidationLoadingMessage5() {
    return "업로드 완료 후 다시 시도해 주시기 바랍니다.";
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
      return this.issueFailCount > 0 ? "쿠폰 지급 완료" : "쿠폰 지급 성공";
    }
    if (this.isIssueFailed) {
      return "쿠폰 지급 실패";
    }
    return "쿠폰 지급 진행 중";
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
    return "쿠폰을 순차적으로 지급하고 있습니다.";
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

  get selectedLimitCountText() {
    return `총 ${this.selectedLimitItems.length}건`;
  }

  get selectedLimitCodeHeader() {
    return LIMIT_CODE_HEADERS[this.selectedLimitType] || "Code";
  }

  get selectedLimitNameHeader() {
    return LIMIT_NAME_HEADERS[this.selectedLimitType] || "Name";
  }

  get showSelectedLimitCodeColumn() {
    return this.selectedLimitType !== "StoreTypeIncludeList";
  }

  get selectedLimitPageItems() {
    const start = (this.limitPage - 1) * this.limitPageSize;
    return this.selectedLimitItems.slice(start, start + this.limitPageSize);
  }

  get selectedLimitPageNumbers() {
    const total = Math.max(1, Math.ceil(this.selectedLimitItems.length / this.limitPageSize));
    return Array.from({ length: total }, (_, index) => ({
      key: `page-${index + 1}`,
      number: index + 1,
      className: index + 1 === this.limitPage ? "limit-page-btn is-active" : "limit-page-btn"
    }));
  }

  get isLimitPageGroupPrevDisabled() {
    return this.limitPage <= 1;
  }

  get isLimitPageGroupNextDisabled() {
    return this.limitPage >= Math.max(1, Math.ceil(this.selectedLimitItems.length / this.limitPageSize));
  }

  get hasPolicyUploadPreviewRows() {
    return this.policyUploadPreviewRows.length > 0;
  }

  get hasPolicyUploadErrors() {
    return this.policyUploadErrors.length > 0;
  }

  get policyUploadSuccessCount() {
    return this.policyUploadPreviewRows.length;
  }

  get policyUploadFailCount() {
    return this.policyUploadErrors.length;
  }

  get hasPolicyUploadResult() {
    return this.policyUploadPreviewRows.length > 0 || this.policyUploadErrors.length > 0;
  }

  get policyUploadActionButtonLabel() {
    return "완료";
  }

  get isPolicyUploadActionDisabled() {
    return this.isPolicyUploadLoading;
  }

  get policyUploadProgressTitle() {
    return `${this.policyUploadTitle} 결과 확인`;
  }

  get policyUploadProgressClass() {
    return "issue-progress-panel";
  }

  get policyUploadProgressDescription() {
    if (!this.hasPolicyUploadResult) {
      return "파일을 업로드하면 등록 가능한 목록과 오류 목록을 바로 확인할 수 있습니다.";
    }
    return `정상 ${this.policyUploadSuccessCount}건 / 오류 ${this.policyUploadFailCount}건을 확인했습니다.`;
  }

  get policyUploadProgressCountText() {
    const totalCount = this.policyUploadSuccessCount + this.policyUploadFailCount;
    return `${this.policyUploadSuccessCount} / ${totalCount}`;
  }

  get policyUploadProgressPercent() {
    const totalCount = this.policyUploadSuccessCount + this.policyUploadFailCount;
    if (!totalCount) {
      return 0;
    }
    return Math.min(100, Math.round((this.policyUploadSuccessCount / totalCount) * 100));
  }

  get policyUploadProgressMeta() {
    if (!this.hasPolicyUploadResult) {
      return "업로드 결과가 이 영역에 표시됩니다.";
    }
    return `정상 ${this.policyUploadSuccessCount}건 / 오류 ${this.policyUploadFailCount}건`;
  }

  get policyUploadDropzoneClass() {
    return this.isPolicyUploadDragOver ? "policy-upload-dropzone policy-upload-dropzone--active" : "policy-upload-dropzone";
  }

  get policyUploadGuideText() {
    return this.policyUploadType === "productIncludeItems"
      ? "코드 컬럼(ProductCode)이 포함된 CSV 파일을 업로드하면 선택 목록에 일괄 반영할 수 있습니다."
      : "코드 컬럼(StoreCode)이 포함된 CSV 파일을 업로드하면 선택 목록에 일괄 반영할 수 있습니다.";
  }

  get policyUploadWarningText() {
    return "최대 5천건만 업로드하세요. 초과 시 업로드가 지연되거나 실패할 수 있습니다.";
  }

  get isDiscountRateDisabled() {
    return this.policyForm.discountRateOperator === OPERATOR_NONE;
  }

  get isTotalQuantityDisabled() {
    return this.policyForm.totalQuantityOperator === OPERATOR_NONE;
  }

  get isSalesAmountDisabled() {
    return this.policyForm.salesAmountOperator === OPERATOR_NONE;
  }

  getSection(sectionKey) {
    return this.policySections.find((section) => section.key === sectionKey);
  }

  updateSection(sectionKey, updater) {
    const nextSections = JSON.parse(JSON.stringify(this.policySections));
    const target = nextSections.find((section) => section.key === sectionKey);
    if (!target) {
      return;
    }
    updater(target);
    this.policySections = nextSections.map((section) => this.decorateSection(section));
  }

  normalizeOperatorValue(value) {
    return value ? value : OPERATOR_NONE;
  }

  normalizeTarget(item, isCategorySection) {
    const normalized = {
      ...item,
      id: item.id || item.code,
      name: item.name || item.code,
      code: item.code || item.id,
      displayText: item.code && item.name && item.code !== item.name ? `${item.name} (${item.code})` : item.name || item.code || item.id,
      pillClass: isCategorySection ? "policy-selected-pill policy-selected-pill--category" : "policy-selected-pill",
      textClass: isCategorySection ? "category-selected-text" : ""
    };
    if (!isCategorySection) {
      return normalized;
    }
    normalized.pathLabel = item.pathLabel || item.name || item.code;
    normalized.displayText = normalized.pathLabel;
    normalized.level = item.level || "";
    normalized.systemCode = item.systemCode || "";
    normalized.largeCode = item.largeCode || "";
    normalized.mediumCode = item.mediumCode || "";
    normalized.smallCode = item.smallCode || "";
    normalized.codePath = [normalized.systemCode, normalized.largeCode, normalized.mediumCode, normalized.smallCode].filter(Boolean).join(" / ");
    return normalized;
  }

  createCategoryNode(item) {
    const node = this.normalizeTarget(item, true);
    const levelName = (node.level || "SMALL").toLowerCase();
    return {
      ...node,
      children: [],
      expanded: false,
      levelClass: `category-level category-level--${levelName}`,
      badgeClass: `category-level-badge category-level-badge--${levelName}`,
      toggleText: "펼치기"
    };
  }

  buildCategoryTree(items) {
    const largeMap = new Map();

    (items || []).forEach((item) => {
      const node = this.createCategoryNode(item);
      const largeKey = `${node.systemCode}-${node.largeCode}`;

      if (!largeMap.has(largeKey)) {
        largeMap.set(largeKey, {
          ...this.createCategoryNode({
            ...node,
            id: largeKey,
            name: node.largeName || node.name,
            code: largeKey,
            level: "LARGE",
            pathLabel: node.largeName || node.name,
            mediumCode: "",
            smallCode: ""
          }),
          id: largeKey,
          children: []
        });
      }

      const largeNode = largeMap.get(largeKey);
      if (node.level === "LARGE") {
        Object.assign(largeNode, node);
        return;
      }

      const mediumKey = `${largeKey}-${node.mediumCode}`;
      let mediumNode = (largeNode.children || []).find((child) => child.id === mediumKey || child.id === node.id);
      if (!mediumNode) {
        mediumNode = {
          ...this.createCategoryNode({
            ...node,
            id: mediumKey,
            name: node.mediumName || node.name,
            code: mediumKey,
            level: "MEDIUM",
            pathLabel: node.mediumName || node.name,
            smallCode: ""
          }),
          id: mediumKey,
          children: []
        };
        largeNode.children = [...largeNode.children, mediumNode];
      }

      if (node.level === "MEDIUM") {
        Object.assign(mediumNode, node);
        return;
      }

      mediumNode.children = [...(mediumNode.children || []), node];
    });

    return Array.from(largeMap.values());
  }

  async handleIssueCouponLimitSet() {
    this.isPolicyModalOpen = true;
    this.isPolicyLoading = true;
    this.policySections = this.createPolicySections();
    this.policyForm = this.createEmptyPolicyForm();
    try {
      const config = await getCouponPolicyConfig({ voucherDefinitionId: this.recordId });
      this.applyPolicyConfig(config || {});
      await this.loadCategoryTree();
    } catch (error) {
      this.policyErrorMessage = this.getErrorMessage(error);
      this.isPolicyErrorModalOpen = true;
    } finally {
      this.isPolicyLoading = false;
    }
  }

  closePolicyModal() {
    this.isPolicyModalOpen = false;
  }

  closePolicyErrorModal() {
    this.isPolicyErrorModalOpen = false;
    this.policyErrorMessage = "";
  }

  applyPolicyConfig(config) {
    const nextSections = this.createPolicySections();
    nextSections.forEach((section) => {
      section.selectedItems = (config[section.key] || []).map((item) => this.normalizeTarget(item, section.isCategorySection));
    });
    this.policySections = nextSections;
    this.policyStoreTypeOptions = (config.storeTypeOptions || []).map((item) => ({ ...item, checked: item.selected }));
    this.policyOrderTypeOptions = (config.orderTypeOptions || []).map((item) => ({ ...item, checked: item.selected }));
    this.policyForm = {
      discountRateOperator: this.normalizeOperatorValue(config.discountRateOperator),
      discountRate: config.discountRate,
      totalQuantityOperator: this.normalizeOperatorValue(config.totalQuantityOperator),
      totalQuantity: config.totalQuantity,
      salesAmountOperator: this.normalizeOperatorValue(config.salesAmountOperator),
      salesAmount: config.salesAmount
    };
  }

  async loadCategoryTree() {
    const section = this.getSection("productCategoryIncludeItems");
    if (!section) {
      return;
    }
    const rows = await searchCouponPolicyTargets({
      targetType: "CATEGORY",
      keyword: "",
      excludeIds: section.selectedItems.map((item) => item.id)
    });
    this.updateSection("productCategoryIncludeItems", (target) => {
      target.resultTree = this.buildCategoryTree(rows || []);
      target.hasSearched = true;
    });
  }

  handlePolicyKeywordChange(event) {
    const sectionKey = event.target.dataset.section;
    this.updateSection(sectionKey, (section) => {
      section.keyword = event.target.value;
    });
  }

  handlePolicyKeywordEnter(event) {
    if (event.key === "Enter") {
      this.handlePolicySearch(event);
    }
  }

  async handlePolicySearch(event) {
    const sectionKey = (event.currentTarget && event.currentTarget.dataset.section) || (event.target && event.target.dataset.section);
    const section = this.getSection(sectionKey);
    if (!section) {
      return;
    }
    try {
      const rows = await searchCouponPolicyTargets({
        targetType: section.targetType,
        keyword: section.keyword,
        excludeIds: section.selectedItems.map((item) => item.id)
      });
      this.updateSection(sectionKey, (target) => {
        target.hasSearched = true;
        if (target.isCategorySection) {
          target.resultTree = this.buildCategoryTree(rows || []);
          target.results = [];
        } else {
          target.results = (rows || []).map((item) => this.normalizeTarget(item, false));
        }
      });
    } catch (error) {
      this.policyErrorMessage = this.getErrorMessage(error);
      this.isPolicyErrorModalOpen = true;
    }
  }

  findTreeNode(nodes, targetId) {
    for (const node of nodes || []) {
      if (node.id === targetId) {
        return node;
      }
      const child = this.findTreeNode(node.children || [], targetId);
      if (child) {
        return child;
      }
    }
    return null;
  }

  removeTreeNode(nodes, targetId) {
    return (nodes || [])
      .filter((node) => node.id !== targetId)
      .map((node) => ({ ...node, children: this.removeTreeNode(node.children || [], targetId) }));
  }

  handleCategoryToggle(event) {
    const sectionKey = event.currentTarget.dataset.section;
    const nodeId = event.currentTarget.dataset.id;
    this.updateSection(sectionKey, (section) => {
      const tree = JSON.parse(JSON.stringify(section.resultTree || []));
      const node = this.findTreeNode(tree, nodeId);
      if (!node) {
        return;
      }
      node.expanded = !node.expanded;
      node.toggleText = node.expanded ? "접기" : "펼치기";
      section.resultTree = tree;
    });
  }

  handlePolicyAddResult(event) {
    const sectionKey = event.currentTarget.dataset.section;
    const itemId = event.currentTarget.dataset.id;
    this.updateSection(sectionKey, (section) => {
      let item = (section.results || []).find((entry) => entry.id === itemId);
      if (!item && section.isCategorySection) {
        item = this.findTreeNode(section.resultTree || [], itemId);
      }
      if (!item || (section.selectedItems || []).some((entry) => entry.id === item.id)) {
        return;
      }
      section.selectedItems = [...section.selectedItems, item];
      section.results = (section.results || []).filter((entry) => entry.id !== itemId);
      if (section.isCategorySection) {
        section.resultTree = this.removeTreeNode(section.resultTree || [], itemId);
      }
    });
  }

  handlePolicyRemoveSelected(event) {
    const sectionKey = event.currentTarget.dataset.section;
    const itemId = event.currentTarget.dataset.id;
    this.updateSection(sectionKey, (section) => {
      section.selectedItems = (section.selectedItems || []).filter((item) => item.id !== itemId);
    });
    if (sectionKey === "productCategoryIncludeItems") {
      this.loadCategoryTree();
    }
  }

  handleStoreTypeToggle(event) {
    const value = event.target.value;
    this.policyStoreTypeOptions = this.policyStoreTypeOptions.map((item) => {
      return item.value === value ? { ...item, checked: event.target.checked } : item;
    });
  }

  handleOrderTypeToggle(event) {
    const value = event.target.value;
    this.policyOrderTypeOptions = this.policyOrderTypeOptions.map((item) => {
      return item.value === value ? { ...item, checked: event.target.checked } : item;
    });
  }

  handlePolicyNumberChange(event) {
    const name = event.target.name;
    const value = event.target.value === "" ? null : event.target.value;
    const nextForm = { ...this.policyForm, [name]: value };

    if (name === "discountRateOperator" && value === OPERATOR_NONE) {
      nextForm.discountRate = null;
    }
    if (name === "totalQuantityOperator" && value === OPERATOR_NONE) {
      nextForm.totalQuantity = null;
    }
    if (name === "salesAmountOperator" && value === OPERATOR_NONE) {
      nextForm.salesAmount = null;
    }

    this.policyForm = nextForm;
  }

  getSanitizedNumericPolicy() {
    const result = {
      discountRateOperator: this.policyForm.discountRateOperator === OPERATOR_NONE ? null : this.policyForm.discountRateOperator,
      discountRate: this.policyForm.discountRateOperator === OPERATOR_NONE ? null : this.policyForm.discountRate,
      totalQuantityOperator: this.policyForm.totalQuantityOperator === OPERATOR_NONE ? null : this.policyForm.totalQuantityOperator,
      totalQuantity: this.policyForm.totalQuantityOperator === OPERATOR_NONE ? null : this.policyForm.totalQuantity,
      salesAmountOperator: this.policyForm.salesAmountOperator === OPERATOR_NONE ? null : this.policyForm.salesAmountOperator,
      salesAmount: this.policyForm.salesAmountOperator === OPERATOR_NONE ? null : this.policyForm.salesAmount
    };

    if (result.discountRateOperator && (result.discountRate === null || result.discountRate === undefined || result.discountRate === "")) {
      throw new Error("최대 할인율 값을 입력하세요.");
    }
    if (result.totalQuantityOperator && (result.totalQuantity === null || result.totalQuantity === undefined || result.totalQuantity === "")) {
      throw new Error("최소 수량 값을 입력하세요.");
    }
    if (result.salesAmountOperator && (result.salesAmount === null || result.salesAmount === undefined || result.salesAmount === "")) {
      throw new Error("최소 금액 값을 입력하세요.");
    }

    return result;
  }

  async handlePolicySave() {
    this.isPolicySaving = true;
    try {
      const numericPolicy = this.getSanitizedNumericPolicy();
      await saveCouponPolicy({
        requestJson: JSON.stringify({
          voucherDefinitionId: this.recordId,
          productIncludeIds: this.getSection("productIncludeItems").selectedItems.map((item) => item.id),
          storeIncludeIds: this.getSection("storeIncludeItems").selectedItems.map((item) => item.id),
          gradeIncludeIds: this.getSection("gradeIncludeItems").selectedItems.map((item) => item.id),
          productCategoryIncludeIds: this.getSection("productCategoryIncludeItems").selectedItems.map((item) => item.id),
          storeTypeValues: this.policyStoreTypeOptions.filter((item) => item.checked).map((item) => item.value),
          orderTypeValues: this.policyOrderTypeOptions.filter((item) => item.checked).map((item) => item.value),
          discountRateOperator: numericPolicy.discountRateOperator,
          discountRate: numericPolicy.discountRate,
          totalQuantityOperator: numericPolicy.totalQuantityOperator,
          totalQuantity: numericPolicy.totalQuantity,
          salesAmountOperator: numericPolicy.salesAmountOperator,
          salesAmount: numericPolicy.salesAmount
        })
      });
      this.isPolicyModalOpen = false;
      this.hasLoaded = false;
      await this.loadPageData();
      this.dispatchEvent(new ShowToastEvent({ title: "완료", message: "쿠폰 사용 정책을 저장했습니다.", variant: "success" }));
      window.location.reload();
    } catch (error) {
      this.policyErrorMessage = this.getErrorMessage(error);
      this.isPolicyErrorModalOpen = true;
    } finally {
      this.isPolicySaving = false;
    }
  }

  openPolicyUploadModal(event) {
    const sectionKey = event.currentTarget.dataset.section;
    this.policyUploadType = sectionKey;
    this.policyUploadTitle = sectionKey === "productIncludeItems" ? "제품 일괄 등록" : "매장 일괄 등록";
    this.policyUploadFileName = "";
    this.policyUploadPreviewRows = [];
    this.policyUploadErrors = [];
    this.isPolicyUploadDragOver = false;
    this.isPolicyUploadModalOpen = true;
  }

  closePolicyUploadModal() {
    this.isPolicyUploadModalOpen = false;
    this.isPolicyUploadLoading = false;
    this.isPolicyUploadDragOver = false;
  }

  clearPolicyUploadFile() {
    if (this.isPolicyUploadLoading) {
      return;
    }
    this.policyUploadFileName = "";
    this.policyUploadPreviewRows = [];
    this.policyUploadErrors = [];
    this.isPolicyUploadDragOver = false;
  }

  handlePolicyUploadClick() {
    const input = this.template.querySelector(".policy-upload-file-input");
    if (input) {
      input.click();
    }
  }

  handlePolicyUploadDragEnter(event) {
    event.preventDefault();
    this.isPolicyUploadDragOver = true;
  }

  handlePolicyUploadDragOver(event) {
    event.preventDefault();
    this.isPolicyUploadDragOver = true;
  }

  handlePolicyUploadDragLeave(event) {
    event.preventDefault();
    const relatedTarget = event.relatedTarget;
    if (!relatedTarget || !event.currentTarget.contains(relatedTarget)) {
      this.isPolicyUploadDragOver = false;
    }
  }

  handlePolicyUploadDrop(event) {
    event.preventDefault();
    this.isPolicyUploadDragOver = false;
    const file = event.dataTransfer?.files && event.dataTransfer.files[0];
    if (!file) {
      return;
    }
    this.processPolicyUploadFile(file);
  }

  handlePolicyUploadFileChange(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) {
      return;
    }
    this.processPolicyUploadFile(file);
    event.target.value = null;
  }

  processPolicyUploadFile(file) {
    this.policyUploadFileName = file.name;
    const reader = new FileReader();
    reader.onload = async () => {
      this.isPolicyUploadLoading = true;
      try {
        const base64Data = String(reader.result).split(",")[1];
        const result =
          this.policyUploadType === "productIncludeItems" ? await parseProductLimitFile({ base64Data }) : await parseStoreLimitFile({ base64Data });
        this.policyUploadPreviewRows = result.previewRows || [];
        this.policyUploadErrors = result.errors || [];
      } catch (error) {
        this.policyErrorMessage = this.getErrorMessage(error);
        this.isPolicyErrorModalOpen = true;
      } finally {
        this.isPolicyUploadLoading = false;
      }
    };
    reader.readAsDataURL(file);
  }

  applyPolicyUploadRows() {
    if (!this.policyUploadType || !this.policyUploadPreviewRows.length) {
      this.closePolicyUploadModal();
      return;
    }

    this.updateSection(this.policyUploadType, (section) => {
      const existingIds = new Set((section.selectedItems || []).map((item) => item.id));
      const uploaded = this.policyUploadPreviewRows
        .filter((row) => !existingIds.has(row.id || row.code))
        .map((row) => this.normalizeTarget({ id: row.id || row.code, code: row.code, name: row.name }, false));
      section.selectedItems = [...section.selectedItems, ...uploaded];
    });

    this.closePolicyUploadModal();
  }

  handleToggleMore(event) {
    const type = event.currentTarget.dataset.type;
    const target = this.limitItems.find((item) => item.type === type);
    this.selectedLimitType = type;
    this.selectedLimitLabel = target ? target.label : "";
    this.selectedLimitItems = target ? target.values : [];
    this.limitPage = 1;
    this.isLimitModalOpen = true;
  }

  closeLimitModal() {
    this.isLimitModalOpen = false;
  }

  handleLimitPageClick(event) {
    this.limitPage = Number(event.currentTarget.dataset.page);
  }

  handleLimitPageGroupPrev() {
    if (this.limitPage > 1) {
      this.limitPage -= 1;
    }
  }

  handleLimitPageGroupNext() {
    const total = Math.max(1, Math.ceil(this.selectedLimitItems.length / this.limitPageSize));
    if (this.limitPage < total) {
      this.limitPage += 1;
    }
  }

  handleUploadClick() {
    this.previewMembers = [];
    this.successCount = 0;
    this.failCount = 0;
    this.successMemberIds = [];
    this.uploadFileName = "";
    this.isUploadDragOver = false;
    this.isUploadProcessing = false;
    this.issueErrorMessage = "";
    this.isIssueErrorModalOpen = false;
    this.resetIssueProgress();
    this.isUploadModalOpen = true;
  }

  handleCouponUploadFileClick() {
    const input = this.template.querySelector(".coupon-upload-file-input");
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
    const file = event.dataTransfer?.files && event.dataTransfer.files[0];
    if (!file) {
      return;
    }
    this.processCouponUploadFile(file);
  }

  handleFileChange(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) {
      return;
    }
    this.processCouponUploadFile(file);
    event.target.value = null;
  }

  processCouponUploadFile(file) {
    this.previewMembers = [];
    this.successCount = 0;
    this.failCount = 0;
    this.successMemberIds = [];
    this.issueErrorMessage = "";
    this.isIssueErrorModalOpen = false;
    this.resetIssueProgress();
    this.uploadFileName = file.name;
    this.isUploadProcessing = true;
    this.isUploadModalOpen = true;

    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const result = await parseCouponFile({ base64Data: String(reader.result).split(",")[1] });
        this.previewMembers = result.errors || [];
        this.successCount = result.successCount || 0;
        this.failCount = result.failCount || 0;
        this.successMemberIds = result.successMemberIds || [];
      } catch (error) {
        this.issueErrorMessage = this.getErrorMessage(error);
        this.isIssueErrorModalOpen = true;
      } finally {
        this.isUploadProcessing = false;
      }
    };
    reader.readAsDataURL(file);
  }

  clearCouponUploadFile() {
    if (this.isUploadProcessing || this.isIssueInProgress) {
      return;
    }
    this.previewMembers = [];
    this.successCount = 0;
    this.failCount = 0;
    this.successMemberIds = [];
    this.uploadFileName = "";
    this.isUploadDragOver = false;
    this.issueErrorMessage = "";
    this.isIssueErrorModalOpen = false;
    this.resetIssueProgress();
  }

  resetIssueProgress() {
    this.stopIssueProgressPolling();
    this.issueJobId = "";
    this.issueRequestToken = "";
    this.issueStatus = "";
    this.issueProcessedCount = 0;
    this.issueSuccessCount = 0;
    this.issueFailCount = 0;
    this.issueProgressMessage = "";
    this.isIssueLoading = false;
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
      const result = await getIssueCouponProgress({
        issueJobId: this.issueJobId,
        totalCount: this.successCount,
        requestToken: this.issueRequestToken
      });

      this.issueStatus = result?.status || "PROCESSING";
      this.issueProcessedCount = result?.processedCount || 0;
      this.issueSuccessCount = result?.successCount || 0;
      this.issueFailCount = result?.failCount || 0;
      this.issueProgressMessage = result?.message || "";

      if (result?.isCompleted || result?.isFailed) {
        this.stopIssueProgressPolling();
      }
    } catch (error) {
      this.stopIssueProgressPolling();
      this.issueStatus = "FAILED";
      this.issueProgressMessage = this.getErrorMessage(error);
    }
  }

  closeUploadModal() {
    if (this.isUploadProcessing || this.isIssueInProgress) {
      return;
    }
    this.isUploadModalOpen = false;
  }

  closeIssueErrorModal() {
    this.isIssueErrorModalOpen = false;
    this.issueErrorMessage = "";
  }

  async handleIssueCoupon() {
    if (this.isIssueCompleted || this.isIssueFailed) {
      this.closeUploadModal();
      return;
    }

    this.isIssueLoading = true;
    try {
      const result = await issueCoupon({ memberIds: this.successMemberIds, voucherDefinitionId: this.recordId });
      this.issueJobId = result?.issueJobId || "";
      this.issueRequestToken = result?.requestToken || "";
      this.issueStatus = result?.status || "PROCESSING";
      this.issueProcessedCount = result?.processedCount || 0;
      this.issueSuccessCount = result?.successCount || 0;
      this.issueFailCount = result?.failCount || 0;
      this.issueProgressMessage = result?.message || "";

      if (this.issueJobId) {
        await this.refreshIssueProgress();
        if (this.isIssueInProgress) {
          this.startIssueProgressPolling();
        }
      } else {
        this.issueStatus = "COMPLETED";
        this.issueProcessedCount = this.successCount;
        this.issueSuccessCount = result?.successCount || this.successCount;
        this.issueFailCount = result?.failCount || 0;
      }
    } catch (error) {
      this.issueErrorMessage = this.getErrorMessage(error);
      this.isIssueErrorModalOpen = true;
      this.issueStatus = "FAILED";
      this.issueProgressMessage = this.getErrorMessage(error);
    } finally {
      this.isIssueLoading = false;
    }
  }

  getErrorMessage(error) {
    if (error && error.body && error.body.message) {
      return error.body.message;
    }
    if (error && error.message) {
      return error.message;
    }
    return "처리 중 오류가 발생했습니다.";
  }
}