"""Runs every sample through the deployed pipeline and checks it raises the
flags it is meant to (and the clean control raises none).

    cd backend
    FFMPEG=<ffmpeg> .venv/Scripts/python.exe ../tool/samples/verify.py [ID ...]

Each sample runs as its own anonymous user, so the per-user daily cap does
not get in the way; the users are deleted afterwards. Counts against the
global daily cap.
"""

import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent.parent / "benchmark"))

from client import Client  # noqa: E402
from run_one import api_key  # noqa: E402

# Categories that count as issues: verified flags, not "supported" fact checks.
_IGNORED_LABELS = {"supported"}


def issues(flags: list[dict]) -> list[str]:
    out = []
    for flag in flags:
        if flag.get("uncertain") or flag.get("factLabel") in _IGNORED_LABELS:
            continue
        out.append(flag["category"])
    return sorted(set(out))


def run(sample: dict) -> dict:
    try:
        return _run(sample)
    except Exception as error:  # noqa: BLE001
        return {"id": sample["id"], "status": f"error: {error}", "expected": sorted(set(sample["expect"])),
                "actual": [], "uncertain": [], "titles": [], "pass": False}


def _run(sample: dict) -> dict:
    client = Client(api_key())
    declaration = dict(sample["declaration"])
    clips = None
    if sample.get("clip"):
        clip = sample["clip"]
        declaration["borrowedClips"] = [{"label": clip["label"], "fileName": f"{clip['id']}.mp4"}]
        clips = {0: str(HERE / "out" / f"{clip['id']}.mp4")}
    result = client.check(str(HERE / "out" / f"{sample['id']}.mp4"), declaration, clip_files=clips)
    got = issues(result.flags)
    want = sorted(set(sample["expect"]))
    if result.job_id:
        client.delete(result.job_id)
    client.delete_account()
    return {
        "id": sample["id"],
        "status": result.status,
        "expected": want,
        "actual": got,
        "uncertain": sorted({f["category"] for f in result.flags if f.get("uncertain")}),
        "titles": [f"{f['category']}: {f['title']}" + (" (uncertain)" if f.get("uncertain") else "") for f in result.flags],
        # Every intended flag, and nothing outside what the sample allows.
        "pass": result.status == "done" and set(want) <= set(got) <= set(want) | set(sample.get("allow", [])),
    }


def main() -> None:
    manifest = json.loads((HERE / "samples.json").read_text(encoding="utf-8"))
    only = set(sys.argv[1:])
    todo = [s for s in manifest["samples"] if not only or s["id"] in only]
    with ThreadPoolExecutor(3) as pool:
        rows = list(pool.map(run, todo))
    for row in rows:
        print(json.dumps(row, ensure_ascii=False))
    print("| Sample | Expected | Actual | Result |")
    print("|---|---|---|---|")
    for row in rows:
        print(f"| {row['id']} | {', '.join(row['expected']) or 'none'} | {', '.join(row['actual']) or 'none'} | "
              f"{'pass' if row['pass'] else 'FAIL'} |")


if __name__ == "__main__":
    main()
