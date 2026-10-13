"""Text normalization shared by everything that must match words exactly
(ledger quotes now, the evidence gate later)."""

import re
import unicodedata

# Curly quotes and the two long dashes, by code point.
_QUOTES = {0x2018: "'", 0x2019: "'", 0x201C: '"', 0x201D: '"', 0x2013: "-", 0x2014: "-"}
_SPACE = re.compile(r"\s+")
_EDGE_PUNCT = re.compile(r"^[\s\"'.,;:!?()]+|[\s\"'.,;:!?()]+$")
_WORD = re.compile(r"[\w₹%]+", re.UNICODE)


def normalize(text: str) -> str:
    """Case, quote style, Unicode form and spacing never decide a match."""
    text = unicodedata.normalize("NFKC", text).translate(_QUOTES).lower()
    return _EDGE_PUNCT.sub("", _SPACE.sub(" ", text))


def tokens(text: str) -> list[str]:
    """Words only, punctuation dropped: what speech and a quote share."""
    return _WORD.findall(normalize(text))


def contains(haystack: str, needle: str) -> bool:
    """True when `needle` appears word for word in `haystack`, ignoring
    punctuation between words."""
    hay, nee = tokens(haystack), tokens(needle)
    if not nee:
        return False
    return find_span(hay, nee) is not None


def find_span(hay: list[str], nee: list[str]) -> tuple[int, int] | None:
    """Start and end (exclusive) of `nee` inside `hay`, by token."""
    n = len(nee)
    for i in range(len(hay) - n + 1):
        if hay[i : i + n] == nee:
            return i, i + n
    return None
