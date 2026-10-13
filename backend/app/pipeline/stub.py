"""STUB pipeline. No AI runs here: each stage waits, reports a plausible
detail line, and the report stage writes the bundled fixture flags. Replace
these classes one by one with real implementations."""

import asyncio
import json
from pathlib import Path

from ..config import settings
from .base import CheckContext, StageResult

_FIXTURES = Path(__file__).resolve().parent.parent / "fixtures"


def _fixture(name: str) -> dict:
    return json.loads((_FIXTURES / name).read_text(encoding="utf-8"))


class _Waiting:
    name = ""
    detail = ""

    async def run(self, ctx: CheckContext) -> StageResult:
        ctx.progress(self.detail)
        await asyncio.sleep(settings.stub_stage_seconds)
        return StageResult(self.detail)


class StubExtract(_Waiting):
    name = "extract"
    detail = "Transcribing audio and reading on-screen text"


class StubClaims(_Waiting):
    name = "claims"
    detail = "14 claims found"


class StubChecking(_Waiting):
    name = "checking"
    detail = "Checking 8 claims"


class StubEvidence(_Waiting):
    name = "evidence"
    detail = "Weighing 12 sources"


class StubReport(_Waiting):
    name = "report"
    detail = "Writing your report"

    async def run(self, ctx: CheckContext) -> StageResult:
        result = await super().run(ctx)
        # A re-run gets the "fixed" fixture so the comparison has something
        # to show; a first run gets the full one.
        fixture = _fixture("report_v2.json" if ctx.parent else "report_v1.json")
        ctx.flags = _fit(fixture["flags"], fixture["video"]["durationMs"], ctx.duration_ms)
        return result


def _fit(flags: list[dict], fixture_ms: int, video_ms: int | None) -> list[dict]:
    """Rescales the fixture's timestamps onto the real video's length so
    markers land inside it."""
    if not video_ms or video_ms <= 0:
        return flags
    scale = video_ms / fixture_ms
    return [
        {**f, "startMs": int(f["startMs"] * scale), "endMs": int(f["endMs"] * scale)}
        for f in flags
    ]


def stub_stages() -> list:
    return [StubExtract(), StubClaims(), StubChecking(), StubEvidence(), StubReport()]
