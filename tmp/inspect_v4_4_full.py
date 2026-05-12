"""V4 (4-1~4-4) 매칭 행 전체 RequestBody/ResponseBody 출력."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_4_matched.csv"

TARGETS = {
    "a12JO000000MDcyYAG": "4-1 Order",
    "a12JO000000MDDBYA4": "4-2 Sale",
    "a12JO000000MDg9YAG": "4-3 PointCredit (에코포인트)",
    "a12JO000000MAIUYA4": "4-4 PointDebit (부분반품 추정)",
}


def pretty(s, limit=2000):
    if not s:
        return ""
    try:
        return json.dumps(json.loads(s), ensure_ascii=False, indent=2)[:limit]
    except Exception:
        return s[:limit]


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        rows = {r["Id"]: r for r in csv.DictReader(f)}
    for sf_id, label in TARGETS.items():
        rec = rows.get(sf_id)
        if not rec:
            print(f"!! {sf_id} {label} not found")
            continue
        print("=" * 100)
        print(f"{label}  /  {rec['CreatedDate']}  /  {sf_id}  /  {rec['ApexClass__c']}")
        print(f"URL : {rec['RequestUrl__c']}")
        print("--- request ---")
        print(pretty(rec["RequestBody__c"]))
        print("--- response ---")
        print(pretty(rec["ResponseBody__c"]))
        print()


if __name__ == "__main__":
    main()
