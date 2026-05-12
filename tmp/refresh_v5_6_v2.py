"""V5-6 v2 회원 269999800214 의 최신 audit 추가 조회 (08:26 ~)."""
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-08T17:25:00.000+09:00"   # 08:25 UTC
END   = "2026-05-08T23:59:00.000+09:00"   # 14:59 UTC

OUT_CSV = TMP / "_v5_6_v2_refresh.csv"
MEMBER = "269999800214"


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    soql_file = TMP / "_v5_6_v2_query.soql"
    soql_file.write_text(soql, encoding="utf-8")
    cmd = [SF_CMD, "data", "query", "--file", str(soql_file),
           "--target-org", TARGET_ORG, "--result-format", "csv"]
    print(f"[run] sf data query {START} ~ {END}", flush=True)
    proc = subprocess.run(cmd, capture_output=True, shell=False)
    if proc.returncode != 0:
        sys.stderr.buffer.write(proc.stderr[:3000])
        raise RuntimeError(f"sf query failed exit={proc.returncode}")
    OUT_CSV.write_bytes(proc.stdout)
    print(f"[saved] {OUT_CSV} ({OUT_CSV.stat().st_size:,} bytes)")


def main():
    run_query()
    matched = []
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            text = (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "") + (r.get("RequestUrl__c") or "")
            if MEMBER in text:
                matched.append(r)
    print(f"[matched] {len(matched)} records for {MEMBER}")
    for r in matched:
        cd = r.get("CreatedDate", "")[:19]
        if cd < "2026-05-08T08:26":
            continue
        print(f"  {cd}  {r['Id']}  {r['ApexClass__c']}  {r['RequestUrl__c']}")


if __name__ == "__main__":
    main()
