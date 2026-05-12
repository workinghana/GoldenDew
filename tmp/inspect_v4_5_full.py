"""V4 (5-1~5-5) primary action 전체 본문 출력."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_5_matched.csv"

TARGETS = [
    "a12JO000000LwM4YAK",  # 5-1 Sale 1
    "a12JO000000LwsDYAS",  # 5-2 PointCredit 9000
    "a12JO000000LvOLYA0",  # 5-3a Return 1
    "a12JO000000Lv6dYAC",  # 5-3b Return 2
    "a12JO000000LrHWYA0",  # 5-4 Return 3 (통반품 추정)
    "a12JO000000LwyoYAC",  # 5-5 Sale 2 재판매
]


def summarize(body, full=False):
    if not body:
        return ""
    try:
        d = json.loads(body)
    except Exception:
        return body[:500]
    if full:
        return json.dumps(d, ensure_ascii=False, indent=2)[:3500]
    keep = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "OriginalOrderId", "Type",
            "OrderStatus__c", "SaleStatus__c", "PointsList",
            "ActualPaymentAmount__c", "PromotionNo__c", "StoreCode__c"]
    out = {k: d.get(k) for k in keep if d.get(k) is not None}
    if isinstance(d.get("OrderItem"), list):
        out["OrderItem"] = [
            {"P": it.get("ProductCode"), "Q": it.get("Quantity"),
             "Net": it.get("NetSalesUnitPrice__c"), "DR": it.get("DiscountRate__c"),
             "EX": it.get("isExclude")}
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
        rows = {r["Id"]: r for r in csv.DictReader(f)}
    for sf_id in TARGETS:
        rec = rows.get(sf_id)
        if not rec:
            print(f"!! missing {sf_id}")
            continue
        print("=" * 100)
        print(f"{sf_id}  /  {rec['CreatedDate']}  /  {rec['ApexClass__c']}")
        print(f"URL : {rec['RequestUrl__c']}")
        print("--- request ---")
        print(summarize(rec["RequestBody__c"]))
        print("--- response (msg, credit/debit) ---")
        try:
            j = json.loads(rec["ResponseBody__c"])
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
                        {"PT": x.get("PT_USE"), "CD": x.get("CD_TYPE_POINT")}
                        for x in data["DebitPointList"]
                    ]
                if data.get("CancelPointsCreditedList"):
                    ip["Cancel"] = [
                        {"PT": x.get("PT_USE"), "CD": x.get("CD_TYPE_POINT")}
                        for x in data["CancelPointsCreditedList"]
                    ]
                if data.get("PointCreditList"):
                    ip["PCredit"] = [
                        {"PT": x.get("PT_TARGET"), "RM": x.get("TX_REMARK"), "CD": x.get("CD_TYPE_POINT")}
                        for x in data["PointCreditList"]
                    ]
            print(f"msg : {j.get('message')}  /  success: {j.get('success')}  /  code: {j.get('code')}")
            if ip:
                print(json.dumps(ip, ensure_ascii=False))
        except Exception:
            print(rec["ResponseBody__c"][:500])
        print()


if __name__ == "__main__":
    main()
