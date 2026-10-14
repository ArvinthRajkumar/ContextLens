"""A headless ContextLens client: the same API calls the app makes.

Signs up an anonymous user, attests with the App Check debug token,
uploads through the GCS resumable protocol, submits a declaration, polls
the job in Firestore and reads per-stage timings from Cloud Run logs.
Standard library only, so it runs from any Python 3.11+.
"""

import json
import os
import re
import subprocess
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

PROJECT = "contextlens-tekken"
ANDROID_APP = "1:115890664288:android:1a18e65980c62d3ff16405"
API = "https://contextlens-api-115890664288.us-central1.run.app"
GCLOUD = os.environ.get("GCLOUD", r"C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd")
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")


# Sent with requests that use the Android Firebase key, as the Android SDK
# does: the key is restricted to this package and the debug signing cert.
ANDROID_CLIENT = {
    "X-Android-Package": "app.contextlens.contextlens",
    "X-Android-Cert": "1ED4168DB6ACD0312915323B4521D4AC88CC0002",
}


def call(method: str, url: str, body=None, headers=None, raw: bytes | None = None, timeout: int = 60):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    request = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if body is not None:
        request.add_header("Content-Type", "application/json")
    if "key=" in url:
        # The Android key only answers the app's package and signing cert.
        for name, value in ANDROID_CLIENT.items():
            request.add_header(name, value)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            text = response.read().decode() or "{}"
            return response.status, dict(response.headers), json.loads(text) if text.startswith("{") else text
    except urllib.error.HTTPError as error:
        text = error.read().decode()
        return error.code, dict(error.headers), json.loads(text) if text.startswith("{") else text


def firestore_value(value: dict):
    """Firestore REST typed values to plain JSON."""
    if "mapValue" in value:
        return {k: firestore_value(v) for k, v in value["mapValue"].get("fields", {}).items()}
    if "arrayValue" in value:
        return [firestore_value(v) for v in value["arrayValue"].get("values", [])]
    for key in ("stringValue", "booleanValue", "timestampValue"):
        if key in value:
            return value[key]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return float(value["doubleValue"])
    return None


def probe(path: str) -> tuple[int, int, int]:
    """Duration in ms, width and height, read with ffmpeg."""
    info = subprocess.run([FFMPEG, "-hide_banner", "-i", path], capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stderr
    h, m, s = re.search(r"Duration: (\d+):(\d+):(\d+(?:\.\d+)?)", info).groups()
    w, hgt = re.search(r"Video:.*?(\d{2,5})x(\d{2,5})", info).groups()
    return int((int(h) * 3600 + int(m) * 60 + float(s)) * 1000), int(w), int(hgt)


@dataclass
class Result:
    job_id: str
    status: str
    flags: list = field(default_factory=list)
    error: dict | None = None
    total_ms: int = 0
    stages: dict = field(default_factory=dict)
    tokens: dict = field(default_factory=dict)
    gate: list = field(default_factory=list)
    calls: list = field(default_factory=list)
    pipeline: str = ""
    skipped: list = field(default_factory=list)


class Client:
    def __init__(self, api_key: str, api: str = API):
        self.api = api
        status, _, body = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key}",
                               {"returnSecureToken": True})
        if status != 200:
            raise RuntimeError(f"sign-up failed [{status}]")
        self.uid = body["localId"]
        self.headers = {"Authorization": f"Bearer {body['idToken']}"}
        token = os.environ.get("APP_CHECK_DEBUG_TOKEN") or open(
            os.path.expanduser("~/.contextlens/appcheck-debug-token"), encoding="utf-8").read().strip()
        status, _, body = call(
            "POST",
            f"https://firebaseappcheck.googleapis.com/v1/projects/{PROJECT}/apps/{ANDROID_APP}:exchangeDebugToken?key={api_key}",
            {"debugToken": token},
        )
        if status != 200:
            raise RuntimeError(f"App Check exchange failed [{status}]")
        self.headers["X-Firebase-AppCheck"] = body["token"]

    def upload(self, path: str, content_type: str = "video/mp4") -> str:
        data = open(path, "rb").read()
        status, _, up = call("POST", f"{self.api}/v1/uploads",
                             {"fileName": os.path.basename(path), "contentType": content_type, "sizeBytes": len(data)},
                             self.headers)
        if status != 201:
            raise RuntimeError(f"upload create failed [{status}] {up}")
        status, headers, _ = call("POST", up["uploadUrl"], raw=b"", headers={
            "x-goog-resumable": "start", "Content-Type": content_type, "X-Upload-Content-Length": str(len(data))})
        session = headers.get("Location") or headers.get("location")
        status, _, _ = call("PUT", session, raw=data, headers={"Content-Range": f"bytes 0-{len(data) - 1}/{len(data)}"},
                            timeout=300)
        if status not in (200, 201):
            raise RuntimeError(f"upload failed [{status}]")
        return up["jobId"]

    def upload_clip(self, job: str, index: int, path: str) -> None:
        """The original of borrowed clip `index`, attached as a file."""
        data = open(path, "rb").read()
        status, _, body = call("POST", f"{self.api}/v1/jobs/{job}/clips",
                               {"index": index, "contentType": "video/mp4", "sizeBytes": len(data)}, self.headers)
        if status != 201:
            raise RuntimeError(f"clip upload create failed [{status}] {body}")
        _, headers, _ = call("POST", body["uploadUrl"], raw=b"", headers={
            "x-goog-resumable": "start", "Content-Type": "video/mp4", "X-Upload-Content-Length": str(len(data))})
        session = headers.get("Location") or headers.get("location")
        status, _, _ = call("PUT", session, raw=data, headers={"Content-Range": f"bytes 0-{len(data) - 1}/{len(data)}"},
                            timeout=300)
        if status not in (200, 201):
            raise RuntimeError(f"clip upload failed [{status}]")

    def check(self, path: str, declaration: dict, timeout_s: int = 360, clip_files: dict[int, str] | None = None) -> Result:
        duration, width, height = probe(path)
        job = self.upload(path)
        for index, clip_path in (clip_files or {}).items():
            self.upload_clip(job, index, clip_path)
        status, _, body = call("POST", f"{self.api}/v1/jobs/{job}/submit",
                               {"declaration": declaration, "video": {"durationMs": duration, "width": width, "height": height}},
                               self.headers)
        if status != 202:
            raise RuntimeError(f"submit failed [{status}] {body}")
        started = time.monotonic()
        doc_url = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/jobs/{job}"
        while time.monotonic() - started < timeout_s:
            status, _, doc = call("GET", doc_url, headers=self.headers)
            fields = {k: firestore_value(v) for k, v in doc.get("fields", {}).items()} if status == 200 else {}
            if fields.get("status") in ("done", "failed"):
                return Result(job, fields["status"], fields.get("flags") or [], fields.get("error"),
                              int((time.monotonic() - started) * 1000), pipeline=fields.get("pipeline") or "",
                              skipped=fields.get("skipped") or [])
            time.sleep(1.0)
        return Result(job, "timeout", total_ms=int((time.monotonic() - started) * 1000))

    def delete(self, job: str) -> None:
        call("DELETE", f"{self.api}/v1/jobs/{job}", headers=self.headers)


def stage_logs(results: list[Result], minutes: int = 60) -> None:
    """Fills per-stage ms, tokens and gate notes from Cloud Run's structured
    log lines (needs gcloud credentials)."""
    if not results:
        return
    token = subprocess.run([GCLOUD, "auth", "print-access-token"], capture_output=True, text=True).stdout.strip()
    since = (datetime.now(timezone.utc) - timedelta(minutes=minutes)).strftime("%Y-%m-%dT%H:%M:%SZ")
    by_job = {r.job_id: r for r in results}
    ids = " OR ".join(f'textPayload:"{j}"' for j in by_job)
    page = None
    while True:
        body = {
            "resourceNames": [f"projects/{PROJECT}"],
            "filter": f'resource.type="cloud_run_revision" AND timestamp>="{since}" AND ({ids})',
            "pageSize": 1000,
        }
        if page:
            body["pageToken"] = page
        status, _, data = call("POST", "https://logging.googleapis.com/v2/entries:list", body,
                               {"Authorization": f"Bearer {token}", "x-goog-user-project": PROJECT})
        for entry in data.get("entries", []) if status == 200 else []:
            text = entry.get("textPayload") or ""
            start = text.find("{")
            if start < 0:
                continue
            try:
                event = json.loads(text[start:])
            except ValueError:
                continue
            result = by_job.get(event.get("jobId"))
            if not result:
                continue
            if event.get("event") == "stage_done":
                result.stages[event["stage"]] = {k: v for k, v in event.items() if k not in {"event", "jobId", "stage"}}
            elif event.get("event") == "gate":
                result.gate.append(event)
            elif event.get("event") == "model_call":
                result.calls.append(event)
        page = data.get("nextPageToken") if status == 200 else None
        if not page:
            break
