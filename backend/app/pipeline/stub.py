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

    async def _wait(self) -> None:
        await asyncio.sleep(settings.stub_stage_seconds)


class StubExtract(_Waiting):
    name = "extract"

    async def run(self, ctx: CheckContext) -> StageResult:
        await self._wait()
        return StageResult("Transcribing audio and reading on-screen text")


class StubClaims(_Waiting):
    name = "claims"

    async def run(self, ctx: CheckContext) -> StageResult:
        await self._wait()
        return StageResult("14 claims found")


class StubChecking(_Waiting):
    name = "checking"

    async def run(self, ctx: CheckContext) -> StageResult:
        await self._wait()
        return StageResult("Checking 8 claims")


class StubEvidence(_Waiting):
    name = "evidence"

    async def run(self, ctx: CheckContext) -> StageResult:
        await self._wait()
        return StageResult("Weighing 12 sources")


class StubReport(_Waiting):
    name = "report"

    async def run(self, ctx: CheckContext) -> StageResult:
        await self._wait()
        # A re-run gets the "fixed" fixture so the comparison has something
        # to show; a first run gets the full one.
        fixture = _fixture("report_v2.json" if ctx.parent else "report_v1.json")
        ctx.flags = fixture["flags"]
        return StageResult("Writing your report")


def stub_stages() -> list:
    return [StubExtract(), StubClaims(), StubChecking(), StubEvidence(), StubReport()]
