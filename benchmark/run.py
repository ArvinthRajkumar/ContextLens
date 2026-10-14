"""Runs every benchmark case through the deployed pipeline and scores it.

    python benchmark/run.py            # run all cases, then score
    python benchmark/run.py --score    # score the last run again

Needs benchmark/media (python benchmark/generate.py), the Android API key
(read from lib/firebase_options.dart), the App Check debug token in
~/.contextlens/appcheck-debug-token, gcloud for the stage logs, and the
backend venv for the evidence audit. Writes benchmark/results/raw.json and
benchmark/results/metrics.json.
"""

import argparse
import json
import statistics
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "backend"))

from client import Client, Result, stage_logs  # noqa: E402
from run_one import api_key  # noqa: E402

MEDIA = HERE / "media"
RESULTS = HERE / "results"
PRICING = json.loads((HERE / "pricing.json").read_text(encoding="utf-8"))
WORKERS = 3


def jobs(cases: dict) -> list[dict]:
    out = []
    for case in cases["compliance"] + cases["controls"]:
        out.append({"id": case["id"], "group": "compliance" if case["id"].startswith("C") else "control",
                    "video": MEDIA / f"{case['id']}.mp4", "declaration": case["declaration"]})
    for case in cases["factchecks"] + cases.get("freshFactchecks", []):
        out.append({"id": case["id"], "group": "factcheck", "video": MEDIA / f"{case['id']}.mp4",
                    "declaration": {"caption": "Sharing something useful #info", "isPaid": False, "category": "general"}})
    for case in cases["borrowed"]:
        out.append({"id": case["id"], "group": "borrowed", "video": MEDIA / f"{case['id']}_clip.mp4",
                    "declaration": {"caption": f"From {case['label']} #clip", "isPaid": False, "category": "general",
                                    "borrowedClips": [{"label": case["label"], "fileName": f"{case['id']}_source.mp4"}]},
                    "clip": MEDIA / f"{case['id']}_source.mp4"})
    return out


def run_all(cases: dict, only: tuple[str, ...] | None = None) -> dict:
    client = Client(api_key())
    todo = [j for j in jobs(cases) if not only or j["id"].startswith(only)]

    def one(job: dict) -> tuple[str, Result]:
        clips = {0: str(job["clip"])} if job.get("clip") else None
        for attempt in range(2):
            try:
                result = client.check(str(job["video"]), job["declaration"], clip_files=clips)
                print(f"{job['id']}: {result.status} {result.total_ms / 1000:.1f}s {len(result.flags)} flags", flush=True)
                return job["id"], result
            except Exception as error:  # noqa: BLE001
                print(f"{job['id']}: client error {error}", flush=True)
                time.sleep(5)
        return job["id"], Result("", "client_error")

    with ThreadPoolExecutor(WORKERS) as pool:
        results = dict(pool.map(one, todo))
    time.sleep(30)
    stage_logs([r for r in results.values() if r.job_id], minutes=180)
    for result in results.values():
        if result.job_id:
            client.delete(result.job_id)
    raw = {case_id: asdict(result) for case_id, result in results.items()}
    from client import probe

    for job in todo:
        minutes = probe(str(job["video"]))[0] / 60000
        if job.get("clip"):
            minutes += probe(str(job["clip"]))[0] / 60000
        raw[job["id"]]["audioMinutes"] = round(minutes, 3)
    RESULTS.mkdir(exist_ok=True)
    if only and (RESULTS / "raw.json").exists():
        raw = {**json.loads((RESULTS / "raw.json").read_text(encoding="utf-8")), **raw}
    (RESULTS / "raw.json").write_text(json.dumps(raw, indent=1, ensure_ascii=False), encoding="utf-8")
    return raw


# Scoring


def verified(flags: list[dict]) -> list[dict]:
    return [f for f in flags if not f.get("uncertain")]


def match(expected: list[dict], predicted: list[dict]) -> tuple[list[tuple[dict, dict]], list[dict], list[dict]]:
    """Greedy one-to-one match by category, preferring a cited clause the
    label accepts. Returns pairs, unmatched expected, unmatched predicted."""
    pairs, left = [], list(predicted)
    missed = []
    for want in expected:
        same = [p for p in left if p["category"] == want["category"]]
        best = next((p for p in same if (p.get("citation") or {}).get("clauseId") in want["clauses"]), None) or (
            same[0] if same else None)
        if best is None:
            missed.append(want)
        else:
            pairs.append((want, best))
            left.remove(best)
    return pairs, missed, left


def ratio(a: int, b: int) -> float | None:
    return round(a / b, 3) if b else None


def score(cases: dict, raw: dict) -> dict:
    from app.pipeline.checks.clauses import CLAUSES
    from app.pipeline.checks.pages import fetch
    from app.pipeline.textmatch import contains

    counts = {c: {"tp": 0, "fp": 0, "fn": 0} for c in ("disclosure", "claims")}
    clause_ok = clause_total = 0
    per_case = {}
    all_flags = []
    for case in cases["compliance"] + cases["controls"]:
        result = raw[case["id"]]
        flags = verified(result["flags"])
        all_flags += result["flags"]
        pairs, missed, extra = match(case["expect"]["flags"], [f for f in flags if f["category"] in counts])
        allowed = set(case["expect"].get("allow", []))
        extra = [f for f in extra if f["category"] not in allowed]
        for want, got in pairs:
            counts[want["category"]]["tp"] += 1
            clause_total += 1
            clause_ok += (got.get("citation") or {}).get("clauseId") in want["clauses"]
        for want in missed:
            counts[want["category"]]["fn"] += 1
        for got in extra:
            counts[got["category"]]["fp"] += 1
        per_case[case["id"]] = {
            "status": result["status"],
            "expected": [w["category"] for w in case["expect"]["flags"]],
            "found": [f"{f['category']}:{(f.get('citation') or {}).get('clauseId') or f.get('factLabel') or ''}"
                      + (" (uncertain)" if f.get("uncertain") else "") for f in result["flags"]],
            "missed": [w["category"] for w in missed],
            "falsePositives": [f["title"] for f in extra],
        }

    # Borrowed clips
    b = {"tp": 0, "fp": 0, "fn": 0, "tn": 0}
    omissions = omissions_found = 0
    aligned = aligned_ok = 0
    for case in cases["borrowed"]:
        result = raw[case["id"]]
        all_flags += result["flags"]
        flag = next((f for f in verified(result["flags"]) if f["category"] == "borrowed"), None)
        expect = case["expect"]["flag"]
        b["tp" if flag and expect else "fp" if flag else "fn" if expect else "tn"] += 1
        if expect:
            omissions += 1
            omissions_found += flag is not None
        truth = json.loads((MEDIA / f"{case['id']}_truth.json").read_text(encoding="utf-8"))
        any_flag = next((f for f in result["flags"] if f["category"] == "borrowed" and f.get("diff")), None)
        if any_flag:
            aligned += 1
            start = _source_start(any_flag["diff"], truth["sourceWords"])
            aligned_ok += start is not None and abs(start - truth["kept"][0][0]) <= 2.0
        per_case[case["id"]] = {"status": result["status"], "expectFlag": expect, "flagged": flag is not None,
                                "uncertain": any(f.get("uncertain") for f in result["flags"] if f["category"] == "borrowed")}

    # Fact checks
    agree = abstain = missing = 0
    for case in cases["factchecks"]:
        result = raw[case["id"]]
        all_flags += result["flags"]
        checks = [f for f in result["flags"] if f["category"] == "factcheck"]
        good = {"contradicted", "previously_fact_checked"}
        if case["rating"] == "Half True":
            good |= {"insufficient_evidence"}
        decided = [f for f in checks if not f.get("uncertain")]
        if any(f.get("factLabel") in good for f in decided):
            agree += 1
            outcome = "agrees"
        elif checks and not decided or any(f.get("factLabel") == "insufficient_evidence" for f in decided):
            abstain += 1
            outcome = "abstained"
        elif not checks:
            missing += 1
            outcome = "no fact check"
        else:
            outcome = "disagrees"
        per_case[case["id"]] = {"status": result["status"], "rating": case["rating"], "outcome": outcome,
                                "labels": [f"{f.get('factLabel')}{' (uncertain)' if f.get('uncertain') else ''}" for f in checks]}

    # Fresh fact checks: no published review exists, so Gemini with Search
    # has to judge them itself.
    fresh = {"agree": 0, "abstain": 0, "disagree": 0, "missing": 0, "total": 0}
    for case in cases.get("freshFactchecks", []):
        result = raw[case["id"]]
        all_flags += result["flags"]
        checks = [f for f in result["flags"] if f["category"] == "factcheck"]
        decided = [f for f in checks if not f.get("uncertain")]
        fresh["total"] += 1
        if any(f.get("factLabel") == case["expected"] for f in decided):
            outcome = "agree"
        elif any(f.get("factLabel") in {"supported", "contradicted"} for f in decided):
            outcome = "disagree"
        elif checks:
            outcome = "abstain"
        else:
            outcome = "missing"
        fresh[outcome] += 1
        per_case[case["id"]] = {"status": result["status"], "expected": case["expected"], "outcome": outcome,
                                "labels": [f"{f.get('factLabel')}{' (uncertain)' if f.get('uncertain') else ''}" for f in checks]}

    # Evidence audit: every verified quote, checked again here, independently.
    audit = {"checked": 0, "failures": [], "groundingAttributed": 0}
    truths = {c["id"]: json.loads((MEDIA / f"{c['id']}_truth.json").read_text(encoding="utf-8")) for c in cases["borrowed"]}
    page_cache: dict[str, str] = {}
    for case_id, result in raw.items():
        for flag in verified(result["flags"]):
            quote = (flag.get("sourceQuote") or {}).get("text")
            if not quote:
                continue
            clause_id = (flag.get("citation") or {}).get("clauseId")
            if clause_id:
                ok = contains(CLAUSES[clause_id]["text"], quote)
            elif flag["category"] == "borrowed":
                ok = contains(" ".join(w["text"] for w in truths[case_id]["sourceWords"]), quote)
            elif flag["sourceQuote"]["source"].endswith("as matched by Google Search grounding"):
                audit["groundingAttributed"] += 1
                continue
            elif flag.get("factLabel") == "previously_fact_checked":
                audit["groundingAttributed"] += 0
                ok = True  # verified against the Fact Check Tools response at run time
            else:
                url = (flag.get("citation") or {}).get("url") or ""
                if url not in page_cache:
                    page = fetch(url) if url else None
                    page_cache[url] = page.text if page else ""
                ok = contains(page_cache[url], quote) if page_cache[url] else None
                if ok is None:
                    audit.setdefault("unreachable", 0)
                    audit["unreachable"] += 1
                    continue
            audit["checked"] += 1
            if not ok:
                audit["failures"].append({"case": case_id, "flag": flag["title"]})

    # Latency and cost
    done = [r for r in raw.values() if r["status"] == "done"]
    latencies = [r["total_ms"] / 1000 for r in done]
    stage_ms = {s: [r["stages"][s]["ms"] / 1000 for r in done if s in r.get("stages", {})]
                for s in ("extract", "claims", "checking", "evidence", "report")}
    costs = [_cost(r) for r in done if r.get("stages")]
    uncertain = sum(1 for f in all_flags if f.get("uncertain"))
    return {
        "runs": len(raw),
        "completed": len(done),
        "failed": [k for k, r in raw.items() if r["status"] != "done"],
        "checkers": {c: {**v, "precision": ratio(v["tp"], v["tp"] + v["fp"]), "recall": ratio(v["tp"], v["tp"] + v["fn"])}
                     for c, v in counts.items()},
        "clauseAccuracy": ratio(clause_ok, clause_total),
        "borrowed": {**b, "precision": ratio(b["tp"], b["tp"] + b["fp"]), "recall": ratio(b["tp"], b["tp"] + b["fn"])},
        "omissionDetection": ratio(omissions_found, omissions),
        "alignmentWithin2s": ratio(aligned_ok, aligned),
        "alignmentCases": aligned,
        "factcheck": {"agree": agree, "abstain": abstain, "missing": missing, "total": len(cases["factchecks"]),
                      "agreement": ratio(agree, len(cases["factchecks"]))},
        "freshFactcheck": {**fresh, "agreement": ratio(fresh["agree"], fresh["total"])},
        "abstentionRate": ratio(uncertain, len(all_flags)),
        "flagsTotal": len(all_flags),
        "evidenceAudit": audit,
        "latency": {"median": round(statistics.median(latencies), 1) if latencies else None,
                    "p90": round(sorted(latencies)[int(0.9 * (len(latencies) - 1))], 1) if latencies else None,
                    "stagesMedian": {s: round(statistics.median(v), 1) for s, v in stage_ms.items() if v}},
        "costPerReelUsd": {"median": round(statistics.median(costs), 4) if costs else None},
        "perCase": per_case,
    }


def _source_start(diff: dict, words: list[dict]) -> float | None:
    """Where in the source the system says the clip starts, in seconds."""
    from app.pipeline.textmatch import find_span, tokens

    original = tokens(diff["originalTranscript"])
    keys = [t for w in words for t in tokens(w["text"])]
    owners = [w for w in words for _ in tokens(w["text"])]
    span = find_span(keys, original[:6])
    return owners[span[0]]["start"] if span else None


def _cost(result: dict) -> float:
    tokens_in = sum(s.get("inputTokens", 0) for s in result["stages"].values())
    tokens_out = sum(s.get("outputTokens", 0) for s in result["stages"].values())
    searches = sum(1 for c in result.get("calls", []) if c.get("search"))
    minutes = result.get("audioMinutes", 0.75)
    return (tokens_in * PRICING["geminiInputPerM"] + tokens_out * PRICING["geminiOutputPerM"]) / 1e6 + \
        searches * PRICING["searchGroundingPerPrompt"] + minutes * PRICING["chirpPerMinute"] + \
        PRICING["checkGroundingPerFlag"] * len(result["flags"])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--score", action="store_true", help="Only score the saved raw results.")
    parser.add_argument("--only", help="Comma separated case ID prefixes to rerun; the rest are kept from raw.json.")
    args = parser.parse_args()
    cases = json.loads((HERE / "cases.json").read_text(encoding="utf-8"))
    if args.score:
        raw = json.loads((RESULTS / "raw.json").read_text(encoding="utf-8"))
    else:
        raw = run_all(cases, tuple(args.only.split(",")) if args.only else None)
    metrics = score(cases, raw)
    (RESULTS / "metrics.json").write_text(json.dumps(metrics, indent=1, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({k: v for k, v in metrics.items() if k != "perCase"}, indent=1))


if __name__ == "__main__":
    main()
