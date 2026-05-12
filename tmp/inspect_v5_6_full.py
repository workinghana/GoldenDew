"""V5-6 5건 판매 audit 본문."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v5_6_matched.csv"

TARGETS = {
    "a12JO000000MCqcYAG": "A 판매 SAL278",
    "a12JO000000MGe5YAG": "B 판매 SAL281",
    "a12JO000000MDtEYAW": "C 판매 SAL283",
    "a12JO000000MKOKYA4": "D 판매 SAL285",
    "a12JO000000MKTAYA4": "E 판매 SAL288",
}


def show(rec, label):
    print("=" * 100)
    print(f"{label}  /  {rec['CreatedDate']}  /  {rec['Id']}")
    try:
        req = json.loads(rec["RequestBody__c"]) if rec.get("RequestBody__c") else {}
        keep = ["MemberNo__c", "SaleNo__c", "ActualPaymentAmount__c", "PromotionNo__c"]
        print({k: req.get(k) for k in keep if req.get(k) is not None})
        if isinstance(req.get("OrderItem"), list):
            for it in req["OrderItem"]:
                print(f"  item P={it.get('ProductCode')}  Q={it.get('Quantity')}  Net={it.get('NetSalesUnitPrice__c')}")
        if isinstance(req.get("TransactionJournal"), list):
            for t in req["TransactionJournal"]:
                print(f"  TJ DEP={t.get('DepositNo__c')}-{t.get('DeposiSeqNo__c')}  Pay={t.get('PaymentMethod')}  T={t.get('DepositType__c')}  Amt={t.get('TransactionAmount')}")
    except Exception as e:
        print(f"req parse: {e}")
    try:
        j = json.loads(rec["ResponseBody__c"])
        print(f"msg: {j.get('message')}")
        data = j.get("data") or {}
        if isinstance(data, dict):
            for key in ["CreditPointList", "DebitPointList"]:
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
            print(f"!! missing {sf_id}")
            continue
        show(rec, label)


if __name__ == "__main__":
    main()
