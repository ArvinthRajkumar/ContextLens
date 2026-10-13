"""The real pipeline: Extract (Chirp 3 + Gemini), the claim ledger, the
checkers, the evidence gate and the report."""

import asyncio
import json
import logging
import os
import tempfile

from .. import storage
from .base import CheckContext, StageResult
from .checks import gate, router
from .checks.candidate import Candidate
from .ledger import build, summary
from .media import MediaError, extract_audio, probe
from .speech import Transcript, transcribe
from .visual import VisualFacts, analyse

log = logging.getLogger(__name__)


def _job_prefix(ctx: CheckContext) -> str:
    return ctx.object_name.rsplit("/", 1)[0]


class RealExtract:
    """Speech and screen in parallel: Chirp 3 words with timestamps, and
    Gemini's structured read of overlays, labels, products and shots."""

    name = "extract"

    async def run(self, ctx: CheckContext) -> StageResult:
        ctx.progress("Transcribing audio and reading on-screen text")
        with tempfile.TemporaryDirectory() as tmp:
            video = os.path.join(tmp, "source")
            await asyncio.to_thread(storage.download, ctx.object_name, video)
            duration_ms, has_audio = await asyncio.to_thread(probe, video)
            if duration_ms is None:
                raise MediaError("video_unreadable")
            ctx.duration_ms = ctx.duration_ms or duration_ms

            transcript, visual = await asyncio.gather(
                self._speech(ctx, video, tmp, duration_ms, has_audio),
                asyncio.to_thread(
                    analyse, ctx, self.name, storage.gcs_uri(ctx.object_name), ctx.content_type, duration_ms
                ),
            )

        ctx.data["transcript"] = transcript
        ctx.data["visual"] = visual
        prefix = _job_prefix(ctx)
        await asyncio.to_thread(storage.upload_text, json.dumps(transcript.to_json()), f"{prefix}/transcript.json")
        await asyncio.to_thread(storage.upload_text, visual.model_dump_json(), f"{prefix}/visual.json")
        words = len(transcript.words)
        detail = f"{words} words heard, {len(visual.screen_text)} on-screen texts"
        ctx.progress(detail)
        return StageResult(detail)

    async def _speech(self, ctx: CheckContext, video: str, tmp: str, duration_ms: int, has_audio: bool) -> Transcript:
        if not has_audio:
            return Transcript()
        audio = os.path.join(tmp, "audio.flac")
        await asyncio.to_thread(extract_audio, video, audio)
        gcs_audio = None
        if duration_ms > 55_000:
            object_name = f"{_job_prefix(ctx)}/audio.flac"
            await asyncio.to_thread(storage.upload_file, audio, object_name, "audio/flac")
            gcs_audio = storage.gcs_uri(object_name)
        return await asyncio.to_thread(transcribe, audio, duration_ms, gcs_audio)


class RealLedger:
    name = "claims"

    async def run(self, ctx: CheckContext) -> StageResult:
        transcript: Transcript = ctx.data["transcript"]
        visual: VisualFacts = ctx.data["visual"]
        ctx.progress("Listing what you say and show")
        items = await asyncio.to_thread(build, ctx, self.name, transcript, visual, ctx.declaration)
        ctx.data["ledger"] = items
        await asyncio.to_thread(
            storage.upload_text, json.dumps(items, ensure_ascii=False), f"{_job_prefix(ctx)}/ledger.json"
        )
        detail = summary(items)
        ctx.progress(detail)
        return StageResult(detail)


class RealChecking:
    name = "checking"

    async def run(self, ctx: CheckContext) -> StageResult:
        ledger = ctx.data["ledger"]
        items = sum(1 for i in ledger if i["type"] not in {"disclosure_label", "product_shot"})
        ctx.progress(f"Checking {items} {'item' if items == 1 else 'items'}")
        candidates = await router.run(ctx)
        ctx.data["candidates"] = candidates
        detail = f"{len(candidates)} possible {'issue' if len(candidates) == 1 else 'issues'} to verify"
        ctx.progress(detail)
        return StageResult(detail)


class RealEvidence:
    """The evidence gate: verbatim spans, then Check Grounding."""

    name = "evidence"

    async def run(self, ctx: CheckContext) -> StageResult:
        candidates: list[Candidate] = ctx.data["candidates"]
        transcript: Transcript = ctx.data["transcript"]
        visual: VisualFacts = ctx.data["visual"]
        sources = gate.Sources(
            transcript=transcript.text,
            screen=" | ".join(t.text for t in visual.screen_text),
            caption=ctx.declaration.get("caption") or "",
            pages=ctx.data.get("pages", {}),
        )
        spans = sum(len(c.evidence) for c in candidates)
        ctx.progress(f"Verifying {spans} quoted {'source' if spans == 1 else 'sources'}")
        flags = await asyncio.gather(*(asyncio.to_thread(gate.apply, c, sources) for c in candidates))
        for n, (candidate, flag) in enumerate(zip(candidates, flags, strict=True)):
            log.info(json.dumps({"event": "gate", "jobId": ctx.job_id, "n": n, "category": flag["category"],
                                 "uncertain": bool(flag.get("uncertain")), "notes": candidate.gate_notes}))
        ctx.data["flags"] = flags
        uncertain = sum(1 for f in flags if f.get("uncertain"))
        detail = f"{len(flags) - uncertain} verified, {uncertain} for a human look"
        ctx.progress(detail)
        return StageResult(detail)


def dedupe(flags: list[dict]) -> list[dict]:
    """A fact check that contradicts a line already says it is untrue, so a
    claims flag on the same line for being unproven or misleading (ASCI
    Code 1.1, 1.4) goes."""
    contradicted = {(f["startMs"], f["endMs"]) for f in flags
                    if f.get("factLabel") == "contradicted" and not f.get("uncertain")}
    return [f for f in flags if not (
        f["category"] == "claims"
        and f.get("citation", {}).get("clauseId") in {"asci-code/I.1.1", "asci-code/I.1.4"}
        and (f["startMs"], f["endMs"]) in contradicted
    )]


class RealReport:
    name = "report"

    async def run(self, ctx: CheckContext) -> StageResult:
        ctx.progress("Writing your report")
        flags = sorted(dedupe(ctx.data.get("flags", [])), key=lambda f: (f["startMs"], f["category"]))
        for n, flag in enumerate(flags, start=1):
            flag["id"] = f"f{n}"
        ctx.flags = flags
        return StageResult(f"{len(flags)} flags")


def real_stages() -> list:
    return [RealExtract(), RealLedger(), RealChecking(), RealEvidence(), RealReport()]
