"""V5-2 시나리오 (회원 TEST02009 / 주문 SOR04017 / 판매 SAL04071) audit 추출.

시간 범위: 2026-05-11 01:00 ~ 05:00 KST (= 2026-05-10 16:00 ~ 20:00 UTC)
"""
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"

START = "2026-05-11T01:00:00.000+09:00"
END   = "2026-05-11T05:00:00.000+09:00"

OUT_CSV  = TMP / "_v5_2_raw.csv"
MATCHED  = TMP / "v5_2_matched.csv"
INSPECT  = TMP / "_v5_2_inspect.txt"

KEYS = ["SOR04017", "SAL04071", "DEP040025", "DEP040026", "DEP040027", "DEP040024"]


def run_query():
    soql = (
        "SELECT Id, CreatedDate, ApexClass__c, RequestUrl__c, RequestBody__c, ResponseBody__c "
        "FROM ApexAuditTrail__c "
        f"WHERE CreatedDate >= {START} AND CreatedDate <= {END} "
        "ORDER BY CreatedDate ASC"
    )
    f = TMP / "_v5_2_query.soql"
    f.write_text(soql, encoding="utf-8")
    cmd = [SF_CMD, "data", "query", "--file", str(f), "--target-org", TARGET_ORG, "--result-format", "csv"]
    print(f"[run] {START} ~ {END}", flush=True)
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
            if any(k in text for k in KEYS):
                rows.append(r)
    print(f"[matched] {len(rows)}")

    with MATCHED.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["Id","CreatedDate","ApexClass__c","RequestUrl__c","RequestBody__c","ResponseBody__c"],
            extrasaction="ignore",
        )
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print(f"[saved] {MATCHED}")

    lines = []
    for r in rows:
        cd = r.get("CreatedDate", "")
        rid = r.get("Id", "")
        ac = r.get("ApexClass__c", "")
        url = r.get("RequestUrl__c") or ""
        body = (r.get("RequestBody__c") or "")[:300].replace("\n", " ")
        resp = (r.get("ResponseBody__c") or "")[:200].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  req={body}\n  resp={resp}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
