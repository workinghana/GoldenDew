"""V4-7 audit 본문 확인."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "_v4_4_refresh.csv"

TARGETS = [
    "a12JO000000MEPRYA4",  # 05:43:12 first Order SOR147
    "a12JO000000MEsOYAW",  # 05:47:38 Sale SAL164
    "a12JO000000MEyqYAG",  # 05:49:31 Sale SAL167
    "a12JO000000MF24YAG",  # 05:50:56 Return mentioning SAL167
    "a12JO000000MDDFYA4",  # 05:51:59 Return SAL170
]


def show(rec):
    cd = rec["CreatedDate"]
    rid = rec["Id"]
    ac = rec["ApexClass__c"]
    url = rec["RequestUrl__c"]
    print("=" * 100)
    print(f"{cd}  /  {rid}  /  {ac}  /  {url}")
    try:
        req = json.loads(rec["RequestBody__c"]) if rec.get("RequestBody__c") else {}
        keep = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "OriginalOrderId",
                "ActualPaymentAmount__c", "PromotionNo__c", "OrderStatus__c",
                "SaleStatus__c", "Type", "StoreCode__c"]
        print({k: req.get(k) for k in keep if req.get(k) is not None})
        if isinstance(req.get("OrderItem"), list):
            for it in req["OrderItem"]:
                print(f"  item P={it.get('ProductCode')}  Q={it.get('Quantity')}  Net={it.get('NetSalesUnitPrice__c')}  DR={it.get('DiscountRate__c')}")
        if isinstance(req.get("TransactionJournal"), list):
            for t in req["TransactionJournal"]:
                print(f"  TJ DEP={t.get('DepositNo__c')}-{t.get('DeposiSeqNo__c')}  Pay={t.get('PaymentMethod')}  T={t.get('DepositType__c')}  Amt={t.get('TransactionAmount')}  Coup={t.get('CouponNo')}")
    except Exception as e:
        print(f"req parse fail: {e}")
    try:
        j = json.loads(rec["ResponseBody__c"])
        print(f"msg: {j.get('message')}  / success: {j.get('success')}  / code: {j.get('code')}")
        data = j.get("data") or {}
        if isinstance(data, dict):
            for key in ["CreditPointList", "DebitPointList", "CancelPointsCreditedList"]:
                if data.get(key):
                    print(f"  [{key}]")
                    for x in data[key]:
                        print(f"    PT={x.get('PT_TARGET') or x.get('PT_USE')}  CD={x.get('CD_TYPE_POINT')}  RM={x.get('TX_REMARK')}")
            if data.get("isGoldenBar") is not None:
                print(f"  isGoldenBar: {data.get('isGoldenBar')}")
            if data.get("storeType"):
                print(f"  storeType: {data.get('storeType')}")
    except Exception:
        pass
    print()


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        rows = {r["Id"]: r for r in csv.DictReader(f)}
    for tid in TARGETS:
        rec = rows.get(tid)
        if not rec:
            print(f"!! {tid} not found")
            continue
        show(rec)


if __name__ == "__main__":
    main()
