"""Voiceover for the demo video: one MP3 per section from Cloud
Text-to-Speech (en-IN Chirp 3 HD, male, rate 1.0) in contextlens-tekken.

    ../backend/.venv/Scripts/python.exe voiceover.py

Writes out/vo/S1.mp3 ... S9.mp3 and out/vo/lengths.json. The spoken text
differs from the caption only where the voice needs help reading it.
"""

import base64
import json
import subprocess
import sys
from pathlib import Path

import google.auth
import google.auth.transport.requests

HERE = Path(__file__).parent
OUT = HERE / "out" / "vo"
VOICE = "en-IN-Chirp3-HD-Orus"
PROJECT = "contextlens-tekken"

SCRIPT = {
    "S1": "Creators in India learn that a reel broke the rules after it is already live. Between April and September 2025, 98 percent of the influencer ads ASCI investigated needed changes. We are team Tekken, and this is ContextLens: a check you run before you post.",
    "S2": "Upload a video, or try one of our built-in samples. In fifteen seconds you tell us the caption, whether it is paid, and the topic. Health and finance videos get stricter checks.",
    "S3": "ContextLens then runs a live check. Chirp 3 transcribes the speech, Gemini 2.5 Flash on Vertex AI reads the frames and on-screen text, and builds a timestamped ledger of every claim. Four checkers run in parallel. The median check takes about thirty-six seconds.",
    "S4": "Here is the report. Every flag has a timestamp, the exact rule it breaks, and a fix. This ad label is buried at the end of the caption. ASCI influencer guidelines say it must be upfront, so we cite clause 1.2 c and tell the creator where to move it.",
    "S5": "Health claims are checked against a clause index of the ASCI Code and the Drugs and Magic Remedies Act, so you can see whether a rule is statutory or self-regulatory. Facts are checked with Google's Fact Check Tools API first, then Gemini grounded in Google Search.",
    "S6": "Every flag passes an evidence gate. Its quote must be found in the cited rule or source, and Vertex AI Check Grounding scores the support. If the evidence is not there, ContextLens says uncertain instead of guessing.",
    "S7": "Borrowed clips are aligned with the original transcript. Here the creator cut the sentence that changed the meaning, and ContextLens shows exactly what was left out.",
    "S8": "Fix the video, upload it again, and the re-check shows what was resolved. Under the hood: a Flutter app on Android and web, Firebase Auth, App Check and Cloud Messaging, and a LangGraph pipeline on Cloud Run with Firestore and Cloud Storage.",
    "S9": "On our 34-case benchmark, disclosure, claims and borrowed-clip checks scored 1.00 precision and recall, with zero evidence-gate failures, at about five cents per check. Try it now at contextlens-tekken.web.app. Thank you.",
}

# How the voice should say things it would otherwise misread.
SPOKEN = {
    "ASCI": "A S C I",
    "clause 1.2 c": "clause one point two, c",
    "scored 1.00 precision": "scored one point oh oh precision",
    "contextlens-tekken.web.app": "contextlens dash tekken, dot web dot app",
    "Chirp 3": "Chirp three",
    "Gemini 2.5 Flash": "Gemini two point five Flash",
}


def spoken(text: str) -> str:
    for written, said in SPOKEN.items():
        text = text.replace(written, said)
    return text


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    session = google.auth.transport.requests.AuthorizedSession(credentials)
    session.headers["x-goog-user-project"] = PROJECT
    ffprobe = sys.argv[1] if len(sys.argv) > 1 else "ffprobe"
    lengths = {}
    for key, text in SCRIPT.items():
        out = OUT / f"{key}.mp3"
        response = session.post(
            "https://texttospeech.googleapis.com/v1/text:synthesize",
            json={
                "input": {"text": spoken(text)},
                "voice": {"languageCode": "en-IN", "name": VOICE},
                "audioConfig": {"audioEncoding": "MP3", "speakingRate": 1.0, "sampleRateHertz": 48000},
            },
            timeout=120,
        )
        response.raise_for_status()
        out.write_bytes(base64.b64decode(response.json()["audioContent"]))
        info = subprocess.run([ffprobe, "-hide_banner", "-i", str(out)], capture_output=True, text=True).stderr
        h, m, s = info.split("Duration: ")[1].split(",")[0].split(":")
        lengths[key] = round(int(h) * 3600 + int(m) * 60 + float(s), 2)
        print(key, lengths[key])
    (OUT / "lengths.json").write_text(json.dumps({"voice": VOICE, "script": SCRIPT, "seconds": lengths}, indent=2))
    print("total", round(sum(lengths.values()), 1))


if __name__ == "__main__":
    main()
