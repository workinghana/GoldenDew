import { api, LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from "lightning/refresh";
import parseProductUploadFile from "@salesforce/apex/PromotionProductUploadControllerV1.parseUploadFile";
import insertPromotionProducts from "@salesforce/apex/PromotionProductUploadControllerV1.insertPromotionProducts";
import parseStoreUploadFile from "@salesforce/apex/PromotionAccountUploadControllerV1.parseUploadFile";
import insertPromotionAccounts from "@salesforce/apex/PromotionAccountUploadControllerV1.insertPromotionAccounts";

const PRODUCT_ERROR_COLUMNS = [
  { label: "행", fieldName: "rowNumber", type: "number", initialWidth: 90 },
  { label: "제품 코드", fieldName: "codeValue" },
  { label: "제품명", fieldName: "nameValue" },
  { label: "오류 사유", fieldName: "errorReason" }
];

const STORE_ERROR_COLUMNS = [
  { label: "행", fieldName: "rowNumber", type: "number", initialWidth: 90 },
  { label: "매장 코드", fieldName: "codeValue" },
  { label: "매장명", fieldName: "nameValue" },
  { label: "오류 사유", fieldName: "errorReason" }
];

const UPLOAD_TYPES = {
  PRODUCT: "product",
  STORE: "store"
};

export default class Promotion_upload extends LightningElement {
  @api recordId;

  isModalOpen = false;
  isParsing = false;
  isUploading = false;
  isDragOver = false;
  hasUploaded = false;
  hasPreviewResult = false;

  currentUploadType = UPLOAD_TYPES.PRODUCT;
  fileName = "";
  fileBody;
  previewRows = [];
  errorRows = [];
  successCount = 0;
  failCount = 0;

  handleOpenProductModal() {
    this.openModal(UPLOAD_TYPES.PRODUCT);
  }

  handleOpenStoreModal() {
    this.openModal(UPLOAD_TYPES.STORE);
  }

  openModal(type) {
    this.currentUploadType = type;
    this.isModalOpen = true;
    this.resetState();
  }

  get isProductUpload() {
    return this.currentUploadType === UPLOAD_TYPES.PRODUCT;
  }

  get modalTitle() {
    return this.isProductUpload ? "프로모션 상품 업로드" : "프로모션 매장 업로드";
  }

  get fileGuideText() {
    return this.isProductUpload ? "헤더는 제품 코드(ProductCode__c)만 있으면 됩니다." : "헤더는 매장 코드(StoreCode__c)만 있으면 됩니다.";
  }

  get errorColumns() {
    return this.isProductUpload ? PRODUCT_ERROR_COLUMNS : STORE_ERROR_COLUMNS;
  }

  get hasFile() {
    return !!this.fileBody;
  }

  get hasValidRows() {
    return (this.previewRows || []).length > 0;
  }

  get hasErrors() {
    return (this.errorRows || []).length > 0;
  }

  get isUploadDisabled() {
    return !this.hasFile || !this.hasValidRows || this.isParsing || this.isUploading || this.hasUploaded;
  }

  get uploadButtonLabel() {
    if (this.isUploading) {
      return "업로드 중...";
    }
    if (this.hasUploaded) {
      return "업로드 완료";
    }
    return "업로드";
  }

  get dropZoneClass() {
    return this.isDragOver ? "drop-zone drop-zone--active" : "drop-zone";
  }

  get hasCompletionMessage() {
    return this.hasUploaded && this.successCount > 0;
  }

  get completionMessage() {
    if (!this.hasCompletionMessage) {
      return "";
    }

    return this.isProductUpload
      ? `${this.successCount}개의 제품이 해당 프로모션에 등록 완료되었습니다.`
      : `${this.successCount}개의 매장이 해당 프로모션에 등록 완료되었습니다.`;
  }

  handleCloseModal() {
    if (this.isParsing || this.isUploading) {
      return;
    }

    this.isModalOpen = false;
    this.resetState();
  }

  handleSelectClick() {
    const input = this.template.querySelector('input[type="file"]');
    if (input) {
      input.click();
    }
  }

  handleDragEnter(event) {
    event.preventDefault();
    this.isDragOver = true;
  }

  handleDragOver(event) {
    event.preventDefault();
    this.isDragOver = true;
  }

  handleDragLeave(event) {
    event.preventDefault();
    const relatedTarget = event.relatedTarget;
    if (!relatedTarget || !event.currentTarget.contains(relatedTarget)) {
      this.isDragOver = false;
    }
  }

  handleDrop(event) {
    event.preventDefault();
    this.isDragOver = false;

    const file = event.dataTransfer?.files && event.dataTransfer.files[0];
    if (!file) {
      return;
    }

    this.processFile(file);
  }

  handleFileChange(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) {
      this.resetFileState();
      return;
    }

    this.processFile(file);
  }

  processFile(file) {
    this.resetPreviewState();
    this.fileName = file.name;

    const reader = new FileReader();
    reader.onload = async () => {
      const result = reader.result || "";
      const base64Marker = "base64,";
      const markerIndex = result.indexOf(base64Marker);
      this.fileBody = markerIndex > -1 ? result.substring(markerIndex + base64Marker.length) : null;

      if (!this.fileBody) {
        this.showToast("파일 읽기 실패", "파일 데이터를 읽지 못했습니다.", "error");
        return;
      }

      await this.previewUploadFile();
    };
    reader.readAsDataURL(file);
  }

  async previewUploadFile() {
    if (!this.recordId) {
      this.showToast("프로모션 정보 없음", "현재 프로모션 정보를 찾을 수 없습니다.", "error");
      return;
    }

    this.isParsing = true;
    this.hasUploaded = false;

    try {
      const result = this.isProductUpload
        ? await parseProductUploadFile({ base64Data: this.fileBody, promotionId: this.recordId })
        : await parseStoreUploadFile({ base64Data: this.fileBody, promotionId: this.recordId });

      this.previewRows = result?.previewRows || [];
      this.errorRows = this.normalizeErrors(result?.errors || []);
      this.successCount = result?.successCount || 0;
      this.failCount = result?.failCount || 0;
      this.hasPreviewResult = true;
    } catch (error) {
      this.resetPreviewState();
      this.showToast(
        "파일 검증 실패",
        this.translateServerMessage(error?.body?.message || error?.message) || "파일 검증 중 오류가 발생했습니다.",
        "error"
      );
    } finally {
      this.isParsing = false;
    }
  }

  async handleUploadClick() {
    if (!this.hasValidRows) {
      this.showToast("업로드 불가", this.isProductUpload ? "업로드 가능한 제품이 없습니다." : "업로드 가능한 매장이 없습니다.", "warning");
      return;
    }

    this.isUploading = true;

    try {
      const result = this.isProductUpload
        ? await insertPromotionProducts({ base64Data: this.fileBody, promotionId: this.recordId })
        : await insertPromotionAccounts({ base64Data: this.fileBody, promotionId: this.recordId });

      this.errorRows = this.normalizeErrors(result?.errors || []);
      this.successCount = result?.successCount || 0;
      this.failCount = result?.failCount || 0;
      this.hasPreviewResult = true;
      this.hasUploaded = true;

      if (this.successCount > 0) {
        this.dispatchEvent(new RefreshEvent());
      }

      this.showToast(
        "업로드 완료",
        this.completionMessage || this.translateServerMessage(result?.errorMessage) || "등록 완료된 항목이 없습니다.",
        result?.success ? "success" : "warning"
      );
    } catch (error) {
      this.showToast("업로드 실패", this.translateServerMessage(error?.body?.message || error?.message) || "업로드 중 오류가 발생했습니다.", "error");
    } finally {
      this.isUploading = false;
    }
  }

  normalizeErrors(errors) {
    return (errors || []).map((item, index) => {
      const codeValue = this.isProductUpload ? item?.productCode : item?.storeCode;
      const nameValue = this.isProductUpload ? item?.productName : item?.storeName;
      return {
        key: `${item?.rowNumber || 0}-${codeValue || "empty"}-${index}`,
        rowNumber: item?.rowNumber,
        codeValue: codeValue || "-",
        nameValue: nameValue || "-",
        errorReason: this.translateErrorReason(item?.errorReason) || "-"
      };
    });
  }

  translateErrorReason(message) {
    const translations = {
      "ProductCode__c is required.": "제품 코드가 비어 있습니다.",
      "Duplicate product code in file.": "파일 내 제품 코드가 중복되었습니다.",
      "Product not found.": "일치하는 제품을 찾을 수 없습니다.",
      "PromotionProduct already exists.": "이미 적용 가능 품목에 등록된 제품입니다.",
      "StoreCode__c is required.": "매장 코드가 비어 있습니다.",
      "Duplicate store code in file.": "파일 내 매장 코드가 중복되었습니다.",
      "Store not found.": "일치하는 매장을 찾을 수 없습니다.",
      "PromotionAccount already exists.": "이미 적용 가능 매장에 등록된 매장입니다.",
      "Unknown error": "알 수 없는 오류가 발생했습니다."
    };

    return translations[message] || message;
  }

  translateServerMessage(message) {
    if (!message) {
      return message;
    }

    return message
      .replaceAll("Required column ProductCode__c is missing.", '필수 컬럼 "제품 코드(ProductCode__c)"가 없습니다.')
      .replaceAll("ProductCode__c is required.", "제품 코드가 비어 있습니다.")
      .replaceAll("Duplicate product code in file.", "파일 내 제품 코드가 중복되었습니다.")
      .replaceAll("Product not found.", "일치하는 제품을 찾을 수 없습니다.")
      .replaceAll("PromotionProduct already exists.", "이미 적용 가능 품목에 등록된 제품입니다.")
      .replaceAll("Required column StoreCode__c is missing.", '필수 컬럼 "매장 코드(StoreCode__c)"가 없습니다.')
      .replaceAll("StoreCode__c is required.", "매장 코드가 비어 있습니다.")
      .replaceAll("Duplicate store code in file.", "파일 내 매장 코드가 중복되었습니다.")
      .replaceAll("Store not found.", "일치하는 매장을 찾을 수 없습니다.")
      .replaceAll("PromotionAccount already exists.", "이미 적용 가능 매장에 등록된 매장입니다.")
      .replaceAll("No valid rows to upload.", "업로드 가능한 행이 없습니다.")
      .replaceAll("Unknown error", "알 수 없는 오류가 발생했습니다.");
  }

  resetState() {
    this.isDragOver = false;
    this.resetFileState();
    const input = this.template.querySelector('input[type="file"]');
    if (input) {
      input.value = null;
    }
  }

  resetFileState() {
    this.fileName = "";
    this.fileBody = null;
    this.resetPreviewState();
  }

  resetPreviewState() {
    this.previewRows = [];
    this.errorRows = [];
    this.successCount = 0;
    this.failCount = 0;
    this.hasPreviewResult = false;
    this.hasUploaded = false;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}