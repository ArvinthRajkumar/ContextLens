"""Sends one video through the deployed pipeline N times and prints the
stage timings and flags.

    python benchmark/run_one.py VIDEO --caption TEXT [--paid --brand NAME] [--category health] [--runs 3]

Needs the Android API key (FIREBASE_API_KEY, or read from
lib/firebase_options.dart), the App Check debug token in
~/.contextlens/appcheck-debug-token, and gcloud for the stage logs.
"""

import argparse
import re
import statistics
import time
from pathlib import Path

from client import Client, stage_logs

ROOT = Path(__file__).resolve().parent.parent


def api_key() -> str:
    import os

    if os.environ.get("FIREBASE_API_KEY"):
        return os.environ["FIREBASE_API_KEY"]
    text = (ROOT / "lib" / "firebase_options.dart").read_text(encoding="utf-8")
    return re.search(r"apiKey: '([^']+)'", text).group(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("--caption", required=True)
    parser.add_argument("--paid", action="store_true")
    parser.add_argument("--brand")
    parser.add_argument("--category", default="general")
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--clip", nargs=2, metavar=("LABEL", "FILE"), help="Declare a borrowed clip and attach its original.")
    args = parser.parse_args()

    client = Client(api_key())
    declaration = {"caption": args.caption, "isPaid": args.paid, "category": args.category}
    if args.brand:
        declaration["brandName"] = args.brand
    clip_files = None
    if args.clip:
        declaration["borrowedClips"] = [{"label": args.clip[0], "fileName": Path(args.clip[1]).name}]
        clip_files = {0: args.clip[1]}
    results = []
    for n in range(args.runs):
        result = client.check(args.video, declaration, clip_files=clip_files)
        results.append(result)
        print(f"run {n + 1}: {result.status} in {result.total_ms / 1000:.1f} s, {len(result.flags)} flags")
    time.sleep(20)  # log ingestion
    stage_logs(results)
    for n, result in enumerate(results, start=1):
        stages = ", ".join(f"{k} {v['ms'] / 1000:.1f}s" for k, v in result.stages.items())
        extract = result.stages.get("extract", {})
        print(f"\nrun {n} ({result.job_id[:8]}): total {result.total_ms / 1000:.1f} s; {stages}")
        print(f"  extract parts: visual {extract.get('visualMs', '?')} ms, speech {extract.get('speechMs', '?')} ms")
        for flag in result.flags:
            state = "uncertain" if flag.get("uncertain") else "verified"
            label = flag.get("factLabel") or ""
            clause = (flag.get("citation") or {}).get("clauseId") or ""
            print(f"  {flag['startMs'] / 1000:5.1f}s {flag['category']:<10} {label:<22} {state:<9} {clause:<22} {flag['title']}")
            if flag.get("diff"):
                print("     diff:", " | ".join(f"{s['op']}: {s['text']}" for s in flag["diff"]["segments"]))
        client.delete(result.job_id)
    totals = [r.total_ms / 1000 for r in results]
    if len(totals) > 1:
        print(f"\nmedian total {statistics.median(totals):.1f} s over {len(totals)} runs")


if __name__ == "__main__":
    main()
