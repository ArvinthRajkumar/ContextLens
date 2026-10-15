"""Try a sample: synthetic test videos in their own bucket, listed from
samples.json there, and copied server-side into a user's job so a check can
run without an upload."""

import json
import re
import time
from datetime import timedelta

from . import storage
from .config import settings
from .errors import ApiError

_ID = re.compile(r"^[a-z0-9_]{1,40}$")
_CACHE_SECONDS = 300
_cache: tuple[float, dict[str, dict]] | None = None

NOT_FOUND = ApiError(404, "sample_not_found", "That sample isn't available.")


def _bucket():
    return storage.client().bucket(settings.samples_bucket)


def manifest() -> dict[str, dict]:
    """Samples by id, from the bucket's samples.json (cached for 5 minutes)."""
    global _cache
    now = time.monotonic()
    if _cache and now - _cache[0] < _CACHE_SECONDS:
        return _cache[1]
    data = json.loads(_bucket().blob("samples.json").download_as_text())
    by_id = {s["id"]: s for s in data["samples"] if _ID.match(s.get("id", ""))}
    _cache = (now, by_id)
    return by_id


def find(sample_id: str) -> dict:
    """The manifest entry for `sample_id`; anything else is not found. The id
    never reaches a path unless it is listed."""
    if not _ID.match(sample_id):
        raise NOT_FOUND
    entry = manifest().get(sample_id)
    if entry is None:
        raise NOT_FOUND
    return entry


def _signed(object_name: str, download_name: str | None = None) -> str:
    return _bucket().blob(object_name).generate_signed_url(
        version="v4",
        method="GET",
        expiration=timedelta(minutes=settings.signed_url_minutes),
        response_disposition=f'attachment; filename="{download_name}"' if download_name else None,
        **storage.signing_kwargs(),
    )


def listing() -> list[dict]:
    """What the app shows: the manifest minus test expectations, plus
    short-lived signed URLs for the thumbnail, a preview and a download."""
    out = []
    for sample in manifest().values():
        video = f"{sample['id']}.mp4"
        item = {
            key: sample[key]
            for key in ("id", "title", "hint", "language", "durationMs", "sizeBytes", "width", "height", "declaration")
            if key in sample
        }
        item["thumbnailUrl"] = _signed(f"{sample['id']}.jpg")
        item["videoUrl"] = _signed(video)
        item["downloadUrl"] = _signed(video, video)
        clip = sample.get("clip")
        if clip:
            item["clip"] = {
                "id": clip["id"],
                "label": clip["label"],
                "downloadUrl": _signed(f"{clip['id']}.mp4", f"{clip['id']}.mp4"),
            }
        out.append(item)
    return out


def copy_into(sample: dict, uid: str, job_id: str) -> int:
    """Copies the sample (and its borrowed-clip source) into the job's paths
    in the uploads bucket, server side. Returns the video's size."""
    source = _bucket().blob(f"{sample['id']}.mp4")
    uploads = storage.uploads_bucket()
    copied = _bucket().copy_blob(source, uploads, storage.source_object(uid, job_id))
    clip = sample.get("clip")
    if clip:
        _bucket().copy_blob(_bucket().blob(f"{clip['id']}.mp4"), uploads, storage.clip_object(uid, job_id, 0))
    return copied.size
