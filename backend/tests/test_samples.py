import time

import pytest

from app import limits, samples, storage
from app.errors import ApiError

MANIFEST = {
    "glucoleaf": {
        "id": "glucoleaf",
        "title": "Gifted supplement",
        "hint": "Cure claims",
        "language": "English",
        "durationMs": 34720,
        "sizeBytes": 1192624,
        "width": 720,
        "height": 1280,
        "declaration": {"caption": "x #ad", "isPaid": True, "brandName": "GlucoLeaf", "category": "health"},
        "expect": ["disclosure"],
        "allow": [],
    },
    "vitamind": {
        "id": "vitamind",
        "title": "Clip",
        "hint": "Qualifier missing",
        "declaration": {"caption": "y", "isPaid": False, "category": "health"},
        "clip": {"id": "vitamind_source", "label": "Interview"},
        "expect": ["borrowed"],
    },
}


class _Blob:
    def __init__(self, name: str, bucket: "_Bucket") -> None:
        self.name, self.bucket, self.size = name, bucket, 1234

    def generate_signed_url(self, **kwargs) -> str:
        disposition = kwargs.get("response_disposition")
        return f"https://signed/{self.bucket.name}/{self.name}" + (f"?{disposition}" if disposition else "")


class _Bucket:
    def __init__(self, name: str) -> None:
        self.name, self.copies = name, []

    def blob(self, name: str) -> _Blob:
        return _Blob(name, self)

    def copy_blob(self, blob: _Blob, destination: "_Bucket", new_name: str) -> _Blob:
        self.copies.append((blob.name, destination.name, new_name))
        return _Blob(new_name, destination)


@pytest.fixture
def buckets(monkeypatch):
    sample_bucket, uploads = _Bucket("samples"), _Bucket("uploads")
    monkeypatch.setattr(samples, "_cache", (time.monotonic(), MANIFEST))
    monkeypatch.setattr(samples, "_bucket", lambda: sample_bucket)
    monkeypatch.setattr(storage, "uploads_bucket", lambda: uploads)
    monkeypatch.setattr(storage, "signing_kwargs", lambda: {})
    return sample_bucket, uploads


@pytest.mark.parametrize("bad", ["", "../glucoleaf", "GlucoLeaf", "glucoleaf.mp4", "nope", "a" * 41, "gluco leaf"])
def test_only_listed_ids_are_found(buckets, bad):
    with pytest.raises(ApiError) as caught:
        samples.find(bad)
    assert caught.value.code == "sample_not_found"
    assert caught.value.status == 404


def test_find_returns_the_entry(buckets):
    assert samples.find("glucoleaf")["title"] == "Gifted supplement"


def test_listing_hides_expectations_and_signs_urls(buckets):
    items = {s["id"]: s for s in samples.listing()}
    gluco = items["glucoleaf"]
    assert "expect" not in gluco and "allow" not in gluco
    assert gluco["thumbnailUrl"] == "https://signed/samples/glucoleaf.jpg"
    assert gluco["videoUrl"] == "https://signed/samples/glucoleaf.mp4"
    assert "attachment" in gluco["downloadUrl"]
    assert gluco["declaration"]["brandName"] == "GlucoLeaf"
    assert items["vitamind"]["clip"]["label"] == "Interview"
    assert "vitamind_source.mp4" in items["vitamind"]["clip"]["downloadUrl"]


def test_copy_puts_the_video_where_an_upload_would_go(buckets):
    sample_bucket, _ = buckets
    size = samples.copy_into(MANIFEST["glucoleaf"], "user1", "job1")
    assert size == 1234
    assert sample_bucket.copies == [("glucoleaf.mp4", "uploads", "uploads/user1/job1/source")]


def test_copy_attaches_the_borrowed_clip_source(buckets):
    sample_bucket, _ = buckets
    samples.copy_into(MANIFEST["vitamind"], "user1", "job2")
    assert sample_bucket.copies == [
        ("vitamind.mp4", "uploads", "uploads/user1/job2/source"),
        ("vitamind_source.mp4", "uploads", "uploads/user1/job2/clips/0"),
    ]


@pytest.mark.parametrize(
    ("header", "peer", "ip"),
    [
        ("203.0.113.9", "10.0.0.1", "203.0.113.9"),
        # A client can prepend anything; the front end's own entry is last.
        ("1.2.3.4, 203.0.113.9", "10.0.0.1", "203.0.113.9"),
        (None, "10.0.0.1", "10.0.0.1"),
        ("", None, "unknown"),
    ],
)
def test_client_ip(header, peer, ip):
    assert limits.client_ip(header, peer) == ip
