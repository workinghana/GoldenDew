"""V5-5 시나리오 (회원 TEST01009 / 판매 SAL04058~04063 / 이전 판매 포인트 끌어쓴 후 취소 시도).

시간 범위 캐시: _v5_2_raw.csv (2026-05-11 01:00 ~ 05:00 KST)
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"

RAW_CSV = TMP / "_v5_2_raw.csv"
MATCHED = TMP / "v5_5_matched.csv"
INSPECT = TMP / "_v5_5_inspect.txt"

KEYS = [
    "TEST01009",
    "SAL04058", "SAL04059", "SAL04060", "SAL04061", "SAL04062", "SAL04063",
    "DEP040034",
]


def main():
    if not RAW_CSV.exists():
        raise SystemExit(f"missing {RAW_CSV}")

    rows = []
    with RAW_CSV.open("r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            text = (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "") + (r.get("RequestUrl__c") or "")
            if any(k in text for k in KEYS):
                rows.append(r)
    rows.sort(key=lambda r: r.get("CreatedDate", ""))
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
        body = (r.get("RequestBody__c") or "")[:400].replace("\n", " ")
        resp = (r.get("ResponseBody__c") or "")[:400].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  req={body}\n  resp={resp}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
