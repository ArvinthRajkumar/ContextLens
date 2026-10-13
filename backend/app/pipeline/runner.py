"""Drives a check through its stages and records progress in jobs/{jobId}."""

import logging
from datetime import datetime, timezone
from typing import Any

from google.cloud import firestore

from .base import CheckContext, Stage

log = logging.getLogger(__name__)


def _issues(flags: list[dict[str, Any]]) -> list[dict[str, Any]]:
    # Supported fact checks are checked claims, not issues.
    return [f for f in flags if f.get("factLabel") != "supported"]


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

    try:
        for stage in stages:
            update({"status": "processing", "stage": stage.name, "stageDetail": None})
            result = await stage.run(ctx)
            if result.detail:
                update({"stageDetail": result.detail})

        done: dict[str, Any] = {
            "status": "done",
            "stage": "report",
            "stageDetail": None,
            "flags": ctx.flags,
            "summary": summarize(ctx.flags),
            "pipeline": pipeline_name,
        }
        if ctx.parent is not None:
            done["comparison"] = compare(ctx.parent, ctx.parent["id"], ctx.flags)
        update(done)
    except Exception:
        log.exception("Check failed for job %s", ctx.job_id)
        update(
            {
                "status": "failed",
                "stageDetail": None,
                "error": {
                    "code": "pipeline_error",
                    "message": "Something went wrong while checking your video. Try again.",
                },
            }
        )
