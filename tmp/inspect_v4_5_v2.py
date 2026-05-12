"""V4 5-x : 늦은 sale (06:39+ UTC) 들이 실제 5-x 테스트인지 확인."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_5_matched.csv"


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    rows.sort(key=lambda r: r["CreatedDate"])
    # focus on 2026-05-08T06:00 ~ 08:00 (= 15~17 KST)
    for r in rows:
        cd = r.get("CreatedDate", "")
        if cd[:13] not in ("2026-05-08T06", "2026-05-08T07"):
            continue
        url = r.get("RequestUrl__c") or ""
        if not (url.startswith("/gd/v1/order") or url.startswith("/gd/v1/sale") or
                url.startswith("/gd/v1/return") or url.startswith("/gd/v1/point")):
            continue
        print("=" * 100)
        print(f"{cd}  /  {r['Id']}  /  {r['ApexClass__c']}  /  {url}")
        try:
            req = json.loads(r["RequestBody__c"]) if r.get("RequestBody__c") else {}
            keep = ["MemberNo__c", "OrderNo__c", "SaleNo__c", "OriginalOrderId",
                    "ActualPaymentAmount__c", "PromotionNo__c", "OrderStatus__c"]
            print({k: req.get(k) for k in keep if req.get(k) is not None})
        except Exception:
            pass
        try:
            j = json.loads(r["ResponseBody__c"])
            print(f"msg: {j.get('message')}")
            data = j.get("data") or {}
            if isinstance(data, dict):
                if data.get("CreditPointList"):
                    cl = [(x.get("PT_TARGET"), x.get("TX_REMARK"), x.get("CD_TYPE_POINT")) for x in data["CreditPointList"]]
                    print(f"credits: {cl}")
                if data.get("DebitPointList"):
                    dl = [(x.get("PT_USE"), x.get("CD_TYPE_POINT")) for x in data["DebitPointList"]]
                    print(f"debits: {dl}")
                if data.get("CancelPointsCreditedList"):
                    cl = [(x.get("PT_USE"), x.get("CD_TYPE_POINT")) for x in data["CancelPointsCreditedList"]]
                    print(f"cancels: {cl}")
        except Exception:
            pass


if __name__ == "__main__":
    main()
