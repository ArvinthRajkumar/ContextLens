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
    max_upload_bytes: int = 500 * 1024 * 1024
    # 8 MiB: a multiple of 256 KiB, as GCS resumable uploads require.
    chunk_size: int = 8 * 1024 * 1024
    signed_url_minutes: int = 15
    job_ttl_hours: int = 24
    # Seconds the stub pipeline spends per stage.
    stub_stage_seconds: float = float(os.environ.get("STUB_STAGE_SECONDS", "5"))


settings = Settings()
