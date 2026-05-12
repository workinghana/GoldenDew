"""V4-6 시나리오 (회원 123002600463 / 골드바 1KG) audit trail 추출."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [ROOT / "tmp" / "_v4_raw.csv", ROOT / "tmp" / "_v4_4_refresh.csv", ROOT / "tmp" / "_v4_5_refresh.csv"]
OUT = ROOT / "tmp" / "v4_6_matched.csv"
INSPECT = ROOT / "tmp" / "_v4_6_inspect.txt"

MEMBER = "123002600463"


def main():
    seen = set()
    rows = []
    for src in SOURCES:
        if not src.exists():
            continue
        with src.open("r", encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                if r["Id"] in seen:
                    continue
                req = r.get("RequestBody__c") or ""
                res = r.get("ResponseBody__c") or ""
                if MEMBER not in req and MEMBER not in res:
                    continue
                seen.add(r["Id"])
                rows.append(r)
    rows.sort(key=lambda r: r.get("CreatedDate", ""))
    print(f"[total matched] {len(rows)}")

    out_fields = ["Id", "CreatedDate", "ApexClass__c", "RequestUrl__c", "RequestBody__c", "ResponseBody__c"]
    with OUT.open("w", encoding="utf-8", newline="") as f:
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
        body = r.get("RequestBody__c") or ""
        gold = "GOLD" if any(k in body for k in ["골드", "GOLD", "gold", "골드바"]) else ""
        lines.append(f"{cd}  {rid}  {ac}\n  url={url}  {gold}\n  req={body[:300].replace(chr(10), ' ')}\n")
    INSPECT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[saved] {INSPECT}")


if __name__ == "__main__":
    main()
