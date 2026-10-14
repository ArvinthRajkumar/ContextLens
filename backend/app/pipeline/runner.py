"""Drives a check through its stages and records progress in jobs/{jobId}."""

import json
import logging
import time
import traceback
from datetime import datetime, timezone
from typing import Any

from firebase_admin import messaging
from google.cloud import firestore

from .base import CheckContext, Stage
from .media import MediaError

log = logging.getLogger(__name__)


def _issues(flags: list[dict[str, Any]]) -> list[dict[str, Any]]:
    # Supported fact checks are checked claims, not issues, and flags the
    # evidence gate downgraded to uncertain need a human look, not a fix.
    return [
        f for f in flags if f.get("factLabel") != "supported" and not f.get("uncertain")
    ]


def summarize(flags: list[dict[str, Any]]) -> dict[str, Any]:
    by_category: dict[str, int] = {}
    for flag in _issues(flags):
        by_category[flag["category"]] = by_category.get(flag["category"], 0) + 1
    return {"total": sum(by_category.values()), "byCategory": by_category}


def compare(parent: dict[str, Any], parent_id: str, flags: list[dict[str, Any]]) -> dict:
    before = {f["fingerprint"] for f in _issues(parent.get("flags", []))}
    after = {f["fingerprint"] for f in _issues(flags)}
    return {
        "previousJobId": parent_id,
        "resolved": len(before - after),
        "remaining": len(before & after),
        "newCount": len(after - before),
    }


async def run_check(
    db: firestore.Client,
    ctx: CheckContext,
    stages: list[Stage],
    *,
    pipeline_name: str,
) -> None:
    ref = db.collection("jobs").document(ctx.job_id)

    def update(fields: dict[str, Any]) -> None:
        ref.update({**fields, "updatedAt": datetime.now(timezone.utc)})

    ctx.progress = lambda detail: update({"stageDetail": detail})
    try:
        for stage in stages:
            update({"status": "processing", "stage": stage.name, "stageDetail": None})
            started = time.monotonic()
            await stage.run(ctx)
            log_stage(ctx, stage.name, started)

        done: dict[str, Any] = {
            "status": "done",
            "stage": "report",
            "stageDetail": None,
            "flags": ctx.flags,
            "summary": summarize(ctx.flags),
            "pipeline": pipeline_name,
        }
        if ctx.data.get("skipped"):
            # Checkers that couldn't run; the app says the report is partial.
            done["skipped"] = sorted(set(ctx.data["skipped"]))
        if ctx.parent is not None:
            done["comparison"] = compare(ctx.parent, ctx.parent["id"], ctx.flags)
        update(done)
    except Exception as error:
        # Type and stack only: messages can quote the transcript or a URL.
        log.error(
            "Check failed for job %s: %s %s",
            ctx.job_id,
            type(error).__name__,
            "".join(traceback.format_tb(error.__traceback__)),
        )
        code = error.code if isinstance(error, MediaError) else "pipeline_error"
        update({"status": "failed", "stageDetail": None, "error": {"code": code, "message": _FAILURE_COPY[code]}})
        return
    try:
        notify_ready(db, ctx.uid, ctx.job_id, ref.get().get("title"))
    except Exception:
        log.warning("Could not send the report notification for %s", ctx.job_id)


_FAILURE_COPY = {
    "pipeline_error": "Something went wrong while checking your video. Try again.",
    "audio_unreadable": "We couldn't read the audio track. Export the video again as MP4 and try once more.",
    "video_unreadable": "We couldn't read this video. Export it again as MP4 and try once more.",
}


def log_stage(ctx: CheckContext, stage: str, started: float) -> None:
    """One structured line per stage: latency and model tokens. Never the
    caption, transcript or URLs."""
    tokens = ctx.tokens.get(stage, {"input": 0, "output": 0})
    log.info(
        json.dumps(
            {
                "event": "stage_done",
                "jobId": ctx.job_id,
                "stage": stage,
                "ms": int((time.monotonic() - started) * 1000),
                "inputTokens": tokens["input"],
                "outputTokens": tokens["output"],
                **(ctx.data.get("timings", {}) if stage == "extract" else {}),
            }
        )
    )


def notify_ready(db: firestore.Client, uid: str, job_id: str, title: str | None) -> None:
    """Best effort: a report is fine without its notification."""
    device = db.collection("devices").document(uid).get()
    if not device.exists:
        return
    try:
        messaging.send(
            messaging.Message(
                token=device.get("fcmToken"),
                notification=messaging.Notification(
                    title="Your report is ready",
                    body=title or "Tap to see what we found.",
                ),
                data={"type": "report_ready", "jobId": job_id},
                android=messaging.AndroidConfig(priority="high"),
            )
        )
    except Exception as error:
        # An expired or unregistered token: drop it so we stop trying.
        log.warning("Push failed: %s", type(error).__name__)
        if isinstance(error, messaging.UnregisteredError):
            db.collection("devices").document(uid).delete()
