"""V5-1 핵심 audit 본문 출력."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v5_1_matched.csv"

TARGETS = {
    "a12JO000000MHBwYAO": "사전(1)(2) Order SOR160",
    "a12JO000000MFGbYAO": "사전(3) Sale SAL213",
    "a12JO000000MFZuYAO": "사전(4) PointCredit 에코 6000P",
    "a12JO000000MHjoYAG": "진행(1) Return SAL222 부분반품",
    "a12JO000000MHoeYAG": "진행(2-1/2-2) Return SAL227 시도",
    "a12JO000000MH78YAG": "진행(2-1/2-2) DELETE SAL227",
    "a12JO000000MDd4YAG": "진행(2-3) Return SAL229 PASS",
}


def show(rec, label):
    print("=" * 100)
    print(f"{label}  /  {rec['CreatedDate']}  /  {rec['Id']}  /  {rec['ApexClass__c']}  /  {rec['RequestUrl__c']}")
    try:
        req = json.loads(rec["RequestBody__c"]) if rec.get("RequestBody__c") else {}
        keep = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "OriginalOrderId",
                "ActualPaymentAmount__c", "PromotionNo__c", "OrderStatus__c",
                "SaleStatus__c", "PointsList"]
        print({k: req.get(k) for k in keep if req.get(k) is not None})
        if isinstance(req.get("OrderItem"), list):
            for it in req["OrderItem"]:
                print(f"  item P={it.get('ProductCode')}  Q={it.get('Quantity')}  Net={it.get('NetSalesUnitPrice__c')}")
        if isinstance(req.get("TransactionJournal"), list):
            for t in req["TransactionJournal"]:
                print(f"  TJ DEP={t.get('DepositNo__c')}-{t.get('DeposiSeqNo__c')}  Pay={t.get('PaymentMethod')}  T={t.get('DepositType__c')}  Amt={t.get('TransactionAmount')}  Coup={t.get('CouponNo')}")
    except Exception as e:
        print(f"req parse: {e}")
    try:
        j = json.loads(rec["ResponseBody__c"])
        print(f"msg: {j.get('message')}  / success: {j.get('success')}  / code: {j.get('code')}")
        data = j.get("data") or {}
        if isinstance(data, dict):
            for key in ["CreditPointList", "DebitPointList", "CancelPointsCreditedList", "PointCreditList"]:
                if data.get(key):
                    print(f"  [{key}]")
                    for x in data[key]:
                        print(f"    PT={x.get('PT_TARGET') or x.get('PT_USE')}  CD={x.get('CD_TYPE_POINT')}  RM={x.get('TX_REMARK')}")
    except Exception:
        pass
    print()


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        rows = {r["Id"]: r for r in csv.DictReader(f)}
    for sf_id, label in TARGETS.items():
        rec = rows.get(sf_id)
        if not rec:
            print(f"!! missing {sf_id} {label}")
            continue
        show(rec, label)


if __name__ == "__main__":
    main()
