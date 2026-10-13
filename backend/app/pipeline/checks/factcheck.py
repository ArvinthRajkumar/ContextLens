"""Fact check: Gemini picks the checkable claims, Google's Fact Check Tools
looks for an existing review, and Gemini with Google Search grounding
judges the rest. Every quote must be found on a page we fetched."""

import asyncio
import json
import logging
import os
import re
import time
from typing import Literal

import httpx
from pydantic import BaseModel, Field
from rapidfuzz import fuzz

from ..base import CheckContext
from ..gemini import generate, generate_grounded
from ..textmatch import contains
from .candidate import Candidate, Evidence
from .pages import Page, fetch

FACT_TYPES = {"factual_claim", "health_claim", "financial_claim"}
log = logging.getLogger(__name__)

_FACTCHECK_URL = "https://factchecktools.googleapis.com/v1alpha1/claims:search"
# How close a published review's claim must be to ours to count as the
# same claim.
_REVIEW_MATCH = 70
_FETCH_SECONDS = 12


class Checkable(BaseModel):
    item_id: str
    checkable: bool = Field(description="False for personal experience, opinion, jokes or promises about the creator's own life.")
    claim: str = Field(description="The claim as one standalone English sentence, with its subject spelled out.")
    domain: Literal["health", "finance", "other"]


class Checkables(BaseModel):
    items: list[Checkable]


_FILTER = """You pick which statements in an Indian creator's video can be fact-checked against
public sources. A checkable claim states a general fact (a health effect, a statistic, a rule, a
financial fact). Personal experience ("my sugar is under control") is not checkable here. Rewrite each
checkable one as a standalone English sentence with its subject (for example "Most Indians are
deficient in vitamin D")."""

_VERDICT = """You fact-check one claim from an Indian creator's video. Always run Google Search
first and base the verdict only on pages you found.
Prefer primary or authoritative sources: ICMR, WHO, Cochrane, PubMed reviews, RBI, SEBI, DICGC,
government sites, established fact-checkers. Answer with JSON only:
{"verdict": "supported" | "contradicted" | "insufficient_evidence",
 "quote": "one sentence copied word for word from the best source page",
 "source_title": "...", "publisher": "...",
 "title": "under 60 characters, sentence case, what is true",
 "explanation": "one or two sentences to the creator, second person, no dashes as punctuation",
 "suggested_fix": "one concrete rewording or cut",
 "sources_say": "one or two sentences stating only what the sources say about the claim, without mentioning the creator"}
Use insufficient_evidence when sources disagree or none address the claim."""


# Long dashes in model copy become commas (house style); quotes are never touched.
_DASHES = re.compile(r"\s*[" + chr(0x2013) + chr(0x2014) + r"]\s*")


def _clean(text: str) -> str:
    return _DASHES.sub(", ", text).strip()


async def _review(query: str) -> tuple[dict, str] | None:
    """An existing published fact check of this claim, with the raw response
    text the gate verifies against."""
    key = os.environ.get("FACTCHECK_API_KEY")
    if not key:
        return None
    async with httpx.AsyncClient(timeout=10) as http:
        # The key goes in a header so it never appears in a URL.
        response = await http.get(
            _FACTCHECK_URL, params={"query": query, "pageSize": 5}, headers={"X-Goog-Api-Key": key}
        )
    if response.status_code != 200:
        return None
    for claim in response.json().get("claims", []):
        text = claim.get("text") or ""
        reviews = claim.get("claimReview") or []
        if reviews and fuzz.token_set_ratio(query.lower(), text.lower()) >= _REVIEW_MATCH:
            return {"claim": claim, "review": reviews[0]}, json.dumps(response.json(), ensure_ascii=False)
    return None


async def _fetch(url: str) -> Page | None:
    """A slow site must not hold up the report."""
    try:
        return await asyncio.wait_for(asyncio.to_thread(fetch, url), _FETCH_SECONDS)
    except TimeoutError:
        return None


def _page_with(quote: str, pages: list[Page]) -> Page | None:
    return next((p for p in pages if contains(p.text, quote)), None)


async def _judge(ctx: CheckContext, stage: str, item: dict, check: Checkable) -> Candidate | None:
    started = time.monotonic()
    found = await _review(check.claim)
    severity = "high" if check.domain in {"health", "finance"} else "medium"
    base = {
        "category": "factcheck",
        "startMs": item["startMs"],
        "endMs": item["endMs"],
        "fingerprint": "factcheck:" + re.sub(r"[^a-z0-9]+", "-", check.claim.lower()).strip("-")[:50],
    }
    spoken = Evidence("transcript" if item["source"] == "speech" else "screen", item["text"])
    if found:
        hit, raw = found
        review, claim = hit["review"], hit["claim"]
        key = f"factcheck:{review.get('url', check.claim)}"
        ctx.data.setdefault("pages", {})[key] = raw
        publisher = (review.get("publisher") or {}).get("name") or "a fact-checker"
        rating = review.get("textualRating") or "rated"
        return Candidate(
            {
                **base,
                "severity": "low" if rating.lower().startswith(("true", "correct")) else severity,
                "title": _clean(f"{publisher} has fact-checked this before"),
                "evidence": _clean(f'"{item["text"]}" matches a claim {publisher} rated: {rating}.'),
                "citation": {"title": review.get("title") or claim.get("text", ""), "url": review.get("url"), "publisher": publisher},
                "sourceQuote": {"text": claim.get("text", ""), "source": f"{publisher}, via Google Fact Check Tools"},
                "suggestedFix": "Read the fact check and change or cut the line to match what it found.",
                "factLabel": "previously_fact_checked",
            },
            [spoken, Evidence("factcheck", claim.get("text", ""), key)],
        )

    data, sources = await asyncio.to_thread(generate_grounded, ctx, stage, f"Claim: {check.claim}", _VERDICT)
    if not sources:
        # Answered from memory: ask again, the gate needs pages to check.
        data, sources = await asyncio.to_thread(
            generate_grounded, ctx, stage, f"Search Google, then fact-check. Claim: {check.claim}", _VERDICT
        )
    verdict = data.get("verdict")
    if verdict not in {"supported", "contradicted", "insufficient_evidence"}:
        return None
    quote = (data.get("quote") or "").strip()
    judged = time.monotonic()
    pages = [p for p in await asyncio.gather(*(_fetch(s.uri) for s in sources[:5])) if p]
    store = ctx.data.setdefault("pages", {})
    for fetched in pages:
        store[fetched.url] = fetched.text
    page = _page_with(quote, pages) if quote else None
    source_page = page or (pages[0] if pages else None)
    flag = {
        **base,
        "title": _clean(data.get("title") or check.claim)[:80],
        "evidence": _clean(data.get("explanation") or ""),
        "suggestedFix": _clean(data.get("suggested_fix") or "Check the source and reword the line."),
        "factLabel": verdict,
    }
    if verdict != "supported":
        flag["severity"] = "low" if verdict == "insufficient_evidence" else severity
    if source_page:
        flag["citation"] = {
            "title": data.get("source_title") or source_page.title or source_page.url,
            "url": source_page.url,
            "publisher": data.get("publisher") or None,
        }
    evidence = [spoken]
    if verdict != "insufficient_evidence" or quote:
        flag["sourceQuote"] = {"text": quote, "source": flag.get("citation", {}).get("title", "Web source")}
        # Page "" fails the gate on purpose: no fetched page holds the quote.
        evidence.append(Evidence("page", quote, page.url if page else ""))
    # Grounding checks the explanation against what the sources say, around
    # the quote on the page that holds it, then the start of the others.
    context = []
    terms = [w for w in re.findall(r"[a-z]{5,}", check.claim.lower())]
    for fetched in ([page] if page else []) + [p for p in pages if p is not page]:
        lowered = fetched.text.lower()
        at = lowered.find(quote.lower()[:40]) if fetched is page else -1
        if at < 0:
            # Skip the navigation: start where the page first talks about the claim.
            hits = [h for h in (lowered.find(t) for t in terms) if h >= 0]
            at = min(hits) if hits else 0
        context.append(fetched.text[max(0, at - 3000) : at + 5000])
    return Candidate(
        flag,
        evidence,
        grounding_facts=context if page else [],
        grounding_answer=_clean(data.get("sources_say") or "") or None,
        gate_notes=[
            f"pages fetched: {len(pages)}/{len(sources)}",
            f"ms: search+verdict {int((judged - started) * 1000)}, pages {int((time.monotonic() - judged) * 1000)}",
        ],
    )


async def check(ctx: CheckContext, stage: str, ledger: list[dict]) -> list[Candidate]:
    """Fetched pages and review responses go to ctx.data["pages"], keyed
    by URL, for the gate."""
    items = [i for i in ledger if i["type"] in FACT_TYPES and "factcheck" in i.get("checks", []) and "startMs" in i]
    if not items:
        return []
    prompt = "\n".join(f'{i["id"]}: "{i["text"]}"' + (f' [about: {i["subject"]}]' if i.get("subject") else "") for i in items)
    picks = await asyncio.to_thread(generate, ctx, stage, [prompt], Checkables, _FILTER)
    by_id = {i["id"]: i for i in items}
    jobs = [_judge(ctx, stage, by_id[p.item_id], p) for p in picks.items if p.checkable and p.item_id in by_id]
    results = await asyncio.gather(*jobs, return_exceptions=True)
    for r in results:
        if isinstance(r, Exception):
            log.warning("Fact check failed for one claim: %s", type(r).__name__)
    return [r for r in results if isinstance(r, Candidate)]
