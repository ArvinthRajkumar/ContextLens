"""A proposed flag plus the spans the evidence gate must verify."""

from dataclasses import dataclass, field
from typing import Literal

EvidenceKind = Literal[
    "clause", "transcript", "screen", "caption", "page", "grounding", "factcheck", "source_transcript"
]


@dataclass(frozen=True)
class Evidence:
    """`quote` must appear word for word in the text `kind` and `ref` point
    to: a clause ID, the video's transcript or overlays, a fetched page URL,
    a Fact Check Tools response, or a borrowed clip's source transcript."""

    kind: EvidenceKind
    quote: str
    ref: str = ""


@dataclass
class Candidate:
    flag: dict
    evidence: list[Evidence]
    # Passages for Vertex Check Grounding (does the flag's evidence line
    # follow from them?). Empty for deterministic checks, which measure
    # rather than interpret.
    grounding_facts: list[str] = field(default_factory=list)
    # The statement Check Grounding tests against those facts; the flag's
    # evidence line when not set.
    grounding_answer: str | None = None
    # Why the gate downgraded it, for the log.
    gate_notes: list[str] = field(default_factory=list)
