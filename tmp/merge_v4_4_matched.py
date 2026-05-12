"""V4 (4-1~4-4) matched.csv 를 refresh 데이터와 병합."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
RAW = TMP / "_v4_4_refresh.csv"
OUT = TMP / "v4_4_matched.csv"

MEMBER = "123002600463"


def main():
    rows = []
    with RAW.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            if MEMBER in req or MEMBER in res:
                rows.append(r)
    print(f"[matched] {len(rows)} rows")
    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print(f"[saved] {OUT}")


if __name__ == "__main__":
    main()
