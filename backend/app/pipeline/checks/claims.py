"""Claims compliance: each claim is judged against the clauses retrieved
for it, and the judge may only cite those clauses, quoting them."""

import re
from typing import Literal

from pydantic import BaseModel, Field

from ..base import CheckContext
from ..gemini import generate
from .candidate import Candidate, Evidence
from .clauses import CLAUSES, best_sentence, citation, clause_text, label, retrieve, scheduled_conditions

CLAIM_TYPES = {"health_claim", "financial_claim", "personal_result", "promo_offer"}

_HEALTH = ["asci-code/I.1.1", "asci-code/I.1.4", "asci-code/I.ex(d)"]
_FINANCE = ["asci-code/I.ex(e)", "asci-code/I.1.5", "asci-ig/add2-I.1"]
_SCHEDULE = ["dmr-act/3(d)", "dmr-act/schedule"]


class Finding(BaseModel):
    item_ids: list[str] = Field(description="Ledger items this finding covers.")
    violates: bool
    clause_id: str = Field(description="One of the candidate clause IDs given for these items.")
    clause_quote: str = Field(description="The words of that clause the finding rests on, copied exactly.")
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
- Group claims that are one issue (for example two lines about the same disease) into one finding.
- Plain personal taste, prices and codes alone are not violations. Report violates=false for them
  only if asked; otherwise leave them out.
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
    out: list[Candidate] = []
    for finding in findings:
        covered = [by_id[i] for i in finding.item_ids if i in by_id]
        allowed = {cid for item in covered for cid in options[item["id"]]}
        if not finding.violates or not covered or finding.clause_id not in allowed:
            continue
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
