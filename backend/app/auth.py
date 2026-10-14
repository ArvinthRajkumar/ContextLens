"""Firebase ID token and App Check verification."""

import logging
from dataclasses import dataclass

from fastapi import Header
from firebase_admin import app_check, auth

from .config import settings
from .errors import ApiError

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class Caller:
    uid: str


def verify_caller(
    authorization: str | None = Header(default=None),
    x_firebase_appcheck: str | None = Header(default=None),
) -> Caller:
    """FastAPI dependency: the signed-in Firebase user making the request."""
    if not authorization or not authorization.startswith("Bearer "):
        log.warning("auth_rejected reason=id_token_missing")
        raise ApiError(401, "unauthenticated", "Sign in again to continue.")
    try:
        decoded = auth.verify_id_token(authorization.removeprefix("Bearer ").strip())
    except Exception as error:
        log.warning("auth_rejected reason=id_token_invalid error=%s", type(error).__name__)
        raise ApiError(401, "unauthenticated", "Sign in again to continue.") from None

    _check_app(x_firebase_appcheck)
    return Caller(uid=decoded["uid"])


def _check_app(token: str | None) -> None:
    if not token:
        if settings.enforce_app_check:
            log.warning("auth_rejected reason=app_check_missing")
            raise ApiError(401, "app_check_failed", "This app couldn't be verified.")
        log.warning("App Check token missing (not enforced)")
        return
    try:
        app_check.verify_token(token)
    except Exception as error:
        if settings.enforce_app_check:
            log.warning("auth_rejected reason=app_check_invalid error=%s", type(error).__name__)
            raise ApiError(401, "app_check_failed", "This app couldn't be verified.") from None
        # Not enforced yet: note it and let the request through.
        log.warning("App Check token did not verify (not enforced)")
