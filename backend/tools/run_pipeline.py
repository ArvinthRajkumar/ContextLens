"""Runs the real Extract and Claim ledger stages on a local video, the way
Cloud Run does, and prints the ledger. Uses your ADC credentials.

    cd backend
    .venv/Scripts/python.exe -m tools.run_pipeline VIDEO [--caption TEXT] [--paid --brand NAME] [--category health]

The video goes to uploads/dev-local/<id>/ in the bucket and is deleted at
the end (the bucket's 1-day lifecycle is the backstop).
"""

import argparse
import asyncio
import json
import time
import uuid

from app import storage
from app.pipeline.base import CheckContext
from app.pipeline.real import RealExtract, RealLedger


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("--caption", default="")
    parser.add_argument("--paid", action="store_true")
    parser.add_argument("--brand")
    parser.add_argument("--category", default="general", choices=["health", "finance", "general"])
    parser.add_argument("--out", help="Write the ledger JSON here too.")
    args = parser.parse_args()

    job_id = f"local-{uuid.uuid4().hex[:8]}"
    prefix = f"uploads/dev-local/{job_id}"
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
    try:
        for stage in (RealExtract(), RealLedger()):
            started = time.monotonic()
            print(f"[{stage.name}]")
            await stage.run(ctx)
            tokens = ctx.tokens.get(stage.name, {"input": 0, "output": 0})
            print(f"  {int((time.monotonic() - started) * 1000)} ms, tokens in {tokens['input']} out {tokens['output']}")
    finally:
        storage.delete_prefix(f"{prefix}/")

    transcript = ctx.data["transcript"]
    print(f"\nLanguage: {transcript.language}, {len(transcript.words)} words, {ctx.duration_ms} ms")
    ledger = ctx.data["ledger"]
    text = json.dumps(ledger, indent=2, ensure_ascii=False)
    print(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")


if __name__ == "__main__":
    asyncio.run(main())
