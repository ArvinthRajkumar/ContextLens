"""Abuse and cost caps: checks per user per day, checks running at once per
user, and checks per day across everyone. Counters live in Firestore under
usage/{day} and usage/{day}_{uid}, one document per day (UTC), and expire
with the jobs."""

from datetime import datetime, timedelta, timezone

from google.cloud import firestore

from .config import settings
from .errors import ApiError

# A job still "queued" or "processing" this long after its last update has
# died with its instance; it no longer counts as running.
_STALE = timedelta(minutes=15)

DAILY_LIMIT = ApiError(429, "daily_limit", "Daily limit reached, try again tomorrow.")
TOO_MANY_RUNNING = ApiError(
    429, "too_many_running", "You have 3 checks running. Wait for one to finish, then try again."
)
BUSY = ApiError(503, "busy", "ContextLens is busy, try later.")


def _day(now: datetime) -> str:
    return now.astimezone(timezone.utc).strftime("%Y-%m-%d")


def _refs(db: firestore.Client, uid: str, now: datetime):
    day = _day(now)
    usage = db.collection("usage")
    return usage.document(f"{day}_{uid}"), usage.document(day)


def _running(db: firestore.Client, uid: str, now: datetime) -> int:
    jobs = (
        db.collection("jobs")
        .where(filter=firestore.FieldFilter("ownerUid", "==", uid))
        .where(filter=firestore.FieldFilter("status", "in", ["queued", "processing"]))
        .stream()
    )
    fresh = 0
    for doc in jobs:
        updated = doc.get("updatedAt")
        if updated is None or now - updated < _STALE:
            fresh += 1
    return fresh


def verdict(mine: int, everyone: int, running: int) -> None:
    """Raises the cap a new check would break, given today's counts."""
    if mine >= settings.daily_checks_per_user:
        raise DAILY_LIMIT
    if everyone >= settings.daily_checks_total:
        raise BUSY
    if running >= settings.concurrent_checks_per_user:
        raise TOO_MANY_RUNNING


def check(db: firestore.Client, uid: str, now: datetime) -> None:
    """Raises the cap that a new check would break. Counts nothing: an upload
    that is never submitted costs no model calls."""
    mine, everyone = _refs(db, uid, now)
    verdict(
        (mine.get().to_dict() or {}).get("count", 0),
        (everyone.get().to_dict() or {}).get("count", 0),
        _running(db, uid, now),
    )


def claim(db: firestore.Client, uid: str, now: datetime) -> None:
    """Counts one submitted check against both daily caps, atomically, so two
    submits racing for the last slot can't both get it."""
    running = _running(db, uid, now)
    mine, everyone = _refs(db, uid, now)
    expires = now + timedelta(days=2)

    @firestore.transactional
    def take(transaction: firestore.Transaction) -> None:
        mine_count = (mine.get(transaction=transaction).to_dict() or {}).get("count", 0)
        all_count = (everyone.get(transaction=transaction).to_dict() or {}).get("count", 0)
        verdict(mine_count, all_count, running)
        transaction.set(mine, {"count": mine_count + 1, "uid": uid, "expiresAt": expires})
        transaction.set(everyone, {"count": all_count + 1, "expiresAt": expires})

    take(db.transaction())
