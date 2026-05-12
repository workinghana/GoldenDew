"""V5-4 시나리오 관련 audit 검색 - SOR064, SOR065, SAL266 등."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    ROOT / "tmp" / "_v4_raw.csv",
    ROOT / "tmp" / "_v4_4_refresh.csv",
    ROOT / "tmp" / "_v4_5_refresh.csv",
    ROOT / "tmp" / "_v5_1_raw.csv",
    ROOT / "tmp" / "_v5_3_raw.csv",
]

KEYS = ["SOR202605060064", "SOR202605060065", "SAL202605080266", "PRO202605041082"]
MEMBER = "173000400470"


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
    print(f"[matched] {len(rows)} unique records")
    for r in rows:
        cd = r.get("CreatedDate", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c", "")
        rid = r.get("Id", "")
        body = r.get("RequestBody__c") or ""
        hits = [k for k in KEYS if k in body or k in (r.get("ResponseBody__c") or "")]
        member_hit = MEMBER in body
        print(f"  {cd}  {rid}  {ac}\n    url={url}\n    keys={hits}  member_match={member_hit}")


if __name__ == "__main__":
    main()
