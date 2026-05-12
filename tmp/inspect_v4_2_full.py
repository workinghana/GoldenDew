"""V4-2 매칭된 10건의 RequestBody 핵심만 출력 (쿠폰 금액 확인)."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_2_matched.csv"

TARGET_IDS = {
    "a12JO000000M3QjYAK": "4-2-1-a Order  SOR202605080077",
    "a12JO000000M7HQYA0": "4-2-1-b Sale   SAL202605080058",
    "a12JO000000M7R6YAK": "4-2-1-c Return SAL202605080059",
    "a12JO000000M5QvYAK": "4-2-2-a Sale   SAL202605080060",
    "a12JO000000M7kSYAS": "4-2-2-b Return SAL202605080061",
    "a12JO000000M5NmYAK": "4-2-3-a Order  SOR202605080078",
    "a12JO000000M85QYAS": "4-2-3-b Sale   SAL202605080064",
    "a12JO000000M8OmYAK": "4-2-4-a Order  SOR202605080081",
    "a12JO000000M3QnYAK": "4-2-4-b Sale   SAL202605080068",
    "a12JO000000M6YJYA0": "4-2-4-c Return SAL202605080070",
}


def summarize(body):
    if not body:
        return ""
    try:
        d = json.loads(body)
    except Exception:
        return body[:300]
    keep_keys = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "Type",
                 "ActualPaymentAmount__c", "PromotionNo__c", "StoreCode__c", "AccountId"]
    out = {k: d.get(k) for k in keep_keys if d.get(k) is not None}
    if isinstance(d.get("OrderItem"), list):
        items = []
        for it in d["OrderItem"]:
            items.append({
                "ProductCode": it.get("ProductCode"),
                "Quantity": it.get("Quantity"),
                "Net": it.get("NetSalesUnitPrice__c"),
            })
        out["OrderItem"] = items
    if isinstance(d.get("TransactionJournal"), list):
        tjs = []
        for t in d["TransactionJournal"]:
            tjs.append({
                "DepositNo": t.get("DepositNo__c"),
                "Seq": t.get("DeposiSeqNo__c"),
                "Pay": t.get("PaymentMethod"),
                "Type": t.get("DepositType__c"),
                "Amount": t.get("TransactionAmount"),
                "Coupon": t.get("CouponNo"),
            })
        out["TransactionJournal"] = tjs
    return json.dumps(out, ensure_ascii=False, indent=2)


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        rows = {r["Id"]: r for r in csv.DictReader(f)}
    for sf_id, label in TARGET_IDS.items():
        rec = rows.get(sf_id)
        if not rec:
            print(f"!! missing: {sf_id} {label}")
            continue
        print("=" * 100)
        print(f"{label}  /  {rec['CreatedDate']}  /  {sf_id}")
        print(summarize(rec["RequestBody__c"]))
        # Try to extract coupon-related response info
        try:
            r = json.loads(rec["ResponseBody__c"])
            data = r.get("data") or {}
            if isinstance(data, dict):
                interesting = {}
                if data.get("CreditPointList"):
                    interesting["CreditPointList"] = [
                        {"PT_TARGET": x.get("PT_TARGET"), "TX_REMARK": x.get("TX_REMARK"),
                         "CD_TYPE_POINT": x.get("CD_TYPE_POINT"), "CD_TYPE_SAVE": x.get("CD_TYPE_SAVE")}
                        for x in data["CreditPointList"]
                    ]
                if data.get("DebitPointList"):
                    interesting["DebitPointList"] = [
                        {"PT_USE": x.get("PT_USE"), "CD_TYPE_POINT": x.get("CD_TYPE_POINT"),
                         "CD_TYPE_SAVE": x.get("CD_TYPE_SAVE")}
                        for x in data["DebitPointList"]
                    ]
                if interesting:
                    print("[response]", json.dumps(interesting, ensure_ascii=False))
                print("[message]", r.get("message"))
        except Exception:
            pass
        print()


if __name__ == "__main__":
    main()
