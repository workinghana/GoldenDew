import { LightningElement, api, wire } from "lwc";
import getPointDetails from "@salesforce/apex/LoyaltyAggrSubUIController.getPointDetails";

export default class Pointdetail extends LightningElement {
  @api recordId;

  pointDetails = [];
  filteredPointDetails = [];
  pagedPointDetails = [];

  expireFrom;
  expireTo;

  error;
  isLoading = true;

  pageSize = 7;
  currentPage = 1;
  totalPages = 0;

  /* ===== 포인트 집계 ===== */

  pointSummary = [];
  totalPoint = 0;

  @wire(getPointDetails, { loyaltyProgramMemberId: "$recordId" })
  wiredPointDetails({ data, error }) {
    this.isLoading = false;

    if (data) {
      this.pointDetails = data.details.map((row) => ({
        ...row,
        remainingClass: row.remainingPoints === 0 ? "zero" : "remain"
      }));

      this.filteredPointDetails = [...this.pointDetails];

      this.calculatePointSummary();

      this.totalPages = Math.ceil(this.filteredPointDetails.length / this.pageSize);

      this.currentPage = 1;

      this.updatePagedData();

      this.error = undefined;
    } else if (error) {
      this.error = error;

      this.pointDetails = [];
      this.filteredPointDetails = [];
      this.pagedPointDetails = [];
    }
  }

  /* ================= 포인트 집계 ================= */

  calculatePointSummary() {
    const baseTypes = ["기념일포인트", "승급포인트", "기타포인트", "에코포인트", "사은포인트", "구매포인트"];

    const map = new Map();

    // 기본값 0 세팅
    baseTypes.forEach((type) => {
      map.set(type, 0);
    });

    let total = 0;

    this.filteredPointDetails.forEach((row) => {
      const type = row.pointTypeName;
      const point = row.remainingPoints || 0;

      total += point;

      if (map.has(type)) {
        map.set(type, map.get(type) + point);
      }
    });

    this.pointSummary = baseTypes.map((type) => ({
      name: type,
      points: map.get(type) || 0
    }));

    this.totalPoint = total;
  }

  get hasData() {
    return this.filteredPointDetails && this.filteredPointDetails.length > 0;
  }

  get hasError() {
    return !!this.error;
  }

  get showEmpty() {
    return !this.isLoading && !this.hasData && !this.hasError;
  }

  get pageList() {
    return Array.from({ length: this.totalPages }, (_, i) => {
      const page = i + 1;

      return {
        page,
        className: page === this.currentPage ? "active" : ""
      };
    });
  }

  handleExpireDateChange(event) {
    const type = event.target.dataset.type;
    const value = event.target.value;

    if (type === "from") {
      this.expireFrom = value;
    }

    if (type === "to") {
      this.expireTo = value;
    }

    this.applyExpireFilter();
  }

  applyExpireFilter() {
    this.filteredPointDetails = this.pointDetails.filter((row) => {
      if (!row.expirationDate) return false;

      const expDate = row.expirationDate.slice(0, 10);

      if (this.expireFrom && expDate < this.expireFrom) return false;

      if (this.expireTo && expDate > this.expireTo) return false;

      return true;
    });

    this.calculatePointSummary();

    this.totalPages = Math.ceil(this.filteredPointDetails.length / this.pageSize);

    this.currentPage = 1;

    this.updatePagedData();
  }

  handlePageClick(event) {
    const page = Number(event.target.dataset.page);

    if (page === this.currentPage) return;

    this.currentPage = page;

    this.updatePagedData();
  }

  updatePagedData() {
    const startIndex = (this.currentPage - 1) * this.pageSize;

    const endIndex = startIndex + this.pageSize;

    this.pagedPointDetails = this.filteredPointDetails.slice(startIndex, endIndex);
  }
}