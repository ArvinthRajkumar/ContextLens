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
from urllib.parse import urlparse

import httpx
from pydantic import BaseModel, Field
from rapidfuzz import fuzz

from ..base import CheckContext
from ..gemini import Support, generate, generate_grounded
from ..textmatch import contains, tokens
from .candidate import Candidate, Evidence
from .pages import Page, fetch

FACT_TYPES = {"factual_claim", "health_claim", "financial_claim"}
log = logging.getLogger(__name__)

_FACTCHECK_URL = "https://factchecktools.googleapis.com/v1alpha1/claims:search"
# How close a published review's claim must be to ours to count as the
# same claim.
_REVIEW_MATCH = 70
_FETCH_SECONDS = 12
_MAX_SOURCES = 6
_SUPPORT_CONFIDENCE = 0.7
_NO_PAGE = Page("", "", "")

# Sources the verdict should lean on: Indian government and regulators,
# health bodies, and IFCN signatory fact-checkers working in India.
_TRUSTED = (
    "gov.in", "nic.in", "who.int", "nih.gov", "cochrane.org", "cochranelibrary.com",
    "rbi.org.in", "sebi.gov.in", "boomlive.in", "altnews.in", "factly.in", "newschecker.in",
    "vishvasnews.com", "thequint.com", "factcrescendo.com", "newsmeter.in", "indiatoday.in",
)


def trusted(url_or_domain: str) -> bool:
    host = (urlparse(url_or_domain).hostname if "://" in url_or_domain else url_or_domain) or ""
    return any(host == d or host.endswith("." + d) for d in _TRUSTED)


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
Prefer, in order: Indian government and regulators (gov.in, pib.gov.in, icmr.gov.in, rbi.org.in,
sebi.gov.in), WHO, NIH and Cochrane, then IFCN fact-checkers (BOOM, Alt News, Factly, Newschecker,
Vishvas News). Copy the quote exactly from a page you found and repeat it in the explanation. Answer with JSON only:
{"verdict": "supported" | "contradicted" | "insufficient_evidence",
 "quote": "one sentence copied word for word from the best source page",
 "source_title": "...", "publisher": "...",
 "title": "under 60 characters, sentence case, what is true",
 "explanation": "one or two sentences to the creator, second person, no dashes as punctuation",
 "suggested_fix": "one concrete rewording or cut",
 "sources_say": "one sentence stating only what the sources say about the claim, without mentioning the creator"}
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

    data, sources, supports = await asyncio.to_thread(
        generate_grounded, ctx, stage, f"Search Google, then fact-check. Claim: {check.claim}", _VERDICT
    )
    if not sources:
        # Answered from memory: ask again, the gate needs pages to check.
        data, sources, supports = await asyncio.to_thread(
            generate_grounded, ctx, stage, f"Use Google Search for this. Claim: {check.claim}", _VERDICT
        )
    verdict = data.get("verdict")
    if verdict not in {"supported", "contradicted", "insufficient_evidence"}:
        return None
    quote = (data.get("quote") or "").strip()
    judged = time.monotonic()
    fetched = list(await asyncio.gather(*(_fetch(s.uri) for s in sources[:_MAX_SOURCES])))
    store = ctx.data.setdefault("pages", {})
    for page in fetched:
        if page and page.text:
            store[page.url] = page.text

    # Where the quote is backed: word for word on a page we fetched (trusted
    # sites first), else a span of the answer that Google Search grounding
    # attributes to a retrieved page. Either way the URL is one Gemini
    # actually retrieved.
    def rank(i: int) -> bool:
        return not trusted(sources[i].domain or (fetched[i] or _NO_PAGE).url)

    order = sorted(range(len(fetched)), key=rank)
    verbatim = next((i for i in order if quote and fetched[i] and contains(fetched[i].text, quote)), None)
    attributed = None if verbatim is not None or not quote else _attributed(quote, supports, len(fetched))
    chosen = verbatim if verbatim is not None else attributed
    source_page = fetched[chosen] if chosen is not None else None
    url = (source_page.url if source_page else sources[chosen].uri) if chosen is not None else None

    flag = {
        **base,
        "title": _clean(data.get("title") or check.claim)[:80],
        "evidence": _clean(data.get("explanation") or ""),
        "suggestedFix": _clean(data.get("suggested_fix") or "Check the source and reword the line."),
        "factLabel": verdict,
    }
    if verdict != "supported":
        flag["severity"] = "low" if verdict == "insufficient_evidence" else severity
    if chosen is not None:
        flag["citation"] = {
            "title": data.get("source_title") or (source_page.title if source_page else "") or sources[chosen].title or url,
            "url": url,
            "publisher": data.get("publisher") or sources[chosen].domain or None,
        }
    evidence = [spoken]
    notes = [f"pages read: {sum(1 for p in fetched if p and p.text)}/{len(sources)}"]
    if verdict != "insufficient_evidence" or quote:
        source_name = flag.get("citation", {}).get("title", "Web source")
        if verbatim is not None:
            evidence.append(Evidence("page", quote, url))
            flag["sourceQuote"] = {"text": quote, "source": source_name}
        elif attributed is not None:
            # Not on a page we could read, but Google's grounding ties it to
            # one it retrieved: verified against that span, labelled as such.
            key = f"grounding:{url}"
            store[key] = " ".join(s.text for s in supports)
            evidence.append(Evidence("grounding", quote, key))
            flag["sourceQuote"] = {"text": quote, "source": f"{source_name}, as matched by Google Search grounding"}
            notes.append("quote matched by grounding support")
        else:
            # "" fails the gate on purpose: nothing retrieved backs the quote.
            evidence.append(Evidence("page", quote, ""))
            flag["sourceQuote"] = {"text": quote, "source": source_name}

    # Check Grounding tests what the sources say against the pages, around
    # the quote on the page that holds it and where the others discuss the
    # claim. Without readable pages there is nothing independent to test.
    context = []
    terms = re.findall(r"[a-z]{5,}", check.claim.lower())
    readable = [p for p in fetched if p and p.text]
    for page in sorted(readable, key=lambda p: p is not source_page):
        lowered = page.text.lower()
        at = lowered.find(quote.lower()[:40]) if quote else -1
        if at < 0:
            hits = [h for h in (lowered.find(t) for t in terms) if h >= 0]
            at = min(hits) if hits else 0
        context.append(page.text[max(0, at - 3000) : at + 5000])
    notes.append(f"ms: search+verdict {int((judged - started) * 1000)}, pages {int((time.monotonic() - judged) * 1000)}")
    return Candidate(
        flag,
        evidence,
        grounding_facts=context if chosen is not None else [],
        grounding_answer=_clean(data.get("sources_say") or "") or None,
        gate_notes=notes,
    )


def _attributed(quote: str, supports: list[Support], count: int) -> int | None:
    """The retrieved source a grounding support ties the quote to, when the
    support's span and the quote match after normalizing (one contains the
    other, 40 characters or more) with confidence of 0.7 or more."""
    wanted = " ".join(tokens(quote))
    best: tuple[float, int] | None = None
    for support in supports:
        span = " ".join(tokens(support.text))
        if len(span) < 40 or not (span in wanted or wanted in span):
            continue
        scores = support.confidence or (1.0,) * len(support.sources)
        for index, score in zip(support.sources, scores, strict=False):
            if index < count and score >= _SUPPORT_CONFIDENCE and (best is None or score > best[0]):
                best = (score, index)
    return best[1] if best else None


async def check(ctx: CheckContext, stage: str, ledger: list[dict]) -> list[Candidate]:
    """Fetched pages and review responses go to ctx.data["pages"], keyed
    by URL, for the gate."""
    # Every factual, health or money claim goes to the filter, whatever the
    # ledger's checks list says: the filter decides what is checkable.
    items = [i for i in ledger if i["type"] in FACT_TYPES and "startMs" in i]
    if not items:
        return []
    # The whole transcript rides along: "most Indians are deficient" only
    # becomes a checkable claim once the filter sees the line before it.
    transcript = ctx.data.get("transcript")
    context = f"Full transcript: {transcript.text}\n\n" if transcript and transcript.words else ""
    lines = "\n".join(f'{i["id"]}: "{i["text"]}"' + (f' [about: {i["subject"]}]' if i.get("subject") else "") for i in items)
    prompt = f"{context}Statements:\n{lines}"
    picks = await asyncio.to_thread(generate, ctx, stage, [prompt], Checkables, _FILTER, thinking_budget=0)
    by_id = {i["id"]: i for i in items}
    jobs = [_judge(ctx, stage, by_id[p.item_id], p) for p in picks.items if p.checkable and p.item_id in by_id]
    results = await asyncio.gather(*jobs, return_exceptions=True)
    for r in results:
        if isinstance(r, Exception):
            log.warning(json.dumps({"event": "factcheck_claim_failed", "jobId": ctx.job_id, "error": type(r).__name__}))
            # The report must say a fact check is missing, not look clean.
            ctx.data.setdefault("skipped", []).append("factcheck")
    return [r for r in results if isinstance(r, Candidate)]
