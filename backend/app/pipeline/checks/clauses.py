"""The clause index: lookup, citations, scheduled diseases and retrieval."""

import json
import math
import re
from functools import cache
from pathlib import Path

from google.genai import types
from rapidfuzz import fuzz

from ..gemini import client

_INDEX = json.loads((Path(__file__).resolve().parents[2] / "clauses" / "index.json").read_text(encoding="utf-8"))
INSTRUMENTS: dict[str, dict] = _INDEX["instruments"]
CLAUSES: dict[str, dict] = {c["id"]: c for c in _INDEX["clauses"]}

_EMBEDDING_MODEL = "text-embedding-005"

# Everyday words for the Schedule's conditions (Drugs and Magic Remedies
# Act, s. 3(d)). Matching any of them puts s. 3(d) in front of the judge;
# the judge still decides whether the video suggests treating it.
_SCHEDULE_ALIASES = {
    "Diabetes": r"diabet\w*|blood sugar|sugar levels?|insulin",
    "High or low blood pressure": r"blood pressure|\bbp\b|hypertension",
    "Cancer": r"cancer",
    "Heart diseases": r"heart (disease|problem|attack)s?|cardiac",
    "Obesity": r"obes\w+",
    "Tumours": r"tumou?rs?",
    "Tuberculosis": r"tuberculosis|\btb\b",
    "Sexual impotence": r"impoten\w+|erectile",
    "Sterility in women": r"infertil\w+|sterility",
    "Gall stones, kidney stones and bladder stones": r"(gall|kidney|bladder) stones?",
    "Epilepsy": r"epilep\w+|seizures?",
    "Glaucoma": r"glaucoma",
    "Cataract": r"cataracts?",
    "Leucoderma": r"leucoderma|vitiligo",
    "Rheumatism": r"rheumat\w+|arthritis",
    "Stature of persons": r"increase (your )?height|grow taller",
    "Forms and structure of the female bust": r"breast (size|enlarge\w*)|bust",
}


def clause_text(clause_id: str) -> str:
    return CLAUSES[clause_id]["text"]


def citation(clause_id: str) -> dict:
    clause = CLAUSES[clause_id]
    instrument = INSTRUMENTS[clause["instrument"]]
    return {
        "title": instrument["title"],
        "url": instrument["url"],
        "publisher": instrument["publisher"],
        "clauseId": clause_id,
        "instrument": instrument["short"],
        "clause": clause["clause"],
        "authority": instrument["authority"],
    }


def label(clause_id: str) -> str:
    clause = CLAUSES[clause_id]
    return f"{INSTRUMENTS[clause['instrument']]['short']}, {clause['clause']}"


def scheduled_conditions(text: str) -> list[str]:
    lowered = text.lower()
    return [name for name, pattern in _SCHEDULE_ALIASES.items() if re.search(pattern, lowered)]


_SENTENCE = re.compile(r"(?<=[.;:])\s+")


def best_sentence(clause_id: str, quote: str) -> str | None:
    """The clause sentence closest to `quote`, when close enough that the
    model plainly meant it. Repairs a quote that drifted from the source;
    the gate still checks the result word for word."""
    text = clause_text(clause_id)
    if quote and quote in text:
        return quote
    best, score = None, 0.0
    for sentence in _SENTENCE.split(text):
        s = fuzz.ratio(sentence.lower(), quote.lower())
        if s > score:
            best, score = sentence, s
    return best if score >= 85 else None


def _embed(texts: list[str], task: str) -> list[list[float]]:
    response = client().models.embed_content(
        model=_EMBEDDING_MODEL,
        contents=texts,
        config=types.EmbedContentConfig(task_type=task),
    )
    return [e.values for e in response.embeddings]


@cache
def _clause_vectors() -> dict[str, list[float]]:
    ids = list(CLAUSES)
    docs = [f"{label(i)}: {CLAUSES[i]['text']}" for i in ids]
    return dict(zip(ids, _embed(docs, "RETRIEVAL_DOCUMENT"), strict=True))


def _cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b, strict=True))
    return dot / (math.sqrt(sum(x * x for x in a)) * math.sqrt(sum(y * y for y in b)) or 1.0)


def retrieve(texts: list[str], k: int = 4, topic: str = "claims") -> list[list[str]]:
    """Top `k` clause IDs per text, among clauses tagged with `topic`."""
    if not texts:
        return []
    vectors = _clause_vectors()
    pool = [cid for cid, c in CLAUSES.items() if topic in c["topics"]]
    out = []
    for query in _embed(texts, "RETRIEVAL_QUERY"):
        ranked = sorted(pool, key=lambda cid: _cosine(query, vectors[cid]), reverse=True)
        out.append(ranked[:k])
    return out
