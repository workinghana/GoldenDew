"""Poll an Apex test run until done, then fetch the result + coverage."""
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "tmp" / "coverage_all_20260512"
SF_CMD = r"C:\Program Files\sf\bin\sf.cmd"
TARGET_ORG = "goldendew-sb"
RUN_ID = "707JO00000EfuUFYAZ"


def run_sf_json(args):
    cmd = [SF_CMD, *args, "--json"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + "\n" + proc.stderr + "\n")
        raise RuntimeError(f"sf failed: {' '.join(args)}")
    return json.loads(proc.stdout)


def query_status():
    soql = (
        "SELECT Id, AsyncApexJobId, Status, ClassesCompleted, ClassesEnqueued, "
        "MethodsCompleted, MethodsEnqueued FROM ApexTestRunResult "
        f"WHERE AsyncApexJobId = '{RUN_ID}'"
    )
    out = run_sf_json([
        "data", "query",
        "--target-org", TARGET_ORG,
        "--query", soql,
    ])
    records = out.get("result", {}).get("records", [])
    return records[0] if records else None


def fetch_result():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        SF_CMD, "apex", "get", "test",
        "--target-org", TARGET_ORG,
        "--test-run-id", RUN_ID,
        "--code-coverage",
        "--result-format", "json",
        "--output-dir", str(OUT_DIR),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    print(proc.stdout)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr + "\n")
        sys.exit(proc.returncode)


def main():
    while True:
        rec = query_status()
        if rec is None:
            print("[wait] no record yet")
        else:
            status = rec.get("Status")
            mc = rec.get("MethodsCompleted")
            me = rec.get("MethodsEnqueued")
            cc = rec.get("ClassesCompleted")
            ce = rec.get("ClassesEnqueued")
            print(f"[wait] status={status} classes={cc}/{ce} methods={mc}/{me}", flush=True)
            if status in ("Completed", "Failed", "Aborted"):
                break
        time.sleep(60)
    print("[fetch] fetching result + coverage")
    fetch_result()
    print("[done]")


if __name__ == "__main__":
    main()
