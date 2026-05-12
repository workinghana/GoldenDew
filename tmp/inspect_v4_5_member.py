"""V4 (5-1~5-5) 시나리오 audit trail 추출 — 회원 173000400470 VVIP."""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW1 = ROOT / "tmp" / "_v4_raw.csv"
RAW2 = ROOT / "tmp" / "_v4_4_refresh.csv"
OUT = ROOT / "tmp" / "v4_5_matched.csv"
INSPECT = ROOT / "tmp" / "_v4_5_inspect.txt"

MEMBER = "173000400470"


def collect(src):
    rows = []
    if not src.exists():
        return rows
    with src.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            if MEMBER in req or MEMBER in res:
                rows.append(r)
    return rows


def main():
    seen = set()
    matched = []
    for src in (RAW1, RAW2):
        for r in collect(src):
            if r["Id"] in seen:
                continue
            seen.add(r["Id"])
            matched.append(r)
    matched.sort(key=lambda r: r.get("CreatedDate", ""))
    print(f"[matched] {len(matched)} unique rows")

    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        for r in matched:
            w.writerow(r)
    print(f"[saved] {OUT}")

    lines = []
    for r in matched:
        cd = r.get("CreatedDate", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c", "")
        rid = r.get("Id", "")
        req = (r.get("RequestBody__c") or "")[:200].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  req={req}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
