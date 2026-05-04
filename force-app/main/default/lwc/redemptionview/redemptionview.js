import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getPointRedemptionRows from "@salesforce/apex/PointLedgerUIControllerV1.getPointRedemptionRows";

export default class Redemptionview extends NavigationMixin(LightningElement) {
  pageSize = 7;
  visiblePageCount = 5;
  @api recordId;

  rows = [];
  error;
  isLoading = true;
  currentPage = 1;
  filterDate = "";

  @wire(getPointRedemptionRows, { loyaltyProgramMemberId: "$recordId" })
  wiredRedemptionRows({ data, error }) {
    this.isLoading = false;

    if (data) {
      this.rows = data
        .map((row) => ({
          ...row,
          redemptionDateText: this.formatDate(row.redemptionDate),
          redemptionPointsText: this.formatSignedNumber(row.redemptionPoints, row.isCancel),
          saleAmountText: this.formatNumber(row.saleAmount),
          orderNoText: row.orderNo || "",
          saleNoText: row.saleNo || "",
          hasOrderLink: Boolean(row.orderNo && row.recordId),
          hasSaleLink: Boolean(row.saleNo && row.recordId),
          hasNoLink: !row.orderNo && !row.saleNo,
          accrualSaleNoText: row.accrualSaleNo || "-",
          returnSaleNoText: row.returnSaleNo || "-",
          hasAccrualLink: Boolean(row.accrualSaleNo && row.accrualRecordId),
          hasReturnLink: Boolean(row.returnSaleNo && row.recordId),
          rowClass: row.isCancel ? "row-cancel" : ""
        }))
        .sort((a, b) => this.compareDateAsc(a.redemptionDate, b.redemptionDate));
      this.currentPage = 1;
      this.error = undefined;
      return;
    }

    if (error) {
      this.error = error;
      this.rows = [];
      this.currentPage = 1;
    }
  }

  formatSignedNumber(value, isCancel) {
    const num = Number(value || 0);
    if (num === 0) {
      return "-";
    }

    const formatted = num.toLocaleString("ko-KR");
    return isCancel ? `-${formatted}` : formatted;
  }

  formatDate(value) {
    if (!value) {
      return "-";
    }

    return String(value).replaceAll("-", "/");
  }

  formatNumber(value) {
    const num = Number(value || 0);
    return num === 0 ? "-" : num.toLocaleString("ko-KR");
  }

  get hasRows() {
    return this.filteredRows.length > 0;
  }

  get hasSourceRows() {
    return this.rows.length > 0;
  }

  get hasError() {
    return !!this.error;
  }

  get filteredRows() {
    return this.rows.filter((row) => {
      const rowDate = this.normalizeDate(row.redemptionDate);
      return !this.filterDate || rowDate === this.filterDate;
    });
  }

  get pagedRows() {
    const startIndex = (this.currentPage - 1) * this.pageSize;
    return this.filteredRows.slice(startIndex, startIndex + this.pageSize);
  }

  get totalPages() {
    return Math.ceil(this.filteredRows.length / this.pageSize);
  }

  get hasPagination() {
    return this.totalPages > 1;
  }

  get pageWindowStart() {
    return Math.floor((this.currentPage - 1) / this.visiblePageCount) * this.visiblePageCount + 1;
  }

  get pageItems() {
    const endPage = Math.min(this.pageWindowStart + this.visiblePageCount - 1, this.totalPages);
    return Array.from({ length: endPage - this.pageWindowStart + 1 }, (_, index) => {
      const pageNumber = this.pageWindowStart + index;
      return {
        number: pageNumber,
        key: `page-${pageNumber}`,
        className: pageNumber === this.currentPage ? "page-btn is-active" : "page-btn"
      };
    });
  }

  get isPrevDisabled() {
    return this.pageWindowStart <= 1;
  }

  get isNextDisabled() {
    return this.pageWindowStart + this.visiblePageCount > this.totalPages;
  }

  handlePageClick(event) {
    this.currentPage = Number(event.currentTarget.dataset.page);
  }

  handleRecordNavigate(event) {
    event.preventDefault();
    const recordId = event.currentTarget.dataset.id;
    if (!recordId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId,
        objectApiName: "Order",
        actionName: "view"
      }
    });
  }

  handleDateFilterChange(event) {
    this.filterDate = event.target.value;
    this.currentPage = 1;
  }

  handlePrevPage() {
    if (!this.isPrevDisabled) {
      this.currentPage = Math.max(1, this.pageWindowStart - this.visiblePageCount);
    }
  }

  handleNextPage() {
    if (!this.isNextDisabled) {
      this.currentPage = Math.min(this.totalPages, this.pageWindowStart + this.visiblePageCount);
    }
  }

  normalizeDate(value) {
    if (!value) {
      return "";
    }
    return String(value).slice(0, 10);
  }

  compareDateAsc(left, right) {
    const leftDate = this.normalizeDate(left);
    const rightDate = this.normalizeDate(right);

    if (!leftDate && !rightDate) {
      return 0;
    }
    if (!leftDate) {
      return 1;
    }
    if (!rightDate) {
      return -1;
    }

    return leftDate.localeCompare(rightDate);
  }
}
