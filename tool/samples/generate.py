"""Builds the Try a sample videos from tool/samples/scripts.json.

Speech comes from Cloud Text-to-Speech (en-IN Chirp 3 HD voices), one call
per line so captions can follow the exact timing. Video is ffmpeg only:
gradient backgrounds that cut between scenes, a bold caption per spoken
line and the overlays from the script. No generated images or footage.
Every file is tagged "synthetic test video" in its metadata.

    cd backend
    FFMPEG=<ffmpeg> .venv/Scripts/python.exe ../tool/samples/generate.py [ID ...]

Writes tool/samples/out/<id>.mp4 and <id>.jpg (gitignored) and refreshes
tool/samples/samples.json with the real durations.
"""

import base64
import json
import os
import re
import subprocess
import sys
import textwrap
import wave
from pathlib import Path

import google.auth
import google.auth.transport.requests
import requests

HERE = Path(__file__).parent
OUT = HERE / "out"
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
PROJECT = "contextlens-tekken"
FONT = "C\\:/Windows/Fonts/segoeuib.ttf" if os.name == "nt" else "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
RATE = 24000
GAP_S = 0.35
LEAD_S = 0.6
SIZE = (720, 1280)
FPS = 30
TAG = "synthetic test video"

_session = None


def _auth() -> requests.Session:
    global _session
    if _session is None:
        credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        _session = google.auth.transport.requests.AuthorizedSession(credentials)
        _session.headers["x-goog-user-project"] = PROJECT
    return _session


def speak(text: str, voice: str, out: Path) -> float:
    """Synthesizes `text` to a mono 24 kHz WAV; returns its length in seconds."""
    if not out.exists():
        response = _auth().post(
            "https://texttospeech.googleapis.com/v1/text:synthesize",
            json={
                "input": {"text": text},
                "voice": {"languageCode": "en-IN", "name": voice},
                "audioConfig": {"audioEncoding": "LINEAR16", "sampleRateHertz": RATE},
            },
            timeout=60,
        )
        response.raise_for_status()
        out.write_bytes(base64.b64decode(response.json()["audioContent"]))
    with wave.open(str(out)) as w:
        return w.getnframes() / w.getframerate()


def _pcm(path: Path) -> bytes:
    with wave.open(str(path)) as w:
        return w.readframes(w.getnframes())


def _silence(seconds: float) -> bytes:
    return b"\0\0" * int(RATE * seconds)


def build_audio(parts: list[tuple[str, str]], work: Path, out: Path) -> list[tuple[float, float]]:
    """Speaks each (voice, text) line with a pause between; returns each
    line's (start, end) in seconds in the final track."""
    pcm, spans, t = _silence(LEAD_S), [], LEAD_S
    for i, (voice, text) in enumerate(parts):
        wav = work / f"line{i:02d}_{voice.split('-')[-1]}.wav"
        length = speak(text, voice, wav)
        pcm += _pcm(wav)
        spans.append((t, t + length))
        pcm += _silence(GAP_S)
        t += length + GAP_S
    pcm += _silence(LEAD_S)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)
    return spans


def ffmpeg(*args: str, cwd: Path | None = None) -> None:
    subprocess.run([FFMPEG, "-loglevel", "error", "-y", *args], check=True, cwd=cwd)


def _text_file(work: Path, name: str, text: str, width: int) -> str:
    (work / name).write_text("\n".join(textwrap.wrap(text, width)), encoding="utf-8")
    return name


def _y(pos: str) -> str:
    return {"top": "h*0.12", "middle": "(h-text_h)/2", "bottom": "h*0.70"}[pos]


def render(
    audio: Path,
    spans: list[tuple[float, float]],
    captions: list[str],
    scenes: list[tuple[float, list[str]]],
    overlays: list[dict],
    work: Path,
    out: Path,
    title: str,
    size: tuple[int, int] = SIZE,
) -> float:
    """Gradient scenes, one caption per spoken line, overlays, then the
    audio. Returns the video length in seconds."""
    with wave.open(str(audio)) as w:
        length = w.getnframes() / w.getframerate()
    width, height = size
    inputs: list[str] = []
    graph: list[str] = []
    start = 0.0
    for i, (end, colors) in enumerate(scenes):
        end = min(end, length) if i < len(scenes) - 1 else length
        inputs += ["-f", "lavfi", "-i",
                   f"gradients=s={width}x{height}:c0={colors[0]}:c1={colors[1]}:x0=0:y0=0:x1={width}:y1={height}"
                   f":speed=0.008:d={end - start:.3f}:r={FPS}"]
        start = end
    graph.append("".join(f"[{i}:v]" for i in range(len(scenes))) + f"concat=n={len(scenes)}:v=1:a=0[bg]")
    label = "bg"
    char_width = 20 if width < height else 40
    caption_y = 0.58 if width < height else 0.40
    for i, ((a, b), text) in enumerate(zip(spans, captions, strict=True)):
        name = _text_file(work, f"cap{i:02d}.txt", text, char_width)
        graph.append(
            f"[{label}]drawtext=fontfile='{FONT}':textfile='{name}':expansion=none:fontsize=46:fontcolor=white:line_spacing=4:"
            f"box=1:boxcolor=black@0.55:boxborderw=18:x=(w-text_w)/2:y=h*{caption_y}:"
            f"enable='between(t,{a:.3f},{b + GAP_S:.3f})'[c{i}]"
        )
        label = f"c{i}"
    for i, o in enumerate(overlays):
        name = _text_file(work, f"ovl{i:02d}.txt", o["text"], 26)
        graph.append(
            f"[{label}]drawtext=fontfile='{FONT}':textfile='{name}':expansion=none:fontsize={o.get('size', 52)}:fontcolor=white:"
            f"box=1:boxcolor=0x0B0F14@0.7:boxborderw=20:x=(w-text_w)/2:y={_y(o.get('pos', 'top'))}:"
            f"enable='between(t,{o['from']:.3f},{o['to']:.3f})'[o{i}]"
        )
        label = f"o{i}"
    graph.append(
        f"[{label}]drawtext=fontfile='{FONT}':text='Synthetic test video':fontsize=22:fontcolor=white@0.8:"
        f"x=(w-text_w)/2:y=h-text_h-28[mark]"
    )
    label = "mark"
    (work / "graph.txt").write_text(";\n".join(graph), encoding="utf-8")
    ffmpeg(
        *inputs, "-i", audio.name,
        "-/filter_complex", "graph.txt", "-map", f"[{label}]", "-map", f"{len(scenes)}:a",
        "-c:v", "libx264", "-preset", "slow", "-crf", "26", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "96k", "-shortest", "-movflags", "+faststart",
        "-metadata", f"title={title}", "-metadata", f"comment={TAG}", "-metadata", f"description={TAG}",
        str(out.resolve()),
        cwd=work,
    )
    return length


def thumbnail(video: Path, out: Path, at: float) -> None:
    ffmpeg("-ss", f"{at:.2f}", "-i", str(video), "-frames:v", "1", "-vf", "scale=360:-2", "-q:v", "4", str(out))


def _when(ref, spans: list[tuple[float, float]], edge: int) -> float:
    if ref == "end":
        return spans[-1][1] + LEAD_S
    return spans[ref][edge]


def build_reel(sample: dict) -> dict:
    work = OUT / "work" / sample["id"]
    work.mkdir(parents=True, exist_ok=True)
    audio = work / "voice.wav"
    spans = build_audio([(sample["voice"], line) for line in sample["lines"]], work, audio)
    scenes = [(_when(s["until"], spans, 1) + GAP_S / 2, s["colors"]) for s in sample["scenes"]]
    overlays = [
        {**o, "from": spans[o["lines"][0]][0], "to": _when(o["lines"][1], spans, 1)}
        for o in sample["overlays"]
    ]
    video = OUT / f"{sample['id']}.mp4"
    length = render(audio, spans, sample["lines"], scenes, overlays, work, video, sample["title"])
    thumbnail(video, OUT / f"{sample['id']}.jpg", spans[min(1, len(spans) - 1)][0] + 0.5)
    return {"durationMs": int(length * 1000)}


def build_borrowed(spec: dict) -> tuple[dict, dict]:
    work = OUT / "work" / spec["id"]
    work.mkdir(parents=True, exist_ok=True)
    voices = spec["voices"]
    lines = [(voices[who], text) for who, text in spec["lines"]]

    # The full interview, landscape.
    audio = work / "source.wav"
    spans = build_audio(lines, work, audio)
    source = OUT / f"{spec['sourceId']}.mp4"
    names = [f"{'Host' if who == 'host' else 'Dr Mehta'}: {text}" for who, text in spec["lines"]]
    src_len = render(audio, spans, names, [(1e9, spec["sourceColors"])], [
        {"text": spec["sourceTitle"], "from": 0, "to": src_len_guess(spans), "pos": "top", "size": 40},
    ], work, source, spec["sourceTitle"], size=(1280, 720))

    # The reel: the chosen lines cut out of the interview audio, so the words
    # match the original exactly and the omitted qualifier is simply gone.
    with wave.open(str(audio)) as w:
        pcm = w.readframes(w.getnframes())
    reel_pcm, reel_spans, t = _silence(LEAD_S), [], LEAD_S
    for i in spec["reelLines"]:
        a, b = spans[i]
        reel_pcm += pcm[int(a * RATE) * 2:int(b * RATE) * 2] + _silence(GAP_S)
        reel_spans.append((t, t + b - a))
        t += b - a + GAP_S
    reel_pcm += _silence(LEAD_S)
    reel_audio = work / "reel.wav"
    with wave.open(str(reel_audio), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(reel_pcm)
    reel = OUT / f"{spec['id']}.mp4"
    reel_len = render(reel_audio, reel_spans, [spec["lines"][i][1] for i in spec["reelLines"]],
                      [(1e9, spec["reelColors"])],
                      [{"text": "Doctor explains vitamin D", "from": 0, "to": t + LEAD_S, "pos": "top"}],
                      work, reel, spec["title"])
    thumbnail(reel, OUT / f"{spec['id']}.jpg", reel_spans[1][0] + 0.5)
    thumbnail(source, OUT / f"{spec['sourceId']}.jpg", spans[1][0] + 0.5)
    return {"durationMs": int(reel_len * 1000)}, {"durationMs": int(src_len * 1000)}


def src_len_guess(spans: list[tuple[float, float]]) -> float:
    return spans[-1][1] + LEAD_S


def _describe(entry: dict, video: Path) -> None:
    """Size and resolution from the file, for the app's preview card."""
    if not video.exists():
        return
    entry["sizeBytes"] = video.stat().st_size
    info = subprocess.run([FFMPEG, "-hide_banner", "-i", str(video)], capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stderr
    match = re.search(r"Video:.*?(\d{3,4})x(\d{3,4})", info)
    duration = re.search(r"Duration: (\d+):(\d+):([\d.]+)", info)
    if match:
        entry["width"], entry["height"] = int(match.group(1)), int(match.group(2))
    if duration:
        h, m, sec = duration.groups()
        entry["durationMs"] = int((int(h) * 3600 + int(m) * 60 + float(sec)) * 1000)


def main() -> None:
    OUT.mkdir(exist_ok=True)
    scripts = json.loads((HERE / "scripts.json").read_text(encoding="utf-8"))
    manifest_path = HERE / "samples.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in manifest["samples"]}
    only = set(sys.argv[1:])

    for sample in scripts["samples"]:
        if only and sample["id"] not in only:
            continue
        meta = build_reel(sample)
        by_id[sample["id"]].update(meta)
        print(f"{sample['id']}: {meta['durationMs'] / 1000:.1f}s")

    spec = scripts["borrowed"]
    if not only or spec["id"] in only:
        reel, source = build_borrowed(spec)
        by_id[spec["id"]].update(reel)
        by_id[spec["id"]]["clip"]["durationMs"] = source["durationMs"]
        print(f"{spec['id']}: {reel['durationMs'] / 1000:.1f}s, source {source['durationMs'] / 1000:.1f}s")

    for sample in manifest["samples"]:
        _describe(sample, OUT / f"{sample['id']}.mp4")
        if sample.get("clip"):
            _describe(sample["clip"], OUT / f"{sample['clip']['id']}.mp4")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
