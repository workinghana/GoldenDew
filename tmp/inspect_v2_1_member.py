"""V2-1 시나리오 (회원 103006200153) audit trail 추출/검사."""

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "tmp" / "_v4_raw.csv"  # 5/7~5/10 KST 전체
OUT = ROOT / "tmp" / "v2_1_matched.csv"
MEMBER = "103006200153"

KEY_FIELDS = [
    "SaleNo__c", "OrderNo__c", "OriginalOrderId", "originalOrderId", "orderId",
    "ActualPaymentAmount__c", "MemberNo__c",
    "OrderStatus__c", "SaleStatus__c",
    "code", "success", "message",
    "PT_TARGET", "TX_REMARK", "CD_TYPE_POINT", "CD_TYPE_SAVE",
    "DepositNo__c", "DepositType__c", "TransactionAmount", "PaymentMethod",
    "CouponNo", "Quantity", "PromotionId", "promotionNo", "PromotionNo__c",
]


def short(v, n=300):
    s = json.dumps(v, ensure_ascii=False) if not isinstance(v, str) else v
    s = s.replace("\n", " ")
    return s if len(s) <= n else s[:n] + "..."


def extract(text):
    if not text:
        return {}
    out = {}
    try:
        obj = json.loads(text)
    except Exception:
        return {"_raw": short(text, 240)}

    def walk(node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k in KEY_FIELDS and k not in out:
                    out[k] = v
                if isinstance(v, (dict, list)):
                    walk(v)
        elif isinstance(node, list):
            for item in node[:3]:
                walk(item)
    walk(obj)
    return out


rows = []
with RAW.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f)
    for r in reader:
        req = r.get("RequestBody__c") or ""
        res = r.get("ResponseBody__c") or ""
        if MEMBER in req or MEMBER in res:
            rows.append(r)

rows.sort(key=lambda r: (str(r.get("CreatedDate") or ""), str(r.get("Id") or "")))
print(f"[matched] {len(rows)} rows for member {MEMBER}")

# 저장
out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
with OUT.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
    w.writeheader()
    for r in rows:
        w.writerow(r)
print(f"[saved] {OUT}")

print()
for i, r in enumerate(rows, start=1):
    print("=" * 100)
    print(f"[{i:>2}] {r['CreatedDate']}  Id={r['Id']}")
    print(f"     ApexClass = {r['ApexClass__c']}")
    print(f"     URL       = {short(r['RequestUrl__c'], 100)}")
    rk = extract(r['RequestBody__c'])
    sk = extract(r['ResponseBody__c'])
    print(f"     Req       : {rk}")
    print(f"     Res       : {sk}")
