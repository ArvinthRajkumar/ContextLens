"""The evidence gate. Every quoted span must appear word for word in what
it cites (clause text, the video's transcript, overlays or caption, a
fetched page, a Fact Check Tools response, a clip's source transcript),
and interpreted flags must pass Vertex Check Grounding. A flag that fails
either becomes uncertain: listed for a human look, never counted."""

import logging
from collections.abc import Callable
from dataclasses import dataclass

import google.auth
from google.auth.transport.requests import AuthorizedSession

from ...config import settings
from ..textmatch import contains
from .candidate import Candidate, Evidence
from .clauses import CLAUSES

log = logging.getLogger(__name__)

_GROUNDING_URL = (
    "https://discoveryengine.googleapis.com/v1/projects/{project}/locations/global/"
    "groundingConfigs/default_grounding_config:check"
)


@dataclass
class Sources:
    transcript: str
    screen: str
    caption: str
    pages: dict[str, str]


def haystack(ev: Evidence, sources: Sources) -> str | None:
    match ev.kind:
        case "clause":
            clause = CLAUSES.get(ev.ref)
            return clause["text"] if clause else None
        case "transcript":
            return sources.transcript
        case "screen":
            return sources.screen
        case "caption":
            return sources.caption
        case "page" | "grounding" | "factcheck" | "source_transcript":
            return sources.pages.get(ev.ref)
    return None


def verbatim_failures(candidate: Candidate, sources: Sources) -> list[str]:
    failures = []
    for ev in candidate.evidence:
        text = haystack(ev, sources)
        if text is None:
            failures.append(f"{ev.kind}: source not available")
        elif not contains(text, ev.quote):
            failures.append(f"{ev.kind}: quote not found")
    return failures


def check_grounding(answer: str, facts: list[str]) -> float | None:
    """Vertex Check Grounding support score for `answer` given `facts`,
    from 0 to 1. None when the service can't be reached."""
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    session = AuthorizedSession(credentials)
    response = session.post(
        _GROUNDING_URL.format(project=settings.project_id),
        json={
            "answerCandidate": answer,
            "facts": [{"factText": f[:10_000]} for f in facts[:20]],
            "groundingSpec": {"citationThreshold": 0.6},
        },
        timeout=20,
    )
    if response.status_code != 200:
        log.warning("Check Grounding returned %s", response.status_code)
        return None
    return float(response.json().get("supportScore", 0.0))


def _verified(text: str, candidate: Candidate, sources: Sources) -> bool:
    if not text:
        return False
    for ev in candidate.evidence:
        if ev.quote == text:
            source = haystack(ev, sources)
            return source is not None and contains(source, text)
    return False


def apply(
    candidate: Candidate,
    sources: Sources,
    grounding: Callable[[str, list[str]], float | None] = check_grounding,
) -> dict:
    """Returns the flag to publish, marked uncertain when it failed."""
    flag = dict(candidate.flag)
    failures = verbatim_failures(candidate, sources)
    if not failures and candidate.grounding_facts:
        score = grounding(candidate.grounding_answer or flag["evidence"], candidate.grounding_facts)
        floor = settings.claims_min_support if candidate.drop_if_weak else settings.grounding_min_support
        if score is not None and score < floor:
            failures.append(f"grounding: support {score:.2f}")
            if candidate.drop_if_weak:
                flag["dropped"] = True
        elif score is not None:
            candidate.gate_notes.append(f"grounding {score:.2f}")
    candidate.gate_notes += failures
    if failures:
        flag["uncertain"] = True
        # A quote we couldn't find is not shown as "From the source".
        quote = flag.get("sourceQuote")
        if quote and not _verified(quote["text"], candidate, sources):
            flag.pop("sourceQuote")
    return flag
