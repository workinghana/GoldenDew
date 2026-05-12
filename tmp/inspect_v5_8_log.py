"""V5-8 시나리오 (V5 7-1 ~ 7-5 / 회원 269999800188/189/192/194) audit 추출.

캐시: _v5_2_raw.csv (2026-05-11 01:00 ~ 05:00 KST)
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"

RAW_CSV = TMP / "_v5_2_raw.csv"
MATCHED = TMP / "v5_8_matched.csv"
INSPECT = TMP / "_v5_8_inspect.txt"

KEYS = ["269999800188", "269999800189", "269999800192", "269999800194"]


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
        body = (r.get("RequestBody__c") or "")[:350].replace("\n", " ")
        resp = (r.get("ResponseBody__c") or "")[:250].replace("\n", " ")
        # which member key matched
        members = [k for k in KEYS if k in body or k in resp or k in url]
        lines.append(f"{cd}  {rid}  {ac}  members={members}\n  url={url}\n  req={body}\n  resp={resp}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
