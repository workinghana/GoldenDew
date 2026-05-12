"""V4-7 시나리오 감지 — 회원 123002600463 / 특정 SOR/SAL 번호 매칭."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    ROOT / "tmp" / "v4_6_matched.csv",  # already filtered for member 123002600463
    ROOT / "tmp" / "_v4_4_refresh.csv",
    ROOT / "tmp" / "_v4_5_refresh.csv",
    ROOT / "tmp" / "_v4_raw.csv",
]
KEYS = ["SOR202605080147", "SAL202605080164", "SAL202605080167", "SAL202605080170"]


def main():
    seen = set()
    rows = []
    for src in SOURCES:
        if not src.exists():
            continue
        with src.open("r", encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                if r["Id"] in seen:
                    continue
                req = r.get("RequestBody__c") or ""
                res = r.get("ResponseBody__c") or ""
                if any(k in req or k in res for k in KEYS):
                    seen.add(r["Id"])
                    rows.append(r)
    rows.sort(key=lambda r: r.get("CreatedDate", ""))
    print(f"[matched] {len(rows)} records mention any V4-7 key")
    for r in rows:
        cd = r.get("CreatedDate", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c", "")
        rid = r.get("Id", "")
        body = r.get("RequestBody__c") or ""
        hits = [k for k in KEYS if k in body or k in (r.get("ResponseBody__c") or "")]
        print(f"  {cd}  {rid}  {ac}\n    url={url}\n    hits={hits}")


if __name__ == "__main__":
    main()
