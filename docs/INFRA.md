# ContextLens infrastructure

Everything lives in one Google Cloud / Firebase project. Created on 2026-10-13.

## Project
| Item | Value |
|---|---|
| Project ID | `contextlens-tekken` |
| Project number | `115890664288` |
| Billing account | `01FA9C-7BE321-D68E71` ("My Billing Account", INR), linked |
| Budget | "contextlens-tekken 1000 INR", id `bf3e279e-1730-4d31-b510-f3087d789813`, alerts at 50%, 90%, 100% |
| Budget alerts (2026-10-14) | "contextlens-tekken-alert-INR-500" (`5ed999d1-a2e7-44df-8deb-62a6b24d5319`) and "contextlens-tekken-alert-INR-750" (`c1d4f0ce-3f94-4b8d-a3cd-0085194e312f`), filtered to this project, one alert at 100% each, emailed to the billing account's admins (the owner). Budgets only warn: they do not cap or stop spending. |
| Owner account | arvinth2002ra@gmail.com |

## Enabled APIs
run, cloudbuild, artifactregistry, firestore, storage, iam, iamcredentials, aiplatform, speech, firebaseappcheck, playintegrity, factchecktools, discoveryengine, secretmanager, apikeys (2026-10-13), identitytoolkit, fcm, firebaserules, cloudresourcemanager, billingbudgets, firebase, firebasestorage, serviceusage (plus their defaults). Compute Engine is not enabled and not needed.

## Firebase
| Item | Value |
|---|---|
| Android app | `1:115890664288:android:1a18e65980c62d3ff16405` (package `app.contextlens.contextlens`) |
| iOS app | `1:115890664288:ios:6544c6bf7a8004f1f16405` (bundle `app.contextlens.contextlens`) |
| App config | `lib/firebase_options.dart` and `android/app/google-services.json` (flutterfire configure; iOS uses `firebase_options.dart` only). Client config is public by design. |
| Auth | Anonymous and Google sign-in, enabled in the Firebase console on 2026-10-13. No Identity Platform upgrade. |
| Android SHA fingerprints | Debug keystore (`~/.android/debug.keystore`): SHA-256 `D1:3D:90:2E:DC:1C:3D:59:3E:0F:31:1B:7B:DF:C2:09:95:5F:D3:1E:21:3F:C0:86:F4:EB:6B:F7:96:13:30:D4`, SHA-1 `1E:D4:16:8D:B6:AC:D0:31:29:15:32:3B:45:21:D4:AC:88:CC:00:02`. Add the release key's SHA-256 when there is one. |
| App Check | Android registered with Play Integrity (token TTL 1 h, device integrity `NO_INTEGRITY` for now). Debug builds use the debug provider with a registered debug token ("Dev emulator and smoke test (2026-10-13 rotation)"; the first one was deleted), kept outside the repo in `~/.contextlens/appcheck-debug-token` and passed with `--dart-define=APP_CHECK_DEBUG_TOKEN=...`. Revoke it in the console (App Check, Apps, Manage debug tokens) if it leaks. iOS not registered yet. |

## Firestore
| Item | Value |
|---|---|
| Database | `(default)`, Native mode, `nam5` |
| TTL | `jobs.expiresAt` (collection group `jobs`) |
| Rules | `firebase/firestore.rules`: the owner reads `jobs/{id}` when `ownerUid == request.auth.uid`; no client writes; everything else denied |
| Collections | `jobs/{jobId}` (backend writes), `devices/{uid}` (FCM tokens, backend only) |

## Cloud Storage
| Item | Value |
|---|---|
| Bucket | `contextlens-tekken.firebasestorage.app` (Firebase default bucket), `US` multi-region, uniform access |
| Lifecycle | delete objects after 1 day (`firebase/storage-lifecycle.json`) |
| CORS | `firebase/storage-cors.json` (resumable upload headers) |
| Rules | `firebase/storage.rules`: no client access; uploads and playback use V4 signed URLs |
| Object layout | `uploads/{uid}/{jobId}/source`, plus `audio.flac` (long videos), `transcript.json`, `visual.json`, `ledger.json` written by the real pipeline; all go when the job is deleted or after a day |
| Dev access | `user:arvinth2002ra@gmail.com` has `roles/storage.objectAdmin` on the bucket (2026-10-13) so `backend/tools/run_pipeline.py` can run locally with ADC; basic Owner has no object read under uniform access |

## Cloud Run
| Item | Value |
|---|---|
| Service | `contextlens-api`, `us-central1` |
| URL | https://contextlens-api-115890664288.us-central1.run.app |
| Runtime SA | `contextlens-api@contextlens-tekken.iam.gserviceaccount.com` (no keys) |
| Settings | CPU always allocated, min 0 (set explicitly 2026-10-14), max 3 instances, 1 vCPU, 2 GiB, concurrency 40, timeout 300 s, public ingress (auth is Firebase ID tokens) |
| Why CPU always allocated | The check runs as a background task after `submit` has already returned 202. With request-based CPU, Cloud Run throttles the CPU once the response is sent and the pipeline would stall, so it must stay on. |
| Expected cost | Idle: zero per day, because min instances is 0 and the service scales to zero with no traffic. Per check: Cloud Run instance time is about 1 vCPU and 2 GiB for the check (30 to 90 s) plus up to about 15 minutes kept warm afterwards, roughly USD 0.002 active and at most about USD 0.02 if the instance idles out alone (list price about USD 0.08 per hour at 1 vCPU and 2 GiB, before the monthly free tier, which covered all Cloud Run usage so far). Models and APIs add about USD 0.05 per check (benchmark/RESULTS.md). So about USD 0.05 to 0.07, or roughly INR 4 to 6, per check. |
| Env | `GOOGLE_CLOUD_PROJECT`, `BUCKET`, `SERVICE_ACCOUNT`, `ENFORCE_APP_CHECK=true` (since revision 00007, 2026-10-13), `STUB_STAGE_SECONDS=5`. Memory 2 GiB (videos are downloaded to the in-memory /tmp). `FACTCHECK_API_KEY` from Secret Manager `factcheck-api-key:latest`. Pipeline: `PIPELINE_MODE=real` (since revision 00008; `stub` walks fixtures), `GEMINI_MODEL=gemini-2.5-flash`, `GEMINI_LOCATION=us-central1`, `SPEECH_LOCATION=us`, `SPEECH_LANGUAGES=auto` (defaults in `backend/app/config.py`) |

Runtime SA roles: custom `projects/contextlens-tekken/roles/groundingChecker` (only `discoveryengine.groundingConfigs.check`, for Vertex Check Grounding), `roles/datastore.user`, `roles/aiplatform.user`, `roles/speech.client`, `roles/firebaseauth.viewer`, `roles/firebaseappcheck.tokenVerifier`, `roles/firebasecloudmessaging.admin`, `roles/logging.logWriter` (project); `roles/storage.objectAdmin` (bucket); `roles/iam.serviceAccountTokenCreator` on itself, so it can sign V4 URLs through IAM signBlob.

## Secrets and keys
| Item | Value |
|---|---|
| Fact Check Tools key | API key `factcheck-backend-2`, restricted to `factchecktools.googleapis.com` (the first key was deleted after it appeared in request logs; httpx URL logging is now off and the key travels in the `X-Goog-Api-Key` header) |
| Secret | `factcheck-api-key` (version 2 enabled, version 1 disabled); the runtime SA has `roles/secretmanager.secretAccessor` on it |

## Build
| Item | Value |
|---|---|
| Artifact Registry | `us-central1-docker.pkg.dev/contextlens-tekken/contextlens` (repo `contextlens`, Docker), image `api` |
| Build SA | `contextlens-build@contextlens-tekken.iam.gserviceaccount.com`: `roles/logging.logWriter`, `roles/artifactregistry.writer`, `roles/storage.objectViewer` |
| Build source bucket | `gs://contextlens-tekken_cloudbuild` (created by Cloud Build) |

## Deploy
```bash
gcloud builds submit backend --config backend/cloudbuild.yaml --region us-central1 --service-account projects/contextlens-tekken/serviceAccounts/contextlens-build@contextlens-tekken.iam.gserviceaccount.com
```
```bash
gcloud run deploy contextlens-api --image us-central1-docker.pkg.dev/contextlens-tekken/contextlens/api:latest --region us-central1
```
Smoke test (needs the Android API key from `lib/firebase_options.dart`; attests with the App Check debug token when `~/.contextlens/appcheck-debug-token` exists, and `--enforced` also checks that a request without App Check is refused):
```bash
backend/.venv/Scripts/python.exe backend/tests/smoke_api.py https://contextlens-api-115890664288.us-central1.run.app <API_KEY> [--enforced]
```

## Models
| Use | Model | Where |
|---|---|---|
| Speech | Chirp 3 (`chirp_3`), word timestamps, language `auto` | Speech-to-Text v2, `us` multi-region. Recognize inline up to 55 s, BatchRecognize through GCS beyond. |
| Video and ledger | `gemini-2.5-flash` | Vertex AI, `us-central1`. Probed 2026-10-13: it is the newest Flash on the regional endpoint; gemini-3.5 to 3.8 Flash answer only on the `global` endpoint. A/B one with `GEMINI_LOCATION=global GEMINI_MODEL=gemini-3.8-flash` (Cloud Run env, or the shell for `tools/run_pipeline.py`). |

Language note: `en-IN` and `hi-IN` together made Chirp 3 transliterate an English and Hinglish test video entirely into Devanagari. `auto` and `en-IN` alone both kept it in Latin script, with the Hindi line as spoken.

## Credentials on the dev machine
`gcloud auth application-default login` (scopes cloud-platform and firebase). The Firebase CLI and flutterfire use it through `GOOGLE_APPLICATION_CREDENTIALS=%APPDATA%\gcloud\application_default_credentials.json`; there is no separate `firebase login`.

## Smoke test, 2026-10-13
All 16 checks passed against revisions `contextlens-api-00002-7bz` and `contextlens-api-00005-fb6` (current): health, anonymous sign-up, unauthenticated upload refused (401), `POST /v1/uploads`, resumable session opened with the signed URL, file uploaded, submit (202), the job walked extract, claims, checking, evidence, report in Firestore, 5 stub flags written, another user cannot read the job (403), the owner cannot write it (403), video URL issued and serves the file, `POST /v1/devices` (204), `DELETE /v1/jobs/{id}` (204), deleted job gone (404).
