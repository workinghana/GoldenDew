"""V1 시나리오 3-1 ~ 3-4 (VIP 무제한 정률쿠폰 COP2026MY0011).

캐시: _v1_raw.csv (2026-05-10 18:00 ~ 23:00 KST)
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"

RAW_CSV = TMP / "_v1_raw.csv"
MATCHED = TMP / "v1_3x_matched.csv"
INSPECT = TMP / "_v1_3x_inspect.txt"

KEYS = ["COP2026MY0011", "9TKSHRYN", "AKU33FUQ"]


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
