import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_scenario_matched.csv"

KEY_FIELDS = [
    "SaleNo__c", "OrderNo__c", "OriginalOrderId", "originalOrderId", "orderId",
    "ActualPaymentAmount__c", "MemberNo__c",
    "OrderStatus__c", "SaleStatus__c",
    "code", "success", "message",
    "PT_TARGET", "TX_REMARK", "CD_TYPE_POINT", "CD_TYPE_SAVE",
    "DepositNo__c", "DepositType__c", "TransactionAmount", "PaymentMethod",
    "CouponNo", "Quantity", "PromotionId", "promotionNo", "PromotionNo__c",
    "PointDebitList", "PointCreditList",
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


with SRC.open("r", encoding="utf-8", newline="") as f:
    rows = list(csv.DictReader(f))

rows.sort(key=lambda r: (str(r.get("CreatedDate") or ""), str(r.get("Id") or "")))

print(f"[total] {len(rows)} rows for member 212501600243")
for i, r in enumerate(rows, start=1):
    print()
    print("=" * 100)
    print(f"[{i:>2}] {r['CreatedDate']}  Id={r['Id']}")
    print(f"     ApexClass = {r['ApexClass__c']}")
    print(f"     URL       = {short(r['RequestUrl__c'], 120)}")
    rk = extract(r['RequestBody__c'])
    sk = extract(r['ResponseBody__c'])
    print(f"     Req       : {rk}")
    print(f"     Res       : {sk}")
