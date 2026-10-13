"""Cloud Storage: object naming and V4 signed URLs.

Cloud Run has no private key, so URLs are signed as the runtime service
account through IAM signBlob (it holds roles/iam.serviceAccountTokenCreator
on itself).
"""

from datetime import timedelta

import google.auth
from google.auth.transport import requests as google_requests
from google.cloud import storage

from .config import settings

_credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
_client = storage.Client(project=settings.project_id, credentials=_credentials)
_bucket = _client.bucket(settings.bucket)


def source_object(uid: str, job_id: str) -> str:
    return f"uploads/{uid}/{job_id}/source"


def _signing_kwargs() -> dict:
    if not _credentials.valid:
        _credentials.refresh(google_requests.Request())
    return {
        "service_account_email": settings.service_account,
        "access_token": _credentials.token,
    }


def resumable_start_url(object_name: str, content_type: str, size_bytes: int) -> str:
    """A URL the app POSTs to (with these exact headers) to open a resumable
    session. Binding the length and type stops the URL being reused for a
    different upload."""
    return _bucket.blob(object_name).generate_signed_url(
        version="v4",
        method="POST",
        expiration=timedelta(minutes=settings.signed_url_minutes),
        headers={
            "x-goog-resumable": "start",
            "content-type": content_type,
            "x-upload-content-length": str(size_bytes),
        },
        **_signing_kwargs(),
    )


def playback_url(object_name: str) -> str:
    return _bucket.blob(object_name).generate_signed_url(
        version="v4",
        method="GET",
        expiration=timedelta(minutes=settings.signed_url_minutes),
        **_signing_kwargs(),
    )


def object_size(object_name: str) -> int | None:
    blob = _bucket.get_blob(object_name)
    return None if blob is None else blob.size


def delete_prefix(prefix: str) -> None:
    for blob in _client.list_blobs(settings.bucket, prefix=prefix):
        blob.delete()


def gcs_uri(object_name: str) -> str:
    return f"gs://{settings.bucket}/{object_name}"


def download(object_name: str, path: str) -> None:
    _bucket.blob(object_name).download_to_filename(path)


def upload_file(path: str, object_name: str, content_type: str) -> None:
    _bucket.blob(object_name).upload_from_filename(path, content_type=content_type)


def upload_text(text: str, object_name: str, content_type: str = "application/json") -> None:
    _bucket.blob(object_name).upload_from_string(text, content_type=content_type)
