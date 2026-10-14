"""Runs the real pipeline on a local video, the way Cloud Run does, and
prints the ledger and the flags. Uses your ADC credentials; set
FACTCHECK_API_KEY for Fact Check Tools.

    cd backend
    .venv/Scripts/python.exe -m tools.run_pipeline VIDEO [--caption TEXT] [--paid --brand NAME] [--category health]

The video goes to uploads/dev-local/<id>/ in the bucket and is deleted at
the end (the bucket's 1-day lifecycle is the backstop).
"""

import argparse
import asyncio
import json
import logging
import os
import time
import uuid

from app import storage
from app.pipeline.base import CheckContext
from app.pipeline.real import real_stages
from app.pipeline.runner import summarize
from app.pipeline.speech import Transcript, Word
from app.pipeline.visual import VisualFacts


async def main() -> None:
    logging.basicConfig(level=logging.WARNING, format="%(levelname)s %(name)s: %(message)s")
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("--caption", default="")
    parser.add_argument("--paid", action="store_true")
    parser.add_argument("--brand")
    parser.add_argument("--category", default="general", choices=["health", "finance", "general"])
    parser.add_argument("--out", help="Write the ledger and flags JSON here too.")
    parser.add_argument("--keep", help="Save the extract and ledger results here, to rerun the checkers with --reuse.")
    parser.add_argument("--reuse", help="Skip extract and ledger: load what --keep saved.")
    args = parser.parse_args()

    job_id = f"local-{uuid.uuid4().hex[:8]}"
    prefix = f"uploads/dev-local/{job_id}"
    if not args.reuse:
        storage.upload_file(args.video, f"{prefix}/source", "video/mp4")
    ctx = CheckContext(
        job_id=job_id,
        uid="dev-local",
        object_name=f"{prefix}/source",
        declaration={
            "caption": args.caption,
            "isPaid": args.paid,
            "brandName": args.brand,
            "category": args.category,
        },
    )
    ctx.progress = lambda detail: print(f"  ... {detail}")
    stages = real_stages()
    if args.reuse:
        saved = json.loads(open(args.reuse, encoding="utf-8").read())
        ctx.duration_ms = saved["durationMs"]
        ctx.data["transcript"] = Transcript(saved["transcript"]["language"], [Word(**w) for w in saved["transcript"]["words"]])
        ctx.data["visual"] = VisualFacts.model_validate(saved["visual"])
        ctx.data["ledger"] = saved["ledger"]
        stages = stages[2:]
    try:
        for stage in stages:
            started = time.monotonic()
            print(f"[{stage.name}]")
            await stage.run(ctx)
            tokens = ctx.tokens.get(stage.name, {"input": 0, "output": 0})
            print(f"  {int((time.monotonic() - started) * 1000)} ms, tokens in {tokens['input']} out {tokens['output']}")
            if stage.name == "extract":
                print(f"  {ctx.data.get('timings')}")
    finally:
        storage.delete_prefix(f"{prefix}/")

    transcript = ctx.data["transcript"]
    if args.keep:
        with open(args.keep, "w", encoding="utf-8") as f:
            json.dump({"durationMs": ctx.duration_ms, "transcript": transcript.to_json(),
                       "visual": ctx.data["visual"].model_dump(), "ledger": ctx.data["ledger"]}, f, ensure_ascii=False)
    print(f"\nLanguage: {transcript.language}, {len(transcript.words)} words, {ctx.duration_ms} ms")
    for candidate in ctx.data.get("candidates", []):
        print(f"gate: {candidate.flag['category']:<10} {candidate.flag.get('factLabel') or '':<12} "
              f"{'U' if any('grounding:' in n or 'not' in n for n in candidate.gate_notes) else '-'} "
              f"{candidate.flag['title'][:50]:<50} {candidate.gate_notes}")
        if os.environ.get("SHOW_GROUNDING") and candidate.grounding_facts:
            print(f"      answer: {candidate.grounding_answer or candidate.flag['evidence']}")
            for fact in candidate.grounding_facts:
                print(f"      fact: {fact[:300]}")
    result = {"ledger": ctx.data["ledger"], "flags": ctx.flags, "summary": summarize(ctx.flags)}
    text = json.dumps(result, indent=2, ensure_ascii=False)
    print(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")


if __name__ == "__main__":
    asyncio.run(main())
