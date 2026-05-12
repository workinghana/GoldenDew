import csv
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

# 시나리오 2 대상 시간 범위 (5/7 09:31 KST ~ 현재까지 — 안전 범위)
START = "2026-05-07T09:31:00.000+09:00"
END = "2026-05-09T23:59:00.000+09:00"

# 시나리오 2 + 회원 103006200124 매칭
NUMBERS = [
    "SOR202605080077",
    "SOR202605080078",
    "SOR202605080081",
    "SAL202605080058",
    "SAL202605080059",
    "SAL202605080060",
    "SAL202605080061",
    "SAL202605080064",
    "SAL202605080068",
    "SAL202605080070",
    "103006200124",  # member
]

OUT_CSV = TMP / "_scenario2_raw.csv"
OUT_FILTERED = TMP / "scenario2_matched.csv"


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    soql_file = TMP / "_scenario2_query.soql"
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


def matched(row, numbers):
    req = row.get("RequestBody__c") or ""
    res = row.get("ResponseBody__c") or ""
    return [n for n in numbers if (n in req) or (n in res)]


def main():
    if not OUT_CSV.exists() or OUT_CSV.stat().st_size < 100:
        run_query()
    else:
        print(f"[reuse] {OUT_CSV}")

    rows = []
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            hits = matched(r, NUMBERS)
            if hits:
                r["_hits"] = ",".join(hits)
                rows.append(r)
    print(f"[matched] {len(rows)} rows")

    counts = {n: 0 for n in NUMBERS}
    for r in rows:
        for n in r["_hits"].split(","):
            counts[n] += 1
    for n in NUMBERS:
        print(f"  {n}: {counts[n]}")

    # 매칭된 행만 저장
    if rows:
        out_fields = ["_hits", "Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
        with OUT_FILTERED.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
            w.writeheader()
            for r in rows:
                w.writerow(r)
        print(f"[saved-filtered] {OUT_FILTERED}")


if __name__ == "__main__":
    main()
