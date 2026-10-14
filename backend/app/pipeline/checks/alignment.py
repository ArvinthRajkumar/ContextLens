"""Aligns a borrowed clip's words with its source to show what was cut.

rapidfuzz finds the stretch of the source the clip comes from (windows
over the source's words); difflib then aligns word by word inside it.
The result names splices (source words dropped between two kept parts)
and the sentence right after the clip when it was left out."""

import difflib
import re
from dataclasses import dataclass, field

from rapidfuzz import fuzz

from ..textmatch import tokens

_WINDOW_SLACK = 0.5
_MIN_SCORE = 60.0
# Dropping this many source words between two kept parts is a splice.
_SPLICE_WORDS = 3
_QUALIFIER = re.compile(r"^(but|only|if|unless|however|except|although|though|provided|as long as)\b", re.IGNORECASE)
_SENTENCE = re.compile(r"(?<=[.?!])\s+")


@dataclass
class Alignment:
    score: float
    source_start: int
    source_end: int
    segments: list[dict] = field(default_factory=list)
    splices: list[str] = field(default_factory=list)
    cut_mid_sentence: bool = False
    omitted_next: str | None = None
    original: str = ""

    @property
    def changes_meaning(self) -> bool:
        return bool(self.splices) or self.cut_mid_sentence or self.omitted_next is not None


def _window(clip: list[str], source: list[str]) -> tuple[int, int, float]:
    """Best matching source window, by rapidfuzz ratio over joined words."""
    n = len(clip)
    if not n or not source:
        return 0, 0, 0.0
    target = " ".join(clip)
    best = (0, 0, 0.0)
    lo, hi = max(1, int(n * (1 - _WINDOW_SLACK))), int(n * (1 + _WINDOW_SLACK)) + 1
    for size in range(lo, min(hi, len(source)) + 1):
        for start in range(0, len(source) - size + 1):
            score = fuzz.ratio(target, " ".join(source[start : start + size]))
            if score > best[2]:
                best = (start, start + size, score)
    return best


def _words(text: str) -> tuple[list[str], list[str]]:
    """Words as written (for display) and their match keys (lowercase, no
    punctuation). Words with no letters or digits are dropped."""
    shown, keys = [], []
    for word in text.split():
        key = " ".join(tokens(word))
        if key:
            shown.append(word)
            keys.append(key)
    return shown, keys


def _sentence_spans(text: str) -> list[tuple[int, int, str]]:
    """Word start and end of each source sentence."""
    spans, at = [], 0
    for sentence in _SENTENCE.split(text.strip()):
        n = len(_words(sentence)[0])
        if n:
            spans.append((at, at + n, sentence))
            at += n
    return spans


def align(clip_text: str, source_text: str) -> Alignment | None:
    clip_shown, clip = _words(clip_text)
    source_shown, source = _words(source_text)
    start, end, score = _window(clip, source)
    if score < _MIN_SCORE:
        return None
    sentences = _sentence_spans(source_text)

    def sentence_start(at: int) -> int:
        return next((s[0] for s in sentences if s[0] <= at < s[1]), at)

    def sentence_end(at: int) -> int:
        return next((s[1] for s in sentences if s[0] < at <= s[1]), at)

    # The best window may hold only one part of a spliced clip: look a clip's
    # length either side, keep the span between the first and last real
    # match (two words or more), and widen it to whole sentences so a cut
    # mid-sentence shows as a deletion.
    n = len(clip)
    region_lo, region_hi = sentence_start(max(0, start - n)), sentence_end(min(len(source), end + n))
    region = source[region_lo:region_hi]
    anchors = [b for b in difflib.SequenceMatcher(None, region, clip, autojunk=False).get_matching_blocks() if b.size >= 2]
    if anchors:
        start, end = region_lo + anchors[0].a, region_lo + anchors[-1].a + anchors[-1].size
    lo, hi = sentence_start(start), sentence_end(end)
    last = next((s for s in sentences if s[1] == hi), None)
    window, window_shown = source[lo:hi], source_shown[lo:hi]

    matcher = difflib.SequenceMatcher(None, window, clip, autojunk=False)
    segments: list[dict] = []
    splices: list[str] = []
    blocks = [b for b in matcher.get_matching_blocks() if b.size]
    for prev, nxt in zip(blocks, blocks[1:], strict=False):
        gap = nxt.a - (prev.a + prev.size)
        if gap >= _SPLICE_WORDS and nxt.b == prev.b + prev.size:
            splices.append(" ".join(window_shown[prev.a + prev.size : nxt.a]))
    for op, a0, a1, b0, b1 in matcher.get_opcodes():
        # Shared words are shown as the source wrote them; segments carry
        # their own leading space so the app can join them as they are.
        if op == "equal":
            segments.append({"op": "equal", "text": " ".join(window_shown[a0:a1])})
        else:
            if a1 > a0:
                segments.append({"op": "delete", "text": " ".join(window_shown[a0:a1])})
            if b1 > b0:
                segments.append({"op": "insert", "text": " ".join(clip_shown[b0:b1])})
    for segment in segments[1:]:
        segment["text"] = " " + segment["text"]

    matched_end = lo + (blocks[-1].a + blocks[-1].size if blocks else 0)
    cut_mid = bool(last) and matched_end < hi and hi - matched_end >= _SPLICE_WORDS
    following = next((s for s in sentences if s[0] == hi), None)
    omitted_next = following[2] if following and _QUALIFIER.match(following[2]) else None
    original = " ".join(s[2] for s in sentences if s[0] >= lo and s[1] <= hi)
    return Alignment(score, lo, hi, segments, splices, cut_mid, omitted_next, original)
