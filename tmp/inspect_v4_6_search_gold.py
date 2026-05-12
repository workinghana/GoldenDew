"""V4-6 골드바 시나리오 후보 audit 검색 — 회원 123002600463 의 5/7 ~ 5/8 sale/order 중 후속 테스트들."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_6_matched.csv"


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    rows.sort(key=lambda r: r["CreatedDate"])

    # focus on records AFTER V4 4-4 (05:19:03) — 5-x candidates
    for r in rows:
        cd = r.get("CreatedDate", "")
        if cd[:19] < "2026-05-08T05:22":
            continue
        if cd[:19] > "2026-05-08T07:00":
            continue
        url = r.get("RequestUrl__c") or ""
        if not (url.startswith("/gd/v1/order") or url.startswith("/gd/v1/sale") or
                url.startswith("/gd/v1/return") or url.startswith("/gd/v1/point/credit")):
            continue
        print("=" * 100)
        print(f"{cd}  /  {r['Id']}  /  {r['ApexClass__c']}  /  {url}")
        try:
            req = json.loads(r["RequestBody__c"]) if r.get("RequestBody__c") else {}
            keep = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "OriginalOrderId",
                    "ActualPaymentAmount__c", "PromotionNo__c", "OrderStatus__c",
                    "PointsList"]
            print({k: req.get(k) for k in keep if req.get(k) is not None})
            if isinstance(req.get("OrderItem"), list):
                for it in req["OrderItem"]:
                    print(f"  item: P={it.get('ProductCode')}  Q={it.get('Quantity')}  "
                          f"Net={it.get('NetSalesUnitPrice__c')}  DR={it.get('DiscountRate__c')}")
            if isinstance(req.get("TransactionJournal"), list):
                for t in req["TransactionJournal"]:
                    print(f"  TJ: DEP={t.get('DepositNo__c')}-{t.get('DeposiSeqNo__c')} Pay={t.get('PaymentMethod')} T={t.get('DepositType__c')} Amt={t.get('TransactionAmount')}")
        except Exception as e:
            print(f"req parse fail: {e}")
        try:
            j = json.loads(r["ResponseBody__c"])
            print(f"msg: {j.get('message')}  / success: {j.get('success')}")
            data = j.get("data") or {}
            if isinstance(data, dict):
                if data.get("CreditPointList"):
                    for x in data["CreditPointList"]:
                        print(f"  credit: PT={x.get('PT_TARGET')}  RM={x.get('TX_REMARK')}  CD={x.get('CD_TYPE_POINT')}")
                if data.get("DebitPointList"):
                    for x in data["DebitPointList"]:
                        print(f"  debit:  PT={x.get('PT_USE')}  CD={x.get('CD_TYPE_POINT')}")
                if data.get("CancelPointsCreditedList"):
                    for x in data["CancelPointsCreditedList"]:
                        print(f"  cancel: PT={x.get('PT_USE')}  CD={x.get('CD_TYPE_POINT')}")
                if data.get("PointCreditList"):
                    for x in data["PointCreditList"]:
                        print(f"  pcredit: PT={x.get('PT_TARGET')}  RM={x.get('TX_REMARK')}  CD={x.get('CD_TYPE_POINT')}")
                if data.get("isGoldenBar") is not None:
                    print(f"  isGoldenBar: {data.get('isGoldenBar')}")
        except Exception:
            pass


if __name__ == "__main__":
    main()
