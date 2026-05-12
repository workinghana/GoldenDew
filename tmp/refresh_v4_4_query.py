"""V4 (4-1~4-4) 회원 123002600463 의 최신 audit trail 신규 쿼리.

오늘 분(2026-05-08) 만 다시 조회 — 캐시 후의 추가 record 보정.
"""

import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-08T14:00:00.000+09:00"
END   = "2026-05-08T23:59:00.000+09:00"

OUT_CSV = TMP / "_v4_4_refresh.csv"


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    soql_file = TMP / "_v4_4_query.soql"
    soql_file.write_text(soql, encoding="utf-8")
    cmd = [
        SF_CMD, "data", "query",
        "--file", str(soql_file),
        "--target-org", TARGET_ORG,
        "--result-format", "csv",
    ]
    print(f"[run] sf data query (range {START} ~ {END})", flush=True)
    proc = subprocess.run(cmd, capture_output=True, shell=False)
    if proc.returncode != 0:
        sys.stderr.buffer.write(proc.stdout[:4000])
        sys.stderr.buffer.write(b"\n")
        sys.stderr.buffer.write(proc.stderr[:4000])
        raise RuntimeError(f"sf query failed (exit {proc.returncode})")
    OUT_CSV.write_bytes(proc.stdout)
    print(f"[saved] {OUT_CSV} ({OUT_CSV.stat().st_size:,} bytes)")


def main():
    run_query()
    member = "123002600463"
    matched = []
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            if member in req or member in res:
                matched.append(r)
    print(f"[matched] {len(matched)} new rows for member {member}")
    for r in matched:
        cd = r.get("CreatedDate", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c", "")
        rid = r.get("Id", "")
        print(f"  {cd}  {rid}  {ac}  {url}")


if __name__ == "__main__":
    main()
