"""V2-4 시나리오 audit trail 추출.

- 회원 103006200153
- 시간 범위: 2026-05-08 13:23:00 KST ~ 13:34:00 KST  (UTC 04:23 ~ 04:34)
- 시나리오: [TEST] 기획행사_프로모션 / 단계 4-1 / 구매포인트 적립 10,000P
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "tmp" / "_v4_raw.csv"
OUT = ROOT / "tmp" / "v2_4_matched.csv"
INSPECT = ROOT / "tmp" / "_v2_4_inspect.txt"

MEMBER = "103006200153"
START_UTC = "2026-05-08T04:23:00"
END_UTC   = "2026-05-08T04:34:30"


def main():
    matched = []
    with RAW.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            cd = r.get("CreatedDate") or ""
            if not (START_UTC <= cd <= END_UTC + "z"):
                # CreatedDate format e.g. 2026-05-08T04:23:30.000+0000
                pass
            ts = cd[:19]
            if ts < START_UTC or ts > END_UTC:
                continue
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            if MEMBER not in req and MEMBER not in res:
                continue
            matched.append(r)

    print(f"[matched] {len(matched)} rows")
    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        for r in matched:
            w.writerow(r)
    print(f"[saved] {OUT}")

    # inspect summary
    lines = []
    for r in matched:
        cd = r.get("CreatedDate", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c", "")
        rid = r.get("Id", "")
        req = (r.get("RequestBody__c") or "")[:200].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}  {url}\n  req={req}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
