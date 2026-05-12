"""V5-4 시나리오 (회원 TEST02009 / 판매 SAL04050 / 프로모션 비활성화) audit 추출.

시간 범위 캐시: _v1_raw.csv (2026-05-10 18:00 ~ 23:00 KST)
"""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"

RAW_CSV = TMP / "_v1_raw.csv"
MATCHED = TMP / "v5_4_matched.csv"
INSPECT = TMP / "_v5_4_inspect.txt"

# SAL04050 + 그 원 주문번호 추정 (SAL04050 호출의 OriginalOrderId 또는 SOR04xxx 매칭)
KEYS_PRIMARY = ["SAL04050"]


def main():
    if not RAW_CSV.exists():
        raise SystemExit(f"missing {RAW_CSV}")

    # 1차: SAL04050 직접 매칭
    primary_rows = []
    raw_rows = list(csv.DictReader(RAW_CSV.open("r", encoding="utf-8", newline="")))
    for r in raw_rows:
        text = (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "") + (r.get("RequestUrl__c") or "")
        if any(k in text for k in KEYS_PRIMARY):
            primary_rows.append(r)
    print(f"[primary matched] {len(primary_rows)}")

    # 2차: SAL04050 의 OriginalOrderId 추출 (SOR04xxx) → 원 주문 로그 합치기
    extra_keys = set()
    pat = re.compile(r"SOR\d{5}")
    for r in primary_rows:
        text = (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "")
        for m in pat.findall(text):
            extra_keys.add(m)
    print(f"[extra keys] {sorted(extra_keys)}")

    rows = list(primary_rows)
    seen = {r["Id"] for r in rows}
    if extra_keys:
        for r in raw_rows:
            if r["Id"] in seen:
                continue
            text = (r.get("RequestBody__c") or "") + (r.get("ResponseBody__c") or "") + (r.get("RequestUrl__c") or "")
            if any(k in text for k in extra_keys):
                rows.append(r)
                seen.add(r["Id"])
    rows.sort(key=lambda r: r.get("CreatedDate", ""))
    print(f"[total matched] {len(rows)}")

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
