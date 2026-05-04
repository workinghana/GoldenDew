import { LightningElement, wire, api } from "lwc";
import getMemberHistory from "@salesforce/apex/MemberHistoryUIController.getMemberHistory";

export default class MemberHistory extends LightningElement {
  @api recordId;

  histories;
  error;

  columns = [
    {
      label: "변경일시",
      fieldName: "changeDate",
      type: "date",
      typeAttributes: {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit"
      }
    },
    {
      label: "변경 항목",
      fieldName: "fieldName",
      type: "text"
    },
    {
      label: "변경 전 값",
      fieldName: "oldValue",
      type: "text",
      wrapText: true
    },
    {
      label: "변경 후 값",
      fieldName: "newValue",
      type: "text",
      wrapText: true
    }
  ];

  @wire(getMemberHistory, { loyaltyProgramMemberId: "$recordId" })
  wiredHistory({ data, error }) {
    if (data) {
      this.histories = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.histories = undefined;
      console.error("회원 변경 이력 조회 오류", error);
    }
  }
}
