"""Four S1 samples with Gemini-TTS (Cloud Text-to-Speech, en-IN) so a voice
can be picked by ear. Writes out/voice_samples/S1_<voice>.mp3.

    ../backend/.venv/Scripts/python.exe voice_samples.py [MODEL]
"""

import base64
import sys
from pathlib import Path

import google.auth
import google.auth.transport.requests

OUT = Path(__file__).parent / "out" / "voice_samples"
PROJECT = "contextlens-tekken"
MODEL = sys.argv[1] if len(sys.argv) > 1 else "gemini-2.5-pro-tts"
VOICES = ["Charon", "Puck", "Fenrir", "Kore"]
STYLE = (
    "You are an energetic, warm young Indian tech founder presenting your product demo to judges. "
    "Sound confident and genuinely excited, vary your pitch, smile while you talk, and pause naturally "
    "between ideas. Not robotic, not salesy."
)
S1 = (
    "Every day, creators in India post reels that quietly break advertising rules. A missing ad label, "
    "a cure claim, a podcast clip cut out of context. Between April and September 2025, ninety-eight "
    "percent of the influencer ads A S C I investigated needed changes. Most creators only find out after "
    "the video is live. We are team Tekken, and we built ContextLens to catch it before you post."
)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    session = google.auth.transport.requests.AuthorizedSession(credentials)
    session.headers["x-goog-user-project"] = PROJECT
    for voice in VOICES:
        response = session.post(
            "https://texttospeech.googleapis.com/v1/text:synthesize",
            json={
                "input": {"prompt": STYLE, "text": S1},
                "voice": {"languageCode": "en-IN", "name": voice, "modelName": MODEL},
                "audioConfig": {"audioEncoding": "MP3", "sampleRateHertz": 48000},
            },
            timeout=180,
        )
        if not response.ok:
            print(voice, response.status_code, response.text[:300])
            continue
        path = OUT / f"S1_{voice}.mp3"
        path.write_bytes(base64.b64decode(response.json()["audioContent"]))
        print(voice, path.name)


if __name__ == "__main__":
    main()
