import { LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import search from "@salesforce/apex/MagazineSubscriptionInquiryController.search";

export default class MagazineSubscriptionTable extends NavigationMixin(LightningElement) {
  @track rows = [];
  @track total = 0;

  loading = false;

  keyword = "";
  fromDate = null;
  toDate = null;
  storeManaCode = "";
  isSubscribed = "";

  pageSize = 20;
  pageNumber = 1;
  sortBy = "Magazine_Response_Time__c";
  sortDirection = "DESC";

  columns = [
    {
      label: "No.",
      fieldName: "Magazine_uuid__c",
      type: "text",
      initialWidth: 150,
      cellAttributes: { class: "mono" }
    },
    {
      label: "고객이름",
      fieldName: "Magazine_A_Name__c",
      type: "text",
      sortable: true,
      initialWidth: 140
    },
    {
      label: "휴대전화",
      fieldName: "Magazine_A_MobilePhone__c",
      type: "text",
      initialWidth: 150,
      cellAttributes: { class: "mono" }
    },
    {
      label: "생년월일",
      fieldName: "Magazine_A_Birthdate__c",
      type: "date",
      initialWidth: 130
    },
    {
      label: "회원 여부",
      fieldName: "Magazine_A_account_YN__c",
      type: "text",
      initialWidth: 120
    },
    {
      label: "회원번호",
      fieldName: "memberRecordUrl",
      type: "url",
      typeAttributes: {
        label: { fieldName: "Magazine_MemberNo__c" },
        target: "_self"
      },
      initialWidth: 140
    },
    {
      label: "신청 일시",
      fieldName: "Magazine_Response_Time__c",
      type: "date",
      sortable: true,
      initialWidth: 150
    },
    {
      label: "구독 시즌",
      fieldName: "Magazine_Season__c",
      type: "text",
      initialWidth: 110
    },
    {
      label: "발송일자",
      fieldName: "Magazine_SentDate__c",
      type: "date",
      initialWidth: 130
    },
    {
      label: "우편번호",
      fieldName: "Magazine_A_ZIP_Code__c",
      type: "text",
      initialWidth: 120,
      cellAttributes: { class: "mono" }
    },
    {
      label: "주소",
      fieldName: "Magazine_Address__c",
      type: "text",
      wrapText: true,
      initialWidth: 240
    },
    {
      label: "개인정보 동의 여부",
      fieldName: "Magazine_A_sns_YN__c",
      type: "text",
      initialWidth: 160
    },
    {
      label: "업데이트 여부",
      fieldName: "Magazine_IsUpdated__c",
      type: "boolean",
      initialWidth: 120
    },
    {
      type: "action",
      typeAttributes: {
        rowActions: [{ label: "레코드 보기", name: "view" }]
      },
      initialWidth: 110
    }
  ];

  get subOptions() {
    return [
      { label: "전체", value: "" },
      { label: "Y", value: "Y" },
      { label: "N", value: "N" }
    ];
  }

  get pageSizeOptions() {
    return [
      { label: "10", value: 10 },
      { label: "20", value: 20 },
      { label: "50", value: 50 },
      { label: "100", value: 100 }
    ];
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.total / this.pageSize));
  }

  get prevDisabled() {
    return this.loading || this.pageNumber <= 1;
  }

  get nextDisabled() {
    return this.loading || this.pageNumber >= this.totalPages;
  }

  connectedCallback() {
    this.search();
  }

  onKeywordChange(event) {
    this.keyword = event.target.value;
  }

  onFromDateChange(event) {
    this.fromDate = event.target.value;
  }

  onToDateChange(event) {
    this.toDate = event.target.value;
  }

  onStoreChange(event) {
    this.storeManaCode = event.target.value;
  }

  onSubscribedChange(event) {
    this.isSubscribed = event.detail.value;
  }

  onPageSizeChange(event) {
    this.pageSize = Number(event.detail.value);
    this.pageNumber = 1;
    this.search();
  }

  async search() {
    this.loading = true;
    try {
      const res = await search({
        keyword: this.keyword,
        fromDate: this.fromDate,
        toDate: this.toDate,
        storeManaCode: this.storeManaCode,
        isSubscribed: this.isSubscribed,
        pageSize: this.pageSize,
        pageNumber: this.pageNumber,
        sortBy: this.sortBy,
        sortDirection: this.sortDirection
      });

      this.rows = (res.records || []).map((row) => ({
        ...row,
        memberRecordUrl: row.Magazine_MemberContactId__c ? `/${row.Magazine_MemberContactId__c}` : null
      }));
      this.total = res.total || 0;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(err);
    } finally {
      this.loading = false;
    }
  }

  reset() {
    this.keyword = "";
    this.fromDate = null;
    this.toDate = null;
    this.storeManaCode = "";
    this.isSubscribed = "";
    this.pageSize = 20;
    this.pageNumber = 1;
    this.sortBy = "Magazine_Response_Time__c";
    this.sortDirection = "DESC";
    this.search();
  }

  onSort(event) {
    this.sortBy = event.detail.fieldName;
    this.sortDirection = event.detail.sortDirection;
    this.pageNumber = 1;
    this.search();
  }

  prev() {
    if (this.pageNumber > 1) {
      this.pageNumber -= 1;
      this.search();
    }
  }

  next() {
    if (this.pageNumber < this.totalPages) {
      this.pageNumber += 1;
      this.search();
    }
  }

  onRowAction(event) {
    const row = event.detail.row;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: row.Id,
        objectApiName: "TransactionJournal",
        actionName: "view"
      }
    });
  }
}
