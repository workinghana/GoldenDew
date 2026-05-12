"""V4 (4-1~4-4) 의 Return 후속 record (05:19:03) 본문 확인."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "v4_4_matched.csv"

TARGET = "a12JO000000MDOWYA4"  # 4-4 first Return


def main():
    with SRC.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            if r["Id"] != TARGET:
                continue
            print(f"{r['CreatedDate']}  /  {r['ApexClass__c']}  /  {r['RequestUrl__c']}")
            print("--- request ---")
            try:
                print(json.dumps(json.loads(r["RequestBody__c"]), ensure_ascii=False, indent=2))
            except Exception:
                print(r["RequestBody__c"])
            print("--- response ---")
            try:
                print(json.dumps(json.loads(r["ResponseBody__c"]), ensure_ascii=False, indent=2)[:3500])
            except Exception:
                print(r["ResponseBody__c"][:3500])


if __name__ == "__main__":
    main()
