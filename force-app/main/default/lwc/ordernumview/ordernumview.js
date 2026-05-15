import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";

import getOrderNumView from "@salesforce/apex/OrderNumViewController.getOrderNumView";
import ORDER_OBJECT from "@salesforce/schema/Order";
import ORDER_STATUS_FIELD from "@salesforce/schema/Order.OrderStatus__c";

export default class Ordernumview extends NavigationMixin(LightningElement) {
  @api recordId;

  order;
  error;
  completed;
  wiredOrderResult;
  isSaleItemsModalOpen = false;
  isSaleRecordsModalOpen = false;
  isOrderRecordsModalOpen = false;
  isOrderItemsModalOpen = false;
  isReturnItemsModalOpen = false;
  currentSaleItemsPage = 1;
  currentOrderItemsPage = 1;
  currentReturnItemsPage = 1;
  saleItemsPerPage = 10;
  saleItemsPageButtonCount = 5;

  emptyText = "정보 없음";
  orderEmptyText = "주문 없음";
  saleEmptyText = "판매 없음";
  returnEmptyText = "반품 없음";

  @wire(getObjectInfo, { objectApiName: ORDER_OBJECT })
  orderObjectInfo;

  @wire(getPicklistValues, { recordTypeId: "$orderRecordTypeId", fieldApiName: ORDER_STATUS_FIELD })
  orderStatusPicklistValuesResult;

  @wire(getOrderNumView, { orderId: "$recordId" })
  wiredOrder(result) {
    this.wiredOrderResult = result;
    const { data, error } = result;

    if (data) {
      this.order = data;
      this.error = undefined;
      return;
    }

    if (error) {
      this.error = error;
      this.order = undefined;

      console.error("getOrderNumView error", error);
    }
  }

  @api
  refreshData() {
    refreshApex(this.wiredOrderResult);
  }

  get orderRecordTypeId() {
    return this.orderObjectInfo?.data?.defaultRecordTypeId;
  }

  get orderStatusPicklistValues() {
    return this.orderStatusPicklistValuesResult?.data?.values ?? [];
  }

  get hasOrderData() {
    return Boolean(this.order?.orderNo);
  }

  get hasSaleData() {
    return Boolean(this.order?.saleNo);
  }

  get hasReturnData() {
    return Boolean(this.order?.returnNo);
  }

  get showSaleDetailData() {
    return this.order?.saleDetailAvailable === true;
  }

  get isOrderStarted() {
    return this.hasOrderData;
  }

  get isSaleStarted() {
    return this.hasSaleData;
  }

  get isReturnStarted() {
    return this.hasReturnData;
  }

  get orderProgressLabel() {
    const state = this.getOrderProgressState(this.order?.orderStatus, this.hasOrderData);
    if (state === "completed") return "인도완료";
    if (state === "cancelled") return "주문 취소";
    if (state === "in_progress") return "진행중";
    return "미진행";
  }

  get showOrderProgressBadge() {
    return this.getOrderProgressState(this.order?.orderStatus, this.hasOrderData) !== "not_started";
  }

  get saleProgressLabel() {
    const state = this.order?.saleProgressState || this.getStageProgressState(this.order?.saleStatus, this.hasSaleData);
    if (state === "completed") {
      const saleItemCount = this.order?.saleItems?.length ?? 0;
      const returnItemCount = this.order?.returnItems?.length ?? 0;

      // 혼재(판매 품목 중 일부만 반품): 부분 판매
      if (saleItemCount > 0 && returnItemCount > 0 && returnItemCount < saleItemCount) {
        return "부분 판매";
      }

      // 전체 입금 취소 (반품 없을 때만): 삭제
      if (this.order?.saleHasDepositCancellation === true && !this.hasReturnData) return "삭제";

      // 전부 판매 / 전부 반품 정리됨: 판매 완료
      return "판매 완료";
    }
    if (state === "cancelled") return "판매 삭제";
    if (state === "in_progress") return "부분 판매";
    return "미진행";
  }

  get returnProgressLabel() {
    const state = this.order?.returnProgressState || this.getStageProgressState(this.order?.returnStatus, this.hasReturnData);
    if (state === "completed") return "반품 완료";
    if (state === "cancelled") return "반품 삭제";
    if (state === "in_progress") return "부분 반품";
    return "미진행";
  }

  get orderProgressClass() {
    return this.getProgressClassForState(this.getOrderProgressState(this.order?.orderStatus, this.hasOrderData));
  }

  get saleProgressClass() {
    const state = this.order?.saleProgressState || this.getStageProgressState(this.order?.saleStatus, this.hasSaleData);
    if (state === "completed" && this.order?.saleHasDepositCancellation === true && !this.hasReturnData) {
      return this.getProgressClassForState("cancelled");
    }
    if (state === "completed" && this.hasReturnData) {
      return this.getProgressClassForState("in_progress");
    }
    return this.getProgressClassForState(state);
  }

  get returnProgressClass() {
    return this.getProgressClassForState(this.order?.returnProgressState || this.getStageProgressState(this.order?.returnStatus, this.hasReturnData));
  }

  get orderNo() {
    return this.isOrderStarted ? (this.order?.orderNo ?? this.emptyText) : this.orderEmptyText;
  }

  get orderStatusLabel() {
    return this.isOrderStarted ? (this.order?.orderStatus ?? this.emptyText) : this.orderEmptyText;
  }

  get orderTypeLabel() {
    return this.isOrderStarted ? (this.order?.orderType ?? this.emptyText) : this.orderEmptyText;
  }

  get orderDateText() {
    return this.isOrderStarted ? (this.order?.orderDate ? this.formatDate(this.order.orderDate) : this.emptyText) : this.orderEmptyText;
  }

  get orderStoreName() {
    return this.isOrderStarted ? (this.order?.orderStoreName ?? this.emptyText) : this.orderEmptyText;
  }

  get orderQuantityText() {
    if (this.orderItems.length > 0) {
      return this.formatQuantity(this.orderItems.length);
    }

    return this.formatQuantity(this.order?.orderQuantity);
  }

  get totalAmountText() {
    return this.formatCurrency(this.order?.totalAmount);
  }

  get orderCashAmountText() {
    return this.formatCurrency(this.order?.orderCashAmount);
  }

  get orderCardAmountText() {
    return this.formatCurrency(this.order?.orderCardAmount);
  }

  get orderCouponAmountText() {
    return this.formatCurrency(this.order?.orderCouponAmount);
  }

  get orderPointAmountText() {
    return this.formatCurrency(this.order?.orderPointAmount);
  }

  get orderDeptVoucherAmountText() {
    return this.formatCurrency(this.order?.orderDeptVoucherAmount);
  }

  get orderHqVoucherAmountText() {
    return this.formatCurrency(this.order?.orderHqVoucherAmount);
  }

  get orderUpgradeAmountText() {
    return this.formatCurrency(this.order?.orderUpgradeAmount);
  }

  get orderProvisionalAmountText() {
    return this.formatCurrency(this.order?.orderProvisionalAmount);
  }

  get orderQuantitySummaryText() {
    return `총 ${this.orderQuantityText}개`;
  }

  get orderPaymentItems() {
    return [
      { key: "order-cash", label: "현금", value: this.orderCashAmountText },
      { key: "order-card", label: "카드", value: this.orderCardAmountText },
      { key: "order-coupon", label: "쿠폰", value: this.orderCouponAmountText },
      { key: "order-point", label: "포인트", value: this.orderPointAmountText },
      { key: "order-dept-voucher", label: "백화점 상품권", value: this.orderDeptVoucherAmountText },
      { key: "order-hq-voucher", label: "본사 교환권", value: this.orderHqVoucherAmountText },
      { key: "order-upgrade", label: "업그레이드", value: this.orderUpgradeAmountText },
      { key: "order-provisional", label: "가주문", value: this.orderProvisionalAmountText }
    ];
  }

  get orderPaymentTotalText() {
    return this.formatCurrency(this.order?.orderDepositTotalAmount);
  }

  get orderRecords() {
    return this.order?.orderRecords ?? [];
  }

  get hasOrderRecordsButton() {
    return this.orderRecords.length > 0;
  }

  get orderRecordsButtonLabel() {
    return `모두 보기(${this.orderRecords.length}건)`;
  }

  get orderRecordRows() {
    return this.orderRecords.map((record, index) => {
      const navigable = Boolean(record.orderRecordId && record.orderNo);
      return {
        key: `order-record-${record.orderNo || index}`,
        orderNo: record.orderNo || this.emptyText,
        navigationOrderId: record.orderRecordId,
        navigable,
        notNavigable: !navigable,
        status: record.status || this.emptyText,
        orderDate: record.orderDate ? this.formatDate(record.orderDate) : this.emptyText,
        storeName: record.storeName || this.emptyText,
        amount: this.formatCurrency(record.amount)
      };
    });
  }

  get orderItems() {
    return this.order?.orderItems ?? [];
  }

  get hasOrderItems() {
    return this.orderItems.length > 0;
  }

  get visibleOrderItems() {
    return this.orderItems.slice(0, 2).map((item) => this.formatItem(item));
  }

  get showOrderItemsButton() {
    return this.orderItems.length > 0;
  }

  get orderItemsButtonLabel() {
    return `모두 보기(${this.orderItems.length}건)`;
  }

  get totalOrderItemsPages() {
    return Math.max(1, Math.ceil(this.orderItems.length / this.saleItemsPerPage));
  }

  get pagedOrderItems() {
    const startIndex = (this.currentOrderItemsPage - 1) * this.saleItemsPerPage;
    return this.orderItems.slice(startIndex, startIndex + this.saleItemsPerPage).map((item) => this.formatItem(item));
  }

  get orderItemsPageGroupStart() {
    return Math.floor((this.currentOrderItemsPage - 1) / this.saleItemsPageButtonCount) * this.saleItemsPageButtonCount + 1;
  }

  get orderItemsPageGroupEnd() {
    return Math.min(this.orderItemsPageGroupStart + this.saleItemsPageButtonCount - 1, this.totalOrderItemsPages);
  }

  get orderItemsPageNumbers() {
    const pages = [];

    for (let pageNumber = this.orderItemsPageGroupStart; pageNumber <= this.orderItemsPageGroupEnd; pageNumber += 1) {
      pages.push({
        key: `order-page-${pageNumber}`,
        number: pageNumber,
        className: pageNumber === this.currentOrderItemsPage ? "page-number-btn page-number-btn--active" : "page-number-btn"
      });
    }

    return pages;
  }

  get disablePreviousOrderItemsPageGroup() {
    return this.orderItemsPageGroupStart <= 1;
  }

  get disableNextOrderItemsPageGroup() {
    return this.orderItemsPageGroupEnd >= this.totalOrderItemsPages;
  }

  get saleStoreName() {
    return this.showSaleDetailData ? (this.order?.saleStoreName ?? this.emptyText) : this.saleEmptyText;
  }

  get saleNo() {
    return this.showSaleDetailData ? (this.order?.saleNo ?? this.emptyText) : this.saleEmptyText;
  }

  get saleStatusLabel() {
    return this.showSaleDetailData ? (this.order?.saleStatus ?? this.emptyText) : this.saleEmptyText;
  }

  get saleDateText() {
    return this.showSaleDetailData ? (this.order?.saleDate ? this.formatDate(this.order.saleDate) : this.emptyText) : this.saleEmptyText;
  }

  get saleQuantityText() {
    const explicitSaleQuantity = Number(this.showSaleDetailData ? this.order?.saleQuantity : 0);
    if (Number.isFinite(explicitSaleQuantity) && explicitSaleQuantity > 0) {
      return this.formatQuantity(explicitSaleQuantity);
    }

    return this.formatQuantity(this.saleItems);
  }

  get saleItems() {
    return this.showSaleDetailData ? (this.order?.saleItems ?? []) : [];
  }

  get saleRecords() {
    return this.order?.saleRecords ?? [];
  }

  get hasSaleRecordsButton() {
    return this.saleRecords.length > 0;
  }

  get saleRecordsButtonLabel() {
    return `모두 보기(${this.saleRecords.length}건)`;
  }

  get saleRecordRows() {
    return this.saleRecords.map((record, index) => {
      const navigable = Boolean(record.saleOrderId && record.saleNo);
      return {
        key: `sale-record-${record.saleNo || index}`,
        saleNo: record.saleNo || this.emptyText,
        navigationOrderId: record.saleOrderId,
        navigable,
        notNavigable: !navigable,
        status: record.status || this.emptyText,
        saleDate: record.saleDate ? this.formatDate(record.saleDate) : this.emptyText,
        storeName: record.storeName || this.emptyText,
        amount: this.formatCurrency(record.amount)
      };
    });
  }

  get hasSaleItems() {
    return this.saleItems.length > 0;
  }

  get showSaleItemsEmptyState() {
    return !this.hasSaleItems;
  }

  get visibleSaleItems() {
    return this.saleItems.slice(0, 2).map((item) => this.formatItem(item));
  }

  get totalSaleItemsPages() {
    return Math.max(1, Math.ceil(this.saleItems.length / this.saleItemsPerPage));
  }

  get pagedSaleItems() {
    const startIndex = (this.currentSaleItemsPage - 1) * this.saleItemsPerPage;
    return this.saleItems.slice(startIndex, startIndex + this.saleItemsPerPage).map((item) => this.formatItem(item));
  }

  get saleItemsPageGroupStart() {
    return Math.floor((this.currentSaleItemsPage - 1) / this.saleItemsPageButtonCount) * this.saleItemsPageButtonCount + 1;
  }

  get saleItemsPageGroupEnd() {
    return Math.min(this.saleItemsPageGroupStart + this.saleItemsPageButtonCount - 1, this.totalSaleItemsPages);
  }

  get saleItemsPageNumbers() {
    const pages = [];

    for (let pageNumber = this.saleItemsPageGroupStart; pageNumber <= this.saleItemsPageGroupEnd; pageNumber += 1) {
      pages.push({
        key: `sale-page-${pageNumber}`,
        number: pageNumber,
        className: pageNumber === this.currentSaleItemsPage ? "page-number-btn page-number-btn--active" : "page-number-btn"
      });
    }

    return pages;
  }

  get hasPreviousSaleItemsPageGroup() {
    return this.saleItemsPageGroupStart > 1;
  }

  get hasNextSaleItemsPageGroup() {
    return this.saleItemsPageGroupEnd < this.totalSaleItemsPages;
  }

  get disablePreviousSaleItemsPageGroup() {
    return !this.hasPreviousSaleItemsPageGroup;
  }

  get disableNextSaleItemsPageGroup() {
    return !this.hasNextSaleItemsPageGroup;
  }

  get showSaleItemsButton() {
    return this.saleItems.length > 0;
  }

  get saleItemsButtonLabel() {
    return `모두 보기(${this.saleItems.length}건)`;
  }

  get saleAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleTotalAmount : 0);
  }

  get salePaymentTotalText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleDepositTotalAmount : 0);
  }

  get saleCashAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleCashAmount : 0);
  }

  get saleCardAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleCardAmount : 0);
  }

  get saleCouponAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleCouponAmount : 0);
  }

  get salePointAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.salePointAmount : 0);
  }

  get saleDeptVoucherAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleDeptVoucherAmount : 0);
  }

  get saleHqVoucherAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleHqVoucherAmount : 0);
  }

  get saleUpgradeAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleUpgradeAmount : 0);
  }

  get saleProvisionalAmountText() {
    return this.formatCurrency(this.showSaleDetailData ? this.order?.saleProvisionalAmount : 0);
  }

  get saleQuantitySummaryText() {
    return `총 ${this.saleQuantityText}개`;
  }

  get salePaymentItems() {
    return [
      { key: "cash", label: "현금", value: this.saleCashAmountText },
      { key: "card", label: "카드", value: this.saleCardAmountText },
      { key: "coupon", label: "쿠폰", value: this.saleCouponAmountText },
      { key: "point", label: "포인트", value: this.salePointAmountText },
      { key: "dept-voucher", label: "백화점 상품권", value: this.saleDeptVoucherAmountText },
      { key: "hq-voucher", label: "본사 교환권", value: this.saleHqVoucherAmountText },
      { key: "upgrade", label: "업그레이드", value: this.saleUpgradeAmountText },
      { key: "provisional", label: "가주문", value: this.saleProvisionalAmountText }
    ];
  }

  get salePointItems() {
    return this.buildPointItems(this.showSaleDetailData ? this.order?.earnedPointItems : [], "point");
  }

  get hasSalePointItems() {
    return this.salePointItems.length > 0;
  }

  get returnPaymentItems() {
    return [
      { key: "refund-cash", label: "현금", value: this.refundCashAmountText },
      { key: "refund-card", label: "카드", value: this.refundCardAmountText },
      { key: "refund-coupon", label: "쿠폰", value: this.refundCouponAmountText },
      { key: "refund-point", label: "포인트", value: this.refundPointAmountText },
      { key: "refund-dept-voucher", label: "백화점 상품권", value: this.refundDeptVoucherAmountText },
      { key: "refund-hq-voucher", label: "본사 교환권", value: this.refundHqVoucherAmountText },
      { key: "refund-upgrade", label: "업그레이드", value: this.refundUpgradeAmountText },
      { key: "refund-provisional", label: "가주문", value: this.refundProvisionalAmountText }
    ];
  }

  get returnStoreName() {
    return this.isReturnStarted ? (this.order?.returnStoreName ?? this.emptyText) : this.returnEmptyText;
  }

  get returnNo() {
    return this.isReturnStarted ? (this.order?.returnNo ?? this.returnEmptyText) : this.returnEmptyText;
  }

  get returnStatusLabel() {
    return this.isReturnStarted ? (this.order?.returnStatus ?? this.returnEmptyText) : this.returnEmptyText;
  }

  get returnDateText() {
    return this.isReturnStarted ? (this.order?.returnDate ? this.formatDate(this.order.returnDate) : this.emptyText) : this.returnEmptyText;
  }

  get returnQuantityText() {
    return this.formatQuantity(this.isReturnStarted ? this.order?.returnQuantity : 0);
  }

  get returnAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.returnTotalAmount : 0);
  }

  get refundAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.returnTotalAmount : 0);
  }

  get refundCashAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundCashAmount : 0);
  }

  get refundCardAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundCardAmount : 0);
  }

  get refundCouponAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundCouponAmount : 0);
  }

  get refundPointAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundPointAmount : 0);
  }

  get refundDeptVoucherAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundDeptVoucherAmount : 0);
  }

  get refundHqVoucherAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundHqVoucherAmount : 0);
  }

  get refundUpgradeAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundUpgradeAmount : 0);
  }

  get refundProvisionalAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundProvisionalAmount : 0);
  }

  get restoredPointItems() {
    return this.buildPointItems(this.isReturnStarted ? this.order?.restoredPointItems : [], "restored-point");
  }

  get returnItems() {
    return this.isReturnStarted ? (this.order?.returnItems ?? []) : [];
  }

  get hasReturnItems() {
    return this.returnItems.length > 0;
  }

  get visibleReturnItems() {
    return this.returnItems.slice(0, 2).map((item) => this.formatItem(item));
  }

  get showReturnItemsButton() {
    return this.returnItems.length > 0;
  }

  get returnItemsButtonLabel() {
    return `모두 보기(${this.returnItems.length}건)`;
  }

  get totalReturnItemsPages() {
    return Math.max(1, Math.ceil(this.returnItems.length / this.saleItemsPerPage));
  }

  get pagedReturnItems() {
    const startIndex = (this.currentReturnItemsPage - 1) * this.saleItemsPerPage;
    return this.returnItems.slice(startIndex, startIndex + this.saleItemsPerPage).map((item) => this.formatItem(item));
  }

  get returnItemsPageGroupStart() {
    return Math.floor((this.currentReturnItemsPage - 1) / this.saleItemsPageButtonCount) * this.saleItemsPageButtonCount + 1;
  }

  get returnItemsPageGroupEnd() {
    return Math.min(this.returnItemsPageGroupStart + this.saleItemsPageButtonCount - 1, this.totalReturnItemsPages);
  }

  get returnItemsPageNumbers() {
    const pages = [];

    for (let pageNumber = this.returnItemsPageGroupStart; pageNumber <= this.returnItemsPageGroupEnd; pageNumber += 1) {
      pages.push({
        key: `return-page-${pageNumber}`,
        number: pageNumber,
        className: pageNumber === this.currentReturnItemsPage ? "page-number-btn page-number-btn--active" : "page-number-btn"
      });
    }

    return pages;
  }

  get disablePreviousReturnItemsPageGroup() {
    return this.returnItemsPageGroupStart <= 1;
  }

  get disableNextReturnItemsPageGroup() {
    return this.returnItemsPageGroupEnd >= this.totalReturnItemsPages;
  }

  get returnPaymentTotalText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.returnDepositTotalAmount : 0);
  }

  get pointTypeOptions() {
    return this.order?.pointTypeOptions ?? [];
  }

  get customerName() {
    return this.order?.customerName ?? this.emptyText;
  }

  get customerMemberNo() {
    return this.order?.customerMemberNo ?? this.emptyText;
  }

  get customerPhone() {
    return this.formatPhone(this.order?.customerPhone);
  }

  get customerGrade() {
    return this.order?.customerGrade ?? this.emptyText;
  }

  get managedStoreName() {
    return this.order?.managedStoreName ?? this.emptyText;
  }

  handleOpenSaleItemsModal() {
    this.currentSaleItemsPage = 1;
    this.isSaleItemsModalOpen = true;
  }

  handleOpenOrderItemsModal() {
    this.currentOrderItemsPage = 1;
    this.isOrderItemsModalOpen = true;
  }

  handleOpenOrderRecordsModal() {
    this.isOrderRecordsModalOpen = true;
  }

  handleCloseOrderRecordsModal() {
    this.isOrderRecordsModalOpen = false;
  }

  handleCloseOrderItemsModal() {
    this.isOrderItemsModalOpen = false;
    this.currentOrderItemsPage = 1;
  }

  handleCloseSaleItemsModal() {
    this.isSaleItemsModalOpen = false;
    this.currentSaleItemsPage = 1;
  }

  handleOpenReturnItemsModal() {
    this.currentReturnItemsPage = 1;
    this.isReturnItemsModalOpen = true;
  }

  handleCloseReturnItemsModal() {
    this.isReturnItemsModalOpen = false;
    this.currentReturnItemsPage = 1;
  }

  handleOpenSaleRecordsModal() {
    this.isSaleRecordsModalOpen = true;
  }

  handleCloseSaleRecordsModal() {
    this.isSaleRecordsModalOpen = false;
  }

  handleSaleItemsPageClick(event) {
    const pageNumber = Number(event.currentTarget.dataset.page);

    if (!Number.isFinite(pageNumber)) {
      return;
    }

    this.currentSaleItemsPage = pageNumber;
  }

  handleOrderItemsPageClick(event) {
    const pageNumber = Number(event.currentTarget.dataset.page);

    if (!Number.isFinite(pageNumber)) {
      return;
    }

    this.currentOrderItemsPage = pageNumber;
  }

  handleReturnItemsPageClick(event) {
    const pageNumber = Number(event.currentTarget.dataset.page);

    if (!Number.isFinite(pageNumber)) {
      return;
    }

    this.currentReturnItemsPage = pageNumber;
  }

  handlePreviousSaleItemsPageGroup() {
    this.currentSaleItemsPage = Math.max(1, this.saleItemsPageGroupStart - this.saleItemsPageButtonCount);
  }

  handleNextSaleItemsPageGroup() {
    this.currentSaleItemsPage = Math.min(this.totalSaleItemsPages, this.saleItemsPageGroupStart + this.saleItemsPageButtonCount);
  }

  handlePreviousOrderItemsPageGroup() {
    this.currentOrderItemsPage = Math.max(1, this.orderItemsPageGroupStart - this.saleItemsPageButtonCount);
  }

  handleNextOrderItemsPageGroup() {
    this.currentOrderItemsPage = Math.min(this.totalOrderItemsPages, this.orderItemsPageGroupStart + this.saleItemsPageButtonCount);
  }

  handlePreviousReturnItemsPageGroup() {
    this.currentReturnItemsPage = Math.max(1, this.returnItemsPageGroupStart - this.saleItemsPageButtonCount);
  }

  handleNextReturnItemsPageGroup() {
    this.currentReturnItemsPage = Math.min(this.totalReturnItemsPages, this.returnItemsPageGroupStart + this.saleItemsPageButtonCount);
  }

  handleCustomerDetail() {
    const loyaltyProgramMemberId = this.order?.loyaltyProgramMemberId;
    if (!loyaltyProgramMemberId) {
      return;
    }

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: loyaltyProgramMemberId,
        objectApiName: "LoyaltyProgramMember",
        actionName: "view"
      }
    });
  }

  get hasOrderNoLink() {
    return this.isOrderStarted && Boolean(this.order?.orderRecordId);
  }

  get hasSaleNoLink() {
    return this.showSaleDetailData && Boolean(this.order?.saleOrderId);
  }

  get hasReturnNoLink() {
    return this.isReturnStarted && Boolean(this.order?.returnOrderId);
  }

  handleNavigateOrder() {
    this.navigateToOrder(this.order?.orderRecordId);
  }

  handleNavigateSale() {
    this.navigateToOrder(this.order?.saleOrderId);
  }

  handleNavigateReturn() {
    this.navigateToOrder(this.order?.returnOrderId);
  }

  navigateToOrder(orderId) {
    if (!orderId) {
      return;
    }

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: orderId,
        objectApiName: "Order",
        actionName: "view"
      }
    });
  }

  handleNavigateRowOrder(event) {
    this.navigateToOrder(event.currentTarget.dataset.orderId);
  }

  buildPointItems(sourceItems, prefix) {
    const pointAmountByType = new Map();
    const pointLabelByType = new Map();
    const typeByLabel = new Map();
    const preferredLabels = ["구매포인트", "사은포인트", "에코포인트", "이벤트포인트", "기타포인트"];

    this.pointTypeOptions.forEach((option) => {
      const type = option?.type;
      const label = option?.label || option?.type;

      if (!type || !label) {
        return;
      }

      pointLabelByType.set(type, label);
      typeByLabel.set(label, type);
    });

    if (Array.isArray(sourceItems)) {
      sourceItems.forEach((item) => {
        const type = item?.type || item?.label;
        const label = item?.label || item?.type;

        if (!type) {
          return;
        }

        pointLabelByType.set(type, label || type);
        pointAmountByType.set(type, Number(item?.amount) || 0);
        if (label) {
          typeByLabel.set(label, type);
        }
      });
    }

    return preferredLabels.map((label, index) => {
      const type = typeByLabel.get(label) || label;
      const amount = pointAmountByType.has(type) ? pointAmountByType.get(type) : 0;
      const resolvedLabel = pointLabelByType.get(type) || label;

      return {
        key: `${prefix}-${type}-${index}`,
        label: resolvedLabel,
        value: `${this.formatNumber(amount)}P`
      };
    });
  }

  formatItem(item) {
    const orderNoBlank = !item?.orderNo;
    const saleNoBlank = !item?.saleNo;
    const targetOrderId = item?.orderId || null;
    return {
      ...item,
      quantityText: `${this.formatQuantity(item?.quantity)}개`,
      amountText: this.formatCurrency(item?.amount),
      summaryText: `${this.formatQuantity(item?.quantity)}개`,
      orderNoText: orderNoBlank ? "-" : item.orderNo,
      saleNoText: saleNoBlank ? "-" : item.saleNo,
      orderNoClass: orderNoBlank ? "col-no-empty" : "",
      saleNoClass: saleNoBlank ? "col-no-empty" : "",
      orderNoNavigable: !orderNoBlank && Boolean(targetOrderId),
      saleNoNavigable: !saleNoBlank && Boolean(targetOrderId),
      navigationOrderId: targetOrderId
    };
  }

  getProgressLabel(statusLabel, hasData) {
    return this.getProgressLabelForState(this.getStageProgressState(statusLabel, hasData));
  }

  getProgressLabelForState(progressState) {
    if (progressState === "completed") {
      return "진행 완료";
    }

    if (progressState === "cancelled") {
      return "진행 취소";
    }

    if (progressState === "in_progress") {
      return "진행중";
    }

    return "미진행";
  }

  getProgressClass(statusLabel, hasData) {
    return this.getProgressClassForState(this.getStageProgressState(statusLabel, hasData));
  }

  getProgressClassForState(progressState) {
    if (progressState === "completed") {
      return "progress-badge progress-badge--completed";
    }

    if (progressState === "cancelled") {
      return "progress-badge progress-badge--cancelled";
    }

    if (progressState === "in_progress") {
      return "progress-badge progress-badge--in-progress";
    }

    return "progress-badge progress-badge--not-started";
  }

  getOrderProgressState(statusLabel, hasData) {
    if (this.isConfiguredOrderStatus(statusLabel)) {
      const stageProgressState = this.getStageProgressState(statusLabel, hasData);
      if (stageProgressState === "cancelled") {
        return "cancelled";
      }

      if (this.isOrderCompletionStatus(statusLabel)) {
        return "completed";
      }

      if (!this.orderCompletionStatusEntry && stageProgressState === "completed") {
        return "completed";
      }

      return hasData ? "in_progress" : "not_started";
    }

    return this.getStageProgressState(statusLabel, hasData);
  }

  isConfiguredOrderStatus(statusLabel) {
    const normalizedStatus = this.normalizeStatusText(statusLabel);
    if (!normalizedStatus) {
      return false;
    }

    return this.orderStatusPicklistValues.some((entry) => {
      return this.normalizeStatusText(entry?.label) === normalizedStatus || this.normalizeStatusText(entry?.value) === normalizedStatus;
    });
  }

  get orderCompletionStatusEntry() {
    let lastPlannedStatusIndex = -1;

    this.orderStatusPicklistValues.forEach((entry, index) => {
      if (this.isPlannedOrderStatusEntry(entry)) {
        lastPlannedStatusIndex = index;
      }
    });

    if (lastPlannedStatusIndex < 0) {
      return null;
    }

    return this.orderStatusPicklistValues.slice(lastPlannedStatusIndex + 1).find((entry) => this.isCompletionLikeOrderStatusEntry(entry)) ?? null;
  }

  isOrderCompletionStatus(statusLabel) {
    const matchedEntry = this.getMatchingOrderStatusEntry(statusLabel);
    if (!matchedEntry || !this.orderCompletionStatusEntry) {
      return false;
    }

    return this.isSameOrderStatusEntry(matchedEntry, this.orderCompletionStatusEntry);
  }

  getMatchingOrderStatusEntry(statusLabel) {
    const normalizedStatus = this.normalizeStatusText(statusLabel);
    if (!normalizedStatus) {
      return null;
    }

    return (
      this.orderStatusPicklistValues.find((entry) => {
        return this.normalizeStatusText(entry?.label) === normalizedStatus || this.normalizeStatusText(entry?.value) === normalizedStatus;
      }) ?? null
    );
  }

  isSameOrderStatusEntry(leftEntry, rightEntry) {
    return (
      this.normalizeStatusText(leftEntry?.label) === this.normalizeStatusText(rightEntry?.label) ||
      this.normalizeStatusText(leftEntry?.value) === this.normalizeStatusText(rightEntry?.value)
    );
  }

  isPlannedOrderStatusEntry(entry) {
    const normalizedLabel = this.normalizeStatusText(entry?.label);
    const normalizedValue = this.normalizeStatusText(entry?.value);

    return normalizedLabel.includes("예정") || normalizedValue.includes("예정") || normalizedLabel.includes("planned");
  }

  isCompletionLikeOrderStatusEntry(entry) {
    const normalizedLabel = this.normalizeStatusText(entry?.label);
    const normalizedValue = this.normalizeStatusText(entry?.value);

    return (
      normalizedLabel.includes("완료") ||
      normalizedLabel.includes("complete") ||
      normalizedValue.includes("완료") ||
      normalizedValue.includes("complete")
    );
  }

  getStageProgressState(statusLabel, hasData) {
    const normalizedStatus = (statusLabel || "").trim();
    const normalizedStatusLower = this.normalizeStatusText(statusLabel);

    if (!normalizedStatus) {
      return hasData ? "completed" : "not_started";
    }

    if (
      (normalizedStatus.includes("판매 완료") || normalizedStatusLower.includes("sale complete")) &&
      (normalizedStatus.includes("승인중") || normalizedStatusLower.includes("approving") || normalizedStatusLower.includes("pending approval"))
    ) {
      return "in_progress";
    }

    if (
      normalizedStatus.includes("취소") ||
      normalizedStatus.includes("삭제") ||
      normalizedStatus.includes("중단") ||
      normalizedStatusLower.includes("cancel") ||
      normalizedStatusLower.includes("delete")
    ) {
      return "cancelled";
    }

    if (
      normalizedStatus.includes("완료") ||
      normalizedStatus.includes("결제") ||
      normalizedStatus.includes("성공") ||
      normalizedStatus.includes("생성")
    ) {
      return "completed";
    }

    return "in_progress";
  }

  normalizeStatusText(value) {
    return (value || "").trim().toLowerCase();
  }

  formatCurrency(value) {
    return `${this.formatNumber(value)}원`;
  }

  formatQuantity(value) {
    if (Array.isArray(value)) {
      return this.formatNumber(this.sumItemQuantities(value));
    }
    return this.formatNumber(value);
  }

  sumItemQuantities(items) {
    if (!Array.isArray(items) || items.length === 0) {
      return 0;
    }

    return items.reduce((total, item) => total + (Number(item?.quantity) || 0), 0);
  }

  formatNumber(value) {
    const numberValue = Number(value);
    return Number.isFinite(numberValue) ? numberValue.toLocaleString("ko-KR") : "0";
  }

  formatDate(value) {
    if (!value) {
      return this.emptyText;
    }

    const dateValue = new Date(value);
    return `${dateValue.getFullYear()}.${String(dateValue.getMonth() + 1).padStart(2, "0")}.${String(dateValue.getDate()).padStart(2, "0")}`;
  }

  formatPhone(phone) {
    if (!phone) {
      return this.emptyText;
    }

    const digits = phone.replace(/\D/g, "");
    if (digits.length === 11) {
      return digits.replace(/(\d{3})(\d{4})(\d{4})/, "$1-$2-$3");
    }

    return phone;
  }
}