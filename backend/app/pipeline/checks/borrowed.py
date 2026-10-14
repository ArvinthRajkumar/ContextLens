"""Borrowed clips: transcribe the declared source, align the creator's
quote with it, and flag splices and trimmed context."""

import asyncio
import os
import re
import tempfile
from urllib.parse import urlparse

from google.genai import types
from pydantic import BaseModel, Field

from ... import storage
from ..base import CheckContext
from ..gemini import generate
from ..media import extract_audio, probe
from ..speech import Transcript, transcribe
from .alignment import Alignment, align
from .candidate import Candidate, Evidence

_YOUTUBE = {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}


class SourceTranscript(BaseModel):
    text: str = Field(description="Everything said, word for word, with sentence punctuation. No timestamps, no speaker names.")


_TRANSCRIBE = """Transcribe the speech in this video word for word, in the language spoken, with
normal sentence punctuation. Do not summarise, translate or fix grammar."""


def _youtube(url: str | None) -> bool:
    return bool(url) and urlparse(url).hostname in _YOUTUBE


def _source_transcript(ctx: CheckContext, stage: str, url: str) -> str:
    video = types.Part(file_data=types.FileData(file_uri=url, mime_type="video/*"))
    result = generate(ctx, stage, [types.Content(role="user", parts=[video, types.Part(text="Transcribe it.")])],
                      SourceTranscript, _TRANSCRIBE)
    return result.text


def _file_transcript(object_name: str) -> str:
    """The attached original, transcribed with Chirp like the video itself."""
    with tempfile.TemporaryDirectory() as tmp:
        source = os.path.join(tmp, "clip")
        storage.download(object_name, source)
        duration_ms, has_audio = probe(source)
        if not has_audio:
            return ""
        audio = os.path.join(tmp, "clip.flac")
        extract_audio(source, audio)
        gcs_audio = None
        if (duration_ms or 0) > 55_000:
            storage.upload_file(audio, f"{object_name}.flac", "audio/flac")
            gcs_audio = storage.gcs_uri(f"{object_name}.flac")
        return transcribe(audio, duration_ms, gcs_audio).text


def _clip_items(ledger: list[dict], transcript: Transcript) -> list[dict]:
    """What the creator said that may come from the source: spoken quotes
    the ledger marked, and the whole voiceover (a reposted clip often has no
    quote marked at all). Overlays are not speech and are left out."""
    items = [i for i in ledger if i["type"] == "quote_of_others" and i["source"] == "speech" and "startMs" in i]
    if transcript.words:
        items.append({"text": transcript.text, "startMs": transcript.words[0].start_ms, "endMs": transcript.words[-1].end_ms})
    return items


def _flag(item: dict, label: str, url: str, result: Alignment) -> Candidate:
    if result.splices:
        title, severity = "Clip joins parts said at different moments", "high"
        evidence = f'Your clip of {label} skips "{result.splices[0]}" between two parts, so it sounds like one statement.'
    elif result.cut_mid_sentence:
        title, severity = "Clip stops before the sentence ends", "medium"
        evidence = f"Your clip of {label} cuts the speaker off mid-sentence, which changes what they meant."
    else:
        title, severity = "Clip leaves out the condition that follows", "medium"
        evidence = f'In {label} the next line is "{result.omitted_next}", which your clip leaves out.'
    slug = re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")[:30]
    original = result.original + (f" {result.omitted_next}" if result.omitted_next else "")
    return Candidate(
        {
            "fingerprint": f"borrowed:clip:{slug}",
            "category": "borrowed",
            "severity": severity,
            "startMs": item["startMs"],
            "endMs": item["endMs"],
            "title": title,
            "evidence": evidence,
            "citation": {"title": label, **({"url": url} if url.startswith("https://") else {})},
            "sourceQuote": {"text": original, "source": f"{label}, original"},
            "suggestedFix": "Use the full passage, or say in your own words what the speaker added.",
            "diff": {"clipTranscript": item["text"], "originalTranscript": original, "segments": result.segments},
        },
        [Evidence("source_transcript", original, url), Evidence("transcript", item["text"])],
    )


def has_source(clip: dict) -> bool:
    return bool(clip.get("objectName")) or _youtube(clip.get("url"))


async def check(ctx: CheckContext, stage: str, ledger: list[dict], transcript: Transcript, clips: list[dict]) -> list[Candidate]:
    sources = [c for c in clips if has_source(c)]
    items = _clip_items(ledger, transcript)
    if not sources or not items:
        return []
    out: list[Candidate] = []
    # An attached file wins over a link: it is exactly what the creator cut.
    texts = await asyncio.gather(*(
        asyncio.to_thread(_file_transcript, c["objectName"]) if c.get("objectName")
        else asyncio.to_thread(_source_transcript, ctx, stage, c["url"])
        for c in sources
    ))
    store = ctx.data.setdefault("pages", {})
    for clip, source_text in zip(sources, texts, strict=True):
        key = f"clip:{clip['objectName']}" if clip.get("objectName") else clip["url"]
        clip = {**clip, "url": key}
        store[key] = source_text
        # The span that matches the source best decides.
        aligned = [(await asyncio.to_thread(align, item["text"], source_text), item) for item in items]
        aligned = [(result, item) for result, item in aligned if result]
        if aligned:
            result, item = max(aligned, key=lambda pair: pair[0].score)
            if result.changes_meaning:
                out.append(_flag(item, clip.get("label") or "the source", clip["url"], result))
    return out
