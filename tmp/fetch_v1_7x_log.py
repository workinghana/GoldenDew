"""V1 7-x 시간 범위 추가 조회.
시간 범위: 2026-05-10 00:00 ~ 18:00 KST
"""
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-10T00:00:00.000+09:00"
END   = "2026-05-10T18:00:00.000+09:00"

OUT_CSV  = TMP / "_v1_7x_raw.csv"

def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    f = TMP / "_v1_7x_query.soql"
    f.write_text(soql, encoding="utf-8")
    cmd = [SF_CMD, "data", "query", "--file", str(f), "--target-org", TARGET_ORG, "--result-format", "csv"]
    print(f"[run] {START} ~ {END}", flush=True)
    proc = subprocess.run(cmd, capture_output=True, shell=False)
    if proc.returncode != 0:
        sys.stderr.buffer.write(proc.stderr[:3000])
        raise RuntimeError(f"sf query failed exit={proc.returncode}")
    OUT_CSV.write_bytes(proc.stdout)
    print(f"[saved] {OUT_CSV} ({OUT_CSV.stat().st_size:,} bytes)")


if __name__ == "__main__":
    if not OUT_CSV.exists():
        run_query()
    else:
        print(f"[cache] {OUT_CSV}")
