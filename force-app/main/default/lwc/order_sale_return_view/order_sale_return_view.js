import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createOrder from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.createOrder";
import createMember from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.createMember";
import updateOrder from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.updateOrder";
import createSale from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.createSale";
import updateSale from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.updateSale";
import createReturn from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.createReturn";
import deleteSaleDeposit from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.deleteSaleDeposit";
import deleteSale from "@salesforce/apex/Order_Sale_Return_View_ControllerV1.deleteSale";

// 지정값 — 사전 지정 고정값
const FIXED_ACCOUNT_ID = "GOLDENDEW";
const FIXED_INSERT_ID = "";
const FIXED_DISCOUNT_RATE = 0.0;
const FIXED_TJ_ORDER_NO = null; // TransactionJournal.OrderNo__c 는 null 고정

// 입력 필드 기본값 (사용자가 변경 가능)
const DEFAULT_STORE_CODE = "99998";
const DEFAULT_PRODUCT_CODE = "TEST-001";
const DEFAULT_NET_PRICE = 2000000.0;

// 매장 코드 선택 목록 (label = 매장 Name / value = StoreCode__c)
const STORE_CODE_OPTIONS = [
  { label: "예술의전당점", value: "20001" },
  { label: "밀버스_매장_테스트_백화점", value: "99998" },
  { label: "밀버스_매장_테스트_백화점2", value: "99995" },
  { label: "밀버스_매장_테스트_면세점", value: "99996" },
  { label: "밀버스_매장_테스트_아울렛", value: "99997" }
];

// 주문 상태 코드 선택 목록 (label = 한글 / value = API 코드)
const ORDER_STATUS_OPTIONS = [
  { label: "접수", value: "01" },
  { label: "진열승인", value: "011" },
  { label: "제작의뢰", value: "02" },
  { label: "제작완료", value: "03" },
  { label: "본사납품", value: "04" },
  { label: "출고예정", value: "05" },
  { label: "본사출고", value: "06" },
  { label: "인도예정", value: "07" },
  { label: "인도완료", value: "08" },
  { label: "주문취소", value: "09" },
  { label: "가주문완료", value: "99" },
  { label: "종결", value: "991" }
];

// 주문 구분 코드 선택 목록 (Order.Type 필드)
const ORDER_TYPE_OPTIONS = [
  { label: "고객", value: "01" },
  { label: "진열", value: "02" },
  { label: "수선", value: "03" },
  { label: "가주문", value: "04" },
  { label: "B2B", value: "10" }
];

// 판매 구분 코드 선택 목록 (SaleStatus__c)
const SALE_STATUS_OPTIONS = [
  { label: "정상판매", value: "01" },
  { label: "반품", value: "03" }
];

// 결제 수단 선택 목록 (PaymentMethod)
const PAYMENT_METHOD_OPTIONS = [
  { label: "현금", value: "01" },
  { label: "카드", value: "02" },
  { label: "본사 교환권", value: "06" },
  { label: "포인트", value: "81" },
  { label: "쿠폰", value: "90" }
];

// 입금 구분 선택 목록 (DepositType__c)
const DEPOSIT_TYPE_OPTIONS = [
  { label: "주문 입금", value: "01" },
  { label: "판매 입금", value: "02" },
  { label: "입금 취소", value: "03" }
];

// =============== 번호 자동 생성 헬퍼 (LWC 단독 / localStorage) ===============
function todayYmd() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}${m}${day}`;
}

function nextCounter(prefix) {
  const ymd = todayYmd();
  const key = `gd-counter-${prefix}-${ymd}`;
  let next = 1;
  try {
    next = (Number(localStorage.getItem(key)) || 0) + 1;
    localStorage.setItem(key, String(next));
  } catch (e) {
    next = Math.floor(Math.random() * 999) + 1;
  }
  return `${prefix}${ymd}${String(next).padStart(3, "0")}`;
}

// 입금 번호 fallback 생성기 — 사용자가 prefix 버튼을 누르지 않고 등록 시 빈 값 방지용
function nextDepositNo() {
  return nextCounter("DEP");
}

// 초기 입금 행 — DepositNo 는 사용자가 prefix 버튼(DEP01~04) 으로 직접 입력
function initialJournals() {
  return [newJournal(1)];
}

function initialSaleJournals() {
  return [newSaleJournal(1)];
}

function initialReturnJournals() {
  return [newReturnJournal(1)];
}

function formatNumber(n) {
  const v = Number(n);
  if (Number.isNaN(v)) return String(n);
  return v.toLocaleString();
}

function newItem(idx) {
  return {
    _key: `item-${Date.now()}-${idx}`,
    _idxLabel: idx,
    OrderSeqNo__c: String(idx),
    Status__c: "01",
    ProductCode: DEFAULT_PRODUCT_CODE,
    Quantity: 1,
    isExclude: false,
    NetSalesUnitPrice__c: DEFAULT_NET_PRICE,
    DiscountRate__c: FIXED_DISCOUNT_RATE,
    discountLabel: String(FIXED_DISCOUNT_RATE)
  };
}

function newJournal(idx) {
  return {
    _key: `tj-${Date.now()}-${idx}`,
    _idxLabel: idx,
    DepositNo__c: "",
    DeposiSeqNo__c: String(idx),
    ActivityDate: "",
    PaymentMethod: "01",
    DepositType__c: "01",
    TransactionAmount: 0,
    CouponNo: ""
  };
}

function newModifyJournal(idx) {
  return {
    _key: `mtj-${Date.now()}-${idx}`,
    _idxLabel: idx,
    DepositNo__c: "",
    DeposiSeqNo__c: String(idx),
    ActivityDate: "",
    PaymentMethod: "01",
    DepositType__c: "01",
    TransactionAmount: 0,
    CouponNo: ""
  };
}

function newModifyItem(idx) {
  return {
    _key: `mitem-${Date.now()}-${idx}`,
    _idxLabel: idx,
    OrderSeqNo__c: String(idx),
    Status__c: "991",
    ProductCode: DEFAULT_PRODUCT_CODE,
    Quantity: 1,
    NetSalesUnitPrice__c: 0,
    DiscountRate__c: 0
  };
}

// 판매 등록용 OrderItem (SaleSeqNo__c 사용)
function newSaleItem(idx) {
  return {
    _key: `sitem-${Date.now()}-${idx}`,
    _idxLabel: idx,
    SaleSeqNo__c: String(idx),
    ProductCode: DEFAULT_PRODUCT_CODE,
    Quantity: 1,
    isExclude: false,
    NetSalesUnitPrice__c: DEFAULT_NET_PRICE,
    discountLabel: String(FIXED_DISCOUNT_RATE)
  };
}

// 판매 등록용 TransactionJournal (OrderNo__c 입력 가능)
function newSaleJournal(idx) {
  return {
    _key: `stj-${Date.now()}-${idx}`,
    _idxLabel: idx,
    DepositNo__c: "",
    DeposiSeqNo__c: String(idx),
    ActivityDate: "",
    PaymentMethod: "01",
    DepositType__c: "01",
    TransactionAmount: 0,
    CouponNo: "",
    OrderNo__c: ""
  };
}

// 판매 수정 모달용 항목
function newSaleModifyItem(idx) {
  return {
    _key: `smitem-${Date.now()}-${idx}`,
    _idxLabel: idx,
    SaleSeqNo__c: String(idx),
    ProductCode: DEFAULT_PRODUCT_CODE,
    Quantity: 1,
    NetSalesUnitPrice__c: 0
  };
}

function newSaleModifyJournal(idx) {
  return {
    _key: `smtj-${Date.now()}-${idx}`,
    _idxLabel: idx,
    DepositNo__c: "",
    DeposiSeqNo__c: String(idx),
    ActivityDate: "",
    PaymentMethod: "01",
    DepositType__c: "01",
    TransactionAmount: 0,
    CouponNo: "",
    OrderNo__c: ""
  };
}

// 반품 등록용 OrderItem (Quantity 음수 — 반품)
function newReturnItem(idx) {
  return {
    _key: `ritem-${Date.now()}-${idx}`,
    _idxLabel: idx,
    SaleSeqNo__c: String(idx),
    ProductCode: DEFAULT_PRODUCT_CODE,
    Quantity: -1,
    isExclude: false,
    NetSalesUnitPrice__c: 0,
    DiscountRate__c: 0
  };
}

// 반품 등록용 TransactionJournal (DepositType 03 = 입금 취소)
function newReturnJournal(idx) {
  return {
    _key: `rtj-${Date.now()}-${idx}`,
    _idxLabel: idx,
    DepositNo__c: "",
    DeposiSeqNo__c: String(idx),
    ActivityDate: "",
    PaymentMethod: "01",
    DepositType__c: "03",
    TransactionAmount: 0,
    CouponNo: ""
  };
}

export default class OrderSaleReturnView extends LightningElement {
  @track header = {
    AccountId: FIXED_ACCOUNT_ID,
    StoreCode__c: DEFAULT_STORE_CODE,
    MemberNo__c: "",
    OrderNo__c: "",
    ActualPaymentAmount__c: 0,
    OrderStatus__c: "01",
    Type: "01",
    PromotionNo__c: "",
    InsertId__c: FIXED_INSERT_ID
  };

  @track items = [newItem(1)];
  @track journals = initialJournals();

  @track isSubmitting = false;
  @track showPreview = false;
  @track result = null;

  // ========= 회원 등록 모달 상태 =========
  @track showMemberModal = false;
  @track isRegistering = false;
  @track memberResult = null;
  @track memberForm = {
    StoreRegi__c: "STORE-013",
    StoreMana__c: "STORE-013",
    MemberNo__c: "",
    Grade__c: "01",
    IsSMSAgreed__c: true
  };

  // ========= 주문 수정 모달 상태 =========
  @track showModifyModal = false;
  @track isModifying = false;
  @track modifyResult = null;
  @track showModifyPreview = false;
  @track includeModifyItems = false;
  @track modifyForm = {
    OrderNo__c: "",
    ActualPaymentAmount__c: 0,
    OrderStatus__c: "01"
  };
  @track modifyJournals = [newModifyJournal(1)];
  @track modifyItems = [newModifyItem(1)];

  // ========= 판매 등록 상태 =========
  @track saleHeader = {
    AccountId: FIXED_ACCOUNT_ID,
    StoreCode__c: DEFAULT_STORE_CODE,
    MemberNo__c: "",
    SaleNo__c: "",
    EndDate: "",
    ActualPaymentAmount__c: 0,
    SaleStatus__c: "01",
    PromotionNo__c: "",
    InsertId__c: "골든듀"
  };
  @track saleItems = [newSaleItem(1)];
  @track saleJournals = initialSaleJournals();
  @track isSaleSubmitting = false;
  @track showSalePreview = false;
  @track saleResult = null;

  // ========= 판매 수정 모달 상태 =========
  @track showSaleModifyModal = false;
  @track isSaleModifying = false;
  @track saleModifyResult = null;
  @track showSaleModifyPreview = false;
  @track includeSaleModifyItems = false;
  @track saleModifyForm = {
    SaleNo__c: "",
    ActualPaymentAmount__c: 0,
    SaleStatus__c: "01"
  };
  @track saleModifyJournals = [newSaleModifyJournal(1)];
  @track saleModifyItems = [newSaleModifyItem(1)];

  // ========= 반품 등록 상태 =========
  @track returnHeader = {
    SaleNo__c: "",
    OriginalOrderId: "",
    ActualPaymentAmount__c: 0,
    InsertId__c: "골든듀"
  };
  @track returnItems = [newReturnItem(1)];
  @track returnJournals = initialReturnJournals();
  @track isReturnSubmitting = false;
  @track showReturnPreview = false;
  @track returnResult = null;

  // ========= 계산 프로퍼티 =========
  get actualPaymentAmount() {
    return this.items.reduce((sum, it) => {
      const qty = Number(it.Quantity) || 0;
      const price = Number(it.NetSalesUnitPrice__c) || 0;
      const rate = Number(it.DiscountRate__c) || 0;
      return sum + qty * price * (1 - rate);
    }, 0);
  }

  get actualPaymentLabel() {
    return formatNumber(this.actualPaymentAmount) + " 원";
  }

  get itemsCount() {
    return this.items.length;
  }

  get journalsCount() {
    return this.journals.length;
  }

  get insertIdLabel() {
    return this.header.InsertId__c ? this.header.InsertId__c : "(빈값)";
  }

  // 주문 상태 코드 선택 목록 (lightning-combobox options)
  get orderStatusOptions() {
    return ORDER_STATUS_OPTIONS;
  }

  // 주문 구분 코드 (Order.Type)
  get orderTypeOptions() {
    return ORDER_TYPE_OPTIONS;
  }

  // 판매 구분 코드 (SaleStatus__c)
  get saleStatusOptions() {
    return SALE_STATUS_OPTIONS;
  }

  // 매장 코드 (StoreCode__c) — Name 으로 표시, code 로 인식
  get storeCodeOptions() {
    return STORE_CODE_OPTIONS;
  }

  // 결제 수단 (PaymentMethod)
  get paymentMethodOptions() {
    return PAYMENT_METHOD_OPTIONS;
  }

  // 입금 구분 (DepositType__c)
  get depositTypeOptions() {
    return DEPOSIT_TYPE_OPTIONS;
  }

  // 번호 placeholder — 등록 성공할 때마다 직전 입력값으로 갱신
  @track orderNoPlaceholder = "예: SOR02001 (prefix 버튼 클릭 후 뒤 3자리 입력)";
  @track saleNoPlaceholder = "예: SAL02001 (prefix 버튼 클릭 후 뒤 3자리 입력)";
  @track returnNoPlaceholder = "예: SAL02001 (prefix 버튼 클릭 후 뒤 3자리 입력)";
  @track orderDepNoPlaceholder = "예: DEP02001 (prefix 버튼 클릭 후 뒤 3자리 입력)";
  @track saleDepNoPlaceholder = "예: DEP02001 (prefix 버튼 클릭 후 뒤 3자리 입력)";
  @track returnDepNoPlaceholder = "예: DEP02001 (prefix 버튼 클릭 후 뒤 3자리 입력)";

  // ========= 컴포넌트 초기화 =========
  connectedCallback() {
    // 모든 번호(SOR/SAL/DEP)는 사용자가 prefix 버튼(01~04)으로 직접 선택 → 뒤 3자리 시퀀스 입력
    // 자동 채움 없음
  }

  // ========= 번호 prefix 핸들러 (4명 담당자별 SOR/SAL/DEP 01~04) =========
  // 주문 번호: SOR + prefix(2자리) 만 채우고 뒤 3자리는 사용자 입력
  handlePrefixOrderNo(event) {
    const prefix = event.currentTarget?.dataset?.prefix;
    if (!prefix) return;
    this.header = { ...this.header, OrderNo__c: `SOR${prefix}` };
  }

  // 판매 번호 prefix
  handlePrefixSaleNo(event) {
    const prefix = event.currentTarget?.dataset?.prefix;
    if (!prefix) return;
    this.saleHeader = { ...this.saleHeader, SaleNo__c: `SAL${prefix}` };
  }

  // 반품 번호 prefix (SAL prefix 공유)
  handlePrefixReturnNo(event) {
    const prefix = event.currentTarget?.dataset?.prefix;
    if (!prefix) return;
    this.returnHeader = { ...this.returnHeader, SaleNo__c: `SAL${prefix}` };
  }

  // 입금 번호 prefix — 같은 섹션 내 모든 입금 행 동일 DEP prefix 공유
  handlePrefixOrderDepositNo(event) {
    const prefix = event.currentTarget?.dataset?.prefix;
    if (!prefix) return;
    const dep = `DEP${prefix}`;
    this.journals = this.journals.map((j) => ({ ...j, DepositNo__c: dep }));
  }

  handlePrefixSaleDepositNo(event) {
    const prefix = event.currentTarget?.dataset?.prefix;
    if (!prefix) return;
    const dep = `DEP${prefix}`;
    this.saleJournals = this.saleJournals.map((j) => ({ ...j, DepositNo__c: dep }));
  }

  handlePrefixReturnDepositNo(event) {
    const prefix = event.currentTarget?.dataset?.prefix;
    if (!prefix) return;
    const dep = `DEP${prefix}`;
    this.returnJournals = this.returnJournals.map((j) => ({ ...j, DepositNo__c: dep }));
  }

  // 주문 헤더 — 주문 상세 합계로 판매금액 채움
  handleApplyOrderTotal() {
    this.header = { ...this.header, ActualPaymentAmount__c: this.actualPaymentAmount };
  }

  // 판매 헤더 — 판매 상세 합계로 판매금액 채움
  handleApplySaleTotal() {
    this.saleHeader = { ...this.saleHeader, ActualPaymentAmount__c: this.saleActualPaymentAmount };
  }

  get previewJson() {
    return JSON.stringify(this.buildPayload(), null, 2);
  }

  get resultClass() {
    if (!this.result) return "";
    return this.result.success ? "slds-box slds-theme_success slds-m-top_x-small" : "slds-box slds-theme_error slds-m-top_x-small";
  }

  get resultText() {
    if (!this.result) return "";
    const head = this.result.success ? "✅ 주문 등록 성공" : "❌ 주문 등록 실패";
    const code = this.result.code != null ? ` (code: ${this.result.code})` : "";
    const msg = this.result.message ? ` — ${this.result.message}` : "";
    const oid = this.result.orderId ? ` / orderId: ${this.result.orderId}` : "";
    return `${head}${code}${msg}${oid}`;
  }

  // ========= 헤더 핸들러 =========
  handleHeaderChange(event) {
    const field = event.target.dataset.field;
    if (!field) return;
    // lightning-combobox 는 event.detail.value, lightning-input 은 event.target.value
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.header = { ...this.header, [field]: val };
  }

  // ========= 주문 상세 핸들러 =========
  handleItemChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const isCheckbox = event.target.type === "checkbox";
    let val;
    if (isCheckbox) {
      val = event.target.checked;
    } else if (event.detail && event.detail.value !== undefined) {
      val = event.detail.value; // lightning-combobox
    } else {
      val = event.target.value; // lightning-input
    }
    const next = this.items.map((it, i) => (i === idx ? { ...it, [field]: val } : it));
    this.items = next;
  }

  addItem() {
    this.items = [...this.items, newItem(this.items.length + 1)];
    this.reindexItems();
  }

  removeItem(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.items.length <= 1) {
      this.showToast("알림", "최소 한 개의 주문 상세가 필요합니다.", "warning");
      return;
    }
    this.items = this.items.filter((_, i) => i !== idx);
    this.reindexItems();
  }

  reindexItems() {
    this.items = this.items.map((it, i) => ({
      ...it,
      _idxLabel: i + 1,
      OrderSeqNo__c: String(i + 1)
    }));
  }

  // ========= 입금 핸들러 =========
  handleJournalChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    const next = this.journals.map((j, i) => (i === idx ? { ...j, [field]: val } : j));
    this.journals = next;
  }

  addJournal() {
    // 같은 거래의 추가 입금 행 — 첫 행의 DepositNo 공유 (없으면 새로 생성)
    const depositNo = this.journals[0]?.DepositNo__c || nextDepositNo();
    const next = newJournal(this.journals.length + 1);
    next.DepositNo__c = depositNo;
    this.journals = [...this.journals, next];
    this.reindexJournals();
  }

  removeJournal(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.journals.length <= 1) {
      this.showToast("알림", "최소 한 개의 입금 행이 필요합니다.", "warning");
      return;
    }
    this.journals = this.journals.filter((_, i) => i !== idx);
    this.reindexJournals();
  }

  reindexJournals() {
    this.journals = this.journals.map((j, i) => ({
      ...j,
      _idxLabel: i + 1,
      DeposiSeqNo__c: String(i + 1)
    }));
  }

  togglePreview() {
    this.showPreview = !this.showPreview;
  }

  // ========= 제출 =========
  buildPayload() {
    return {
      AccountId: FIXED_ACCOUNT_ID,
      StoreCode__c: (this.header.StoreCode__c || "").trim(),
      MemberNo__c: (this.header.MemberNo__c || "").trim(),
      OrderNo__c: (this.header.OrderNo__c || "").trim(),
      ActualPaymentAmount__c: Number(this.header.ActualPaymentAmount__c) || 0,
      OrderStatus__c: this.header.OrderStatus__c || "",
      Type: this.header.Type || "",
      PromotionNo__c: this.header.PromotionNo__c || "",
      OrderItem: this.items.map((it) => ({
        OrderSeqNo__c: it.OrderSeqNo__c,
        Status__c: it.Status__c,
        ProductCode: (it.ProductCode || "").trim(),
        Quantity: Number(it.Quantity) || 0,
        isExclude: !!it.isExclude,
        NetSalesUnitPrice__c: Number(it.NetSalesUnitPrice__c) || 0,
        DiscountRate__c: FIXED_DISCOUNT_RATE
      })),
      TransactionJournal: this.journals.map((j) => ({
        DepositNo__c: j.DepositNo__c || "",
        DeposiSeqNo__c: j.DeposiSeqNo__c || "",
        ActivityDate: j.ActivityDate || "",
        PaymentMethod: j.PaymentMethod || "",
        DepositType__c: j.DepositType__c || "",
        TransactionAmount: Number(j.TransactionAmount) || 0,
        CouponNo: j.CouponNo || "",
        OrderNo__c: FIXED_TJ_ORDER_NO
      })),
      InsertId__c: FIXED_INSERT_ID
    };
  }

  validate() {
    if (!(this.header.MemberNo__c || "").trim()) return "회원 번호를 입력하세요.";
    if (!(this.header.OrderNo__c || "").trim()) return "주문 번호를 입력하세요.";
    if (!(this.header.StoreCode__c || "").trim()) return "매장 코드를 입력하세요.";
    if (!this.items.length) return "주문 상세를 한 개 이상 추가하세요.";
    if (!this.journals.length) return "입금 내역을 한 개 이상 추가하세요.";
    for (const it of this.items) {
      if (!it.OrderSeqNo__c) return "주문 일련 번호를 입력하세요.";
      if (!(it.ProductCode || "").trim()) return "상품 코드를 입력하세요.";
      if (!(Number(it.Quantity) > 0)) return "수량은 1 이상이어야 합니다.";
    }
    return null;
  }

  async handleSubmit() {
    const err = this.validate();
    if (err) {
      this.showToast("입력 확인", err, "warning");
      return;
    }
    this.isSubmitting = true;
    this.result = null;
    try {
      const payload = this.buildPayload();
      const res = await createOrder({ jsonBody: JSON.stringify(payload) });
      this.result = res;
      this.showToast(res?.success ? "등록 성공" : "등록 실패", res?.message || "", res?.success ? "success" : "error");
      // 등록 성공 시 직전 입력값을 placeholder 로 → 다음 입력 참고용 / 입력란 비우기
      if (res?.success) {
        const prevOrderNo = (this.header.OrderNo__c || "").trim();
        const prevDep = (this.journals[0]?.DepositNo__c || "").trim();
        if (prevOrderNo) this.orderNoPlaceholder = `직전 입력: ${prevOrderNo}`;
        if (prevDep) this.orderDepNoPlaceholder = `직전 입력: ${prevDep}`;
        this.header = { ...this.header, OrderNo__c: "" };
        this.journals = this.journals.map((j) => ({ ...j, DepositNo__c: "" }));
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "주문 등록 호출 중 오류가 발생했습니다.";
      this.result = { success: false, code: 500, message: msg };
      this.showToast("등록 실패", msg, "error");
    } finally {
      this.isSubmitting = false;
    }
  }

  // ========= 주문 수정 모달 =========
  get modifyJournalsCount() {
    return this.modifyJournals.length;
  }

  get modifyItemsCount() {
    return this.modifyItems.length;
  }

  get modifyResultClass() {
    if (!this.modifyResult) return "";
    return this.modifyResult.success ? "slds-box slds-theme_success slds-m-top_small" : "slds-box slds-theme_error slds-m-top_small";
  }

  get modifyResultText() {
    if (!this.modifyResult) return "";
    const head = this.modifyResult.success ? "✅ 주문 수정 성공" : "❌ 주문 수정 실패";
    const code = this.modifyResult.code != null ? ` (code: ${this.modifyResult.code})` : "";
    const msg = this.modifyResult.message ? ` — ${this.modifyResult.message}` : "";
    const oid = this.modifyResult.orderId ? ` / orderId: ${this.modifyResult.orderId}` : "";
    return `${head}${code}${msg}${oid}`;
  }

  get modifyPreviewJson() {
    return JSON.stringify(this.buildModifyPayload(), null, 2);
  }

  openModifyModal() {
    this.modifyResult = null;
    this.showModifyPreview = false;
    this.showModifyModal = true;
  }

  closeModifyModal() {
    if (this.isModifying) return;
    this.showModifyModal = false;
  }

  toggleModifyPreview() {
    this.showModifyPreview = !this.showModifyPreview;
  }

  toggleModifyItems(event) {
    this.includeModifyItems = event.target.checked;
  }

  handleModifyFormChange(event) {
    const field = event.target.dataset.field;
    if (!field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.modifyForm = { ...this.modifyForm, [field]: val };
  }

  // ----- 수정 모달 입금 -----
  handleModifyJournalChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.modifyJournals = this.modifyJournals.map((j, i) => (i === idx ? { ...j, [field]: val } : j));
  }

  addModifyJournal() {
    this.modifyJournals = [...this.modifyJournals, newModifyJournal(this.modifyJournals.length + 1)];
    this.reindexModifyJournals();
  }

  removeModifyJournal(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.modifyJournals.length <= 1) {
      this.showToast("알림", "최소 한 개의 입금 행이 필요합니다.", "warning");
      return;
    }
    this.modifyJournals = this.modifyJournals.filter((_, i) => i !== idx);
    this.reindexModifyJournals();
  }

  reindexModifyJournals() {
    this.modifyJournals = this.modifyJournals.map((j, i) => ({
      ...j,
      _idxLabel: i + 1,
      DeposiSeqNo__c: String(i + 1)
    }));
  }

  // ----- 수정 모달 주문 상세 -----
  handleModifyItemChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.modifyItems = this.modifyItems.map((it, i) => (i === idx ? { ...it, [field]: val } : it));
  }

  addModifyItem() {
    this.modifyItems = [...this.modifyItems, newModifyItem(this.modifyItems.length + 1)];
    this.reindexModifyItems();
  }

  removeModifyItem(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.modifyItems.length <= 1) {
      this.showToast("알림", "최소 한 개의 주문 상세가 필요합니다.", "warning");
      return;
    }
    this.modifyItems = this.modifyItems.filter((_, i) => i !== idx);
    this.reindexModifyItems();
  }

  reindexModifyItems() {
    this.modifyItems = this.modifyItems.map((it, i) => ({
      ...it,
      _idxLabel: i + 1,
      OrderSeqNo__c: String(i + 1)
    }));
  }

  // ----- 수정 페이로드 빌드 / 제출 -----
  buildModifyPayload() {
    const payload = {
      OrderNo__c: (this.modifyForm.OrderNo__c || "").trim(),
      ActualPaymentAmount__c: Number(this.modifyForm.ActualPaymentAmount__c) || 0,
      OrderStatus__c: this.modifyForm.OrderStatus__c || "",
      TransactionJournal: this.modifyJournals.map((j) => ({
        DepositNo__c: j.DepositNo__c || "",
        DeposiSeqNo__c: j.DeposiSeqNo__c || "",
        ActivityDate: j.ActivityDate || "",
        PaymentMethod: j.PaymentMethod || "",
        DepositType__c: j.DepositType__c || "",
        TransactionAmount: Number(j.TransactionAmount) || 0,
        CouponNo: j.CouponNo || "",
        OrderNo__c: FIXED_TJ_ORDER_NO
      }))
    };
    if (this.includeModifyItems && this.modifyItems.length) {
      payload.OrderItem = this.modifyItems.map((it) => ({
        OrderSeqNo__c: it.OrderSeqNo__c,
        Status__c: it.Status__c,
        ProductCode: (it.ProductCode || "").trim(),
        Quantity: Number(it.Quantity) || 0,
        NetSalesUnitPrice__c: Number(it.NetSalesUnitPrice__c) || 0,
        DiscountRate__c: Number(it.DiscountRate__c) || 0
      }));
    }
    return payload;
  }

  async submitModify() {
    const orderNo = (this.modifyForm.OrderNo__c || "").trim();
    if (!orderNo) {
      this.showToast("입력 확인", "수정할 원주문 번호를 입력하세요.", "warning");
      return;
    }
    this.isModifying = true;
    this.modifyResult = null;
    try {
      const payload = this.buildModifyPayload();
      const res = await updateOrder({ jsonBody: JSON.stringify(payload) });
      this.modifyResult = res;
      this.showToast(res?.success ? "수정 성공" : "수정 실패", res?.message || "", res?.success ? "success" : "error");
      // 수정 성공 시 직전 입력값을 placeholder 로 → 주문 섹션 placeholder 동기화
      if (res?.success) {
        const prevOrderNo = (this.modifyForm.OrderNo__c || "").trim();
        const prevDep = (this.modifyJournals[0]?.DepositNo__c || "").trim();
        if (prevOrderNo) this.orderNoPlaceholder = `직전 입력: ${prevOrderNo}`;
        if (prevDep) this.orderDepNoPlaceholder = `직전 입력: ${prevDep}`;
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "주문 수정 호출 중 오류가 발생했습니다.";
      this.modifyResult = { success: false, code: 500, message: msg };
      this.showToast("수정 실패", msg, "error");
    } finally {
      this.isModifying = false;
    }
  }

  // ============================================================
  // ========= 판매 등록 =========
  // ============================================================
  get saleActualPaymentAmount() {
    return this.saleItems.reduce((sum, it) => {
      const qty = Number(it.Quantity) || 0;
      const price = Number(it.NetSalesUnitPrice__c) || 0;
      return sum + qty * price;
    }, 0);
  }

  get saleActualPaymentLabel() {
    return formatNumber(this.saleActualPaymentAmount) + " 원";
  }

  get saleItemsCount() {
    return this.saleItems.length;
  }

  get saleJournalsCount() {
    return this.saleJournals.length;
  }

  get salePreviewJson() {
    return JSON.stringify(this.buildSalePayload(), null, 2);
  }

  get saleResultClass() {
    if (!this.saleResult) return "";
    return this.saleResult.success ? "slds-box slds-theme_success slds-m-top_x-small" : "slds-box slds-theme_error slds-m-top_x-small";
  }

  get saleResultText() {
    if (!this.saleResult) return "";
    const head = this.saleResult.success ? "✅ 판매 등록 성공" : "❌ 판매 등록 실패";
    const code = this.saleResult.code != null ? ` (code: ${this.saleResult.code})` : "";
    const msg = this.saleResult.message ? ` — ${this.saleResult.message}` : "";
    const oid = this.saleResult.orderId ? ` / orderId: ${this.saleResult.orderId}` : "";
    return `${head}${code}${msg}${oid}`;
  }

  // 판매 헤더
  handleSaleHeaderChange(event) {
    const field = event.target.dataset.field;
    if (!field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.saleHeader = { ...this.saleHeader, [field]: val };
  }

  // 판매 상세
  handleSaleItemChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const isCheckbox = event.target.type === "checkbox";
    const val = isCheckbox ? event.target.checked : event.target.value;
    this.saleItems = this.saleItems.map((it, i) => (i === idx ? { ...it, [field]: val } : it));
  }

  addSaleItem() {
    this.saleItems = [...this.saleItems, newSaleItem(this.saleItems.length + 1)];
    this.reindexSaleItems();
  }

  removeSaleItem(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.saleItems.length <= 1) {
      this.showToast("알림", "최소 한 개의 판매 상세가 필요합니다.", "warning");
      return;
    }
    this.saleItems = this.saleItems.filter((_, i) => i !== idx);
    this.reindexSaleItems();
  }

  reindexSaleItems() {
    this.saleItems = this.saleItems.map((it, i) => ({
      ...it,
      _idxLabel: i + 1,
      SaleSeqNo__c: String(i + 1)
    }));
  }

  // 판매 입금
  handleSaleJournalChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.saleJournals = this.saleJournals.map((j, i) => (i === idx ? { ...j, [field]: val } : j));
  }

  addSaleJournal() {
    // 같은 거래의 추가 입금 행 — 첫 행의 DepositNo 공유 (없으면 새로 생성)
    const depositNo = this.saleJournals[0]?.DepositNo__c || nextDepositNo();
    const next = newSaleJournal(this.saleJournals.length + 1);
    next.DepositNo__c = depositNo;
    this.saleJournals = [...this.saleJournals, next];
    this.reindexSaleJournals();
  }

  removeSaleJournal(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.saleJournals.length <= 1) {
      this.showToast("알림", "최소 한 개의 입금 행이 필요합니다.", "warning");
      return;
    }
    this.saleJournals = this.saleJournals.filter((_, i) => i !== idx);
    this.reindexSaleJournals();
  }

  reindexSaleJournals() {
    this.saleJournals = this.saleJournals.map((j, i) => ({
      ...j,
      _idxLabel: i + 1,
      DeposiSeqNo__c: String(i + 1)
    }));
  }

  toggleSalePreview() {
    this.showSalePreview = !this.showSalePreview;
  }

  // 판매 전체 삭제 — 판매 헤더의 SaleNo__c 사용
  async handleDeleteSale() {
    const saleNo = (this.saleHeader.SaleNo__c || "").trim();
    if (!saleNo) {
      this.showToast("입력 확인", "삭제할 판매 번호를 입력하세요.", "warning");
      return;
    }
    try {
      const res = await deleteSale({ saleNo });
      this.showToast(res?.success ? "삭제 성공" : "삭제 실패", res?.message || "", res?.success ? "success" : "error");
      // 삭제 성공 시 직전 입력 placeholder 갱신 + 입력란 비우기
      if (res?.success) {
        this.saleNoPlaceholder = `직전 입력: ${saleNo}`;
        this.saleHeader = { ...this.saleHeader, SaleNo__c: "" };
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "판매 삭제 호출 중 오류가 발생했습니다.";
      this.showToast("삭제 실패", msg, "error");
    }
  }

  // 판매 입금 단건 삭제 — TJ 행의 DepositNo__c + DeposiSeqNo__c 사용
  async handleDeleteSaleDeposit(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    const j = this.saleJournals[idx];
    if (!j) return;
    const depositNo = (j.DepositNo__c || "").trim();
    const deposiSeqNo = (j.DeposiSeqNo__c || "").trim();
    if (!depositNo) {
      this.showToast("입력 확인", "입금 번호를 입력하세요.", "warning");
      return;
    }
    if (!deposiSeqNo) {
      this.showToast("입력 확인", "입금 일련 번호를 입력하세요.", "warning");
      return;
    }
    try {
      const res = await deleteSaleDeposit({ depositNo, deposiSeqNo });
      this.showToast(res?.success ? "삭제 성공" : "삭제 실패", res?.message || "", res?.success ? "success" : "error");
      // 삭제 성공 시 직전 입력 placeholder 갱신 + 해당 행 입금 번호 비우기
      if (res?.success) {
        this.saleDepNoPlaceholder = `직전 입력: ${depositNo}`;
        this.saleJournals = this.saleJournals.map((row, i) => (i === idx ? { ...row, DepositNo__c: "" } : row));
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "판매 입금 삭제 호출 중 오류가 발생했습니다.";
      this.showToast("삭제 실패", msg, "error");
    }
  }

  buildSalePayload() {
    return {
      AccountId: FIXED_ACCOUNT_ID,
      StoreCode__c: (this.saleHeader.StoreCode__c || "").trim(),
      MemberNo__c: (this.saleHeader.MemberNo__c || "").trim(),
      SaleNo__c: (this.saleHeader.SaleNo__c || "").trim(),
      EndDate: (this.saleHeader.EndDate || "").trim(),
      ActualPaymentAmount__c: Number(this.saleHeader.ActualPaymentAmount__c) || 0,
      SaleStatus__c: this.saleHeader.SaleStatus__c || "",
      PromotionNo__c: this.saleHeader.PromotionNo__c || "",
      OrderItem: this.saleItems.map((it) => ({
        SaleSeqNo__c: it.SaleSeqNo__c,
        ProductCode: (it.ProductCode || "").trim(),
        Quantity: Number(it.Quantity) || 0,
        isExclude: !!it.isExclude,
        NetSalesUnitPrice__c: Number(it.NetSalesUnitPrice__c) || 0
      })),
      TransactionJournal: this.saleJournals.map((j) => ({
        DepositNo__c: j.DepositNo__c || "",
        DeposiSeqNo__c: j.DeposiSeqNo__c || "",
        ActivityDate: j.ActivityDate || "",
        PaymentMethod: j.PaymentMethod || "",
        DepositType__c: j.DepositType__c || "",
        TransactionAmount: Number(j.TransactionAmount) || 0,
        CouponNo: j.CouponNo || "",
        OrderNo__c: j.OrderNo__c || ""
      })),
      InsertId__c: this.saleHeader.InsertId__c || ""
    };
  }

  validateSale() {
    if (!(this.saleHeader.MemberNo__c || "").trim()) return "회원 번호를 입력하세요.";
    if (!(this.saleHeader.SaleNo__c || "").trim()) return "판매 번호를 입력하세요.";
    if (!(this.saleHeader.StoreCode__c || "").trim()) return "매장 코드를 입력하세요.";
    if (!this.saleItems.length) return "판매 상세를 한 개 이상 추가하세요.";
    if (!this.saleJournals.length) return "입금 내역을 한 개 이상 추가하세요.";
    for (const it of this.saleItems) {
      if (!it.SaleSeqNo__c) return "판매 일련 번호를 입력하세요.";
      if (!(it.ProductCode || "").trim()) return "상품 코드를 입력하세요.";
      if (!(Number(it.Quantity) > 0)) return "수량은 1 이상이어야 합니다.";
    }
    return null;
  }

  async handleSaleSubmit() {
    const err = this.validateSale();
    if (err) {
      this.showToast("입력 확인", err, "warning");
      return;
    }
    this.isSaleSubmitting = true;
    this.saleResult = null;
    try {
      const payload = this.buildSalePayload();
      const res = await createSale({ jsonBody: JSON.stringify(payload) });
      this.saleResult = res;
      this.showToast(res?.success ? "등록 성공" : "등록 실패", res?.message || "", res?.success ? "success" : "error");
      // 등록 성공 시 직전 입력값을 placeholder 로 → 다음 입력 참고용 / 입력란 비우기
      if (res?.success) {
        const prevSaleNo = (this.saleHeader.SaleNo__c || "").trim();
        const prevDep = (this.saleJournals[0]?.DepositNo__c || "").trim();
        if (prevSaleNo) this.saleNoPlaceholder = `직전 입력: ${prevSaleNo}`;
        if (prevDep) this.saleDepNoPlaceholder = `직전 입력: ${prevDep}`;
        this.saleHeader = { ...this.saleHeader, SaleNo__c: "" };
        this.saleJournals = this.saleJournals.map((j) => ({ ...j, DepositNo__c: "" }));
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "판매 등록 호출 중 오류가 발생했습니다.";
      this.saleResult = { success: false, code: 500, message: msg };
      this.showToast("등록 실패", msg, "error");
    } finally {
      this.isSaleSubmitting = false;
    }
  }

  // ============================================================
  // ========= 판매 수정 모달 =========
  // ============================================================
  get saleModifyJournalsCount() {
    return this.saleModifyJournals.length;
  }

  get saleModifyItemsCount() {
    return this.saleModifyItems.length;
  }

  get saleModifyResultClass() {
    if (!this.saleModifyResult) return "";
    return this.saleModifyResult.success ? "slds-box slds-theme_success slds-m-top_small" : "slds-box slds-theme_error slds-m-top_small";
  }

  get saleModifyResultText() {
    if (!this.saleModifyResult) return "";
    const head = this.saleModifyResult.success ? "✅ 판매 수정 성공" : "❌ 판매 수정 실패";
    const code = this.saleModifyResult.code != null ? ` (code: ${this.saleModifyResult.code})` : "";
    const msg = this.saleModifyResult.message ? ` — ${this.saleModifyResult.message}` : "";
    const oid = this.saleModifyResult.orderId ? ` / orderId: ${this.saleModifyResult.orderId}` : "";
    return `${head}${code}${msg}${oid}`;
  }

  get saleModifyPreviewJson() {
    return JSON.stringify(this.buildSaleModifyPayload(), null, 2);
  }

  openSaleModifyModal() {
    this.saleModifyResult = null;
    this.showSaleModifyPreview = false;
    this.showSaleModifyModal = true;
  }

  closeSaleModifyModal() {
    if (this.isSaleModifying) return;
    this.showSaleModifyModal = false;
  }

  toggleSaleModifyPreview() {
    this.showSaleModifyPreview = !this.showSaleModifyPreview;
  }

  toggleSaleModifyItems(event) {
    this.includeSaleModifyItems = event.target.checked;
  }

  handleSaleModifyFormChange(event) {
    const field = event.target.dataset.field;
    if (!field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.saleModifyForm = { ...this.saleModifyForm, [field]: val };
  }

  handleSaleModifyJournalChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.saleModifyJournals = this.saleModifyJournals.map((j, i) => (i === idx ? { ...j, [field]: val } : j));
  }

  addSaleModifyJournal() {
    this.saleModifyJournals = [...this.saleModifyJournals, newSaleModifyJournal(this.saleModifyJournals.length + 1)];
    this.reindexSaleModifyJournals();
  }

  removeSaleModifyJournal(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.saleModifyJournals.length <= 1) {
      this.showToast("알림", "최소 한 개의 입금 행이 필요합니다.", "warning");
      return;
    }
    this.saleModifyJournals = this.saleModifyJournals.filter((_, i) => i !== idx);
    this.reindexSaleModifyJournals();
  }

  reindexSaleModifyJournals() {
    this.saleModifyJournals = this.saleModifyJournals.map((j, i) => ({
      ...j,
      _idxLabel: i + 1,
      DeposiSeqNo__c: String(i + 1)
    }));
  }

  handleSaleModifyItemChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    this.saleModifyItems = this.saleModifyItems.map((it, i) => (i === idx ? { ...it, [field]: event.target.value } : it));
  }

  addSaleModifyItem() {
    this.saleModifyItems = [...this.saleModifyItems, newSaleModifyItem(this.saleModifyItems.length + 1)];
    this.reindexSaleModifyItems();
  }

  removeSaleModifyItem(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.saleModifyItems.length <= 1) {
      this.showToast("알림", "최소 한 개의 판매 상세가 필요합니다.", "warning");
      return;
    }
    this.saleModifyItems = this.saleModifyItems.filter((_, i) => i !== idx);
    this.reindexSaleModifyItems();
  }

  reindexSaleModifyItems() {
    this.saleModifyItems = this.saleModifyItems.map((it, i) => ({
      ...it,
      _idxLabel: i + 1,
      SaleSeqNo__c: String(i + 1)
    }));
  }

  buildSaleModifyPayload() {
    const payload = {
      SaleNo__c: (this.saleModifyForm.SaleNo__c || "").trim(),
      ActualPaymentAmount__c: Number(this.saleModifyForm.ActualPaymentAmount__c) || 0,
      SaleStatus__c: this.saleModifyForm.SaleStatus__c || "",
      TransactionJournal: this.saleModifyJournals.map((j) => ({
        DepositNo__c: j.DepositNo__c || "",
        DeposiSeqNo__c: j.DeposiSeqNo__c || "",
        ActivityDate: j.ActivityDate || "",
        PaymentMethod: j.PaymentMethod || "",
        DepositType__c: j.DepositType__c || "",
        TransactionAmount: Number(j.TransactionAmount) || 0,
        CouponNo: j.CouponNo || "",
        OrderNo__c: j.OrderNo__c || ""
      }))
    };
    if (this.includeSaleModifyItems && this.saleModifyItems.length) {
      payload.OrderItem = this.saleModifyItems.map((it) => ({
        SaleSeqNo__c: it.SaleSeqNo__c,
        ProductCode: (it.ProductCode || "").trim(),
        Quantity: Number(it.Quantity) || 0,
        NetSalesUnitPrice__c: Number(it.NetSalesUnitPrice__c) || 0,
        DiscountRate__c: FIXED_DISCOUNT_RATE
      }));
    }
    return payload;
  }

  async submitSaleModify() {
    const saleNo = (this.saleModifyForm.SaleNo__c || "").trim();
    if (!saleNo) {
      this.showToast("입력 확인", "수정할 원판매 번호를 입력하세요.", "warning");
      return;
    }
    this.isSaleModifying = true;
    this.saleModifyResult = null;
    try {
      const payload = this.buildSaleModifyPayload();
      const res = await updateSale({ jsonBody: JSON.stringify(payload) });
      this.saleModifyResult = res;
      this.showToast(res?.success ? "수정 성공" : "수정 실패", res?.message || "", res?.success ? "success" : "error");
      // 수정 성공 시 직전 입력값을 placeholder 로 → 판매 섹션 placeholder 동기화
      if (res?.success) {
        const prevSaleNo = (this.saleModifyForm.SaleNo__c || "").trim();
        const prevDep = (this.saleModifyJournals[0]?.DepositNo__c || "").trim();
        if (prevSaleNo) this.saleNoPlaceholder = `직전 입력: ${prevSaleNo}`;
        if (prevDep) this.saleDepNoPlaceholder = `직전 입력: ${prevDep}`;
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "판매 수정 호출 중 오류가 발생했습니다.";
      this.saleModifyResult = { success: false, code: 500, message: msg };
      this.showToast("수정 실패", msg, "error");
    } finally {
      this.isSaleModifying = false;
    }
  }

  // ============================================================
  // ========= 반품 등록 =========
  // ============================================================
  get returnItemsCount() {
    return this.returnItems.length;
  }

  get returnJournalsCount() {
    return this.returnJournals.length;
  }

  get returnPreviewJson() {
    return JSON.stringify(this.buildReturnPayload(), null, 2);
  }

  get returnResultClass() {
    if (!this.returnResult) return "";
    return this.returnResult.success ? "slds-box slds-theme_success slds-m-top_x-small" : "slds-box slds-theme_error slds-m-top_x-small";
  }

  get returnResultText() {
    if (!this.returnResult) return "";
    const head = this.returnResult.success ? "✅ 반품 등록 성공" : "❌ 반품 등록 실패";
    const code = this.returnResult.code != null ? ` (code: ${this.returnResult.code})` : "";
    const msg = this.returnResult.message ? ` — ${this.returnResult.message}` : "";
    const oid = this.returnResult.orderId ? ` / orderId: ${this.returnResult.orderId}` : "";
    return `${head}${code}${msg}${oid}`;
  }

  // 반품 헤더
  handleReturnHeaderChange(event) {
    const field = event.target.dataset.field;
    if (!field) return;
    this.returnHeader = { ...this.returnHeader, [field]: event.target.value };
  }

  // 반품 상세
  handleReturnItemChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const isCheckbox = event.target.type === "checkbox";
    const val = isCheckbox ? event.target.checked : event.target.value;
    this.returnItems = this.returnItems.map((it, i) => (i === idx ? { ...it, [field]: val } : it));
  }

  addReturnItem() {
    this.returnItems = [...this.returnItems, newReturnItem(this.returnItems.length + 1)];
    this.reindexReturnItems();
  }

  removeReturnItem(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.returnItems.length <= 1) {
      this.showToast("알림", "최소 한 개의 반품 상세가 필요합니다.", "warning");
      return;
    }
    this.returnItems = this.returnItems.filter((_, i) => i !== idx);
    this.reindexReturnItems();
  }

  reindexReturnItems() {
    this.returnItems = this.returnItems.map((it, i) => ({
      ...it,
      _idxLabel: i + 1,
      SaleSeqNo__c: String(i + 1)
    }));
  }

  // 반품 입금
  handleReturnJournalChange(event) {
    const idx = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    if (Number.isNaN(idx) || !field) return;
    const val = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
    this.returnJournals = this.returnJournals.map((j, i) => (i === idx ? { ...j, [field]: val } : j));
  }

  addReturnJournal() {
    // 같은 거래의 추가 입금 행 — 첫 행의 DepositNo 공유 (없으면 새로 생성)
    const depositNo = this.returnJournals[0]?.DepositNo__c || nextDepositNo();
    const next = newReturnJournal(this.returnJournals.length + 1);
    next.DepositNo__c = depositNo;
    this.returnJournals = [...this.returnJournals, next];
    this.reindexReturnJournals();
  }

  removeReturnJournal(event) {
    const idx = Number(event.target.dataset.index);
    if (Number.isNaN(idx)) return;
    if (this.returnJournals.length <= 1) {
      this.showToast("알림", "최소 한 개의 입금 행이 필요합니다.", "warning");
      return;
    }
    this.returnJournals = this.returnJournals.filter((_, i) => i !== idx);
    this.reindexReturnJournals();
  }

  reindexReturnJournals() {
    this.returnJournals = this.returnJournals.map((j, i) => ({
      ...j,
      _idxLabel: i + 1,
      DeposiSeqNo__c: String(i + 1)
    }));
  }

  toggleReturnPreview() {
    this.showReturnPreview = !this.showReturnPreview;
  }

  buildReturnPayload() {
    return {
      SaleNo__c: (this.returnHeader.SaleNo__c || "").trim(),
      OriginalOrderId: (this.returnHeader.OriginalOrderId || "").trim(),
      ActualPaymentAmount__c: Number(this.returnHeader.ActualPaymentAmount__c) || 0,
      OrderItem: this.returnItems.map((it) => ({
        SaleSeqNo__c: it.SaleSeqNo__c,
        ProductCode: (it.ProductCode || "").trim(),
        Quantity: Number(it.Quantity) || 0,
        isExclude: !!it.isExclude,
        NetSalesUnitPrice__c: Number(it.NetSalesUnitPrice__c) || 0,
        DiscountRate__c: Number(it.DiscountRate__c) || 0
      })),
      TransactionJournal: this.returnJournals.map((j) => ({
        DepositNo__c: j.DepositNo__c || "",
        DeposiSeqNo__c: j.DeposiSeqNo__c || "",
        ActivityDate: j.ActivityDate || "",
        PaymentMethod: j.PaymentMethod || "",
        DepositType__c: j.DepositType__c || "",
        TransactionAmount: Number(j.TransactionAmount) || 0,
        CouponNo: j.CouponNo || ""
      })),
      InsertId__c: this.returnHeader.InsertId__c || ""
    };
  }

  validateReturn() {
    if (!(this.returnHeader.SaleNo__c || "").trim()) return "반품 번호를 입력하세요.";
    if (!(this.returnHeader.OriginalOrderId || "").trim()) return "원판매 번호를 입력하세요.";
    if (!this.returnItems.length) return "반품 상세를 한 개 이상 추가하세요.";
    if (!this.returnJournals.length) return "입금 내역을 한 개 이상 추가하세요.";
    for (const it of this.returnItems) {
      if (!it.SaleSeqNo__c) return "판매 일련 번호를 입력하세요.";
      if (!(it.ProductCode || "").trim()) return "상품 코드를 입력하세요.";
      if (Number(it.Quantity) === 0 || Number.isNaN(Number(it.Quantity))) return "수량을 입력하세요 (반품은 음수).";
    }
    return null;
  }

  async handleReturnSubmit() {
    const err = this.validateReturn();
    if (err) {
      this.showToast("입력 확인", err, "warning");
      return;
    }
    this.isReturnSubmitting = true;
    this.returnResult = null;
    try {
      const payload = this.buildReturnPayload();
      const res = await createReturn({ jsonBody: JSON.stringify(payload) });
      this.returnResult = res;
      this.showToast(res?.success ? "등록 성공" : "등록 실패", res?.message || "", res?.success ? "success" : "error");
      // 등록 성공 시 직전 입력값을 placeholder 로 → 다음 입력 참고용 / 입력란 비우기
      if (res?.success) {
        const prevReturnNo = (this.returnHeader.SaleNo__c || "").trim();
        const prevDep = (this.returnJournals[0]?.DepositNo__c || "").trim();
        if (prevReturnNo) this.returnNoPlaceholder = `직전 입력: ${prevReturnNo}`;
        if (prevDep) this.returnDepNoPlaceholder = `직전 입력: ${prevDep}`;
        this.returnHeader = { ...this.returnHeader, SaleNo__c: "" };
        this.returnJournals = this.returnJournals.map((j) => ({ ...j, DepositNo__c: "" }));
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "반품 등록 호출 중 오류가 발생했습니다.";
      this.returnResult = { success: false, code: 500, message: msg };
      this.showToast("등록 실패", msg, "error");
    } finally {
      this.isReturnSubmitting = false;
    }
  }

  // ========= 회원 등록 모달 =========
  openMemberModal() {
    this.memberResult = null;
    this.showMemberModal = true;
  }

  closeMemberModal() {
    if (this.isRegistering) return;
    this.showMemberModal = false;
  }

  handleMemberFieldChange(event) {
    const field = event.target.dataset.field;
    if (!field) return;
    const isCheckbox = event.target.type === "checkbox";
    let val;
    if (isCheckbox) {
      val = event.target.checked;
    } else {
      val = event.detail?.value !== undefined ? event.detail.value : event.target.value;
    }
    this.memberForm = { ...this.memberForm, [field]: val };
  }

  get memberResultClass() {
    if (!this.memberResult) return "";
    return this.memberResult.success ? "slds-box slds-theme_success slds-m-top_small" : "slds-box slds-theme_error slds-m-top_small";
  }

  get memberResultText() {
    if (!this.memberResult) return "";
    const head = this.memberResult.success ? "✅ 회원 등록 성공" : "❌ 회원 등록 실패";
    const code = this.memberResult.code != null ? ` (code: ${this.memberResult.code})` : "";
    const msg = this.memberResult.message ? ` — ${this.memberResult.message}` : "";
    const mn = this.memberResult.memberNo ? ` / 회원번호: ${this.memberResult.memberNo}` : "";
    return `${head}${code}${msg}${mn}`;
  }

  async submitMember() {
    const memberNo = (this.memberForm.MemberNo__c || "").trim();
    if (!memberNo) {
      this.showToast("입력 확인", "회원 번호를 입력하세요.", "warning");
      return;
    }
    this.isRegistering = true;
    this.memberResult = null;
    try {
      const payload = {
        StoreRegi__c: (this.memberForm.StoreRegi__c || "").trim(),
        StoreMana__c: (this.memberForm.StoreMana__c || "").trim(),
        MemberNo__c: memberNo,
        Grade__c: (this.memberForm.Grade__c || "").trim(),
        IsSMSAgreed__c: !!this.memberForm.IsSMSAgreed__c
      };
      const res = await createMember({ jsonBody: JSON.stringify(payload) });
      this.memberResult = res;
      this.showToast(res?.success ? "등록 성공" : "등록 실패", res?.message || "", res?.success ? "success" : "error");
      if (res?.success) {
        // 주문 헤더 회원 번호에 자동 채움
        this.header = { ...this.header, MemberNo__c: res.memberNo || memberNo };
      }
    } catch (e) {
      const msg = e?.body?.message || e?.message || "회원 등록 호출 중 오류가 발생했습니다.";
      this.memberResult = { success: false, code: 500, message: msg };
      this.showToast("등록 실패", msg, "error");
    } finally {
      this.isRegistering = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}