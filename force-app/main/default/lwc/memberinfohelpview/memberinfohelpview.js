import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getMemberHelpView from "@salesforce/apex/TestMemberInfoHelpViewControllerV1.getMemberHelpView";
import getPointHelp from "@salesforce/apex/TestMemberInfoHelpViewControllerV1.getPointHelp";
import creditPoints from "@salesforce/apex/TestMemberInfoHelpViewControllerV1.creditPoints";
import getAvailableCoupons from "@salesforce/apex/TestMemberInfoHelpViewControllerV1.getAvailableCoupons";
import searchStores from "@salesforce/apex/TestMemberInfoHelpViewControllerV1.searchStores";

const POINT_TYPE_LABELS = {
  "01": "구매포인트",
  "02": "기념일포인트",
  "03": "승급포인트",
  "04": "기타포인트",
  "05": "에코포인트",
  "06": "사은포인트"
};

// 주문 구분 코드 선택 목록 (Order.Type)
const ORDER_TYPE_OPTIONS = [
  { label: "고객", value: "01" },
  { label: "진열", value: "02" },
  { label: "수선", value: "03" },
  { label: "가주문", value: "04" },
  { label: "B2B", value: "10" }
];

const ACCRUAL_DATE_FIELDS = ["DT_SAVE_PLAN", "DT_SAVE", "DT_LIMIT_START", "DT_LIMIT_END", "DT_DESTROY_PLAN", "DT_DESTROY_DEL_SALE"];
const REDEMPTION_DATE_FIELDS = ["DT_USE", "DT_SAVE"];
const ACCRUAL_NUMBER_FIELDS = ["PT_SAVE", "PT_USE", "PT_DESTROY", "AM_SAL", "PT_TARGET", "PT_USE_SALE", "PT_USE_SALE_COUPON"];
const REDEMPTION_NUMBER_FIELDS = ["PT_USE", "AM_SAL"];

function formatYmd(value) {
  if (!value || typeof value !== "string") return value || "";
  const v = value.replace(/[^0-9]/g, "");
  if (v.length === 8) return `${v.slice(0, 4)}/${v.slice(4, 6)}/${v.slice(6, 8)}`;
  return value;
}

function formatYm(value) {
  if (!value || typeof value !== "string") return value || "";
  const v = value.replace(/[^0-9]/g, "");
  if (v.length === 6) return `${v.slice(0, 4)}/${v.slice(4, 6)}`;
  return value;
}

function formatNumber(value) {
  if (value === null || value === undefined || value === "") return "";
  const n = Number(value);
  if (Number.isNaN(n)) return value;
  return n.toLocaleString();
}

function decorate(row, dateFields, numberFields) {
  const out = { ...row };
  out.YM_CREATE = formatYm(out.YM_CREATE);
  for (const f of dateFields) if (f in out) out[f] = formatYmd(out[f]);
  for (const f of numberFields) if (f in out) out[f] = formatNumber(out[f]);
  return out;
}

function sumOf(rows, field) {
  return rows.reduce((acc, r) => acc + (Number(r[field]) || 0), 0);
}

export default class Memberinfohelpview extends LightningElement {
  memberNoInput = "";
  jsonInput = "";
  creditJsonInput = "";
  pointHelpJsonInput = "";
  @track pointHelpForm = {
    StoreCode__c: "",
    MemberNo__c: "",
    PromotionNo__c: "",
    OrderDate: "",
    SaleNo__c: ""
  };
  @track pointStoreKeyword = "";
  @track pointStoreOptions = [];
  @track pointStoreDropdownOpen = false;
  @track searchedMemberNo = "";
  @track totalPointsLabel = "";
  @track payablePointsLabel = "";
  @track accrualRows = [];
  @track redemptionRows = [];
  @track accrualSums = {};
  @track redemptionSums = {};
  @track isLoading = false;
  @track hasSearched = false;
  @track showJsonPanel = false;
  @track showCreditPanel = false;
  @track isCrediting = false;
  @track creditResult = null;
  @track pointHelpSearched = false;
  @track pointHelpLoading = false;
  @track pointHelpMemberNo = "";
  @track pointHelpTotalLabel = "";
  @track pointHelpPayableLabel = "";
  @track pointHelpRows = [];
  @track showPointHelpJsonPanel = false;

  // ========= 사용 가능한 쿠폰 도움창 상태 =========
  @track voucherHelpForm = {
    StoreCode__c: "",
    MemberNo__c: "",
    ActualPaymentAmount__c: 0,
    Type: "",
    PromotionNo__c: ""
  };
  @track voucherStoreKeyword = "";
  @track voucherStoreOptions = [];
  @track voucherStoreDropdownOpen = false;
  @track voucherHelpItem = {
    ProductCode: "",
    Quantity: 1,
    NetSalesUnitPrice__c: 0,
    DiscountRate__c: 0
  };
  @track voucherHelpIncludeItem = false;
  @track voucherHelpLoading = false;
  @track voucherHelpSearched = false;
  @track voucherHelpRows = [];
  @track voucherHelpMessage = "";
  @track showVoucherHelpJsonPanel = false;
  voucherHelpJsonInput = "";
  storeSearchTimers = {};

  handleInputChange(event) {
    this.memberNoInput = event.target.value;
  }

  handleKeyUp(event) {
    if (event.keyCode === 13) {
      this.handleSearch();
    }
  }

  handleJsonInputChange(event) {
    this.jsonInput = event.target.value;
  }

  toggleJsonPanel() {
    this.showJsonPanel = !this.showJsonPanel;
  }

  async handleSearch() {
    const memberNo = (this.memberNoInput || "").trim();
    if (!memberNo) {
      this.showToast("알림", "회원번호를 입력하세요.", "warning");
      return;
    }

    this.isLoading = true;
    try {
      const data = await getMemberHelpView({ memberNo });
      const rawAccrual = data?.accrualHistoryList ?? [];
      const rawRedemption = data?.userDestoryHistoryList ?? [];
      this.applyData(memberNo, rawAccrual, rawRedemption, data?.totalPointsBalance);
    } catch (error) {
      const msg = error?.body?.message || error?.message || "조회 중 오류가 발생했습니다.";
      this.showToast("조회 실패", msg, "error");
      this.clearData();
      this.hasSearched = true;
    } finally {
      this.isLoading = false;
    }
  }

  handleApplyJson() {
    const raw = (this.jsonInput || "").trim();
    if (!raw) {
      this.showToast("알림", "JSON을 입력하세요.", "warning");
      return;
    }

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      this.showToast("JSON 파싱 실패", e?.message || "올바른 JSON 형식이 아닙니다.", "error");
      return;
    }

    // 두 가지 형태 모두 허용:
    //   1) 전체 응답: { success, data: { AccrualHistoryList, UserDestoryHistoryList, ... } }
    //   2) data 부분만: { AccrualHistoryList, UserDestoryHistoryList, ... }
    const dataNode = parsed?.data ?? parsed ?? {};
    const rawAccrual = Array.isArray(dataNode.AccrualHistoryList) ? dataNode.AccrualHistoryList : [];
    const rawRedemption = Array.isArray(dataNode.UserDestoryHistoryList) ? dataNode.UserDestoryHistoryList : [];

    this.applyData("(JSON 입력)", rawAccrual, rawRedemption, dataNode.TotalPointsBalance);
    this.showToast("적용 완료", `적립 ${rawAccrual.length}건 / 사용·소멸 ${rawRedemption.length}건`, "success");
  }

  handleClearJson() {
    this.jsonInput = "";
  }

  applyData(memberLabel, rawAccrual, rawRedemption, totalPointsBalance) {
    this.searchedMemberNo = memberLabel;
    const tp = totalPointsBalance == null || totalPointsBalance === "" ? 0 : Number(totalPointsBalance);
    const tpLabel = Number.isNaN(tp) ? "0" : tp.toLocaleString();
    this.totalPointsLabel = tpLabel;
    this.payablePointsLabel = tpLabel;

    this.accrualSums = {
      PT_SAVE: formatNumber(sumOf(rawAccrual, "PT_SAVE")),
      PT_USE: formatNumber(sumOf(rawAccrual, "PT_USE")),
      PT_DESTROY: formatNumber(sumOf(rawAccrual, "PT_DESTROY")),
      AM_SAL: formatNumber(sumOf(rawAccrual, "AM_SAL")),
      PT_TARGET: formatNumber(sumOf(rawAccrual, "PT_TARGET")),
      PT_USE_SALE: formatNumber(sumOf(rawAccrual, "PT_USE_SALE")),
      PT_USE_SALE_COUPON: formatNumber(sumOf(rawAccrual, "PT_USE_SALE_COUPON"))
    };
    this.redemptionSums = {
      PT_USE: formatNumber(sumOf(rawRedemption, "PT_USE")),
      AM_SAL: formatNumber(sumOf(rawRedemption, "AM_SAL"))
    };

    this.accrualRows = rawAccrual.map((r, i) => ({
      _key: `a-${i}`,
      _idx: i + 1,
      ...decorate(r, ACCRUAL_DATE_FIELDS, ACCRUAL_NUMBER_FIELDS)
    }));
    this.redemptionRows = rawRedemption.map((r, i) => ({
      _key: `d-${i}`,
      _idx: i + 1,
      ...decorate(r, REDEMPTION_DATE_FIELDS, REDEMPTION_NUMBER_FIELDS)
    }));
    this.hasSearched = true;
  }

  clearData() {
    this.searchedMemberNo = "";
    this.totalPointsLabel = "";
    this.payablePointsLabel = "";
    this.accrualRows = [];
    this.redemptionRows = [];
    this.accrualSums = {};
    this.redemptionSums = {};
  }

  handleReset() {
    this.memberNoInput = "";
    this.jsonInput = "";
    this.clearData();
    this.hasSearched = false;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  get accrualCount() {
    return this.accrualRows.length;
  }
  get redemptionCount() {
    return this.redemptionRows.length;
  }
  get hasAccrualRows() {
    return this.accrualRows.length > 0;
  }
  get hasRedemptionRows() {
    return this.redemptionRows.length > 0;
  }
  get jsonPanelLabel() {
    return this.showJsonPanel ? "▼ JSON 직접 입력 (테스트용)" : "▶ JSON 직접 입력 (테스트용)";
  }

  get creditPanelLabel() {
    return this.showCreditPanel ? "▼ 포인트 개별 지급 (JSON 입력)" : "▶ 포인트 개별 지급 (JSON 입력)";
  }

  get creditResultClass() {
    if (!this.creditResult) return "";
    return this.creditResult.success ? "slds-box slds-theme_success slds-m-top_x-small" : "slds-box slds-theme_error slds-m-top_x-small";
  }

  get creditResultText() {
    if (!this.creditResult) return "";
    const head = this.creditResult.success ? "✅ 포인트 지급 성공" : "❌ 포인트 지급 실패";
    const code = this.creditResult.code != null ? ` (code: ${this.creditResult.code})` : "";
    const msg = this.creditResult.message ? ` — ${this.creditResult.message}` : "";
    return `${head}${code}${msg}`;
  }

  get hasPointStoreOptions() {
    return this.pointStoreDropdownOpen && this.pointStoreOptions.length > 0;
  }

  get hasVoucherStoreOptions() {
    return this.voucherStoreDropdownOpen && this.voucherStoreOptions.length > 0;
  }

  getStoreState(context) {
    return context === "voucher"
      ? {
          keywordField: "voucherStoreKeyword",
          optionsField: "voucherStoreOptions",
          openField: "voucherStoreDropdownOpen",
          formField: "voucherHelpForm"
        }
      : {
          keywordField: "pointStoreKeyword",
          optionsField: "pointStoreOptions",
          openField: "pointStoreDropdownOpen",
          formField: "pointHelpForm"
        };
  }

  updateStoreState(context, patch) {
    const state = this.getStoreState(context);
    if (Object.prototype.hasOwnProperty.call(patch, "keyword")) {
      this[state.keywordField] = patch.keyword;
    }
    if (Object.prototype.hasOwnProperty.call(patch, "options")) {
      this[state.optionsField] = patch.options;
    }
    if (Object.prototype.hasOwnProperty.call(patch, "isOpen")) {
      this[state.openField] = patch.isOpen;
    }
    if (Object.prototype.hasOwnProperty.call(patch, "storeCode")) {
      this[state.formField] = { ...this[state.formField], StoreCode__c: patch.storeCode };
    }
  }

  handleStoreNameChange(event) {
    const context = event.target?.dataset?.context || "point";
    const keyword = event.target.value || "";
    this.updateStoreState(context, { keyword, storeCode: "", options: [], isOpen: false });

    window.clearTimeout(this.storeSearchTimers[context]);
    this.storeSearchTimers[context] = window.setTimeout(() => {
      this.searchStoreOptions(context, keyword);
    }, 250);
  }

  async searchStoreOptions(context, keyword) {
    const trimmedKeyword = (keyword || "").trim();
    if (!trimmedKeyword) {
      this.updateStoreState(context, { options: [], isOpen: false });
      return;
    }

    try {
      const result = await searchStores({ keyword: trimmedKeyword });
      const options = (result || []).map((store) => ({
        label: store.label || store.storeName || "",
        value: store.value || store.storeCode || "",
        storeName: store.storeName || store.label || "",
        storeCode: store.storeCode || store.value || ""
      }));
      const state = this.getStoreState(context);
      if (this[state.keywordField] === keyword) {
        this.updateStoreState(context, { options, isOpen: options.length > 0 });
      }
    } catch (error) {
      this.updateStoreState(context, { options: [], isOpen: false });
      const msg = error?.body?.message || error?.message || "매장 검색 중 오류가 발생했습니다.";
      this.showToast("매장 검색 실패", msg, "error");
    }
  }

  handleStoreOptionSelect(event) {
    const context = event.currentTarget?.dataset?.context || "point";
    const storeName = event.currentTarget?.dataset?.name || "";
    const storeCode = event.currentTarget?.dataset?.code || "";
    this.updateStoreState(context, {
      keyword: storeName,
      storeCode,
      options: [],
      isOpen: false
    });
  }

  handleStoreInputBlur(event) {
    const context = event.target?.dataset?.context || "point";
    window.setTimeout(() => {
      this.updateStoreState(context, { isOpen: false });
    }, 200);
  }

  handleCreditJsonChange(event) {
    this.creditJsonInput = event.target.value;
  }

  toggleCreditPanel() {
    this.showCreditPanel = !this.showCreditPanel;
  }

  handleClearCreditJson() {
    this.creditJsonInput = "";
    this.creditResult = null;
  }

  // ============= 회원 포인트 사용 도움창 =============
  handlePointHelpFieldChange(event) {
    const field = event.target?.dataset?.field || event.target?.name;
    if (!field) return;
    this.pointHelpForm = { ...this.pointHelpForm, [field]: event.target.value };
  }

  handlePointHelpKeyUp(event) {
    if (event.keyCode === 13) {
      this.handlePointHelpSearch();
    }
  }

  applyPointHelpData(memberLabel, rawPointList) {
    let total = 0;
    const rows = (rawPointList ?? []).map((r, i) => {
      const code = r?.CD_TYPE_POINT ?? "";
      const pts = Number(r?.points ?? 0);
      const safe = Number.isNaN(pts) ? 0 : pts;
      total += safe;
      return {
        _key: `ph-${i}`,
        _idx: i + 1,
        code,
        label: POINT_TYPE_LABELS[code] || code || "(미상)",
        points: safe,
        pointsLabel: safe.toLocaleString()
      };
    });
    const totalLabel = total.toLocaleString();
    this.pointHelpMemberNo = memberLabel;
    this.pointHelpTotalLabel = totalLabel;
    this.pointHelpPayableLabel = totalLabel;
    this.pointHelpRows = rows;
    this.pointHelpSearched = true;
  }

  async handlePointHelpSearch() {
    const memberNo = (this.pointHelpForm.MemberNo__c || "").trim();
    if (!memberNo) {
      this.showToast("알림", "회원 번호를 입력하세요.", "warning");
      return;
    }
    this.pointHelpLoading = true;
    try {
      const data = await getPointHelp({
        memberNo,
        storeCode: (this.pointHelpForm.StoreCode__c || "").trim(),
        promotionNo: (this.pointHelpForm.PromotionNo__c || "").trim(),
        orderDate: (this.pointHelpForm.OrderDate || "").trim(),
        saleNo: (this.pointHelpForm.SaleNo__c || "").trim()
      });
      this.applyPointHelpData(data?.memberNo ?? memberNo, data?.pointList ?? []);
    } catch (error) {
      const msg = error?.body?.message || error?.message || "포인트 도움창 조회 중 오류가 발생했습니다.";
      this.showToast("조회 실패", msg, "error");
      this.pointHelpMemberNo = "";
      this.pointHelpTotalLabel = "";
      this.pointHelpPayableLabel = "";
      this.pointHelpRows = [];
      this.pointHelpSearched = true;
    } finally {
      this.pointHelpLoading = false;
    }
  }

  handlePointHelpReset() {
    this.pointHelpForm = {
      StoreCode__c: "",
      MemberNo__c: "",
      PromotionNo__c: "",
      OrderDate: "",
      SaleNo__c: ""
    };
    this.pointStoreKeyword = "";
    this.pointStoreOptions = [];
    this.pointStoreDropdownOpen = false;
    this.pointHelpMemberNo = "";
    this.pointHelpTotalLabel = "";
    this.pointHelpPayableLabel = "";
    this.pointHelpRows = [];
    this.pointHelpSearched = false;
  }

  get hasPointHelpRows() {
    return this.pointHelpRows.length > 0;
  }

  get pointHelpJsonPanelLabel() {
    return this.showPointHelpJsonPanel ? "▼ JSON 직접 입력 (테스트용)" : "▶ JSON 직접 입력 (테스트용)";
  }

  togglePointHelpJsonPanel() {
    this.showPointHelpJsonPanel = !this.showPointHelpJsonPanel;
  }

  handlePointHelpJsonChange(event) {
    this.pointHelpJsonInput = event.target.value;
  }

  handlePointHelpClearJson() {
    this.pointHelpJsonInput = "";
  }

  handlePointHelpApplyJson() {
    const raw = (this.pointHelpJsonInput || "").trim();
    if (!raw) {
      this.showToast("알림", "JSON을 입력하세요.", "warning");
      return;
    }
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      this.showToast("JSON 파싱 실패", e?.message || "올바른 JSON 형식이 아닙니다.", "error");
      return;
    }
    // 두 가지 형태 허용:
    //   1) 전체 응답: { success, data: { pointList: [...] } }
    //   2) data 부분만: { pointList: [...] }
    //   3) 배열만: [ {CD_TYPE_POINT, points}, ... ]
    let rawList = [];
    if (Array.isArray(parsed)) {
      rawList = parsed;
    } else {
      const dataNode = parsed?.data ?? parsed ?? {};
      rawList = Array.isArray(dataNode.pointList) ? dataNode.pointList : [];
    }
    this.applyPointHelpData("(JSON 입력)", rawList);
    this.showToast("적용 완료", `유형별 포인트 ${rawList.length}건`, "success");
  }

  // ============= 포인트 개별 지급 =============
  async handleCreditSubmit() {
    const body = (this.creditJsonInput || "").trim();
    if (!body) {
      this.showToast("알림", "지급 JSON을 입력하세요.", "warning");
      return;
    }
    try {
      JSON.parse(body);
    } catch (e) {
      this.showToast("JSON 파싱 실패", e?.message || "올바른 JSON 형식이 아닙니다.", "error");
      return;
    }

    this.isCrediting = true;
    this.creditResult = null;
    try {
      const res = await creditPoints({ jsonBody: body });
      this.creditResult = res;
      this.showToast(res?.success ? "지급 성공" : "지급 실패", res?.message || "", res?.success ? "success" : "error");
    } catch (error) {
      const msg = error?.body?.message || error?.message || "지급 호출 중 오류가 발생했습니다.";
      this.creditResult = { success: false, code: 500, message: msg };
      this.showToast("지급 실패", msg, "error");
    } finally {
      this.isCrediting = false;
    }
  }

  // ============= 사용 가능한 쿠폰 도움창 =============
  get orderTypeOptions() {
    return ORDER_TYPE_OPTIONS;
  }

  get voucherHelpRowsCount() {
    return this.voucherHelpRows.length;
  }

  get hasVoucherHelpRows() {
    return this.voucherHelpRows.length > 0;
  }

  get voucherHelpJsonPanelLabel() {
    return this.showVoucherHelpJsonPanel ? "▼ JSON 직접 입력 (테스트용)" : "▶ JSON 직접 입력 (테스트용)";
  }

  toggleVoucherHelpJsonPanel() {
    this.showVoucherHelpJsonPanel = !this.showVoucherHelpJsonPanel;
  }

  handleVoucherHelpFieldChange(event) {
    const field = event.target?.dataset?.field;
    if (!field) return;
    const value = event.detail?.value !== undefined ? event.detail.value : event.target.value;
    this.voucherHelpForm = { ...this.voucherHelpForm, [field]: value };
  }

  handleVoucherHelpItemFieldChange(event) {
    const field = event.target?.dataset?.field;
    if (!field) return;
    this.voucherHelpItem = { ...this.voucherHelpItem, [field]: event.target.value };
  }

  handleVoucherHelpItemToggle(event) {
    this.voucherHelpIncludeItem = event.target.checked;
  }

  handleVoucherHelpJsonChange(event) {
    this.voucherHelpJsonInput = event.target.value;
  }

  handleVoucherHelpClearJson() {
    this.voucherHelpJsonInput = "";
  }

  buildVoucherHelpPayload() {
    const payload = {
      StoreCode__c: (this.voucherHelpForm.StoreCode__c || "").trim(),
      MemberNo__c: (this.voucherHelpForm.MemberNo__c || "").trim(),
      ActualPaymentAmount__c: Number(this.voucherHelpForm.ActualPaymentAmount__c) || 0,
      Type: (this.voucherHelpForm.Type || "").trim(),
      PromotionNo__c: (this.voucherHelpForm.PromotionNo__c || "").trim()
    };
    if (this.voucherHelpIncludeItem) {
      payload.OrderItem = [
        {
          ProductCode: (this.voucherHelpItem.ProductCode || "").trim(),
          Quantity: Number(this.voucherHelpItem.Quantity) || 0,
          NetSalesUnitPrice__c: Number(this.voucherHelpItem.NetSalesUnitPrice__c) || 0,
          DiscountRate__c: Number(this.voucherHelpItem.DiscountRate__c) || 0
        }
      ];
    }
    return payload;
  }

  applyVoucherHelpData(rawList, message) {
    const list = Array.isArray(rawList) ? rawList : [];
    this.voucherHelpRows = list.map((c, i) => {
      const code = c?.VoucherCode ?? c?.NO_COUPON_ALL ?? c?.NO_COUPON ?? c?.couponCode ?? "";
      const name = c?.NM_COUPON ?? c?.VoucherDefinitionName ?? c?.VoucherDefinition?.Name ?? c?.couponName ?? c?.name ?? "";
      const faceRaw = c?.FaceValue ?? c?.AM_COUPON ?? c?.faceValue ?? c?.amount ?? 0;
      const startRaw = c?.EffectiveDate ?? c?.DT_LIMIT_START ?? c?.startDate ?? "";
      const endRaw = c?.ExpirationDate ?? c?.DT_LIMIT_END ?? c?.endDate ?? "";
      const status = c?.Status ?? c?.status ?? "";
      return {
        _key: `vh-${i}`,
        _idx: i + 1,
        code: code || "(코드 없음)",
        name,
        faceValueLabel: formatNumber(faceRaw),
        startDate: formatYmd(typeof startRaw === "string" ? startRaw : String(startRaw)),
        endDate: formatYmd(typeof endRaw === "string" ? endRaw : String(endRaw)),
        status,
        _raw: JSON.stringify(c, null, 2)
      };
    });
    this.voucherHelpMessage = message || "";
    this.voucherHelpSearched = true;
  }

  async handleVoucherHelpSearch() {
    const memberNo = (this.voucherHelpForm.MemberNo__c || "").trim();
    if (!memberNo) {
      this.showToast("알림", "회원 번호를 입력하세요.", "warning");
      return;
    }
    this.voucherHelpLoading = true;
    try {
      const payload = this.buildVoucherHelpPayload();
      const res = await getAvailableCoupons({ jsonBody: JSON.stringify(payload) });
      this.applyVoucherHelpData(res?.couponList ?? [], res?.message ?? "");
      if (!res?.success) {
        this.showToast("조회 실패", res?.message || "쿠폰 조회 실패", "error");
      }
    } catch (error) {
      const msg = error?.body?.message || error?.message || "쿠폰 도움창 조회 중 오류가 발생했습니다.";
      this.showToast("조회 실패", msg, "error");
      this.voucherHelpRows = [];
      this.voucherHelpMessage = msg;
      this.voucherHelpSearched = true;
    } finally {
      this.voucherHelpLoading = false;
    }
  }

  handleVoucherHelpReset() {
    this.voucherHelpForm = {
      StoreCode__c: "",
      MemberNo__c: "",
      ActualPaymentAmount__c: 0,
      Type: "",
      PromotionNo__c: ""
    };
    this.voucherStoreKeyword = "";
    this.voucherStoreOptions = [];
    this.voucherStoreDropdownOpen = false;
    this.voucherHelpItem = {
      ProductCode: "",
      Quantity: 1,
      NetSalesUnitPrice__c: 0,
      DiscountRate__c: 0
    };
    this.voucherHelpIncludeItem = false;
    this.voucherHelpRows = [];
    this.voucherHelpMessage = "";
    this.voucherHelpSearched = false;
  }

  handleVoucherHelpApplyJson() {
    const raw = (this.voucherHelpJsonInput || "").trim();
    if (!raw) {
      this.showToast("알림", "JSON을 입력하세요.", "warning");
      return;
    }
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      this.showToast("JSON 파싱 실패", e?.message || "올바른 JSON 형식이 아닙니다.", "error");
      return;
    }
    // 형태 허용:
    //   1) 전체 응답: { success, data: { couponList: [...] } } / data 가 배열
    //   2) data 부분만: { couponList: [...] }
    //   3) 배열만: [ ... ]
    let rawList = [];
    let message = "";
    if (Array.isArray(parsed)) {
      rawList = parsed;
    } else {
      const dataNode = parsed?.data ?? parsed ?? {};
      message = parsed?.message || "";
      if (Array.isArray(dataNode)) {
        rawList = dataNode;
      } else {
        rawList = dataNode.couponList || dataNode.CouponList || dataNode.voucherList || dataNode.VoucherList || [];
      }
    }
    this.applyVoucherHelpData(rawList, message || "(JSON 입력)");
    this.showToast("적용 완료", `사용 가능 쿠폰 ${rawList.length}건`, "success");
  }
}
