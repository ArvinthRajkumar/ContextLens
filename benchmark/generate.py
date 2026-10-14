"""Builds the benchmark reels from cases.json (synthetic recreations).

Voices come from Gemini TTS, footage is one stock clip looped, overlays are
burned in with ffmpeg. Borrowed-clip pairs are cut from the generated
source using Chirp word timestamps, so the ground truth (which source
seconds the clip keeps) is exact.

    cd backend
    FFMPEG=<ffmpeg> FOOTAGE=<any portrait or landscape mp4> GOOGLE_CLOUD_QUOTA_PROJECT=contextlens-tekken \
        .venv/Scripts/python.exe ../benchmark/generate.py [--only C01,B02]

Writes benchmark/media/ (not committed: regenerate with this script).
"""

import argparse
import json
import os
import subprocess
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "backend"))

from google import genai  # noqa: E402
from google.genai import types  # noqa: E402

from app.pipeline.speech import transcribe  # noqa: E402
from app.pipeline.textmatch import tokens  # noqa: E402

MEDIA = HERE / "media"
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
FOOTAGE = os.environ["FOOTAGE"]
FONT = "C\\:/Windows/Fonts/segoeuib.ttf" if os.name == "nt" else "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
TTS_MODEL = "gemini-2.5-flash-tts"
PAD_S = 0.6

_client = genai.Client(vertexai=True, project="contextlens-tekken", location="us-central1")


def ffmpeg(*args: str) -> None:
    subprocess.run([FFMPEG, "-loglevel", "error", "-y", *args], check=True)


def tts(text: str, voice: str, out_wav: Path, style: str) -> float:
    """Speech for `text`; returns its length in seconds."""
    if not out_wav.exists():
        response = _client.models.generate_content(
            model=TTS_MODEL,
            contents=[f"{style}: {text}"],
            config=types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=voice))
                ),
            ),
        )
        pcm = response.candidates[0].content.parts[0].inline_data.data
        with wave.open(str(out_wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(24000)
            w.writeframes(pcm)
    with wave.open(str(out_wav), "rb") as w:
        return w.getnframes() / w.getframerate()


def _time(value, length: float) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if value == "end":
        return length
    if isinstance(value, str) and value.startswith("end-"):
        return length - float(value[4:])
    raise ValueError(value)


def _escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def render(audio: Path, out: Path, overlays: list[dict], length: float, size: tuple[int, int] = (720, 1280)) -> None:
    w, h = size
    parts = [f"[0:v]scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h},setsar=1"]
    ys = {"top": "h*0.10", "middle": "(h-text_h)/2", "bottom": "h*0.78"}
    for o in overlays:
        start, end = _time(o["start"], length), _time(o["end"], length)
        parts.append(
            f"drawtext=fontfile='{FONT}':text='{_escape(o['text'])}':fontsize={o.get('size', 36)}:fontcolor=white:"
            f"box=1:boxcolor=black@0.55:boxborderw=12:x=(w-text_w)/2:y={ys[o.get('pos', 'top')]}:"
            f"enable='between(t,{start:.2f},{end:.2f})'"
        )
    graph = MEDIA / f"{out.stem}.filter.txt"
    graph.write_text(",".join(parts) + "[v]", encoding="utf-8")
    ffmpeg("-stream_loop", "-1", "-i", FOOTAGE, "-i", str(audio), "-/filter_complex", str(graph), "-map", "[v]",
           "-map", "1:a", "-t", f"{length:.2f}", "-c:v", "libx264", "-crf", "30", "-preset", "veryfast",
           "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", str(out))
    graph.unlink()


def padded(wav: Path, out: Path) -> float:
    """Half a second of silence either side, like a real reel."""
    ffmpeg("-i", str(wav), "-af", f"adelay={int(PAD_S * 1000)},apad=pad_dur={PAD_S}", str(out))
    with wave.open(str(out), "rb") as w:
        return w.getnframes() / w.getframerate()


STYLE = "Read this as an Indian social media creator recording a reel, natural Indian English, lively"


def reel(case: dict, overlays: list[dict]) -> None:
    out = MEDIA / f"{case['id']}.mp4"
    if out.exists():
        return
    raw = MEDIA / f"{case['id']}.voice.wav"
    tts(case["script"], case["voice"], raw, STYLE)
    audio = MEDIA / f"{case['id']}.wav"
    length = padded(raw, audio)
    render(audio, out, overlays, length)
    audio.unlink()


def _find(keys: list[str], phrase: list[str], start: int) -> int:
    """Index of the first word of `phrase` in the transcript, from `start`."""
    for i in range(start, len(keys) - len(phrase) + 1):
        if keys[i : i + len(phrase)] == phrase:
            return i
    raise ValueError(f"phrase not in transcript: {' '.join(phrase)}")


def borrowed(case: dict) -> None:
    clip_out = MEDIA / f"{case['id']}_clip.mp4"
    truth_out = MEDIA / f"{case['id']}_truth.json"
    if clip_out.exists() and truth_out.exists():
        return
    raw = MEDIA / f"{case['id']}_source.voice.wav"
    length = tts(case["source"], case["voice"], raw, "Read this calmly as a speaker on an Indian podcast or news show")
    flac = MEDIA / f"{case['id']}_source.flac"
    ffmpeg("-i", str(raw), "-ac", "1", "-ar", "16000", "-c:a", "flac", str(flac))
    words = transcribe(str(flac), int(length * 1000)).words
    flac.unlink()
    keys = [" ".join(tokens(w.text)) for w in words]
    kept, trims = [], []
    cursor = 0
    for first, last in case["keep"]:
        start_i = _find(keys, tokens(first), cursor)
        end_i = _find(keys, tokens(last), start_i) + len(tokens(last)) - 1
        cursor = end_i + 1
        start, end = max(0.0, words[start_i].start_ms / 1000 - 0.1), words[end_i].end_ms / 1000 + 0.15
        kept.append((start, end))
        trims.append(f"[0:a]atrim={start:.3f}:{end:.3f},asetpts=PTS-STARTPTS[a{len(trims)}]")
    clip_wav = MEDIA / f"{case['id']}_clip.wav"
    graph = ";".join(trims) + ";" + "".join(f"[a{i}]" for i in range(len(trims))) + f"concat=n={len(trims)}:v=0:a=1[a]"
    ffmpeg("-i", str(raw), "-filter_complex", graph, "-map", "[a]", str(clip_wav))
    with wave.open(str(clip_wav), "rb") as w:
        clip_len = w.getnframes() / w.getframerate()
    render(clip_wav, clip_out, [{"text": case["label"], "start": 0.3, "end": "end", "pos": "top", "size": 28}], clip_len)
    source_wav = MEDIA / f"{case['id']}_source.wav"
    source_len = padded(raw, source_wav)
    render(source_wav, MEDIA / f"{case['id']}_source.mp4", [], source_len, (640, 360))
    for tmp in (clip_wav, source_wav):
        tmp.unlink()
    truth_out.write_text(json.dumps({
        "kept": [[s + PAD_S, e + PAD_S] for s, e in kept],
        "sourceWords": [{"text": w.text, "start": w.start_ms / 1000 + PAD_S, "end": w.end_ms / 1000 + PAD_S} for w in words],
    }, indent=1), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="Comma separated case IDs.")
    args = parser.parse_args()
    only = set(args.only.split(",")) if args.only else None
    MEDIA.mkdir(exist_ok=True)
    cases = json.loads((HERE / "cases.json").read_text(encoding="utf-8"))
    for case in cases["compliance"] + cases["controls"]:
        if not only or case["id"] in only:
            reel(case, case.get("overlays", []))
            print("ok", case["id"])
    for case in cases["factchecks"] + cases.get("freshFactchecks", []):
        if not only or case["id"] in only:
            reel(case, [])
            print("ok", case["id"])
    for case in cases["borrowed"]:
        if not only or case["id"] in only:
            borrowed(case)
            print("ok", case["id"])


if __name__ == "__main__":
    main()
