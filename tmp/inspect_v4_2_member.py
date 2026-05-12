"""V4-2 시나리오 audit trail 추출.

- 회원 103006200124 (한상희 VVIP)
- 시간 범위: 2026-05-08 09:00 ~ 12:30 KST  (UTC 00:00 ~ 03:30)
- 시나리오: V4-2 / 4-2-1 ~ 4-2-4
   * 4-2-1 : SOR202605080077, SAL202605080058, SAL202605080059
   * 4-2-2 : SAL202605080060, SAL202605080061
   * 4-2-3 : SOR202605080078, SAL202605080064 (PASS — 수선 반품 불가)
   * 4-2-4 : SOR202605080081, SAL202605080068, SAL202605080070
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "tmp" / "_v4_raw.csv"
OUT = ROOT / "tmp" / "v4_2_matched.csv"
INSPECT = ROOT / "tmp" / "_v4_2_inspect.txt"

MEMBER = "103006200124"
START_UTC = "2026-05-08T00:00:00"
END_UTC   = "2026-05-08T03:30:00"

KEYS = [
    "SOR202605080077", "SAL202605080058", "SAL202605080059",
    "SAL202605080060", "SAL202605080061",
    "SOR202605080078", "SAL202605080064", "SAL202605080065",
    "SOR202605080081", "SAL202605080068", "SAL202605080070",
]


def main():
    matched = []
    with RAW.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            cd = r.get("CreatedDate") or ""
            ts = cd[:19]
            if ts < START_UTC or ts > END_UTC:
                continue
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            if MEMBER not in req and MEMBER not in res:
                continue
            matched.append(r)
    print(f"[matched] {len(matched)} rows in time window")

    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        for r in matched:
            w.writerow(r)
    print(f"[saved] {OUT}")

    # inspect: hits per scenario key
    lines = []
    for r in matched:
        cd = r.get("CreatedDate", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c", "")
        rid = r.get("Id", "")
        body = (r.get("RequestBody__c") or "") + " | " + (r.get("ResponseBody__c") or "")
        hits = [k for k in KEYS if k in body]
        req = (r.get("RequestBody__c") or "")[:160].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  keys={hits}\n  req={req}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
