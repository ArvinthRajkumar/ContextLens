from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass
class CheckContext:
    """What one check knows; stages read it and add to it."""

    job_id: str
    uid: str
    object_name: str
    declaration: dict[str, Any]
    # Set for a re-run: the parent job's document, for comparison.
    parent: dict[str, Any] | None = None
    # Filled by the stages (transcript, claims, evidence...); free-form so a
    # real stage can add what the next one needs.
    data: dict[str, Any] = field(default_factory=dict)
    # Final flags, in the Firestore schema. Set by the report stage.
    flags: list[dict[str, Any]] = field(default_factory=list)


@dataclass(frozen=True)
class StageResult:
    """Optional one-line live detail shown under the stage in the app."""

    detail: str | None = None


class Stage(Protocol):
    # One of: extract, claims, checking, evidence, report.
    name: str

    async def run(self, ctx: CheckContext) -> StageResult: ...
