"""Cuts the demo video from the live-app recordings, the deck pages and the
voiceover. The voice drives the timing: sections run back to back and every
shot is fitted to its section's speech.

    python edit.py FFMPEG

Run it with a Python that has Pillow (the overlays are drawn with it).
Inputs (all under out/, gitignored): rec/rec1.webm, rec2.webm, rec5.webm from
record.mjs, deck/pageNN.png, vo/S1..S9.mp3 and vo/lengths.json from
voiceover.py, plus assets/links_slide_for_video.png and, if present,
assets/music.mp3. Output: out/contextlens_demo.mp4.
"""

import json
import re
import subprocess
import sys
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).parent
OUT = HERE / "out"
WORK = OUT / "edit"
ASSETS = HERE / "assets"
FFMPEG = sys.argv[1] if len(sys.argv) > 1 else "ffmpeg"
FPS = 30
W, H = 1920, 1080
XFADE = 0.3
GAP = 0.25
LEAD = 0.3
TAIL = 0.4
TEMPO = 1.04
MAX_PAUSE = 0.45
EASE = 0.6

# The page as recorded: Windows display scaling (125%) puts the 412x915
# viewport in the top-left 515x1143 pixels of each frame.
CROP = "crop=515:1143:0:0"
PHONE_W, PHONE_H = 450, 1000
PHONE_X, PHONE_Y = 1380 - PHONE_W // 2, (H - PHONE_H) // 2
RADIUS = 44
SHADOW = 80
# The phone floats a few pixels on a slow cycle (in absolute time, so cuts
# line up), which also keeps still screens from reading as frozen.
FLOAT = "{y}+7*sin(2*PI*(t+{start:.3f})/7)"
LEFT_X, LEFT_W = 120, 840
CAPTION_Y = 800

TEAL = (0, 121, 107)
TEAL_DARK = (0, 87, 75)
INK = (16, 42, 39)
ARIAL = "C:/Windows/Fonts/arial.ttf"
ARIAL_BOLD = "C:/Windows/Fonts/arialbd.ttf"

VO = json.loads((OUT / "vo" / "lengths.json").read_text())
SCRIPT = VO["script"]


def phone(take: int, segments: list, *, until=None, zoom=(), badge=None) -> dict:
    """Segments are (start, end, speed) in the recording; a None speed
    stretches that segment to fill whatever time the fixed ones leave.
    Zoom keyframes are (phrase or seconds into the shot, zoom, x, y)."""
    return {"kind": "phone", "take": take, "segments": segments, "until": until, "zoom": list(zoom), "badge": badge}


def deck(source, *, until=None) -> dict:
    path = OUT / "deck" / f"page{source:02d}.png" if isinstance(source, int) else ASSETS / source
    return {"kind": "deck", "src": path, "until": until}


SECTIONS = [
    {"key": "S1", "label": "THE PROBLEM", "headline": "Rule breaks are found after the reel is live",
     "chips": [("Missing ad labels", "A missing ad label"), ("Cure claims, clipped quotes", "a cure claim"),
               ("98% of investigated ads needed changes", "ninety-eight percent")],
     "shots": [deck(1, until=4.0),
               phone(1, [(2.5, 11.0, None)], zoom=[("We are team Tekken", 1.25, 0.5, 0.2)])]},
    {"key": "S2", "label": "TRY A SAMPLE", "headline": "Fifteen seconds of context",
     "chips": [("Android and web", "It runs on Android"), ("Caption, paid, clips, topic", "the caption you plan"),
               ("Stricter health and finance checks", "Health and finance")],
     "shots": [phone(1, [(11.0, 17.0, 1.0), (17.0, 26.3, None)],
                     zoom=[("the caption you plan", 1.15, 0.5, 0.36), ("any borrowed clips", 1.15, 0.5, 0.66)])]},
    {"key": "S3", "label": "LIVE CHECK", "headline": "From upload to report, live",
     "chips": [("Chirp 3", "Chirp 3"), ("Gemini 2.5 Flash on Vertex AI", "Gemini 2.5"),
               ("4 checkers in parallel", "four checkers")],
     "shots": [phone(1, [(24.0, 54.5, None)], badge="Real time")]},
    {"key": "S4", "label": "CITED FLAGS", "headline": "Every flag cites the rule it breaks",
     "chips": [("Tap a timestamp to jump", "timestamp you can tap"), ("ASCI clause 1.2(c)", "quotes clause"),
               ("A fix you can apply", "suggests the fix")],
     "shots": [phone(2, [(47.5, 62.0, None)], until="This first one",
                     zoom=[("how many issues", 1.35, 0.37, 0.6), ("Every flag has", 1.0, 0.5, 0.5)]),
               phone(2, [(66.0, 82.0, None)],
                     zoom=[("ASCI's influencer", 1.35, 0.37, 0.22), ("suggests the fix", 1.35, 0.37, 0.78)])]},
    {"key": "S5", "label": "CLAIMS AND FACTS", "headline": "Statute or self-regulation, with sources",
     "chips": [("ASCI Code and the DMR Act", "clause index"), ("Fact Check Tools API", "Fact Check Tools"),
               ("Google Search grounding", "Google Search grounding")],
     "shots": [phone(2, [(84.0, 88.8, None)], until="and every flag says"),
               phone(2, [(104.8, 106.8, None)], until="For facts", zoom=[(0.0, 1.35, 0.37, 0.62)]),
               phone(2, [(19.0, 37.2, None)], zoom=[("quotes the source", 1.35, 0.37, 0.6)])]},
    {"key": "S6", "label": "EVIDENCE GATE", "headline": "No evidence, no verdict",
     "chips": [("Quote found in the source", "quote is actually found"),
               ("Vertex AI Check Grounding", "Vertex AI Check Grounding"), ("Needs a human look", "needs a human look")],
     "shots": [phone(2, [(107.0, 121.2, None)], zoom=[("needs a human look", 1.35, 0.37, 0.2)])]},
    {"key": "S7", "label": "BORROWED CLIPS", "headline": "See what the clip left out",
     "chips": [("Word by word alignment", "word by word"), ("The missing sentence, highlighted", "highlights exactly")],
     "shots": [phone(5, [(47.5, 67.0, None)], zoom=[("highlights exactly", 1.35, 0.37, 0.72)])]},
    {"key": "S8", "label": "RE-CHECK", "headline": "Fix, upload again, compare",
     "chips": [("Resolved and still open", "what was resolved")],
     "shots": [phone(2, [(9.0, 17.5, None)], until="Under the hood",
                     zoom=[("what was resolved", 1.35, 0.37, 0.74)]),
               deck(7)]},
    {"key": "S9", "label": None, "headline": None, "chips": [],
     "shots": [deck(11, until="ContextLens is live"), deck("links_slide_for_video.png")]},
]
CAPTION_DECKS = {"links_slide_for_video.png"}


def ff(*args: str, capture: bool = False) -> str:
    result = subprocess.run([FFMPEG, "-hide_banner", "-y", *args], cwd=WORK, capture_output=True, text=True)
    if result.returncode:
        sys.exit(result.stderr[-3000:])
    return result.stderr if capture else ""


def media_seconds(path: Path) -> float:
    info = subprocess.run([FFMPEG, "-hide_banner", "-i", str(path)], capture_output=True, text=True).stderr
    h, m, s = info.split("Duration: ")[1].split(",")[0].split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


# Voice ----------------------------------------------------------------------

def prepare_voice(key: str) -> tuple[float, list[tuple[float, float]]]:
    """Trims the edges, speeds the take up a little, shortens every pause
    longer than MAX_PAUSE, and returns its length and the pauses left."""
    out = WORK / f"vo_{key}.wav"
    trim = "silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.03"
    ff("-i", str((OUT / "vo" / f"{key}.mp3").resolve()), "-af",
       f"aresample=48000,{trim},areverse,{trim},areverse,atempo={TEMPO}",
       "-ac", "1", "-c:a", "pcm_s16le", out.name)
    # silenceremove leaves these pauses alone, so cut them by hand: keep the
    # first MAX_PAUSE - 0.05 s of each long pause and drop the rest.
    with wave.open(str(out)) as f:
        rate, frames = f.getframerate(), f.readframes(f.getnframes())
    keep, pos = bytearray(), 0
    for a, b in silences(out.name, "-40dB", MAX_PAUSE):
        cut_from = int((a + MAX_PAUSE - 0.05) * rate) * 2
        keep += frames[pos:cut_from]
        pos = int(b * rate) * 2
    keep += frames[pos:]
    with wave.open(str(out), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(bytes(keep))
    return len(keep) / 2 / rate, silences(out.name, "-35dB", 0.12)


def silences(name: str, noise: str, duration: float) -> list[tuple[float, float]]:
    log = ff("-i", name, "-af", f"silencedetect=noise={noise}:d={duration}", "-f", "null", "-", capture=True)
    starts = [float(x) for x in re.findall(r"silence_start: ([0-9.]+)", log)]
    ends = [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", log)]
    return list(zip(starts, ends))


def sentence_spans(text: str) -> list[tuple[int, int]]:
    spans, start = [], 0
    for m in re.finditer(r"[.?!:;](?= )", text):
        spans.append((start, m.end()))
        start = m.end() + 1
    spans.append((start, len(text)))
    return spans


class Clock:
    """Maps a character of a section's script to the moment it is spoken:
    sentence starts snap to the nearest pause, characters in between are
    spread evenly."""

    def __init__(self, text: str, length: float, pauses: list[tuple[float, float]]):
        self.text = text
        spans = sentence_spans(text)
        bounds = [0.0]
        for a, end in spans[:-1]:
            guess = length * end / len(text)
            near = [p for p in pauses if abs((p[0] + p[1]) / 2 - guess) < 1.5 and p[1] > bounds[-1]]
            bounds.append(min(near, key=lambda p: abs((p[0] + p[1]) / 2 - guess))[1] if near else guess)
        bounds.append(length)
        self.spans = [(a, b, bounds[i], bounds[i + 1]) for i, (a, b) in enumerate(spans)]

    def at(self, char: int) -> float:
        for a, b, ta, tb in self.spans:
            if char <= b:
                return ta + (tb - ta) * max(0, char - a) / max(1, b - a)
        return self.spans[-1][3]

    def phrase(self, phrase: str) -> float:
        index = self.text.find(phrase)
        if index < 0:
            raise ValueError(f"phrase not in script: {phrase}")
        return self.at(index)


# Drawing --------------------------------------------------------------------

def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def wrap(text: str, face: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if face.getlength(trial) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def save(img: Image.Image, name: str) -> str:
    img.save(WORK / name)
    return name


def stills() -> None:
    """Background (teal to white), the phone's soft shadow, and the rounded
    mask for the phone."""
    small = Image.new("RGB", (W // 8, H // 8))
    top, bottom = (214, 239, 233), (255, 255, 255)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            t = min(1.0, 0.55 * x / small.width + 0.45 * y / small.height)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    bg = small.resize((W, H), Image.BICUBIC)
    save(bg, "stage.png")
    alpha = Image.new("L", (PHONE_W + 2 * SHADOW, PHONE_H + 2 * SHADOW), 0)
    ImageDraw.Draw(alpha).rounded_rectangle(
        (SHADOW + 6, SHADOW + 18, SHADOW + PHONE_W - 6, SHADOW + PHONE_H + 10), RADIUS, fill=110)
    shadow = Image.new("RGBA", alpha.size, (11, 61, 54, 0))
    shadow.putalpha(alpha.filter(ImageFilter.GaussianBlur(28)))
    save(shadow, "shadow.png")
    mask = Image.new("L", (PHONE_W, PHONE_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PHONE_W - 1, PHONE_H - 1), RADIUS, fill=255)
    save(mask, "mask.png")


def heading(section: dict) -> tuple[str, int]:
    """Section label and headline in one image; returns it and its height."""
    label_face, head_face = font(ARIAL_BOLD, 28), font(ARIAL_BOLD, 66)
    lines = wrap(section["headline"], head_face, LEFT_W)
    height = 44 + len(lines) * 78
    img = Image.new("RGBA", (LEFT_W, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    x = 0
    for ch in section["label"]:
        draw.text((x, 0), ch, font=label_face, fill=TEAL)
        x += label_face.getlength(ch) + 3
    for i, line in enumerate(lines):
        draw.text((0, 44 + i * 78), line, font=head_face, fill=INK)
    return save(img, f"head_{section['key']}.png"), height


def chip(text: str, name: str) -> tuple[str, int]:
    face = font(ARIAL_BOLD, 30)
    w, h = round(face.getlength(text)) + 52, 60
    img = Image.new("RGBA", (w + 4, h + 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((2, 2, w + 1, h + 1), 30, fill=(255, 255, 255, 235), outline=TEAL, width=3)
    draw.text((28, h / 2 + 2), text, font=face, fill=TEAL_DARK, anchor="lm")
    return save(img, name), h


def caption(text: str, name: str, centred: bool) -> tuple[str, int, int]:
    face = font(ARIAL, 32)
    lines = wrap(text, face, LEFT_W - 36)
    w = round(max(face.getlength(line) for line in lines)) + 36
    h = len(lines) * 42 + 20
    img = Image.new("RGBA", (w, h), (0, 0, 0, 153))
    draw = ImageDraw.Draw(img)
    for i, line in enumerate(lines):
        x = (w - face.getlength(line)) / 2 if centred else 18
        draw.text((x, 10 + i * 42), line, font=face, fill=(255, 255, 255))
    return save(img, name), w, h


def caption_chunks(text: str) -> list[tuple[int, str]]:
    """The script in pieces of at most two caption lines, with where each
    piece starts in the text."""
    face = font(ARIAL, 32)
    chunks = []
    for a, b in sentence_spans(text):
        words = text[a:b].split()
        count = -(-len(wrap(text[a:b], face, LEFT_W - 36)) // 2)
        # Split long sentences evenly, so no piece is a lone trailing word.
        while True:
            size = -(-len(words) // count)
            pieces = [" ".join(words[i:i + size]) for i in range(0, len(words), size)]
            if all(len(wrap(p, face, LEFT_W - 36)) <= 2 for p in pieces):
                break
            count += 1
        pos = a
        for piece in pieces:
            start = text.find(piece, pos)
            chunks.append((start, piece))
            pos = start + len(piece)
    return chunks


# Shots ----------------------------------------------------------------------

def eased(keys: list[tuple[float, float]], base: float, now: str = "t") -> str:
    """An ffmpeg expression in now (seconds) that holds base, then eases to
    each (time, value) over EASE seconds."""
    expr, prev = f"{base}", base
    for t, value in keys:
        u = f"clip(({now}-{t:.3f})/{EASE},0,1)"
        expr += f"+({value - prev:.4f})*{u}*{u}*(3-2*{u})"
        prev = value
    return expr


def phone_video(shot: dict, length: float, zoom: list) -> tuple[list[str], list[str], int]:
    """Input arguments and the filter chain that make the phone screen
    stream [scr]: the recording fitted to the shot, zoomed per keyframe, with
    a slow push-in so the picture never stands still."""
    segs = shot["segments"]
    fixed = sum((b - a) / s for a, b, s in segs if s)
    stretch = sum(b - a for a, b, s in segs if not s)
    fill = (length - fixed) / stretch if stretch else 0
    args, chain = [], []
    for i, (a, b, s) in enumerate(segs):
        speed = s or 1 / max(fill, 1e-6)
        args += ["-ss", f"{a:.3f}", "-t", f"{b - a:.3f}", "-i", str((OUT / "rec" / f"rec{shot['take']}.webm").resolve())]
        chain.append(f"[{i}:v]{CROP},setsar=1,setpts=(PTS-STARTPTS)/{speed:.5f},fps={FPS},"
                     f"scale=900:2000:flags=lanczos[s{i}]")
    joined = "".join(f"[s{i}]" for i in range(len(segs)))
    # zoompan, not scale and crop: crop loses the timestamp when its input
    # size changes every frame. Its clock is the output frame number.
    now = f"(on/{FPS})"
    z = f"((1+0.05*{now}/{length:.3f})*({eased([(t, k[0]) for t, *k in zoom], 1.0, now)}))"
    fx = eased([(t, k[1]) for t, *k in zoom], 0.5, now)
    fy = eased([(t, k[2]) for t, *k in zoom], 0.5, now)
    chain.append(
        f"{joined}concat=n={len(segs)}:v=1:a=0,tpad=stop_mode=clone:stop_duration=2,trim=duration={length:.3f},"
        f"zoompan=z='{z}':x='clip(({fx})*iw-iw/zoom/2,0,iw-iw/zoom)':y='clip(({fy})*ih-ih/zoom/2,0,ih-ih/zoom)':"
        f"d=1:s={PHONE_W}x{PHONE_H}:fps={FPS},format=rgba[scr]")
    return args, chain, len(segs)


def render_shot(shot: dict, index: int, start: float, length: float, overlays: list, zoom: list) -> None:
    graph, extra = [], []
    if shot["kind"] == "deck":
        extra += ["-loop", "1", "-framerate", str(FPS), "-t", f"{length:.3f}", "-i", str(shot["src"].resolve())]
        z = f"(1+0.05*t/{length:.3f})"
        graph.append(f"[0:v]scale={W}:{H},setsar=1,fps={FPS},"
                     f"scale=w='2*trunc({W // 2}*{z})':h='2*trunc({H // 2}*{z})':eval=frame:flags=bicubic,"
                     f"crop={W}:{H}:x='(iw-{W})/2':y='(ih-{H})/2',format=rgba[v0]")
        n = 1
    else:
        args, chain, n = phone_video(shot, length, zoom)
        extra += args + ["-loop", "1", "-framerate", str(FPS), "-t", f"{length:.3f}", "-i", "stage.png",
                         "-i", "mask.png", "-loop", "1", "-framerate", str(FPS), "-t", f"{length:.3f}",
                         "-i", "shadow.png"]
        graph += chain
        float_y = FLOAT.format(y=PHONE_Y, start=start)
        shadow_y = FLOAT.format(y=PHONE_Y - SHADOW, start=start)
        graph += [f"[{n + 1}:v]format=gray[mask]", "[scr][mask]alphamerge[ph]", f"[{n}:v]format=rgba[bg]",
                  f"[{n + 2}:v]format=rgba[sh]",
                  f"[bg][sh]overlay=x={PHONE_X - SHADOW}:y='{shadow_y}'[bs]",
                  f"[bs][ph]overlay=x={PHONE_X}:y='{float_y}'[v0]"]
        n += 3
    label = "v0"
    for j, item in enumerate(overlays):
        extra += ["-loop", "1", "-framerate", str(FPS), "-t", f"{length:.3f}", "-i", item["png"]]
        a, b = item["from"] - start, item.get("to", start + length + 1) - start
        enable = f":enable='between(t,{a:.3f},{b:.3f})'" if a > 0 or b < length else ""
        y = f"{item['y']}"
        if item.get("pop") and a > 0:
            graph.append(f"[{n}:v]format=rgba,fade=in:st={a:.3f}:d=0.3:alpha=1[o{j}]")
            y = f"'{item['y']}+26*(1-clip((t-{a:.3f})/0.3,0,1))'"
        else:
            graph.append(f"[{n}:v]format=rgba[o{j}]")
        graph.append(f"[{label}][o{j}]overlay=x={item['x']}:y={y}{enable}[l{j}]")
        label = f"l{j}"
        n += 1
    graph.append(f"[{label}]format=yuv420p[out]")
    (WORK / f"shot{index:02d}.graph").write_text(";\n".join(graph), encoding="utf-8")
    ff(*extra, "-/filter_complex", f"shot{index:02d}.graph", "-map", "[out]", "-t", f"{length:.3f}",
       "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-r", str(FPS), f"shot{index:02d}.mp4")


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    stills()

    # The voice lays out the timeline.
    voice, t = {}, LEAD
    for section in SECTIONS:
        key = section["key"]
        length, pauses = prepare_voice(key)
        voice[key] = {"start": t, "length": length, "clock": Clock(SCRIPT[key], length, pauses)}
        t += length + GAP
    total = t - GAP + TAIL
    print("voice", {k: round(v["length"], 2) for k, v in voice.items()}, "total", round(total, 2), flush=True)

    def when(key: str, at) -> float:
        v = voice[key]
        return v["start"] + (at if isinstance(at, (int, float)) else v["clock"].phrase(at))

    def spoken_at(key: str, char: int) -> float:
        return voice[key]["start"] + voice[key]["clock"].at(char)

    # Shot boundaries: a section's pictures start just before its voice.
    shots = []
    for k, section in enumerate(SECTIONS):
        key = section["key"]
        begin = 0.0 if k == 0 else voice[key]["start"] - 0.12
        for i, shot in enumerate(section["shots"]):
            if i == 0:
                shot["begin"] = begin
            if shot["until"] is not None:
                section["shots"][i + 1]["begin"] = (begin + shot["until"] if isinstance(shot["until"], float)
                                                    else when(key, shot["until"]) - 0.1)
            shots.append((section, shot))
    for i, (_, shot) in enumerate(shots):
        shot["end"] = shots[i + 1][1]["begin"] if i + 1 < len(shots) else total

    # Captions: on app scenes in the left column, on the links slide in the
    # band under its text, nowhere else.
    captions = []
    for section in SECTIONS:
        key = section["key"]
        chunks = caption_chunks(SCRIPT[key])
        for c, (pos, text) in enumerate(chunks):
            a = spoken_at(key, pos)
            b = spoken_at(key, chunks[c + 1][0]) if c + 1 < len(chunks) else \
                voice[key]["start"] + voice[key]["length"] + GAP
            captions.append((a, b, text))

    for index, (section, shot) in enumerate(shots):
        start, end = shot["begin"], shot["end"]
        length = end - start + (XFADE if index + 1 < len(shots) else 0)
        overlays = []
        app = shot["kind"] == "phone"
        if app and section["headline"]:
            png, height = heading(section)
            overlays.append({"png": png, "x": LEFT_X, "y": 200, "from": start})
            y = 200 + height + 40
            for c, (text, trigger) in enumerate(section["chips"]):
                name, h = chip(text, f"chip_{section['key']}_{c}.png")
                overlays.append({"png": name, "x": LEFT_X, "y": y, "from": when(section["key"], trigger),
                                 "pop": True})
                y += h + 18
        if shot.get("badge"):
            face = font(ARIAL_BOLD, 30)
            w = round(face.getlength(shot["badge"])) + 36
            img = Image.new("RGBA", (w, 56), TEAL + (235,))
            ImageDraw.Draw(img).text((18, 28), shot["badge"], font=face, fill=(255, 255, 255), anchor="lm")
            overlays.append({"png": save(img, f"badge{index}.png"), "x": W - w - 48, "y": 48, "from": start})
        on_links = shot["kind"] == "deck" and shot["src"].name in CAPTION_DECKS
        if app or on_links:
            for c, (a, b, text) in enumerate(captions):
                # On the links slide only lines spoken while it is up: earlier
                # ones belong to the slide before, which has no room for them.
                if b <= start or a >= start + length or (on_links and a < start - 0.1):
                    continue
                name, w, h = caption(text, f"cap_{index:02d}_{c:02d}.png", on_links)
                x, y = ((W - w) // 2, 1052 - h) if on_links else (LEFT_X, CAPTION_Y)
                overlays.append({"png": name, "x": x, "y": y, "from": max(a, start - 1), "to": b})
        zoom = []
        for at, z, fx, fy in shot.get("zoom", []):
            local = at if isinstance(at, float) else when(section["key"], at) - start
            zoom.append((max(0.0, local - EASE / 2), z, fx, fy))
        render_shot(shot, index, start, length, overlays, zoom)
        print(f"shot {index} {section['key']} {start:.2f}-{end:.2f}", flush=True)

    # Crossfade every shot into the next: shot i starts at its begin time.
    inputs, vgraph, prev = [], [], "0:v"
    for i, (_, shot) in enumerate(shots):
        inputs += ["-i", f"shot{i:02d}.mp4"]
        if i:
            vgraph.append(f"[{prev}][{i}:v]xfade=transition=fade:duration={XFADE}:offset={shot['begin']:.3f}[x{i}]")
            prev = f"x{i}"
    vgraph.append(f"[{prev}]format=yuv420p[v]")

    # Voice: each section at its start; music (if there is a track) ducked
    # under it; two-pass loudness to -16 LUFS.
    audio_in, agraph = [], []
    for j, section in enumerate(SECTIONS):
        key = section["key"]
        audio_in += ["-i", f"vo_{key}.wav"]
        ms = round(voice[key]["start"] * 1000)
        agraph.append(f"[{j}:a]adelay={ms}:all=1[a{j}]")
    agraph.append("".join(f"[a{j}]" for j in range(len(SECTIONS))) +
                  f"amix=inputs={len(SECTIONS)}:normalize=0,apad,atrim=duration={total:.3f}[voice]")
    music = ASSETS / "music.mp3"
    mixed = "voice"
    if music.exists():
        m = len(SECTIONS)
        audio_in += ["-stream_loop", "-1", "-i", str(music.resolve())]
        agraph += ["[voice]asplit=2[vmix][vkey]",
                   f"[{m}:a]aresample=48000,aformat=channel_layouts=mono,atrim=duration={total:.3f},volume=-22dB,"
                   f"afade=t=in:d=1,afade=t=out:st={total - 2:.3f}:d=2[mus]",
                   "[mus][vkey]sidechaincompress=threshold=0.03:ratio=6:attack=20:release=400[duck]",
                   "[vmix][duck]amix=inputs=2:normalize=0[mixed]"]
        mixed = "mixed"
    mix = ";\n".join(agraph)
    (WORK / "mix.graph").write_text(
        mix + f";\n[{mixed}]aformat=channel_layouts=stereo,loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json[m]",
        encoding="utf-8")
    log = ff(*audio_in, "-/filter_complex", "mix.graph", "-map", "[m]", "-f", "null", "-", capture=True)
    s = json.loads(log[log.rindex("{"):log.rindex("}") + 1])
    (WORK / "mix.graph").write_text(
        mix + f";\n[{mixed}]aformat=channel_layouts=stereo,loudnorm=I=-16:TP=-1.5:LRA=11:"
        f"measured_I={s['input_i']}:measured_TP={s['input_tp']}:measured_LRA={s['input_lra']}:"
        f"measured_thresh={s['input_thresh']}:offset={s['target_offset']}:linear=true,aresample=48000[m]",
        encoding="utf-8")
    ff(*audio_in, "-/filter_complex", "mix.graph", "-map", "[m]", "-c:a", "pcm_s16le", "-ar", "48000", "mix.wav")

    (WORK / "final.graph").write_text(";\n".join(vgraph), encoding="utf-8")
    final = OUT / "contextlens_demo.mp4"
    ff(*inputs, "-i", "mix.wav", "-/filter_complex", "final.graph", "-map", "[v]", "-map", f"{len(shots)}:a",
       "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(FPS),
       "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart",
       "-t", f"{total:.3f}", str(final.resolve()))
    print("total", round(total, 2), final)


if __name__ == "__main__":
    main()
