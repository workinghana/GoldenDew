"""V5-3 시나리오 audit 추출 — 회원 133005100137 (다른 회원)."""
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-08T15:00:00.000+09:00"  # 06:00 UTC
END   = "2026-05-08T18:30:00.000+09:00"  # 09:30 UTC

OUT_CSV = TMP / "_v5_3_raw.csv"
MATCHED = TMP / "v5_3_matched.csv"
INSPECT = TMP / "_v5_3_inspect.txt"

MEMBER = "133005100137"


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    soql_file = TMP / "_v5_3_query.soql"
    soql_file.write_text(soql, encoding="utf-8")
    cmd = [SF_CMD, "data", "query", "--file", str(soql_file),
           "--target-org", TARGET_ORG, "--result-format", "csv"]
    print(f"[run] sf data query (range {START} ~ {END})", flush=True)
    proc = subprocess.run(cmd, capture_output=True, shell=False)
    if proc.returncode != 0:
        sys.stderr.buffer.write(proc.stderr[:3000])
        raise RuntimeError(f"sf query failed (exit {proc.returncode})")
    OUT_CSV.write_bytes(proc.stdout)
    print(f"[saved-raw] {OUT_CSV} ({OUT_CSV.stat().st_size:,} bytes)")


def main():
    run_query()
    rows = []
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            if MEMBER in req or MEMBER in res:
                rows.append(r)
    rows.sort(key=lambda r: r.get("CreatedDate", ""))
    print(f"[matched] {len(rows)} for {MEMBER}")

    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with MATCHED.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)

    lines = []
    for r in rows:
        cd = r.get("CreatedDate", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c", "")
        rid = r.get("Id", "")
        body = (r.get("RequestBody__c") or "")[:250].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  req={body}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
