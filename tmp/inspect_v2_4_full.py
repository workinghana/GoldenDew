"""V2-4 매칭 행의 전체 RequestBody/ResponseBody 출력."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v2_4_matched.csv"


def pretty(s):
    if not s:
        return ""
    try:
        return json.dumps(json.loads(s), ensure_ascii=False, indent=2)
    except Exception:
        return s


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            print("=" * 100)
            print(f"Id        : {r.get('Id')}")
            print(f"CreatedAt : {r.get('CreatedDate')}")
            print(f"Apex      : {r.get('ApexClass__c')}")
            print(f"Url       : {r.get('RequestUrl__c')}")
            print("--- request ---")
            print(pretty(r.get('RequestBody__c')))
            print("--- response ---")
            print(pretty(r.get('ResponseBody__c')))
            print()


if __name__ == "__main__":
    main()
