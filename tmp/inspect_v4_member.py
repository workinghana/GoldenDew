"""V4 시나리오 (3-1~3-12) audit trail 추출 — 회원 103006200124 한상희 VVIP."""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "tmp" / "_v4_raw.csv"
OUT = ROOT / "tmp" / "v4_matched.csv"
INSPECT = ROOT / "tmp" / "_v4_inspect.txt"

MEMBER = "103006200124"
# V4-2 (09:59~10:52 KST = 00:59~01:52 UTC) 이후. 시나리오 설명상 「3.x」 분 단위 시각.
# 폭넓게 11:00 ~ 17:00 KST = 02:00 ~ 08:00 UTC 로 조회.
START_UTC = "2026-05-08T02:00:00"
END_UTC   = "2026-05-08T08:00:00"


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
