"""Claims compliance: each claim is judged against the clauses retrieved
for it, and the judge may only cite those clauses, quoting them."""

import json
import logging
import re
from typing import Literal

from pydantic import BaseModel, Field
from rapidfuzz import fuzz

from ..base import CheckContext
from ..gemini import generate
from .candidate import Candidate, Evidence
from ..textmatch import contains, normalize, tokens
from .clauses import CLAUSES, best_sentence, citation, clause_text, label, retrieve, scheduled_conditions

log = logging.getLogger(__name__)

CLAIM_TYPES = {"health_claim", "financial_claim", "personal_result", "promo_offer"}

_HEALTH = ["asci-code/I.1.1", "asci-code/I.1.4", "asci-code/I.ex(d)"]
_FINANCE = ["asci-code/I.ex(e)", "asci-code/I.1.5", "asci-ig/add2-I.1"]
_SCHEDULE = ["dmr-act/3(d)", "dmr-act/schedule"]


class Finding(BaseModel):
    item_ids: list[str] = Field(description="Ledger items this finding covers.")
    violates: bool
    clause_id: str = Field(description="One of the candidate clause IDs given for these items.")
    clause_quote: str = Field(description="The words of that clause the finding rests on, copied exactly.")
    claim_quote: str = Field(
        description="The exact words of the claim that break the clause, copied from one of the covered items."
    )
    title: str = Field(description="Under 60 characters, plain, sentence case.")
    evidence: str = Field(
        description="One or two sentences to the creator: quote what they said, then say which words of the clause it breaks."
    )
    severity: Literal["high", "medium", "low"]
    suggested_fix: str = Field(description="One concrete change to the video or caption.")


class Findings(BaseModel):
    findings: list[Finding]


_SYSTEM = """You check claims in an Indian creator's video against advertising rules before it is posted.
Each claim comes with candidate clauses (ID and exact text). Decide whether the claim, as said or
shown, breaks one of them. Rules:
- Cite only a candidate clause of that claim, and copy clause_quote word for word from its text.
- A claim that suggests a product diagnoses, cures, mitigates, treats or prevents a condition in the
  Drugs and Magic Remedies Act Schedule breaks s. 3(d); that is statutory and comes first.
- Health claims need substantiation (ASCI Code 1.1) and restraint (example (d)); returns or safety
  of money must not mislead (example (e)).
- Group claims that are one issue (for example two lines about the same disease) into one finding,
  and give each claim at most one finding: the most specific clause it breaks.
- Only flag what a regulator would act on: health, cure, prevention or body results; returns, safety
  or guarantees about money; investment or medical advice; claims stated as objective fact that
  cannot be true as said. Leave out opinions, taste, ordinary product specs (battery life, capacity,
  price, flavour), and personal experience that promises no health or money outcome.
- claim_quote must be the words that break the rule, copied exactly from the claim.
- Write to the creator in second person, short sentences, no jargon, never use dashes as punctuation."""


def wants(item: dict) -> bool:
    """Claims always go to the judge; routing must not hang on the model's
    optional checks list. Offers only when the ledger asked for it."""
    if "startMs" not in item or item["type"] not in CLAIM_TYPES:
        return False
    return item["type"] != "promo_offer" or "claims" in item.get("checks", [])


def _candidates(item: dict, retrieved: list[str], category: str) -> list[str]:
    forced: list[str] = []
    if item["type"] in {"health_claim", "personal_result"} or category == "health":
        forced += _HEALTH
    if scheduled_conditions(item["text"]):
        forced = _SCHEDULE + forced
    if item["type"] == "financial_claim" or category == "finance":
        forced += _FINANCE
    seen: list[str] = []
    for cid in forced + retrieved:
        if cid in CLAUSES and cid not in seen:
            seen.append(cid)
    return seen[:6]


def _prompt(items: list[dict], options: dict[str, list[str]], declaration: dict) -> str:
    lines = [f"Video category: {declaration.get('category') or 'general'}", "Claims:"]
    for item in items:
        lines.append(f'- {item["id"]} ({item["type"]}, {item["source"]}): "{item["text"]}"'
                     + (f' [about: {item["subject"]}]' if item.get("subject") else ""))
        for cid in options[item["id"]]:
            lines.append(f"    candidate {cid} = {label(cid)}: {clause_text(cid)}")
    return "\n".join(lines)


def _premises(items: list[dict], clause_id: str, quote: str) -> str:
    """What the flag rests on, stated from the sources: what was said and
    what the clause says. Check Grounding scores an inference ("which
    suggests a cure") near zero even when sound, so the gate grounds the
    premises and the judge's reading stays visible as the evidence line."""
    said = " ".join(f'The creator says "{i["text"]}".' for i in items)
    rule = f'{label(clause_id)} says "{quote}".'
    listed = ""
    if clause_id.startswith("dmr-act"):
        names = sorted({n for i in items for n in scheduled_conditions(i["text"])})
        listed = "".join(f" The Schedule includes {n}." for n in names)
    return f"{said} {rule}{listed}"


# Most specific first: statute, then the ASCI provisions written for a
# subject, then the general truthfulness clauses.
_PRIORITY = [
    "dmr-act/3(d)", "dmr-act/4", "dmr-act/schedule",
    "asci-code/I.ex(e)", "asci-ig/add2-I.1", "asci-ig/add2-I.2", "asci-code/I.ex(d)", "asci-ig/add2-I",
    "asci-code/I.1.5", "asci-code/I.1.4", "asci-code/I.1.2", "asci-code/I.1.1", "asci-code/I.1.3", "asci-ig/2",
]
_SEVERITY = {"high": 0, "medium": 1, "low": 2}
_MIN_CLAIM_WORDS = 3
_CLAIM_MATCH = 85


def _rank(clause_id: str) -> int:
    return _PRIORITY.index(clause_id) if clause_id in _PRIORITY else len(_PRIORITY)


def concrete(finding: Finding, covered: list[dict]) -> bool:
    """The finding names words that were actually said or shown: at least
    three words that closely match (partial ratio 85) one of the claims it
    covers. The model may tidy numbers ("3" for "three"), not invent."""
    quote = normalize(finding.claim_quote)
    if len(tokens(quote)) < _MIN_CLAIM_WORDS:
        return False
    return any(
        contains(i["text"], quote) or fuzz.partial_ratio(quote, normalize(i["text"])) >= _CLAIM_MATCH
        for i in covered
    )


# The general truthfulness clauses; a flag citing one of these next to a
# more specific flag is the same problem said twice.
GENERIC = {"asci-code/I.1.1", "asci-code/I.1.4", "asci-code/I.1.5", "asci-ig/2"}
_NEARBY_MS = 5000


def _related(a: tuple[Finding, list[dict]], group: list[tuple[Finding, list[dict]]]) -> bool:
    finding, covered = a
    ids = {i["id"] for i in covered}
    subjects = {_slug(i["subject"]) for i in covered if i.get("subject")}
    for other, other_covered in group:
        if ids & {i["id"] for i in other_covered}:
            return True
        if subjects & {_slug(i["subject"]) for i in other_covered if i.get("subject")}:
            return True
        if other.clause_id == finding.clause_id:
            return True
        # A generic clause beside a specific one, a few seconds apart.
        if (finding.clause_id in GENERIC) != (other.clause_id in GENERIC):
            gap = min(abs(i["startMs"] - j["startMs"]) for i in covered for j in other_covered)
            if gap <= _NEARBY_MS:
                return True
    return False


def merge(findings: list[tuple[Finding, list[dict]]]) -> list[tuple[Finding, list[dict]]]:
    """One flag per problem: findings that share a ledger item, a subject or
    a clause, or a generic clause beside a specific one moments apart,
    become one flag cited to the most specific clause and covering every
    line. Repeats of one violation read as noise."""
    groups: list[list[tuple[Finding, list[dict]]]] = []
    for finding, covered in findings:
        home = next((g for g in groups if _related((finding, covered), g)), None)
        if home is None:
            groups.append([(finding, covered)])
        else:
            home.append((finding, covered))
    out = []
    for group in groups:
        best, _ = min(group, key=lambda pair: (_rank(pair[0].clause_id), _SEVERITY[pair[0].severity]))
        items: dict[str, dict] = {}
        for _, covered in group:
            for item in covered:
                items[item["id"]] = item
        out.append((best, sorted(items.values(), key=lambda i: i["startMs"])))
    return out


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:40]


def check(ctx: CheckContext, stage: str, ledger: list[dict], declaration: dict) -> list[Candidate]:
    items = [i for i in ledger if wants(i)]
    if not items:
        return []
    retrieved = retrieve([i["text"] if not i.get("subject") else f'{i["text"]} ({i["subject"]})' for i in items])
    options = {
        item["id"]: _candidates(item, hits, declaration.get("category") or "general")
        for item, hits in zip(items, retrieved, strict=True)
    }
    findings = generate(ctx, stage, [_prompt(items, options, declaration)], Findings, _SYSTEM, thinking_budget=1024).findings

    by_id = {i["id"]: i for i in items}
    kept: list[tuple[Finding, list[dict]]] = []
    dropped: list[str] = []
    for finding in findings:
        covered = [by_id[i] for i in finding.item_ids if i in by_id]
        allowed = {cid for item in covered for cid in options[item["id"]]}
        if not finding.violates or not covered:
            continue
        if finding.clause_id not in allowed:
            dropped.append("clause not offered")
            continue
        if (
            (declaration.get("category") or "general") == "general"
            and finding.clause_id in GENERIC
            and all(i["type"] in {"personal_result", "promo_offer"} for i in covered)
        ):
            # A personal take on an everyday product ("battery lasted three
            # days") is not what the truthfulness clauses police.
            dropped.append("personal experience, general topic")
            continue
        if not concrete(finding, covered):
            dropped.append(f"no concrete claim span: {len(tokens(finding.claim_quote))} words")
            continue
        kept.append((finding, covered))
    if dropped:
        log.info(json.dumps({"event": "claims_filtered", "jobId": ctx.job_id, "reasons": dropped}))

    out: list[Candidate] = []
    for finding, covered in merge(kept):
        quote = best_sentence(finding.clause_id, finding.clause_quote) or finding.clause_quote
        subject = next((i["subject"] for i in covered if i.get("subject")), covered[0]["text"])
        out.append(Candidate(
            {
                "fingerprint": f"claims:{_slug(finding.clause_id)}:{_slug(subject)}",
                "category": "claims",
                "severity": finding.severity,
                "startMs": min(i["startMs"] for i in covered),
                "endMs": max(i["endMs"] for i in covered),
                "title": finding.title,
                "evidence": finding.evidence,
                "citation": citation(finding.clause_id),
                "sourceQuote": {"text": quote, "source": label(finding.clause_id)},
                "suggestedFix": finding.suggested_fix,
            },
            [Evidence("clause", quote, finding.clause_id)]
            + [Evidence("transcript" if i["source"] == "speech" else "screen", i["text"]) for i in covered],
            grounding_answer=_premises(covered, finding.clause_id, quote),
            # An interpretation the sources don't support is dropped, not
            # shown as uncertain: a weak claims flag is noise.
            drop_if_weak=True,
            grounding_facts=[
                *(f'The creator says: "{i["text"]}"' for i in covered),
                f"{label(finding.clause_id)}: {clause_text(finding.clause_id)}",
                # One fact per listed condition: Check Grounding can't read a
                # 54-item list as support for one entry.
                *(f"The Schedule to the Drugs and Magic Remedies Act includes this condition: {name}."
                  for name in sorted({n for i in covered for n in scheduled_conditions(i["text"])})
                  if finding.clause_id.startswith("dmr-act")),
            ],
        ))
    return out
