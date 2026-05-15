import { api, LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from "lightning/refresh";
import parseUploadFile from "@salesforce/apex/PromotionProductUploadControllerV1.parseUploadFile";
import insertPromotionProducts from "@salesforce/apex/PromotionProductUploadControllerV1.insertPromotionProducts";

const ERROR_COLUMNS = [
  { label: "행", fieldName: "rowNumber", type: "number", initialWidth: 90 },
  { label: "제품코드", fieldName: "productCode" },
  { label: "오류 사유", fieldName: "errorReason" }
];

export default class Promotion_product_upload extends LightningElement {
  @api recordId;

  isModalOpen = false;
  isParsing = false;
  isUploading = false;
  hasUploaded = false;
  hasPreviewResult = false;

  fileName = "";
  fileBody;
  previewRows = [];
  errorRows = [];
  successCount = 0;
  failCount = 0;

  errorColumns = ERROR_COLUMNS;

  get uploadGuideText() {
    return "코드 컬럼(ProductCode)이 포함된 CSV 파일을 업로드하면 선택 목록에 일괄 반영할 수 있습니다.";
  }

  get uploadWarningText() {
    return "최대 5천건만 업로드하세요. 초과 시 업로드가 지연되거나 실패할 수 있습니다.";
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

  handleOpenModal() {
    this.isModalOpen = true;
    this.resetState();
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

  handleFileChange(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) {
      this.resetFileState();
      return;
    }

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

  handleClearFile() {
    if (this.isParsing || this.isUploading) {
      return;
    }
    this.resetState();
  }

  async previewUploadFile() {
    if (!this.recordId) {
      this.showToast("프로모션 정보 없음", "현재 프로모션 정보를 찾을 수 없습니다.", "error");
      return;
    }

    this.isParsing = true;
    this.hasUploaded = false;

    try {
      const result = await parseUploadFile({
        base64Data: this.fileBody,
        promotionId: this.recordId
      });

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
      this.showToast("업로드 불가", "업로드 가능한 제품이 없습니다.", "warning");
      return;
    }

    this.isUploading = true;

    try {
      const result = await insertPromotionProducts({
        base64Data: this.fileBody,
        promotionId: this.recordId
      });

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
        this.translateServerMessage(result?.errorMessage) || `성공 ${this.successCount}건, 실패 ${this.failCount}건`,
        result?.success ? "success" : "warning"
      );
    } catch (error) {
      this.showToast("업로드 실패", this.translateServerMessage(error?.body?.message || error?.message) || "업로드 중 오류가 발생했습니다.", "error");
    } finally {
      this.isUploading = false;
    }
  }

  normalizeErrors(errors) {
    return (errors || []).map((item, index) => ({
      key: `${item?.rowNumber || 0}-${item?.productCode || "empty"}-${index}`,
      rowNumber: item?.rowNumber,
      productCode: item?.productCode || "-",
      errorReason: this.translateErrorReason(item?.errorReason) || "-"
    }));
  }

  translateErrorReason(message) {
    const translations = {
      "ProductCode is required.": "제품 코드가 비어 있습니다.",
      "Duplicate product code in file.": "파일 내 제품 코드가 중복되었습니다.",
      "Product not found.": "일치하는 제품을 찾을 수 없습니다.",
      "PromotionProduct already exists.": "이미 적용 가능 품목에 등록된 제품입니다.",
      "Unknown error": "알 수 없는 오류가 발생했습니다."
    };

    return translations[message] || message;
  }

  translateServerMessage(message) {
    if (!message) {
      return message;
    }

    return message
      .replaceAll("Required column ProductCode is missing.", '필수 컬럼 "제품 코드(ProductCode)"가 없습니다.')
      .replaceAll("ProductCode is required.", "제품 코드가 비어 있습니다.")
      .replaceAll("Duplicate product code in file.", "파일 내 제품 코드가 중복되었습니다.")
      .replaceAll("Product not found.", "일치하는 제품을 찾을 수 없습니다.")
      .replaceAll("PromotionProduct already exists.", "이미 적용 가능 품목에 등록된 제품입니다.")
      .replaceAll("No valid rows to upload.", "업로드 가능한 행이 없습니다.")
      .replaceAll("Unknown error", "알 수 없는 오류가 발생했습니다.");
  }

  resetState() {
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