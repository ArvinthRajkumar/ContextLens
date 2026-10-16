"""Voiceover for the demo video: one MP3 per section from Gemini-TTS through
Cloud Text-to-Speech (en-IN, voice Kore) in contextlens-tekken.

    ../backend/.venv/Scripts/python.exe voiceover.py FFMPEG [--keep-s1] [--only S3 ...]

Writes out/vo/S1.mp3 ... S9.mp3 and out/vo/lengths.json. --keep-s1 reuses
out/voice_samples/S1_Kore.mp3, the take that was picked by ear; --only regenerates just those sections and
keeps the others on disk (a take that drops a phrase is redone this way). The spoken
text differs from the caption only where the voice needs help reading it.
"""

import base64
import json
import shutil
import subprocess
import sys
from pathlib import Path

import google.auth
import google.auth.transport.requests

HERE = Path(__file__).parent
OUT = HERE / "out" / "vo"
VOICE = "Kore"
MODEL = "gemini-2.5-pro-tts"
PROJECT = "contextlens-tekken"
STYLE = (
    "You are an energetic, warm young Indian tech founder presenting your product demo to judges. "
    "Sound confident and genuinely excited, vary your pitch, smile while you talk, and pause naturally "
    "between ideas. Not robotic, not salesy."
)

SCRIPT = {
    "S1": "Every day, creators in India post reels that quietly break advertising rules. A missing ad label, a cure claim, a podcast clip cut out of context. Between April and September 2025, ninety-eight percent of the influencer ads ASCI investigated needed changes. Most creators only find out after the video is live. We are team Tekken, and we built ContextLens to catch it before you post.",
    "S2": "Here is the app. It runs on Android and on the web. You can upload your own video, or tap Try a sample to see how it works. I'll pick GlucoLeaf, a sponsored reel about a supplement. Before the check, we ask for fifteen seconds of context: the caption you plan to post, whether the video is paid or gifted, any borrowed clips, and the topic. Health and finance videos get stricter checks.",
    "S3": "Now the live check starts. The video goes to Cloud Storage through a signed upload, and a LangGraph pipeline on Cloud Run takes over. Chirp 3 transcribes every word with timestamps. Gemini 2.5 Flash on Vertex AI reads the frames and the on-screen text, and builds a claim ledger: every claim, every label, every quote, and exactly when it appears. Then four checkers run in parallel. You can watch each stage live, and on our benchmark the median check takes about thirty-six seconds.",
    "S4": "Here is the report. At the top, how many issues to fix, grouped by type. Every flag has a timestamp you can tap to jump to that moment. This first one is about disclosure. The video is paid, but the ad label is buried at the end of the caption. ASCI's influencer guidelines say the label must be upfront and easy to notice, so ContextLens quotes clause 1.2 c, shows what it found, and suggests the fix: move the label to the start.",
    "S5": "Next, claims. Health claims are checked against a clause index built from the ASCI Code and the Drugs and Magic Remedies Act, and every flag says whether the rule is statutory law or self-regulation, because that changes the risk. For facts, we first ask Google's Fact Check Tools API whether professional fact-checkers have already rated the claim. If they haven't, Gemini checks it with Google Search grounding and quotes the source it relies on.",
    "S6": "What makes this trustworthy is the evidence gate. A flag is only marked verified if its quote is actually found in the cited rule or source, and Vertex AI Check Grounding scores how well the evidence supports it. When the evidence isn't there, ContextLens doesn't guess. It marks the flag as needs a human look, like this one.",
    "S7": "Borrowed clips are a different problem. A creator can take a real podcast quote and cut it so it says something else. ContextLens aligns the clip with the original transcript, word by word. Here, the clip stops right before the speaker adds a condition, and the report highlights exactly the sentence that was left out.",
    "S8": "The creator fixes the video and uploads it again, and the re-check shows what was resolved and what is still open. Under the hood, it's all Google: a Flutter app with Firebase Auth, App Check and Cloud Messaging; Cloud Run, Firestore and Cloud Storage; and Gemini, Chirp, Fact Check Tools and Check Grounding for the AI.",
    "S9": "We tested it on a 34-case benchmark built from real ASCI decision types. Disclosure, claims and borrowed-clip checks all scored 1.00 precision and recall, with zero evidence-gate failures, at about five cents per check. ContextLens is live right now. Open contextlens-tekken.web.app, try a sample, and check your next video before you post. Thank you.",
}

# How the voice should say things it would otherwise misread.
SPOKEN = {
    "ASCI": "A S C I",
    "clause 1.2 c": "clause one point two c",
    "1.00 precision": "one point oh oh precision",
    "contextlens-tekken.web.app": "contextlens dash tekken dot web dot app",
    "Chirp 3": "Chirp three",
    "Gemini 2.5 Flash": "Gemini two point five Flash",
    "34-case": "thirty-four case",
}


def spoken(text: str) -> str:
    for written, said in SPOKEN.items():
        text = text.replace(written, said)
    return text


def seconds(ffmpeg: str, path: Path) -> float:
    info = subprocess.run([ffmpeg, "-hide_banner", "-i", str(path)], capture_output=True, text=True).stderr
    h, m, s = info.split("Duration: ")[1].split(",")[0].split(":")
    return round(int(h) * 3600 + int(m) * 60 + float(s), 2)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ffmpeg = sys.argv[1] if len(sys.argv) > 1 else "ffprobe"
    keep_s1 = "--keep-s1" in sys.argv
    only = {a for a in sys.argv[2:] if a in SCRIPT}
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    session = google.auth.transport.requests.AuthorizedSession(credentials)
    session.headers["x-goog-user-project"] = PROJECT
    lengths = {}
    for key, text in SCRIPT.items():
        out = OUT / f"{key}.mp3"
        if only and key not in only:
            pass
        elif key == "S1" and keep_s1:
            shutil.copyfile(HERE / "out" / "voice_samples" / f"S1_{VOICE}.mp3", out)
        else:
            response = session.post(
                "https://texttospeech.googleapis.com/v1/text:synthesize",
                json={
                    "input": {"prompt": STYLE, "text": spoken(text)},
                    "voice": {"languageCode": "en-IN", "name": VOICE, "modelName": MODEL},
                    "audioConfig": {"audioEncoding": "MP3", "sampleRateHertz": 48000},
                },
                timeout=300,
            )
            response.raise_for_status()
            out.write_bytes(base64.b64decode(response.json()["audioContent"]))
        lengths[key] = seconds(ffmpeg, out)
        print(key, lengths[key], flush=True)
    meta = {"voice": VOICE, "model": MODEL, "script": SCRIPT, "seconds": lengths}
    (OUT / "lengths.json").write_text(json.dumps(meta, indent=2))
    print("total", round(sum(lengths.values()), 1))


if __name__ == "__main__":
    main()
