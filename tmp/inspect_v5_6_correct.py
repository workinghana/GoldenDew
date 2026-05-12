"""V5-6 정확한 시나리오 (회원 TEST02007 / SOR04010, SAL04043, SAL04114, SAL04115) audit 추출."""
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-09T00:00:00.000+09:00"
END   = "2026-05-09T23:59:00.000+09:00"

OUT_CSV = TMP / "_v5_6_correct_raw.csv"
MATCHED = TMP / "v5_6_correct_matched.csv"
INSPECT = TMP / "_v5_6_correct_inspect.txt"

KEYS = ["SOR04010", "SAL04043", "SAL04114", "SAL04115"]
MEMBER = "TEST02007"


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    f = TMP / "_v5_6_correct_query.soql"
    f.write_text(soql, encoding="utf-8")
    cmd = [SF_CMD, "data", "query", "--file", str(f), "--target-org", TARGET_ORG, "--result-format", "csv"]
    print(f"[run] {START}~{END}", flush=True)
    proc = subprocess.run(cmd, capture_output=True, shell=False)
    if proc.returncode != 0:
        sys.stderr.buffer.write(proc.stderr[:3000])
        raise RuntimeError(f"sf query failed exit={proc.returncode}")
    OUT_CSV.write_bytes(proc.stdout)
    print(f"[saved] {OUT_CSV} ({OUT_CSV.stat().st_size:,} bytes)")


def main():
    if not OUT_CSV.exists():
        run_query()
    else:
        print(f"[cache] use existing {OUT_CSV}")
    rows = []
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            text = (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "") + (r.get("RequestUrl__c") or "")
            if any(k in text for k in KEYS) or MEMBER in text:
                rows.append(r)
    print(f"[matched] {len(rows)}")
    with MATCHED.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["Id","CreatedDate","ApexClass__c","RequestUrl__c","RequestBody__c","ResponseBody__c"], extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)

    # filter for primary actions (Order/Sale/Return + Sale/Return delete)
    lines = []
    for r in rows:
        url = r.get("RequestUrl__c") or ""
        ac = r.get("ApexClass__c") or ""
        body = r.get("RequestBody__c") or ""
        # Show key endpoints + DELETE patterns
        if not (url.startswith("/gd/v1/order") or url.startswith("/gd/v1/sale") or
                url.startswith("/gd/v1/return") or url.startswith('{"SaleNo')
                or any(k in body for k in KEYS)):
            continue
        cd = r.get("CreatedDate", "")
        rid = r.get("Id", "")
        b = body[:200].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  req={b}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
