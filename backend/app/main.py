"""ContextLens API (Cloud Run). Contracts: docs/BUILD_PROMPT.md section 6."""

import logging
import re
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import firebase_admin
from fastapi import BackgroundTasks, Depends, FastAPI, Response
from fastapi.exceptions import RequestValidationError
from google.cloud import firestore
from pydantic import BaseModel, Field

from . import storage
from .auth import Caller, verify_caller
from .config import settings
from .errors import (
    ApiError,
    api_error_handler,
    unhandled_error_handler,
    validation_error_handler,
)
from .pipeline.base import CheckContext
from .pipeline.real import real_stages
from .pipeline.runner import run_check
from .pipeline.stub import stub_stages

logging.basicConfig(level=logging.INFO)
# httpx logs every URL at INFO, query strings included: never in our logs.
for noisy in ("httpx", "httpcore"):
    logging.getLogger(noisy).setLevel(logging.WARNING)

firebase_admin.initialize_app(options={"projectId": settings.project_id})
db = firestore.Client(project=settings.project_id)

app = FastAPI(title="ContextLens API", docs_url=None, redoc_url=None)
app.add_exception_handler(ApiError, api_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)
app.add_exception_handler(Exception, unhandled_error_handler)

ALLOWED_TYPES = {"video/mp4", "video/quicktime", "video/webm"}
_CONTROL_CHARS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def _clean(text: str) -> str:
    return _CONTROL_CHARS.sub("", text).strip()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _owned_job(job_id: str, caller: Caller) -> tuple[Any, dict]:
    ref = db.collection("jobs").document(job_id)
    snap = ref.get()
    # Someone else's job looks exactly like a missing one.
    if not snap.exists or snap.get("ownerUid") != caller.uid:
        raise ApiError(404, "not_found", "That check doesn't exist or has expired.")
    return ref, snap.to_dict()


# Not /healthz: Cloud Run reserves paths ending in "z".
@app.get("/health")
def health() -> dict:
    return {"ok": True}


class UploadRequest(BaseModel):
    fileName: str = Field(min_length=1, max_length=255)
    contentType: str
    sizeBytes: int = Field(gt=0)
    sha256: str | None = Field(default=None, pattern=r"^[0-9a-f]{64}$")


@app.post("/v1/uploads", status_code=201)
def create_upload(body: UploadRequest, caller: Caller = Depends(verify_caller)) -> dict:
    if body.contentType not in ALLOWED_TYPES:
        raise ApiError(400, "unsupported_type", "Use an MP4, MOV or WebM video.")
    if body.sizeBytes > settings.max_upload_bytes:
        raise ApiError(413, "too_large", "Videos can be up to 500 MB.")

    job_id = uuid.uuid4().hex
    object_name = storage.source_object(caller.uid, job_id)
    now = _now()
    db.collection("jobs").document(job_id).set(
        {
            "ownerUid": caller.uid,
            "status": "uploading",
            "createdAt": now,
            "updatedAt": now,
            "expiresAt": now + timedelta(hours=settings.job_ttl_hours),
            "version": 1,
            "objectName": object_name,
            "contentType": body.contentType,
            "sizeBytes": body.sizeBytes,
        }
    )
    return {
        "jobId": job_id,
        "uploadUrl": storage.resumable_start_url(object_name, body.contentType, body.sizeBytes),
        "uploadUrlExpiresAt": _iso(now + timedelta(minutes=settings.signed_url_minutes)),
        "maxBytes": settings.max_upload_bytes,
        "chunkSize": settings.chunk_size,
    }


CLIP_TYPES = {"video/mp4", "video/quicktime", "video/webm", "audio/mpeg", "audio/mp4", "audio/aac", "audio/wav", "audio/x-wav"}
MAX_CLIP_BYTES = 200 * 1024 * 1024


class ClipUploadRequest(BaseModel):
    index: int = Field(ge=0, lt=20)
    contentType: str
    sizeBytes: int = Field(gt=0)


@app.post("/v1/jobs/{job_id}/clips", status_code=201)
def create_clip_upload(job_id: str, body: ClipUploadRequest, caller: Caller = Depends(verify_caller)) -> dict:
    """A resumable upload URL for the original of a borrowed clip, so the
    pipeline can compare the creator's cut with it. Only before submit."""
    _, job = _owned_job(job_id, caller)
    if job.get("status") != "uploading":
        raise ApiError(409, "already_submitted", "This check has already started.")
    if body.contentType not in CLIP_TYPES:
        raise ApiError(400, "unsupported_type", "Attach the clip as a video or audio file.")
    if body.sizeBytes > MAX_CLIP_BYTES:
        raise ApiError(413, "too_large", "Clips can be up to 200 MB.")
    object_name = storage.clip_object(caller.uid, job_id, body.index)
    return {
        "uploadUrl": storage.resumable_start_url(object_name, body.contentType, body.sizeBytes),
        "uploadUrlExpiresAt": _iso(_now() + timedelta(minutes=settings.signed_url_minutes)),
    }


class VideoInfo(BaseModel):
    durationMs: int = Field(ge=0)
    width: int = Field(ge=0)
    height: int = Field(ge=0)


class Clip(BaseModel):
    label: str = Field(min_length=1, max_length=60)
    url: str | None = Field(default=None, pattern=r"^https://[^\s]+$", max_length=2048)
    fileName: str | None = Field(default=None, max_length=255)


class Declaration(BaseModel):
    caption: str = Field(min_length=1, max_length=2200)
    isPaid: bool = False
    brandName: str | None = Field(default=None, min_length=2, max_length=80)
    borrowedClips: list[Clip] = Field(default_factory=list, max_length=20)
    category: Literal["health", "finance", "general"] = "general"


class SubmitRequest(BaseModel):
    declaration: Declaration
    parentJobId: str | None = None
    video: VideoInfo | None = None


def _title(caption: str) -> str | None:
    line = next((l.strip() for l in caption.splitlines() if l.strip()), "")
    if not line:
        return None
    if len(line) <= 60:
        return line
    cut = line[:59]
    space = cut.rfind(" ")
    head = cut if line[59] == " " or space <= 30 else cut[:space]
    return head.rstrip() + "…"


@app.post("/v1/jobs/{job_id}/submit", status_code=202)
def submit(
    job_id: str,
    body: SubmitRequest,
    background: BackgroundTasks,
    caller: Caller = Depends(verify_caller),
) -> dict:
    ref, job = _owned_job(job_id, caller)
    if job.get("status") != "uploading":
        raise ApiError(409, "already_submitted", "This check has already started.")

    size = storage.object_size(job["objectName"])
    if size is None:
        raise ApiError(409, "upload_incomplete", "The upload hasn't finished yet.", retryable=True)
    if size != job.get("sizeBytes"):
        raise ApiError(409, "upload_mismatch", "The uploaded file doesn't match. Upload it again.")

    declaration = body.declaration
    if declaration.isPaid and not declaration.brandName:
        raise ApiError(400, "invalid_request", "Name the brand or partner.")
    clean = declaration.model_dump()
    clean["caption"] = _clean(clean["caption"])
    if clean.get("brandName"):
        clean["brandName"] = _clean(clean["brandName"])

    for index, clip in enumerate(clean.get("borrowedClips") or []):
        if clip.get("fileName"):
            if storage.object_size(storage.clip_object(caller.uid, job_id, index)) is None:
                raise ApiError(409, "clip_missing", "An attached clip didn't finish uploading. Try again.", retryable=True)
            clip["objectName"] = storage.clip_object(caller.uid, job_id, index)

    parent = None
    if body.parentJobId:
        _, parent = _owned_job(body.parentJobId, caller)
        parent["id"] = body.parentJobId

    fields: dict[str, Any] = {
        "status": "queued",
        "stage": "extract",
        "updatedAt": _now(),
        "title": _title(clean["caption"]),
        "declaration": clean,
        "version": (parent.get("version", 1) + 1) if parent else 1,
    }
    if parent:
        fields["parentJobId"] = body.parentJobId
    if body.video:
        fields["video"] = body.video.model_dump()
    ref.update(fields)

    ctx = CheckContext(
        job_id=job_id,
        uid=caller.uid,
        object_name=job["objectName"],
        declaration=clean,
        parent=parent,
        duration_ms=body.video.durationMs if body.video else None,
        content_type=job.get("contentType", "video/mp4"),
    )
    if settings.pipeline_mode == "real":
        background.add_task(run_check, db, ctx, real_stages(), pipeline_name=f"real:{settings.gemini_model}")
    else:
        background.add_task(run_check, db, ctx, stub_stages(), pipeline_name="stub")
    return {"jobId": job_id}


@app.get("/v1/jobs/{job_id}/video-url")
def video_url(job_id: str, caller: Caller = Depends(verify_caller)) -> dict:
    _, job = _owned_job(job_id, caller)
    if storage.object_size(job["objectName"]) is None:
        raise ApiError(404, "not_found", "This video has expired.")
    return {
        "url": storage.playback_url(job["objectName"]),
        "expiresAt": _iso(_now() + timedelta(minutes=settings.signed_url_minutes)),
    }


@app.delete("/v1/jobs/{job_id}", status_code=204)
def delete_job(job_id: str, caller: Caller = Depends(verify_caller)) -> Response:
    ref, _ = _owned_job(job_id, caller)
    storage.delete_prefix(f"uploads/{caller.uid}/{job_id}/")
    ref.delete()
    return Response(status_code=204)


class DeviceRequest(BaseModel):
    fcmToken: str = Field(min_length=10, max_length=4096)
    platform: Literal["android", "ios"]


@app.delete("/v1/devices", status_code=204)
def unregister_device(caller: Caller = Depends(verify_caller)) -> Response:
    db.collection("devices").document(caller.uid).delete()
    return Response(status_code=204)


@app.post("/v1/devices", status_code=204)
def register_device(body: DeviceRequest, caller: Caller = Depends(verify_caller)) -> Response:
    db.collection("devices").document(caller.uid).set(
        {"fcmToken": body.fcmToken, "platform": body.platform, "updatedAt": _now()}
    )
    return Response(status_code=204)
