"""End-to-end smoke test against the deployed API.

python backend/tests/smoke_api.py https://contextlens-api-....run.app ANDROID_API_KEY [--enforced]

Attests with App Check through a registered debug token (env
APP_CHECK_DEBUG_TOKEN, or the file ~/.contextlens/appcheck-debug-token).
With --enforced it also checks that a request without App Check is refused.

Signs up a throwaway anonymous user, opens an upload, sends a tiny MP4
through the GCS resumable protocol, submits, follows the stages in
Firestore as that user, fetches the playback URL, then deletes the job.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

PROJECT = "contextlens-tekken"
ANDROID_APP = "1:115890664288:android:1a18e65980c62d3ff16405"

# The smallest valid-looking MP4 header: the stub pipeline walks it to a
# report, the real one fails it as unreadable.
TINY_MP4 = bytes.fromhex("000000206674797069736f6d0000020069736f6d69736f32617663316d703431") + b"\0" * 2048


# Sent with requests that use the Android Firebase key, as the Android SDK
# does: the key is restricted to this package and the debug signing cert.
ANDROID_CLIENT = {
    "X-Android-Package": "app.contextlens.contextlens",
    "X-Android-Cert": "1ED4168DB6ACD0312915323B4521D4AC88CC0002",
}


def call(method, url, body=None, headers=None, raw=None):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if "key=" in url:
        # The Android key only answers the app's package and signing cert.
        for name, value in ANDROID_CLIENT.items():
            req.add_header(name, value)
    try:
        with urllib.request.urlopen(req) as res:
            text = res.read().decode() or "{}"
            return res.status, dict(res.headers), json.loads(text) if text.startswith("{") else text
    except urllib.error.HTTPError as err:
        text = err.read().decode()
        return err.code, dict(err.headers), json.loads(text) if text.startswith("{") else text


def step(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")
    if not ok:
        sys.exit(1)


def debug_token():
    token = os.environ.get("APP_CHECK_DEBUG_TOKEN")
    path = os.path.expanduser("~/.contextlens/appcheck-debug-token")
    if not token and os.path.exists(path):
        token = open(path, encoding="utf-8").read().strip()
    return token


def main(api, key, enforced):
    status, _, body = call("GET", f"{api}/health")
    step("health", status == 200 and body.get("ok"), f"[{status}]")

    status, _, body = call(
        "POST",
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={key}",
        {"returnSecureToken": True},
    )
    step("anonymous sign-up", status == 200, f"[{status}]")
    token, uid = body["idToken"], body["localId"]
    auth = {"Authorization": f"Bearer {token}"}

    secret = debug_token()
    if secret:
        status, _, body = call(
            "POST",
            f"https://firebaseappcheck.googleapis.com/v1/projects/{PROJECT}/apps/{ANDROID_APP}:exchangeDebugToken?key={key}",
            {"debugToken": secret},
        )
        step("App Check debug token exchanged", status == 200 and "token" in body, f"[{status}]")
        bare = dict(auth)
        auth["X-Firebase-AppCheck"] = body["token"]
        if enforced:
            status, _, body = call("POST", f"{api}/v1/uploads", {"fileName": "a.mp4", "contentType": "video/mp4", "sizeBytes": 10}, bare)
            step("uploads without App Check is refused", status == 401 and body["error"]["code"] == "app_check_failed", f"[{status}]")
    else:
        step("App Check debug token available", not enforced, "(none found, sending without App Check)")

    status, _, body = call("POST", f"{api}/v1/uploads", {"fileName": "a.mp4", "contentType": "video/mp4", "sizeBytes": 10}, {})
    step("uploads without a token is refused", status == 401 and body["error"]["code"] == "unauthenticated", f"[{status}]")

    size = len(TINY_MP4)
    status, _, up = call("POST", f"{api}/v1/uploads", {"fileName": "smoke.mp4", "contentType": "video/mp4", "sizeBytes": size}, auth)
    step("POST /v1/uploads", status == 201 and up["chunkSize"] % 262144 == 0, f"[{status}] job {up.get('jobId')}")
    job = up["jobId"]

    status, headers, _ = call(
        "POST",
        up["uploadUrl"],
        raw=b"",
        headers={"x-goog-resumable": "start", "Content-Type": "video/mp4", "X-Upload-Content-Length": str(size)},
    )
    session = headers.get("Location") or headers.get("location")
    step("open resumable session with the signed URL", status in (200, 201) and bool(session), f"[{status}]")

    status, _, _ = call("PUT", session, raw=TINY_MP4, headers={"Content-Range": f"bytes 0-{size - 1}/{size}"})
    step("upload the file", status in (200, 201), f"[{status}]")

    status, _, body = call(
        "POST",
        f"{api}/v1/jobs/{job}/submit",
        {"declaration": {"caption": "Smoke test, please ignore", "category": "general"}, "video": {"durationMs": 7000, "width": 1280, "height": 720}},
        auth,
    )
    step("POST /v1/jobs/{id}/submit", status == 202 and body.get("jobId") == job, f"[{status}]")

    doc_url = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/jobs/{job}"
    seen = []
    deadline = time.time() + 90
    state = None
    while time.time() < deadline:
        status, _, doc = call("GET", doc_url, headers=auth)
        fields = doc.get("fields", {}) if status == 200 else {}
        state = fields.get("status", {}).get("stringValue")
        stage = fields.get("stage", {}).get("stringValue")
        if stage and (not seen or seen[-1] != stage):
            seen.append(stage)
        if state in ("done", "failed"):
            break
        time.sleep(1.5)
    error = fields.get("error", {}).get("mapValue", {}).get("fields", {}).get("code", {}).get("stringValue")
    if state == "failed":
        # PIPELINE_MODE=real decodes the video, and this one is only a header.
        step("real pipeline rejects the fake video cleanly", error == "video_unreadable", f"stages {seen}, error {error}")
    else:
        step("owner reads the job and it walks the stages", state == "done", f"stages {seen}")
        flags = doc["fields"]["flags"]["arrayValue"]["values"]
        step("stub flags written", len(flags) == 5, f"{len(flags)} flags, pipeline={doc['fields']['pipeline']['stringValue']}")

    other = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={key}", {"returnSecureToken": True})[2]["idToken"]
    status, _, _ = call("GET", doc_url, headers={"Authorization": f"Bearer {other}"})
    step("another user cannot read it", status == 403, f"[{status}]")
    status, _, _ = call("PATCH", doc_url + "?updateMask.fieldPaths=status", {"fields": {"status": {"stringValue": "done"}}}, auth)
    step("the owner cannot write it", status == 403, f"[{status}]")

    status, _, body = call("GET", f"{api}/v1/jobs/{job}/video-url", headers=auth)
    step("GET /v1/jobs/{id}/video-url", status == 200 and body["url"].startswith("https://"), f"[{status}]")
    status, _, _ = call("GET", body["url"])
    step("playback URL serves the video", status == 200, f"[{status}]")

    status, _, _ = call("POST", f"{api}/v1/devices", {"fcmToken": "smoke-test-token-not-real", "platform": "android"}, auth)
    step("POST /v1/devices", status == 204, f"[{status}]")

    status, _, _ = call("DELETE", f"{api}/v1/jobs/{job}", headers=auth)
    step("DELETE /v1/jobs/{id}", status == 204, f"[{status}]")
    status, _, _ = call("GET", f"{api}/v1/jobs/{job}/video-url", headers=auth)
    step("deleted job is gone", status == 404, f"[{status}]")
    print(f"\nAll checks passed (uid {uid[:6]}...).")


if __name__ == "__main__":
    main(sys.argv[1].rstrip("/"), sys.argv[2], "--enforced" in sys.argv[3:])
