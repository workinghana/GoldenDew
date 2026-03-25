import { LightningElement, api } from "lwc";
import getPointLedgerRows from "@salesforce/apex/PointLedgerUIControllerV1.getPointLedgerRows";
import resolveLoyaltyProgramMemberId from "@salesforce/apex/PointLedgerUIControllerV1.resolveLoyaltyProgramMemberId";
import resolveOrderId from "@salesforce/apex/PointLedgerUIControllerV1.resolveOrderId";

export default class AccrualLegerview extends LightningElement {
  pageSize = 7;
  visiblePageCount = 5;
  _recordId;

  rows = [];
  error;
  isLoading = true;
  currentPage = 1;
  filterDate = "";
  resolvedMemberId;
  resolvedOrderId;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    this.loadRows();
  }

  async loadRows() {
    if (!this._recordId) {
      this.rows = [];
      this.resolvedMemberId = null;
      this.resolvedOrderId = null;
      this.error = undefined;
      this.isLoading = false;
      return;
    }

    this.isLoading = true;

    try {
      this.resolvedMemberId = await resolveLoyaltyProgramMemberId({ recordId: this._recordId });
      this.resolvedOrderId = await resolveOrderId({ recordId: this._recordId });

      if (!this.resolvedMemberId) {
        this.rows = [];
        this.currentPage = 1;
        this.error = undefined;
        return;
      }

      const data = await getPointLedgerRows({ loyaltyProgramMemberId: this.resolvedMemberId, orderId: this.resolvedOrderId });
      this.rows = (data || []).map((row) => ({
        ...row,
        endDateText: this.formatDate(row.endDate),
        accruedPointsText: this.formatNumber(row.accruedPoints),
        usedPointsText: this.formatNumber(row.usedPoints),
        expiredPointsText: this.formatNumber(row.expiredPoints),
        depositCouponAmountText: this.formatNumber(row.depositCouponAmount),
        depositPointAmountText: this.formatNumber(row.depositPointAmount),
        depositHqExchangeAmountText: this.formatNumber(row.depositHqExchangeAmount)
      }));
      this.currentPage = 1;
      this.error = undefined;
    } catch (error) {
      this.error = error;
      this.rows = [];
      this.currentPage = 1;
    } finally {
      this.isLoading = false;
    }
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
      const rowDate = this.normalizeDate(row.endDate);
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
}