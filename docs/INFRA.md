# ContextLens infrastructure

Everything lives in one Google Cloud / Firebase project. Created on 2026-10-13.

## Project
| Item | Value |
|---|---|
| Project ID | `contextlens-tekken` |
| Project number | `115890664288` |
| Billing account | `01FA9C-7BE321-D68E71` ("My Billing Account", INR), linked |
| Budget | "contextlens-tekken 1000 INR", id `bf3e279e-1730-4d31-b510-f3087d789813`, alerts at 50%, 90%, 100% |
| Owner account | arvinth2002ra@gmail.com |

## Enabled APIs
run, cloudbuild, artifactregistry, firestore, storage, iam, iamcredentials, aiplatform, speech, firebaseappcheck, identitytoolkit, fcm, firebaserules, cloudresourcemanager, billingbudgets, firebase, firebasestorage, serviceusage (plus their defaults). Compute Engine is not enabled and not needed.

## Firebase
| Item | Value |
|---|---|
| Android app | `1:115890664288:android:1a18e65980c62d3ff16405` (package `app.contextlens.contextlens`) |
| iOS app | `1:115890664288:ios:6544c6bf7a8004f1f16405` (bundle `app.contextlens.contextlens`) |
| App config | `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` (flutterfire configure). Client config is public by design. |
| Auth | Anonymous and Google sign-in, enabled in the Firebase console on 2026-10-13. No Identity Platform upgrade. |
| App Check | Not registered yet; the API accepts requests without it while `ENFORCE_APP_CHECK=false`. |

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
| Object layout | `uploads/{uid}/{jobId}/source` |

## Cloud Run
| Item | Value |
|---|---|
| Service | `contextlens-api`, `us-central1` |
| URL | https://contextlens-api-115890664288.us-central1.run.app |
| Runtime SA | `contextlens-api@contextlens-tekken.iam.gserviceaccount.com` (no keys) |
| Settings | CPU always allocated (background stage task), min 0, max 3 instances, 512 MiB, concurrency 40, timeout 300 s, public ingress (auth is Firebase ID tokens) |
| Env | `GOOGLE_CLOUD_PROJECT`, `BUCKET`, `SERVICE_ACCOUNT`, `ENFORCE_APP_CHECK=false`, `STUB_STAGE_SECONDS=5` |

Runtime SA roles: `roles/datastore.user`, `roles/aiplatform.user`, `roles/speech.client`, `roles/firebaseauth.viewer`, `roles/firebaseappcheck.tokenVerifier`, `roles/firebasecloudmessaging.admin`, `roles/logging.logWriter` (project); `roles/storage.objectAdmin` (bucket); `roles/iam.serviceAccountTokenCreator` on itself, so it can sign V4 URLs through IAM signBlob.

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
Smoke test (needs the Android API key from `lib/firebase_options.dart`):
```bash
backend/.venv/Scripts/python.exe backend/tests/smoke_api.py https://contextlens-api-115890664288.us-central1.run.app <API_KEY>
```

## Credentials on the dev machine
`gcloud auth application-default login` (scopes cloud-platform and firebase). The Firebase CLI and flutterfire use it through `GOOGLE_APPLICATION_CREDENTIALS=%APPDATA%\gcloud\application_default_credentials.json`; there is no separate `firebase login`.

## Smoke test, 2026-10-13
All 16 checks passed against revision `contextlens-api-00002-7bz`: health, anonymous sign-up, unauthenticated upload refused (401), `POST /v1/uploads`, resumable session opened with the signed URL, file uploaded, submit (202), the job walked extract, claims, checking, evidence, report in Firestore, 5 stub flags written, another user cannot read the job (403), the owner cannot write it (403), video URL issued and serves the file, `POST /v1/devices` (204), `DELETE /v1/jobs/{id}` (204), deleted job gone (404).
