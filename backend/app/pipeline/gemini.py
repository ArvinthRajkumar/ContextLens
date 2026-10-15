"""Gemini on Vertex AI, with token accounting per stage."""

import json
import logging
import random
import re
import threading
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from dataclasses import dataclass
from functools import cache
from typing import TypeVar

import httpx
from google import genai
from google.genai import errors, types
from pydantic import BaseModel

from ..config import settings
from .base import CheckContext

T = TypeVar("T", bound=BaseModel)
log = logging.getLogger(__name__)

_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.MULTILINE)
_lock = threading.Lock()


# Retries are ours, not the SDK's, so each one is logged and every request
# has its own deadline.
_ROUNDS = 3
_BACKOFF_S = (2.0, 6.0)
# Text calls usually finish in under 10 s.
_DEFAULT_ATTEMPT_S = 45.0
# A request still running after this share of its deadline gets a twin.
_HEDGE_SHARE = 0.35
_RETRY_CODES = {429, 499, 500, 502, 503, 504}
_POOL = ThreadPoolExecutor(max_workers=24, thread_name_prefix="gemini")


@cache
def _make_client(location: str) -> genai.Client:
    return genai.Client(
        vertexai=True,
        project=settings.project_id,
        location=location,
        http_options=types.HttpOptions(retry_options=types.HttpRetryOptions(attempts=1)),
    )


def client() -> genai.Client:
    # Checkers start in parallel threads; two clients built at once and one
    # dropped closes the transport they share.
    with _lock:
        return _make_client(settings.gemini_location)


def _client_for_round(round_: int) -> genai.Client:
    fallback = settings.gemini_fallback_location
    if round_ == _ROUNDS and fallback and fallback != settings.gemini_location:
        with _lock:
            return _make_client(fallback)
    return client()


def _call(ctx: CheckContext, stage: str, contents: list, config: types.GenerateContentConfig,
          attempt_s: float | None, *, hedge: bool = True) -> types.GenerateContentResponse:
    """generate_content, hedged. Most calls return in seconds but a few hang
    for a minute or fail with 429/504, so a second identical request starts
    when the first is slower than usual and the first answer wins. Rounds
    that fail outright back off and go again."""
    deadline = attempt_s or _DEFAULT_ATTEMPT_S
    config.http_options = types.HttpOptions(timeout=int(deadline * 1000))
    # No twin for calls that fail by quota (search): it would only double
    # the 429s.
    hedge_after = deadline * _HEDGE_SHARE if hedge else None
    started = time.monotonic()
    sent = 0

    def attempt(round_: int) -> types.GenerateContentResponse:
        return _client_for_round(round_).models.generate_content(
            model=settings.gemini_model, contents=contents, config=config
        )

    for round_ in range(1, _ROUNDS + 1):
        running = {_POOL.submit(attempt, round_)}
        sent += 1
        hedged = False
        last_error: Exception | None = None
        while running:
            done, running = wait(running, timeout=None if hedged else hedge_after, return_when=FIRST_COMPLETED)
            if not done and not hedged and hedge_after is not None:
                running.add(_POOL.submit(attempt, round_))
                sent += 1
                hedged = True
                log.info(json.dumps({"event": "model_hedge", "jobId": ctx.job_id, "stage": stage}))
                continue
            for future in done:
                error = future.exception()
                if error is None:
                    for other in running:
                        other.cancel()
                    response = future.result()
                    _count(ctx, stage, response)
                    usage = response.usage_metadata
                    log.info(json.dumps({
                        "event": "model_call", "jobId": ctx.job_id, "stage": stage, "requests": sent, "round": round_,
                        "search": not hedge,
                        "ms": int((time.monotonic() - started) * 1000),
                        "inputTokens": (usage.prompt_token_count or 0) if usage else 0,
                        "outputTokens": ((usage.candidates_token_count or 0) + (usage.thoughts_token_count or 0))
                        if usage else 0,
                    }))
                    return response
                code = getattr(error, "code", None) or "timeout"
                if not isinstance(error, (httpx.TimeoutException, errors.APIError)) or (
                    code != "timeout" and code not in _RETRY_CODES
                ):
                    raise error
                last_error = error
                log.warning(json.dumps({"event": "model_retry", "jobId": ctx.job_id, "stage": stage,
                                        "round": round_, "reason": code}))
        if round_ == _ROUNDS:
            raise last_error or RuntimeError("model call failed")
        time.sleep(_BACKOFF_S[min(round_, len(_BACKOFF_S)) - 1] + random.uniform(0, 0.5))
    raise RuntimeError("unreachable")


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
    *,
    thinking_budget: int = 0,
    media_resolution: types.MediaResolution | None = None,
    attempt_seconds: float | None = None,
) -> T:
    """One call that must come back as `schema`, at temperature 0 so the
    same video gives the same result. No thinking by default: it is billed
    as output and adds seconds; a call that needs it asks for a budget."""
    config = types.GenerateContentConfig(
        system_instruction=system,
        temperature=0,
        response_mime_type="application/json",
        response_schema=schema,
        media_resolution=media_resolution,
        thinking_config=types.ThinkingConfig(thinking_budget=thinking_budget),
    )
    response = _call(ctx, stage, contents, config, attempt_seconds)
    parsed = response.parsed
    if isinstance(parsed, schema):
        return parsed
    return schema.model_validate_json(response.text or "{}")


@dataclass(frozen=True)
class WebSource:
    uri: str
    title: str
    domain: str = ""


@dataclass(frozen=True)
class Support:
    """A span of the model's answer that Google Search grounding attributes
    to retrieved pages (indexes into the sources), with confidences."""

    text: str
    sources: tuple[int, ...]
    confidence: tuple[float, ...]


def generate_grounded(
    ctx: CheckContext, stage: str, prompt: str, system: str
) -> tuple[dict, list[WebSource], list[Support]]:
    """A Google Search grounded call. Structured output isn't available with
    search, so the model returns JSON as text; also returns the pages the
    answer was grounded on and which spans of the answer each supports."""
    config = types.GenerateContentConfig(
        system_instruction=system,
        temperature=0,
        tools=[types.Tool(google_search=types.GoogleSearch())],
        # Search does the work; reasoning on top only adds cost and seconds.
        thinking_config=types.ThinkingConfig(thinking_budget=0),
    )
    response = _call(ctx, stage, [prompt], config, 60.0, hedge=False)
    text = _FENCE.sub("", (response.text or "").strip())
    start, end = text.find("{"), text.rfind("}")
    data = json.loads(text[start : end + 1]) if start >= 0 < end else {}
    sources: list[WebSource] = []
    supports: list[Support] = []
    candidate = response.candidates[0] if response.candidates else None
    metadata = candidate.grounding_metadata if candidate else None
    if metadata:
        for chunk in metadata.grounding_chunks or []:
            web = chunk.web
            sources.append(WebSource(web.uri or "", web.title or web.domain or "", web.domain or "") if web else WebSource("", ""))
        for support in metadata.grounding_supports or []:
            if support.segment and support.segment.text:
                supports.append(Support(
                    support.segment.text,
                    tuple(support.grounding_chunk_indices or ()),
                    tuple(support.confidence_scores or ()),
                ))
    return data, sources, supports
