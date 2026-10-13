"""Gemini on Vertex AI, structured output only, with token accounting."""

from functools import cache
from typing import TypeVar

from google import genai
from google.genai import types
from pydantic import BaseModel

from ..config import settings
from .base import CheckContext

T = TypeVar("T", bound=BaseModel)


@cache
def _client() -> genai.Client:
    # Vertex answers 429 when the shared quota is busy; back off and retry
    # (2, 4, 8, 16 s) before the stage fails.
    return genai.Client(
        vertexai=True,
        project=settings.project_id,
        location=settings.gemini_location,
        http_options=types.HttpOptions(
            retry_options=types.HttpRetryOptions(attempts=5, initial_delay=2.0, exp_base=2.0, max_delay=16.0)
        ),
    )


def generate(
    ctx: CheckContext,
    stage: str,
    contents: list,
    schema: type[T],
    system: str,
    media_resolution: types.MediaResolution | None = None,
) -> T:
    """One call that must come back as `schema`. Deterministic settings: the
    same video should give the same ledger."""
    response = _client().models.generate_content(
        model=settings.gemini_model,
        contents=contents,
        config=types.GenerateContentConfig(
            system_instruction=system,
            temperature=0,
            response_mime_type="application/json",
            response_schema=schema,
            media_resolution=media_resolution,
        ),
    )
    usage = response.usage_metadata
    if usage is not None:
        ctx.add_tokens(
            stage,
            usage.prompt_token_count,
            (usage.candidates_token_count or 0) + (usage.thoughts_token_count or 0),
        )
    parsed = response.parsed
    if isinstance(parsed, schema):
        return parsed
    return schema.model_validate_json(response.text or "{}")
