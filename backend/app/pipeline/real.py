"""Real stages. So far: Extract (Chirp 3 + Gemini) and the claim ledger;
the checkers, evidence gate and report are still stubs."""

import asyncio
import json
import os
import tempfile

from .. import storage
from .base import CheckContext, StageResult
from .ledger import build, summary
from .media import MediaError, extract_audio, probe
from .speech import Transcript, transcribe
from .stub import StubChecking, StubEvidence, StubReport
from .visual import VisualFacts, analyse


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
        items = await asyncio.to_thread(build, ctx, self.name, transcript, visual, ctx.declaration)
        ctx.data["ledger"] = items
        await asyncio.to_thread(
            storage.upload_text, json.dumps(items, ensure_ascii=False), f"{_job_prefix(ctx)}/ledger.json"
        )
        detail = summary(items)
        ctx.progress(detail)
        return StageResult(detail)


def real_stages() -> list:
    return [RealExtract(), RealLedger(), StubChecking(), StubEvidence(), StubReport()]
