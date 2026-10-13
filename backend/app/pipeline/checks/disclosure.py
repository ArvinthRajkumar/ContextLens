"""ASCI disclosure rules, deterministic: a brand connection needs a
permitted label up front in the caption and on screen for long enough
(Influencer Guidelines 1, 1.2(b), 1.2(c) and 1.2(d))."""

import math
import re

from .candidate import Candidate, Evidence
from .clauses import citation, clause_text, label

SHORT_VIDEO_MS = 15_000
LONG_VIDEO_MS = 120_000
SHORT_VIDEO_MIN_MS = 3_000
# A label that only shows up in the last fifth reads as "at the end of
# videos" (1.2(b)).
LATE_SHARE = 0.8

_TRIGGERS = {"material_connection", "promo_offer"}


def required_ms(duration_ms: int, promoted: tuple[int, int] | None) -> tuple[int, str]:
    """How long the on-screen label must stay, and the clause saying so."""
    if duration_ms <= SHORT_VIDEO_MS:
        return SHORT_VIDEO_MIN_MS, "asci-ig/1.2(d)(I)"
    if duration_ms < LONG_VIDEO_MS:
        return math.ceil(duration_ms / 3), "asci-ig/1.2(d)(II)"
    start, end = promoted or (0, duration_ms)
    return end - start, "asci-ig/1.2(d)(III)"


def merged(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    for start, end in sorted(intervals):
        if out and start <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], end))
        else:
            out.append((start, end))
    return out


def visible_ms(intervals: list[tuple[int, int]]) -> int:
    return sum(end - start for start, end in merged(intervals))


def covered_ms(intervals: list[tuple[int, int]], span: tuple[int, int]) -> int:
    """How much of `span` the label covers."""
    lo, hi = span
    return sum(max(0, min(end, hi) - max(start, lo)) for start, end in merged(intervals))


def _secs(ms: int) -> str:
    return f"{ms / 1000:.1f}".rstrip("0").rstrip(".") + " s"


def _clock(ms: int) -> str:
    s = ms // 1000
    return f"{s // 60}:{s % 60:02d}"


def _quote(clause_id: str, sentence: str | None = None) -> dict:
    text = sentence or clause_text(clause_id)
    return {"text": text, "source": label(clause_id)}


def _flag(fingerprint: str, severity: str, start: int, end: int, title: str, evidence: str, clause_id: str, fix: str,
          sentence: str | None = None) -> dict:
    return {
        "fingerprint": fingerprint,
        "category": "disclosure",
        "severity": severity,
        "startMs": start,
        "endMs": end,
        "title": title,
        "evidence": evidence,
        "citation": citation(clause_id),
        "sourceQuote": _quote(clause_id, sentence),
        "suggestedFix": fix,
    }


def check(ledger: list[dict], duration_ms: int, declaration: dict) -> list[Candidate]:
    triggers = [i for i in ledger if i["type"] in _TRIGGERS and "startMs" in i]
    if not triggers and not declaration.get("isPaid"):
        return []

    brand = declaration.get("brandName") or next((i["subject"] for i in triggers if i.get("subject")), None) or "the brand"
    slug = re.sub(r"[^a-z0-9]+", "-", brand.lower()).strip("-") or "brand"
    # Anchor on the connection itself ("sent me these") when there is one,
    # otherwise on the first code or offer.
    connections = [i for i in triggers if i["type"] == "material_connection"] or triggers
    first = min(connections, key=lambda i: i["startMs"]) if connections else None
    anchor = (first["startMs"], first["endMs"]) if first else (0, min(duration_ms, 5000))
    connection_ev = [Evidence("transcript" if first["source"] == "speech" else "screen", first["text"])] if first else []
    said = f'You say "{first["text"].rstrip(".,")}"' if first and first["source"] == "speech" else (
        f'The video shows "{first["text"]}"' if first else "This is a paid partnership")

    out: list[Candidate] = []

    # Caption: a permitted label, up front.
    caption_labels = [i for i in ledger if i["type"] == "disclosure_label" and i["source"] == "caption"]
    if not any(i.get("upFront") for i in caption_labels):
        if caption_labels:
            item = caption_labels[0]
            buried = item.get("hashtagPosition") is not None
            clause_id = "asci-ig/1.2(c)" if buried else "asci-ig/1.2(b)"
            where = (f"as hashtag {item['hashtagPosition']} of {item['hashtagCount']}" if buried
                     else "only at the end of the caption")
            out.append(Candidate(
                _flag(f"disclosure:caption-label:{slug}", "medium", *anchor,
                      "Ad label is buried in your caption",
                      f'{said}, but "{item["text"]}" appears {where}, where people can miss it.',
                      clause_id,
                      f'Start your caption with "Ad:" or "Collaboration with {brand}:" before any other text.'),
                [Evidence("clause", clause_text(clause_id), clause_id), Evidence("caption", item["text"]), *connection_ev],
            ))
        else:
            out.append(Candidate(
                _flag(f"disclosure:caption-label:{slug}", "high", *anchor,
                      f"No Ad label for your {brand} connection",
                      f"{said}, but the caption has no label such as Ad, Sponsored or Collaboration.",
                      "asci-ig/1",
                      f'Start your caption with "Ad:" or "Collaboration with {brand}:".'),
                [Evidence("clause", clause_text("asci-ig/1"), "asci-ig/1"), *connection_ev],
            ))

    # On screen: present, early enough and long enough.
    screen = [(i["startMs"], i["endMs"]) for i in ledger if i["type"] == "disclosure_label" and i["source"] == "screen"]
    promoted = (min(i["startMs"] for i in triggers), max(i["endMs"] for i in triggers)) if triggers else None
    need, rule = required_ms(duration_ms, promoted)
    shown = covered_ms(screen, promoted) if rule.endswith("(III)") and promoted else visible_ms(screen)
    need_text = {
        "asci-ig/1.2(d)(I)": "at least 3 seconds",
        "asci-ig/1.2(d)(II)": f"at least a third of the video ({_secs(need)} here)",
        "asci-ig/1.2(d)(III)": "the whole part where you talk about the brand",
    }[rule]
    start_at = _clock(anchor[0])
    fix = f'Put "Ad" on screen from {start_at}, when you first mention {brand}, and keep it up for {need_text}.'
    if not screen:
        out.append(Candidate(
            _flag(f"disclosure:screen-label:{slug}", "high", *anchor,
                  "No Ad label on screen",
                  f"{said}, but no label such as Ad appears on screen. ASCI expects it on screen for {need_text}.",
                  rule, fix),
            [Evidence("clause", clause_text(rule), rule), *connection_ev],
        ))
    else:
        first_label = min(s for s, _ in screen)
        late = first_label >= duration_ms * LATE_SHARE
        if shown < need or late:
            label_text = next(i["text"] for i in ledger if i["type"] == "disclosure_label" and i["source"] == "screen")
            problem = []
            if shown < need:
                problem.append(f"shows for {_secs(shown)}, but ASCI expects {need_text}")
            if late:
                problem.append(f"only appears at {_clock(first_label)}, at the end")
            title = ("On-screen Ad label is too short and too late" if shown < need and late
                     else "On-screen Ad label is too short" if shown < need else "On-screen Ad label comes too late")
            label_span = merged(screen)[0]
            out.append(Candidate(
                _flag(f"disclosure:screen-label-timing:{slug}", "high" if shown < need / 2 else "medium",
                      *label_span, title,
                      f'"{label_text}" {" and ".join(problem)}.',
                      rule, fix),
                [Evidence("clause", clause_text(rule), rule), Evidence("screen", label_text)],
            ))
    return out
