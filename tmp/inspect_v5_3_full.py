"""V5-3 핵심 audit 본문 출력."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v5_3_matched.csv"

TARGETS = {
    "a12JO000000MHgaYAG": "준비 Order SOR162 (StoreCode 99998 / 99995 인도)",
    "a12JO000000MFEzYAO": "진행(1) Sale SAL231 (품목 변경 후 첫 판매)",
    "a12JO000000MCqYYAW": "(SAL231 입금 삭제) DEP246-1",
    "a12JO000000MI6LYAW": "(SAL231 입금 삭제) DEP246-2",
    "a12JO000000MHC0YAO": "진행(2) Sale SAL250 (인도매장 99995)",
    "a12JO000000MFDLYA4": "진행(3) SAL250 판매 삭제 DEP246-1",
    "a12JO000000MIZNYA4": "진행(3) SAL250 판매 삭제 DEP246-2",
}


def show(rec, label):
    print("=" * 100)
    print(f"{label}  /  {rec['CreatedDate']}  /  {rec['Id']}  /  {rec['ApexClass__c']}  /  {rec['RequestUrl__c']}")
    try:
        req = json.loads(rec["RequestBody__c"]) if rec.get("RequestBody__c") else {}
        keep = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "ActualPaymentAmount__c",
                "PromotionNo__c", "OrderStatus__c", "SaleStatus__c", "Type", "StoreCode__c"]
        print({k: req.get(k) for k in keep if req.get(k) is not None})
        if isinstance(req.get("OrderItem"), list):
            for it in req["OrderItem"]:
                print(f"  item P={it.get('ProductCode')}  Q={it.get('Quantity')}  Net={it.get('NetSalesUnitPrice__c')}  EX={it.get('isExclude')}")
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
            if data.get("storeType"):
                print(f"  storeType: {data.get('storeType')}")
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
