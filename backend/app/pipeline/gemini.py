"""Gemini on Vertex AI, with token accounting per stage."""

import json
import re
import threading
from dataclasses import dataclass
from functools import cache
from typing import TypeVar

from google import genai
from google.genai import types
from pydantic import BaseModel

from ..config import settings
from .base import CheckContext

T = TypeVar("T", bound=BaseModel)

_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.MULTILINE)
_lock = threading.Lock()


@cache
def _make_client() -> genai.Client:
    # Vertex answers 429 when the shared quota is busy; back off and retry
    # (2, 4, 8, 16 s) before the stage fails.
    return genai.Client(
        vertexai=True,
        project=settings.project_id,
        location=settings.gemini_location,
        # A call that hangs fails the stage after 3 minutes instead of
        # holding the job forever (video reads have taken close to that).
        http_options=types.HttpOptions(
            timeout=180_000,
            retry_options=types.HttpRetryOptions(attempts=5, initial_delay=2.0, exp_base=2.0, max_delay=16.0),
        ),
    )


def client() -> genai.Client:
    # Checkers start in parallel threads; two clients built at once and one
    # dropped closes the transport they share.
    with _lock:
        return _make_client()


def _count(ctx: CheckContext, stage: str, response: types.GenerateContentResponse) -> None:
    usage = response.usage_metadata
    if usage is not None:
        ctx.add_tokens(
            stage,
            usage.prompt_token_count,
            (usage.candidates_token_count or 0) + (usage.thoughts_token_count or 0),
        )


def generate(
    ctx: CheckContext,
    stage: str,
    contents: list,
    schema: type[T],
    system: str,
) -> T:
    """One call that must come back as `schema`, at temperature 0 so the
    same video gives the same result."""
    response = client().models.generate_content(
        model=settings.gemini_model,
        contents=contents,
        config=types.GenerateContentConfig(
            system_instruction=system,
            temperature=0,
            response_mime_type="application/json",
            response_schema=schema,
        ),
    )
    _count(ctx, stage, response)
    parsed = response.parsed
    if isinstance(parsed, schema):
        return parsed
    return schema.model_validate_json(response.text or "{}")


@dataclass(frozen=True)
class WebSource:
    uri: str
    title: str


def generate_grounded(ctx: CheckContext, stage: str, prompt: str, system: str) -> tuple[dict, list[WebSource]]:
    """A Google Search grounded call. Structured output isn't available with
    search, so the model returns JSON as text; also returns the pages the
    answer was grounded on."""
    response = client().models.generate_content(
        model=settings.gemini_model,
        contents=[prompt],
        config=types.GenerateContentConfig(
            system_instruction=system,
            temperature=0,
            tools=[types.Tool(google_search=types.GoogleSearch())],
        ),
    )
    _count(ctx, stage, response)
    text = _FENCE.sub("", (response.text or "").strip())
    start, end = text.find("{"), text.rfind("}")
    data = json.loads(text[start : end + 1]) if start >= 0 < end else {}
    sources: list[WebSource] = []
    candidate = response.candidates[0] if response.candidates else None
    metadata = candidate.grounding_metadata if candidate else None
    for chunk in (metadata.grounding_chunks or []) if metadata else []:
        if chunk.web and chunk.web.uri:
            sources.append(WebSource(chunk.web.uri, chunk.web.title or chunk.web.domain or ""))
    return data, sources
