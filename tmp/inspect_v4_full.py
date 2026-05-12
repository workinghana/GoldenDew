"""V4 시나리오 (3-1~3-12) primary action 의 전체 RequestBody 핵심 출력."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_matched.csv"

# Order create/update, Sale, Return, PointDebit 등 primary 만
PRIMARY_PREFIX = ("/gd/v1/order", "/gd/v1/sale", "/gd/v1/return")
PRIMARY_APEX_TOKENS = ("PointDebit", "PointCredit", "SaleDeposit", "ReturnDeposit", "OrderApi", "SaleApi", "ReturnApi", "PointHelp")


def summarize(body):
    if not body:
        return ""
    try:
        d = json.loads(body)
    except Exception:
        return body[:300]
    keep = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "OriginalOrderId", "Type",
            "OrderStatus__c", "SaleStatus__c",
            "ActualPaymentAmount__c", "PromotionNo__c", "StoreCode__c", "AccountId"]
    out = {k: d.get(k) for k in keep if d.get(k) is not None}
    if isinstance(d.get("OrderItem"), list):
        out["OrderItem"] = [
            {"P": it.get("ProductCode"), "Q": it.get("Quantity"),
             "Net": it.get("NetSalesUnitPrice__c")}
            for it in d["OrderItem"]
        ]
    if isinstance(d.get("TransactionJournal"), list):
        out["TJ"] = [
            {"DEP": t.get("DepositNo__c"), "S": t.get("DeposiSeqNo__c"),
             "Pay": t.get("PaymentMethod"), "T": t.get("DepositType__c"),
             "Amt": t.get("TransactionAmount"), "Coup": t.get("CouponNo")}
            for t in d["TransactionJournal"]
        ]
    return json.dumps(out, ensure_ascii=False, indent=1)


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    rows.sort(key=lambda r: r.get("CreatedDate", ""))

    for r in rows:
        url = r.get("RequestUrl__c") or ""
        apex = r.get("ApexClass__c") or ""
        if not url.startswith(PRIMARY_PREFIX) and not any(t in apex for t in PRIMARY_APEX_TOKENS):
            continue
        print("=" * 100)
        print(f"{r['CreatedDate']}  /  {r['Id']}  /  {apex}  /  {url}")
        print(summarize(r["RequestBody__c"]))
        # response: only credit/debit point + message
        try:
            j = json.loads(r["ResponseBody__c"])
            data = j.get("data") or {}
            ip = {}
            if isinstance(data, dict):
                if data.get("CreditPointList"):
                    ip["Credit"] = [
                        {"PT": x.get("PT_TARGET"), "RM": x.get("TX_REMARK"),
                         "CD": x.get("CD_TYPE_POINT"), "SAVE": x.get("CD_TYPE_SAVE")}
                        for x in data["CreditPointList"]
                    ]
                if data.get("DebitPointList"):
                    ip["Debit"] = [
                        {"PT": x.get("PT_USE"), "CD": x.get("CD_TYPE_POINT"),
                         "SAVE": x.get("CD_TYPE_SAVE")}
                        for x in data["DebitPointList"]
                    ]
                if data.get("OrderStatus__c"):
                    ip["OrderStatus"] = data.get("OrderStatus__c")
                if data.get("SaleStatus__c"):
                    ip["SaleStatus"] = data.get("SaleStatus__c")
            if ip:
                print("[resp]", json.dumps(ip, ensure_ascii=False))
            print("[msg ]", j.get("message"))
            print("[code]", j.get("code"), "/ success=", j.get("success"))
        except Exception:
            pass
        print()


if __name__ == "__main__":
    main()
