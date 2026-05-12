"""V5-1 시나리오 (회원 TEST03006 / 주문 SOR04011 / 판매 SAL04044 / 반품 SAL04116, SAL04117) audit 추출.

시간 범위 캐시: C:\\Users\\milvus-0\\Goldendew\\tmp\\_v1_raw.csv (2026-05-10 18:00 ~ 23:00 KST)
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"

RAW_CSV = TMP / "_v1_raw.csv"
MATCHED = TMP / "v5_1_matched.csv"
INSPECT = TMP / "_v5_1_inspect.txt"

KEYS = ["TEST03006", "SOR04011", "SAL04044", "SAL04116", "SAL04117"]


def main():
    if not RAW_CSV.exists():
        raise SystemExit(f"missing {RAW_CSV} — run inspect_v1_log.py first")

    rows = []
    with RAW_CSV.open("r", encoding="utf-8", newline="") as f:
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
