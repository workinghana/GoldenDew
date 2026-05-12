"""V5-4 회원 173000400470 + 043004800023 audit 검색 (5/6 ~ 5/8)."""
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-06T00:00:00.000+09:00"
END   = "2026-05-08T23:59:00.000+09:00"

OUT_CSV = TMP / "_v5_4_raw.csv"
MATCHED = TMP / "v5_4_matched.csv"
INSPECT = TMP / "_v5_4_inspect.txt"

MEMBERS = ["173000400470", "043004800023"]
KEYS = ["SOR202605060064", "SOR202605060065", "SAL202605080266", "PRO202605041082"]


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    soql_file = TMP / "_v5_4_query.soql"
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
    if not OUT_CSV.exists():
        run_query()
    else:
        print(f"[cache] use existing {OUT_CSV}")
    rows = []
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            req = r.get("RequestBody__c") or ""
            res = r.get("ResponseBody__c") or ""
            url = r.get("RequestUrl__c") or ""
            text = req + res + url
            if any(k in text for k in KEYS) or any(m in text for m in MEMBERS):
                rows.append(r)
    rows.sort(key=lambda r: r.get("CreatedDate", ""))
    # filter to records where member is referenced (skip pure promo sync calls)
    member_rows = [r for r in rows if any(m in (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "") + (r.get("RequestUrl__c") or "") for m in MEMBERS)]
    print(f"[matched] total={len(rows)}  with-member={len(member_rows)}")

    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with MATCHED.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        for r in member_rows:
            w.writerow(r)

    # Show only Order/Sale/Return/PointCredit primary actions
    lines = []
    for r in member_rows:
        url = r.get("RequestUrl__c") or ""
        ac = r.get("ApexClass__c") or ""
        if not (url.startswith("/gd/v1/order") or url.startswith("/gd/v1/sale") or
                url.startswith("/gd/v1/return") or url.startswith("/gd/v1/point/credit") or
                url.startswith("{\"SaleNo") or url.startswith("{\"MemberNo")):
            continue
        cd = r.get("CreatedDate", "")
        rid = r.get("Id", "")
        body = (r.get("RequestBody__c") or "")[:250].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  req={body}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
