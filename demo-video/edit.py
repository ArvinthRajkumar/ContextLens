"""Cuts the demo video from the live-app recordings, the deck pages and the
voiceover. ffmpeg only.

    python edit.py FFMPEG

Inputs (all under out/, gitignored): rec/rec1.webm, rec2.webm and rec5.webm
with marks1/2/5.json from record.mjs, deck/pageNN.png, vo/S1..S9.mp3 and
vo/lengths.json from voiceover.py. Output: out/contextlens_demo.mp4.
"""

import json
import subprocess
import sys
import textwrap
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE / "out"
WORK = OUT / "edit"
FFMPEG = sys.argv[1] if len(sys.argv) > 1 else "ffmpeg"
FPS = 30
W, H = 1920, 1080
BG = "0xE6F4F1"
TEAL = "0x00796B"
FONT = "C\\:/Windows/Fonts/arial.ttf"
FONT_BOLD = "C\\:/Windows/Fonts/arialbd.ttf"
XFADE = 0.3
VOICE_LEAD = 0.6

# The page as recorded: Windows display scaling (125%) puts the 412x915
# viewport in the top-left 515x1143 pixels of each frame.
CROP = "crop=515:1143:0:0"
PHONE_H = 1000
PHONE_W = round(515 * PHONE_H / 1143 / 2) * 2
RADIUS = 44

VO = json.loads((OUT / "vo" / "lengths.json").read_text())
MARKS = {n: json.loads((OUT / "rec" / f"marks{n}.json").read_text())["marks"] for n in (1, 2, 5)}


def ff(*args: str) -> None:
    # Filter graphs and caption files are named relative to the work folder.
    subprocess.run([FFMPEG, "-loglevel", "error", "-y", *args], check=True, cwd=WORK)


def rec(take: int, start: str, end: str | None = None, *, length: float | None = None,
        skip: float = 0.0, speed: float = 1.0) -> dict:
    marks = MARKS[take]
    a = marks[start] + skip
    b = marks[end] if end else a + (length or 0) * speed
    return {"kind": "phone", "src": OUT / "rec" / f"rec{take}.webm", "start": a, "end": b, "speed": speed}


def deck(page: int) -> dict:
    return {"kind": "deck", "src": OUT / "deck" / f"page{page:02d}.png"}


# Sections: the title on the left, and the shots with how long each one stays.
SECTIONS = [
    ("S1", None, [(deck(1), 7.5), (rec(1, "a_start", "a_end"), 16.0)]),
    ("S2", "Try a sample", [(rec(1, "b_start", "b_end"), 19.0)]),
    ("S3", "Live check", [(rec(1, "c_start", "c_end", speed=1.33), 23.0)]),
    ("S4", "Cited flags", [(rec(2, "d_start", length=12.0), 12.0), (rec(2, "e_start", "e_end"), 19.0)]),
    ("S5", "Claims and facts", [(rec(2, "f_claims_start", length=15.0), 15.0),
                                (rec(2, "f_fact_start", length=15.0), 15.0)]),
    ("S6", "Evidence gate", [(rec(2, "f_uncertain_start", "f_uncertain_end"), 21.0)]),
    ("S7", "Borrowed clips", [(rec(5, "g_start", "g_end", skip=4.5), 21.0)]),
    ("S8", "Re-check", [(rec(2, "h_report_start", "h_report_end"), 7.0),
                        (rec(2, "h_home_start", "h_home_end"), 7.0), (deck(7), 10.0)]),
    # The links slide comes up as the voice says "Try it now".
    ("S9", None, [(deck(11), 11.0), (deck(13), 16.0)]),
]
SPED_UP = {"S3"}


def _text_file(name: str, text: str) -> str:
    path = WORK / name
    # Unix line endings: drawtext draws the CR of a Windows line ending as an
    # extra blank line.
    path.write_text(text, encoding="utf-8", newline=chr(10))
    return path.name


def phone_shot(shot: dict, title: str | None, duration: float, out: Path, sped: bool) -> None:
    """The recording, cropped to the page, scaled to 1000 px tall, rounded,
    with a soft shadow, centred on the background; the section title on the
    left. Frozen on its last frame if the clip is shorter than the shot."""
    seg = shot["end"] - shot["start"]
    pts = 1 / shot["speed"]
    x = (W - PHONE_W) // 2
    y = (H - PHONE_H) // 2
    # The background with the phone's shadow, and the corner mask, are the
    # same for every shot: made once (see stills()), only overlaid here.
    graph = [
        f"[1:v]loop=-1:1:0,trim=duration={duration:.3f},fps={FPS}[bg]",
        f"[2:v]loop=-1:1:0,format=gray[mask]",
        f"[0:v]{CROP},setpts={pts:.4f}*(PTS-STARTPTS),fps={FPS},scale={PHONE_W}:{PHONE_H}:flags=lanczos,"
        f"tpad=stop_mode=clone:stop_duration={duration:.3f},trim=duration={duration:.3f},format=rgba[ph]",
        "[ph][mask]alphamerge[phone]",
        f"[bg][phone]overlay={x}:{y}:shortest=1[b2]",
    ]
    label = "b2"
    if title:
        name = _text_file(f"title_{out.stem}.txt", title)
        graph.append(f"[{label}]drawtext=fontfile='{FONT_BOLD}':textfile='{name}':fontsize=60:fontcolor={TEAL}:"
                     f"x=({x}-text_w)/2:y=h/2-text_h-10[b3]")
        label = "b3"
    if sped:
        name = _text_file(f"sped_{out.stem}.txt", "Sped up")
        graph.append(f"[{label}]drawtext=fontfile='{FONT}':textfile='{name}':fontsize=30:fontcolor=white:"
                     f"box=1:boxcolor={TEAL}@0.9:boxborderw=14:x=w-text_w-48:y=48[b4]")
        label = "b4"
    (WORK / f"{out.stem}.graph").write_text(";\n".join(graph), encoding="utf-8")
    ff("-ss", f"{shot['start']:.3f}", "-t", f"{seg:.3f}", "-i", str(shot["src"].resolve()),
       "-i", "stage.png", "-i", "mask.png",
       "-/filter_complex", f"{out.stem}.graph", "-map", f"[{label}]", "-an",
       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
       str(out.resolve()), )


def stills() -> None:
    """The stage (background plus the phone's soft shadow) and the rounded
    corner mask, rendered once."""
    x = (W - PHONE_W) // 2
    y = (H - PHONE_H) // 2
    ff("-f", "lavfi", "-i", f"color=black:s={PHONE_W}x{PHONE_H}", "-vf",
       f"format=gray,geq=lum='255*lte(hypot(max(0,abs(X-{PHONE_W}/2)-({PHONE_W}/2-{RADIUS})),"
       f"max(0,abs(Y-{PHONE_H}/2)-({PHONE_H}/2-{RADIUS}))),{RADIUS})'", "-frames:v", "1", "mask.png")
    ff("-f", "lavfi", "-i", f"color={BG}:s={W}x{H}", "-i", "mask.png", "-filter_complex",
       f"[1:v]pad={PHONE_W + 160}:{PHONE_H + 160}:80:80:black,boxblur=30:4,format=gray[sm];"
       f"color=0x0B3D36:s={PHONE_W + 160}x{PHONE_H + 160},format=rgba[sc];"
       "[sc][sm]alphamerge,colorchannelmixer=aa=0.32[shadow];"
       f"[0:v][shadow]overlay={x - 80}:{y - 64}",
       "-frames:v", "1", "stage.png")


def deck_shot(shot: dict, duration: float, out: Path) -> None:
    """A deck page full screen with a slow 3% zoom."""
    frames = round(duration * FPS)
    ff("-loop", "1", "-i", str(shot["src"].resolve()), "-vf",
       f"scale=3840:-2,crop=3840:2160,zoompan=z='1+0.03*on/{frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
       f"d={frames}:s={W}x{H}:fps={FPS},format=yuv420p",
       "-frames:v", str(frames), "-c:v", "libx264", "-preset", "medium", "-crf", "18", str(out.resolve()))


def sentences(text: str) -> list[str]:
    out, current = [], ""
    for part in text.replace(": ", ":| ").replace(". ", ".| ").split("| "):
        current = f"{current} {part}".strip()
        if len(current) > 40 or part.endswith((".", "?")):
            out.append(current)
            current = ""
    if current:
        out.append(current)
    return out


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    stills()
    shots, section_starts, t = [], {}, 0.0
    for key, title, items in SECTIONS:
        section_starts[key] = t
        for i, (shot, duration) in enumerate(items):
            out = WORK / f"{key}_{i}.mp4"
            if shot["kind"] == "deck":
                deck_shot(shot, duration, out)
            else:
                phone_shot(shot, title, duration, out, key in SPED_UP)
            shots.append((out, duration))
            t += duration - XFADE
        print(key, "built")

    # Crossfade every shot into the next.
    inputs, graph, prev, offset = [], [], "0:v", 0.0
    for i, (path, duration) in enumerate(shots):
        inputs += ["-i", str(path.resolve())]
        if i == 0:
            offset = duration - XFADE
            continue
        label = f"x{i}"
        graph.append(f"[{prev}][{i}:v]xfade=transition=fade:duration={XFADE}:offset={offset:.3f}[{label}]")
        prev = label
        offset += duration - XFADE
    total = offset + XFADE

    # Captions: each section's script, a sentence or two at a time, spread
    # over the voice in proportion to their length.
    caption_filters = []
    n = 0
    for key, _, _ in SECTIONS:
        text = VO["script"][key]
        voice = VO["seconds"][key]
        start = section_starts[key] + VOICE_LEAD
        parts = sentences(text)
        weights = [len(p) for p in parts]
        acc = 0.0
        for part, weight in zip(parts, weights, strict=True):
            a = start + voice * acc / sum(weights)
            acc += weight
            b = start + voice * acc / sum(weights)
            name = _text_file(f"cap{n:02d}.txt", "\n".join(textwrap.wrap(part, 64)))
            caption_filters.append(
                f"drawtext=fontfile='{FONT}':textfile='{name}':fontsize=36:fontcolor=white:line_spacing=8:"
                f"box=1:boxcolor=black@0.6:boxborderw=18:x=(w-text_w)/2:y=h-text_h-56:"
                f"enable='between(t,{a:.2f},{b:.2f})'"
            )
            n += 1
    graph.append(f"[{prev}]" + ",".join(caption_filters) + "[v]")

    # Voice: each section placed at its start, then normalized to -16 LUFS.
    audio_inputs, delays = [], []
    for j, (key, _, _) in enumerate(SECTIONS):
        audio_inputs += ["-i", str((OUT / "vo" / f"{key}.mp3").resolve())]
        ms = round((section_starts[key] + VOICE_LEAD) * 1000)
        delays.append(f"[{len(shots) + j}:a]aresample=48000,adelay={ms}|{ms}[a{j}]")
    graph += delays
    graph.append("".join(f"[a{j}]" for j in range(len(SECTIONS))) +
                 f"amix=inputs={len(SECTIONS)}:normalize=0,apad,atrim=duration={total:.3f},"
                 "loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[a]")
    (WORK / "final.graph").write_text(";\n".join(graph), encoding="utf-8")
    final = OUT / "contextlens_demo.mp4"
    ff(*inputs, *audio_inputs, "-/filter_complex", "final.graph", "-map", "[v]", "-map", "[a]",
       "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(FPS),
       "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart", str(final.resolve()))
    print("total", round(total, 2), final)


if __name__ == "__main__":
    main()
