"""Local media work with ffmpeg: the audio track for speech, and probing."""

import re
import subprocess

from ..config import settings

_DURATION = re.compile(r"Duration: (\d+):(\d+):(\d+(?:\.\d+)?)")
_AUDIO_STREAM = re.compile(r"Stream #\d+:\d+.*: Audio:")


class MediaError(Exception):
    """The video couldn't be read. Carries a code for the job's error."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def probe(path: str) -> tuple[int | None, bool]:
    """Duration in ms (if known) and whether there is an audio stream."""
    run = subprocess.run(
        [settings.ffmpeg, "-hide_banner", "-i", path],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    info = run.stderr
    match = _DURATION.search(info)
    duration = None
    if match:
        h, m, s = match.groups()
        duration = int((int(h) * 3600 + int(m) * 60 + float(s)) * 1000)
    return duration, bool(_AUDIO_STREAM.search(info))


def extract_audio(video: str, out: str) -> None:
    """Mono 16 kHz FLAC, which Chirp reads without any decoding config."""
    run = subprocess.run(
        [settings.ffmpeg, "-loglevel", "error", "-y", "-i", video, "-vn", "-ac", "1", "-ar", "16000", "-c:a", "flac", out],
        capture_output=True,
        check=False,
    )
    if run.returncode != 0:
        raise MediaError("audio_unreadable")
