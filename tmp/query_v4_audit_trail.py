"""V4 시나리오 (회원 212501600243 신미영 SVIP) audit trail 신규 쿼리.

5/7 ~ 현재까지 전 구간 + 회원번호 필터
"""

import csv
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-07T00:00:00.000+09:00"
END = "2026-05-10T23:59:00.000+09:00"

MEMBER = "212501600243"

OUT_CSV = TMP / "_v4_raw.csv"
OUT_FILTERED = TMP / "v4_scenario_matched.csv"


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    soql_file = TMP / "_v4_query.soql"
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
    print(f"[saved-raw] {OUT_CSV} ({OUT_CSV.stat().st_size:,} bytes)")


def main():
    run_query()
    rows = []
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            if MEMBER in req or MEMBER in res:
                rows.append(r)
    print(f"[matched] {len(rows)} rows for member {MEMBER}")
    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with OUT_FILTERED.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print(f"[saved-filtered] {OUT_FILTERED}")


if __name__ == "__main__":
    main()
