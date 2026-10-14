"""The claim ledger: every checkable thing in the video, typed and
timestamped, for the checkers to route on.

Gemini only picks and types items, pointing at numbered sentences and
overlays; text and times always come from the transcript and the visual
pass, so an item can't contain words that weren't said or shown.
"""

import re
from dataclasses import dataclass
from typing import Literal

from pydantic import BaseModel, Field

from .base import CheckContext
from .gemini import generate
from .speech import Transcript, Word
from .textmatch import find_span, tokens
from .visual import VisualFacts

ItemType = Literal[
    "brand_mention",
    "material_connection",
    "promo_offer",
    "health_claim",
    "financial_claim",
    "factual_claim",
    "personal_result",
    "qualification",
    "quote_of_others",
]
Check = Literal["disclosure", "claims", "visuals", "borrowed", "factcheck"]

_SENTENCE_END = re.compile(r"[.?!।]$")
_PAUSE_MS = 900
_MAX_WORDS = 40

# Labels ASCI accepts (Influencer Guidelines 1.3(a)), as they appear in
# captions. "Paid partnership" is the platform tool.
_LABEL = re.compile(
    r"(?<![\w#])#?(advertisement|ad|sponsored|collaboration|collab|partnership|paid partnership|employee|free ?gift|affiliate)\b",
    re.IGNORECASE,
)
_HASHTAG = re.compile(r"#\w+")


@dataclass(frozen=True)
class Sentence:
    id: int
    words: list[Word]

    @property
    def text(self) -> str:
        return " ".join(w.text for w in self.words)


def sentences(transcript: Transcript) -> list[Sentence]:
    """Split on sentence punctuation, a long pause, or a length cap."""
    out: list[Sentence] = []
    current: list[Word] = []
    for word in transcript.words:
        if current and (word.start_ms - current[-1].end_ms >= _PAUSE_MS or len(current) >= _MAX_WORDS):
            out.append(Sentence(len(out), current))
            current = []
        current.append(word)
        if _SENTENCE_END.search(word.text):
            out.append(Sentence(len(out), current))
            current = []
    if current:
        out.append(Sentence(len(out), current))
    return out


class Pick(BaseModel):
    type: ItemType
    source: Literal["speech", "screen"]
    ref: int = Field(description="Sentence number for speech, overlay number for screen.")
    quote: str = Field(description="The exact words of the item, copied from that sentence or overlay.")
    subject: str | None = Field(default=None, description="The brand, product, person or topic it is about.")
    checks: list[Check]


class Picks(BaseModel):
    items: list[Pick]


_SYSTEM = """You build a claim ledger for an Indian creator video before it is published.
You get numbered transcript sentences, numbered on-screen overlays and the creator's declaration.
List every item a reviewer would need to check:
- brand_mention: a brand or product named.
- material_connection: anything showing the creator got something (paid, sent free, gifted, discount code, affiliate or referral link, employee).
- promo_offer: a price, discount, code or offer.
- health_claim: any claim about health, disease, cure, prevention, weight, or a body result.
- financial_claim: returns, savings, safety of money, interest, insurance, investment advice.
- factual_claim: any other statement of fact that can be checked against a source.
- personal_result: the creator's own experience presented as a result.
- qualification: the creator stating a qualification or registration (doctor, nutritionist, SEBI registered).
- quote_of_others: the creator quoting or replaying someone else.
A personal result that mentions a disease, a medicine or a body change is a health_claim, not a
personal_result. Generic ingredients (vitamin C, ashwagandha) are not brand mentions; only name
brands and branded products. Do not list on-screen disclosure labels or the caption: they are
added separately. Split sentences that hold several claims into separate items. Copy the quote word for word from
one sentence or one overlay; never paraphrase or translate. Hinglish stays as spoken.
checks says which reviews apply: disclosure (material connection, brand deals), claims (ad code
and law on claims), visuals (what the screen shows), borrowed (quoted or reused content),
factcheck (checkable facts). Do not list greetings, filler or calls to action without a claim."""


def _prompt(sents: list[Sentence], visual: VisualFacts, declaration: dict) -> str:
    lines = ["Transcript sentences:"]
    lines += [f"[{s.id}] ({s.words[0].start_ms / 1000:.1f}s) {s.text}" for s in sents] or ["(no speech)"]
    lines.append("On-screen overlays:")
    lines += [f"[{i}] ({t.start_s:.1f}s to {t.end_s:.1f}s, {t.kind}) {t.text}" for i, t in enumerate(visual.screen_text)] or [
        "(none)"
    ]
    lines.append("Declaration:")
    lines.append(f"paid partnership: {bool(declaration.get('isPaid'))}; brand: {declaration.get('brandName') or 'none'}; "
                 f"category: {declaration.get('category') or 'general'}")
    lines.append(f"caption: {declaration.get('caption') or ''}")
    return "\n".join(lines)


def _speech_span(sentence: Sentence, quote: str) -> tuple[str, int, int]:
    """Narrows the item to the quoted words when they are found verbatim,
    otherwise keeps the whole sentence. Returns text, start and end."""
    flat: list[tuple[str, int]] = []
    for index, word in enumerate(sentence.words):
        flat += [(token, index) for token in tokens(word.text)]
    span = find_span([t for t, _ in flat], tokens(quote))
    if span is None:
        return sentence.text, sentence.words[0].start_ms, sentence.words[-1].end_ms
    first, last = flat[span[0]][1], flat[span[1] - 1][1]
    words = sentence.words[first : last + 1]
    return " ".join(w.text for w in words), words[0].start_ms, words[-1].end_ms


def caption_items(caption: str) -> list[dict]:
    """Disclosure labels in the caption, and where they sit: ASCI 1.2(b)
    and 1.2(c) care whether a label is up front or buried in hashtags."""
    items = []
    first_line = caption.strip().splitlines()[0] if caption.strip() else ""
    hashtags = _HASHTAG.findall(caption)
    for match in _LABEL.finditer(caption):
        label = match.group(0)
        if label.startswith("#"):
            # Position among the hashtags, 1-based.
            position = next((i + 1 for i, tag in enumerate(hashtags) if tag.lower() == label.lower()), None)
        else:
            position = None
        items.append(
            {
                "type": "disclosure_label",
                "source": "caption",
                "text": label,
                "upFront": match.start() < len(first_line) and match.start() <= 40,
                "hashtagPosition": position,
                "hashtagCount": len(hashtags),
                "checks": ["disclosure"],
            }
        )
    return items


def screen_items(visual: VisualFacts) -> list[dict]:
    """Overlays and shots the checkers use directly, with exact durations."""
    items = []
    for overlay in visual.screen_text:
        if overlay.kind == "disclosure_label":
            items.append(
                {
                    "type": "disclosure_label",
                    "source": "screen",
                    "text": overlay.text,
                    "startMs": int(overlay.start_s * 1000),
                    "endMs": int(overlay.end_s * 1000),
                    "position": overlay.position,
                    "checks": ["disclosure"],
                }
            )
    for shot in visual.product_shots:
        items.append(
            {
                "type": "product_shot",
                "source": "screen",
                "text": shot.product,
                "subject": shot.brand,
                "startMs": int(shot.start_s * 1000),
                "endMs": int(shot.end_s * 1000),
                "checks": ["disclosure", "visuals"],
            }
        )
    for comparison in visual.before_after:
        items.append(
            {
                "type": "before_after",
                "source": "screen",
                "text": comparison.description,
                "startMs": int(comparison.start_s * 1000),
                "endMs": int(comparison.end_s * 1000),
                "checks": ["claims", "visuals"],
            }
        )
    for clip in visual.borrowed_footage:
        items.append(
            {
                "type": "borrowed_footage",
                "source": "screen",
                "text": clip.description,
                "startMs": int(clip.start_s * 1000),
                "endMs": int(clip.end_s * 1000),
                "creditedOnScreen": clip.credited_on_screen,
                "checks": ["borrowed"],
            }
        )
    return items


def build(
    ctx: CheckContext,
    stage: str,
    transcript: Transcript,
    visual: VisualFacts,
    declaration: dict,
) -> list[dict]:
    sents = sentences(transcript)
    picks: list[Pick] = []
    if sents or visual.screen_text:
        picks = generate(
            ctx, stage, [_prompt(sents, visual, declaration)], Picks, _SYSTEM, thinking_budget=1024
        ).items

    items: list[dict] = []
    seen: set[tuple] = set()
    for pick in picks:
        if pick.source == "speech":
            if not 0 <= pick.ref < len(sents):
                continue
            text, start, end = _speech_span(sents[pick.ref], pick.quote)
        else:
            if not 0 <= pick.ref < len(visual.screen_text):
                continue
            overlay = visual.screen_text[pick.ref]
            text, start, end = overlay.text, int(overlay.start_s * 1000), int(overlay.end_s * 1000)
        key = (pick.type, pick.source, start, text)
        if key in seen:
            continue
        seen.add(key)
        item = {"type": pick.type, "source": pick.source, "text": text, "startMs": start, "endMs": end}
        if pick.subject:
            item["subject"] = pick.subject
        item["checks"] = sorted(set(pick.checks))
        items.append(item)

    items += screen_items(visual)
    items += caption_items(declaration.get("caption") or "")
    items.sort(key=lambda i: (i.get("startMs", 10**9), i["type"]))
    for n, item in enumerate(items, start=1):
        item["id"] = f"L{n}"
    return items


_CLAIM_TYPES = {"health_claim", "financial_claim", "factual_claim", "personal_result"}


def summary(items: list[dict]) -> str:
    """The live line under the Claim ledger stage."""
    claims = sum(1 for i in items if i["type"] in _CLAIM_TYPES)
    brands = sum(1 for i in items if i["type"] in {"brand_mention", "product_shot"})
    labels = sum(1 for i in items if i["type"] == "disclosure_label")
    parts = [f"{claims} {'claim' if claims == 1 else 'claims'} found"]
    if brands:
        parts.append(f"{brands} brand {'mention' if brands == 1 else 'mentions'}")
    if labels:
        parts.append(f"{labels} {'label' if labels == 1 else 'labels'}")
    return ", ".join(parts)
