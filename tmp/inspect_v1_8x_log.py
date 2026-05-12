"""V1 시나리오 8-1 ~ 8-6 — TEST03006 / COP2026MY0016 9908EY4T 흐름.

여러 raw csv 캐시 합쳐서 dedupe.
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"

RAW_CSVS = [
    TMP / "_v1_7x_raw.csv",   # 5/10 00:00 ~ 18:00 KST
    TMP / "_v1_raw.csv",      # 5/10 18:00 ~ 23:00 KST
    TMP / "_v5_5_raw.csv",    # 5/10 22:00 ~ 5/11 02:00 KST
    TMP / "_v5_2_raw.csv",    # 5/11 01:00 ~ 05:00 KST
    TMP / "_v5_8_raw.csv",    # 5/11 05:00 ~ 10:00 KST
]
MATCHED = TMP / "v1_8x_matched.csv"
INSPECT = TMP / "_v1_8x_inspect.txt"

KEYS = ["TEST03006", "9908EY4T"]


def main():
    seen = set()
    rows = []
    for csv_path in RAW_CSVS:
        if not csv_path.exists():
            continue
        with csv_path.open("r", encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                if r["Id"] in seen:
                    continue
                text = (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "") + (r.get("RequestUrl__c") or "")
                if any(k in text for k in KEYS):
                    rows.append(r)
                    seen.add(r["Id"])
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
        resp = (r.get("ResponseBody__c") or "")[:300].replace("\n", " ")
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}\n  req={body}\n  resp={resp}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
