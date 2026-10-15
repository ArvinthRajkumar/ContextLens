"""Settings from the environment (Cloud Run service config)."""

import os
from dataclasses import dataclass


def _flag(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).strip().lower() in {"1", "true", "yes"}


@dataclass(frozen=True)
class Settings:
    project_id: str = os.environ.get("GOOGLE_CLOUD_PROJECT", "contextlens-tekken")
    bucket: str = os.environ.get("BUCKET", "contextlens-tekken.firebasestorage.app")
    # The runtime service account; V4 URLs are signed as it through IAM signBlob.
    service_account: str = os.environ.get(
        "SERVICE_ACCOUNT", "contextlens-api@contextlens-tekken.iam.gserviceaccount.com"
    )
    # Off until the app registers Play Integrity / App Attest.
    enforce_app_check: bool = _flag("ENFORCE_APP_CHECK")
    # Browser origins allowed to call the API: the web build on Firebase Hosting.
    cors_origins: tuple[str, ...] = tuple(
        o.strip()
        for o in os.environ.get(
            "CORS_ORIGINS",
            "https://contextlens-tekken.web.app,https://contextlens-tekken.firebaseapp.com",
        ).split(",")
        if o.strip()
    )
    max_upload_bytes: int = 200 * 1024 * 1024
    max_video_ms: int = 3 * 60 * 1000
    # Caps for the judging period: per user per day, per user at once, and
    # across everyone per day (UTC days).
    daily_checks_per_user: int = int(os.environ.get("DAILY_CHECKS_PER_USER", "10"))
    concurrent_checks_per_user: int = int(os.environ.get("CONCURRENT_CHECKS_PER_USER", "3"))
    daily_checks_total: int = int(os.environ.get("DAILY_CHECKS_TOTAL", "150"))
    # 8 MiB: a multiple of 256 KiB, as GCS resumable uploads require.
    chunk_size: int = 8 * 1024 * 1024
    signed_url_minutes: int = 15
    job_ttl_hours: int = 24
    # Seconds the stub pipeline spends per stage.
    stub_stage_seconds: float = float(os.environ.get("STUB_STAGE_SECONDS", "5"))

    # "stub" walks fixture flags; "real" runs the stages that exist so far
    # and stubs the rest.
    pipeline_mode: str = os.environ.get("PIPELINE_MODE", "stub")
    # Pinned: the newest Flash served from our region's endpoint. Newer
    # Flash models are only on the global endpoint (GEMINI_LOCATION=global).
    gemini_model: str = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    gemini_location: str = os.environ.get("GEMINI_LOCATION", "us-central1")
    # Last-round fallback when the regional endpoint keeps answering 429 or
    # 504 (shared capacity); empty turns it off.
    gemini_fallback_location: str = os.environ.get("GEMINI_FALLBACK_LOCATION", "global")
    # Chirp 3 runs in the "us" multi-region.
    speech_location: str = os.environ.get("SPEECH_LOCATION", "us")
    # "auto" keeps Hinglish in Latin script and Hindi in Devanagari; listing
    # en-IN and hi-IN together transliterates everything to Devanagari.
    speech_languages: tuple[str, ...] = tuple(
        os.environ.get("SPEECH_LANGUAGES", "auto").split(",")
    )
    ffmpeg: str = os.environ.get("FFMPEG", "ffmpeg")
    # Vertex Check Grounding support below this makes an interpreted flag
    # uncertain.
    grounding_min_support: float = float(os.environ.get("GROUNDING_MIN_SUPPORT", "0.4"))
    # Claims flags rest on premises we wrote from the sources, so they
    # should ground well; below this they are dropped.
    claims_min_support: float = float(os.environ.get("CLAIMS_MIN_SUPPORT", "0.6"))


settings = Settings()
