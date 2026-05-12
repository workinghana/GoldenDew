import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "scenario2_matched.csv"

KEY_FIELDS = [
    "SaleNo__c", "OrderNo__c", "OriginalOrderId", "OriginalOrderId__c",
    "originalOrderId", "orderId", "ActualPaymentAmount__c",
    "MemberNo__c", "F_MemberNo__c",
    "OrderStatus__c", "SaleStatus__c", "DeleteDateTime__c",
    "code", "success", "message",
    "PT_TARGET", "TX_REMARK",
    "DepositNo__c", "DepositType__c", "TransactionAmount", "PaymentMethod",
    "CouponNo", "couponNo", "CD_TYPE_POINT", "Quantity",
]


def short(v, n=200):
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
        return {"_raw": short(text, 200)}

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


# 시나리오 2의 액션 로그 후보: 본 거래 등록/수정/삭제/반품 — 회원도움창 등 보조 호출 제외
PRIMARY_CLASSES = {
    "GdOrderApiControllerV1",
    "GdSaleApiControllerV1",
    "GdReturnApiControllerV1",
    "GdSaleDeleteApiControllerV1",
    "GdSaleDeleteBranchHandler",
    "GdReturnApiControllerV2",
    "GdSaleApiControllerV2",
    "GdOrderApiControllerV2",
    "GdPointCreditApiControllerV1",
    "GdPointDebitApiControllerV1",
    "GdMemberApiControllerV1",
    "GdMemberApiControllerV2",
}

with SRC.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

rows.sort(key=lambda r: (str(r.get("CreatedDate") or ""), str(r.get("Id") or "")))

print(f"[total matched] {len(rows)}")
print()
print("=" * 100)
print("PRIMARY ACTION ROWS")
print("=" * 100)

primary = []
for r in rows:
    if r.get("ApexClass__c") in PRIMARY_CLASSES:
        primary.append(r)

for i, r in enumerate(primary, start=1):
    print()
    print(f"[{i:>2}] {r['CreatedDate']}  Id={r['Id']}")
    print(f"     ApexClass = {r['ApexClass__c']}")
    print(f"     URL       = {short(r['RequestUrl__c'], 80)}")
    print(f"     Hits      = {r['_hits']}")
    rk = extract(r['RequestBody__c'])
    sk = extract(r['ResponseBody__c'])
    print(f"     Req       : {rk}")
    print(f"     Res       : {sk}")
