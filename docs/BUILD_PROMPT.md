# ContextLens build prompt

Source: research brief, Section C. This is the spec of record.

You are building ContextLens, a Flutter mobile app (Android first, iOS second) for the Google Cloud AI Builder Cup 2026. Deadline: Oct 18, 2026. Team of two. I am an experienced Flutter developer: skip tutorials, write production code, and stop at each VERIFY step to show me results.

HARD RULES
- Never use em dash or en dash characters anywhere: code, comments, strings, docs, commit messages. Use commas, colons or parentheses.
- Build against a mock backend first. The real Firebase/Cloud Run wiring comes later, behind the same interfaces.
- Use the Dart MCP server tools (analyze, test, hot reload, screenshot) for every VERIFY step.
- When a package version below is marked UNVERIFIED, run `flutter pub add <name>`, keep the resolved caret version, and tell me what it resolved to.

1. PRODUCT GOAL
ContextLens is a pre-publish video checker for creators. A creator picks or shares a draft video, fills a short declaration, watches a live check (1 to 3 minutes), and gets a report: a timeline with flag markers in five categories, each flag with evidence, a citation and a suggested fix. After fixing and re-uploading, the report compares runs ("3 of 4 issues resolved"). Quality bar: it looks and moves like a top-tier Google app, with no jank, no layout overflow and no dead ends.

2. SCREENS AND NAVIGATION (stack only, no bottom nav, no drawer)
Routes (go_router):
  /splash          Intro animation, then replace with /
  /                Home: big "Check a video" CTA, recent runs list (cards), settings icon in the app bar
  /new             Compose: video preview card plus declaration form on one scrolling page, sticky "Run check" button
  /run/:jobId      Run: upload phase, then success animation, then live stage stepper. Auto-navigates to the report when done.
  /report/:jobId   Report: video player plus flag timeline, summary, flag list, run comparison section. Flag detail opens as an OpenContainer full page (or a draggable sheet on small heights).
  /settings        Theme (Dark default, Light, System), reduce motion override, delete my data, privacy policy, about
Flows:
  Home -> /new (shared axis X) -> /run (shared axis X, Hero on the thumbnail) -> /report (fade through, replaces /run so back goes Home)
  Home recent run card -> /report (OpenContainer container transform)
  Report "Fix and re-upload" -> /new?parent=<jobId> (prefills the declaration, asks for the new video)
  Android share sheet (video/*) -> /new with the shared file preselected (works cold and warm)
  FCM notification tap -> /report/:jobId
Back from /run while uploading: confirm dialog "Keep uploading in background?" with the options Keep / Cancel upload.

3. DESIGN SYSTEM (lib/core/theme)
Material 3, useMaterial3 true. Build ColorScheme manually from these tokens (no dynamic color by default; it can wash out the semantic flag colors). Expose an AppColors ThemeExtension for the semantic tokens.

Dark (default)
  background #0B0F14  surface #11161D  surfaceContainer #161C24  surfaceContainerHigh #1C232D  outline #2A3340  outlineVariant #1F2731
  onSurface #E6EBF1  onSurfaceVariant #9AA6B2  primary #3DD6C6  onPrimary #00201D  primaryContainer #0E3B37  onPrimaryContainer #9CF2E8
  error #FF6B6B  scrim #000000 at 60%
Light
  background #F7F9FB  surface #FFFFFF  surfaceContainer #F0F3F6  surfaceContainerHigh #E8ECF0  outline #C5CDD6  outlineVariant #DDE3E9
  onSurface #0E141B  onSurfaceVariant #4A5663  primary #00897D  onPrimary #FFFFFF  primaryContainer #C8F3EE  onPrimaryContainer #00201D
  error #C62828
Flag category colors (dark / light), always paired with an icon and label, never color alone:
  disclosure #FFB547 / #B26A00   claims #FF7A90 / #C2185B   visuals #8AB4FF / #1E5BD8   borrowed #C59BFF / #6B3FC4   factcheck #3DD6C6 / #00897D
Fact-check label colors: supported #4ADE80, contradicted #FF6B6B, previously_fact_checked #8AB4FF, insufficient_evidence #9AA6B2
Verify every text/background pair is >= 4.5:1 (>= 3:1 for large text and icons). Add a unit test that computes contrast for the token pairs.

Typography: bundle the fonts as assets (no runtime font fetching). Inter for UI, JetBrains Mono for timecodes, speed, ETA and counts (FontFeature.tabularFigures()).
  displaySmall 36/44 w600 -0.5   headlineSmall 24/32 w600   titleLarge 20/28 w600   titleMedium 16/24 w600
  bodyLarge 16/24 w400   bodyMedium 14/20 w400   labelLarge 14/20 w600 +0.1   labelSmall 11/16 w600 +0.5
Spacing (4pt grid): space1 4, space2 8, space3 12, space4 16, space5 20, space6 24, space8 32, space10 40, space12 48. Screen padding 20. Min touch target 48.
Radius: xs 6, sm 10, md 14, lg 20, xl 28, full 999. Cards md, sheets xl (top only), buttons full, chips sm.
Elevation: dark mode uses tonal surfaces (surfaceContainer levels) plus a 1px outlineVariant border, no shadows. Light mode uses level1 shadow (0 1 2 rgba 0,0,0,.06) on cards only.
Motion tokens (lib/core/theme/motion.dart), mapped to Flutter's built-in Durations and Easing:
  short2 100ms, short4 200ms, medium2 300ms, medium4 400ms, long2 500ms, extraLong1 700ms
  standard = Easing.standard (0.2,0,0,1), enter = Easing.emphasizedDecelerate (0.05,0.7,0.1,1), exit = Easing.emphasizedAccelerate (0.3,0,0.8,0.15), emphasized = Curves.easeInOutCubicEmphasized, linear only for progress values and opacity
  Rule: enter uses decelerate, exit uses accelerate, and exit is shorter than enter. Bigger movement gets a longer duration.
  Motion.of(context) returns the tokens, with every duration scaled to zero (or a crossfade) when reduced motion is on.

4. ANIMATION SPECS
Reduced motion = MediaQuery.disableAnimations OR the Settings override. Every spec below lists its reduced variant.
a) Splash. Native splash (flutter_native_splash) is a solid background color plus the logo mark, so there's no flash. The Flutter intro runs 1100ms total: lens ring arc draws 0 to 1 (600ms, enter), a scan line sweeps once across the lens (400ms, start at 300ms, standard), wordmark fades in and rises 12dp (300ms, start at 600ms, enter), then fade-through to Home (300ms). App init (Firebase, prefs, auth) runs in parallel. If init finishes first, wait for the intro. If init is slow, hold on the final frame with a subtle pulse. Reduced: static logo for 300ms, then crossfade.
b) Page transitions. PageTransitionsTheme uses SharedAxisPageTransitionsBuilder(horizontal) from the animations package for the forward flow (medium2). FadeThroughTransition for Home <-> Settings and Run -> Report. OpenContainer for run card -> report and flag card -> flag detail (medium4 open, medium2 close, closedColor = surfaceContainer, radius md). Hero on the video thumbnail from Compose to Run. Support Android predictive back.
c) Upload progress. Circular progress ring 160dp, stroke 10, round caps, primary on outlineVariant track. Progress updates tween with TweenAnimationBuilder (200ms, linear) so chunk jumps look continuous. Under the ring: percent (displaySmall mono), then "12.4 MB of 86.0 MB", speed "3.2 MB/s" and "about 24 s left". Smooth speed with an exponential moving average (alpha 0.3) and update the text at most every 500ms. Pause morphs the ring color to onSurfaceVariant with a dashed track. Error shakes the ring 3px x2 (short4), switches it to the error color, and shows a retry button. Reduced: no tweening, no shake.
d) Upload success (original GPay-style moment, CustomPainter plus one AnimationController, 1200ms):
   0 to 200ms: ring at 100% tightens, scale 1.0 to 0.92 (exit curve)
   200 to 550ms: filled primary disc expands from the ring, scale 0.92 to 1.0 with Curves.easeOutBack. HapticFeedback.mediumImpact() at 200ms.
   350 to 750ms: white checkmark path draws using PathMetric.extractPath, stroke 8, round caps (enter curve). HapticFeedback.lightImpact() at 750ms.
   450 to 1050ms: two concentric ripple rings, scale 1.0 to 2.4, opacity 0.35 to 0, the second delayed 120ms
   500 to 1100ms: 14 small particles (circles and short rounded bars in primary, primaryContainer and white) burst radially with slight gravity, fading out. Draw them in the same painter (no confetti package).
   700 to 1000ms: "Uploaded" titleLarge plus "Starting checks" bodyMedium fade in and rise 8dp
   1200ms: the disc shrinks and moves to the top-left of the stepper as the first stage dot (medium4, emphasized). The screen continues into the processing stages.
   Optional sound: off by default, toggle in Settings, a short original chime asset we create ourselves. Never use Google assets.
   Wrap the painter in RepaintBoundary. Announce "Upload complete" via SemanticsService.announce.
   Reduced: static filled check plus a single mediumImpact haptic.
e) Processing stages (Extract, Claim ledger, Checking, Evidence gate, Report). Vertical stepper. The active stage dot shows a pulsing ring (1200ms loop, standard). A completed stage's dot fills and draws a small check (300ms). The connecting line fills top to bottom (medium2). A one-line live detail under the active stage comes from Firestore if present (e.g. "14 claims found"). Show elapsed time in mono. Copy: "Usually 1 to 3 minutes. You can leave, we will notify you." Reduced: no pulse.
f) Report reveal. The summary count rolls up from 0 (600ms, enter). Timeline markers drop in, staggered 40ms each, scale 0 to 1 easeOutBack 250ms. Flag cards fade in and slide up 16dp, staggered 50ms, 300ms, enter. Stagger at most the first 8; the rest appear instantly. Use flutter_animate for staggers, with an explicit .animate(delay: ...) per item. Reduced: everything appears at once.
g) Flag cards. Press feedback scale 0.98 (short2). Expand inline with AnimatedSize (medium2, standard). Tapping a timeline marker seeks the video, scrolls the list to the card, and pulses its border twice (short4 each). Tapping a card seeks the video to flag.startMs and highlights its marker.

5. UPLOAD FLOW SPEC
Picking:
- image_picker pickVideo (uses the Android Photo Picker on Android 13+). No storage permission is requested for gallery picks. iOS: PHPicker through image_picker, no photo-library permission prompt.
- file_picker as a fallback for Files/Drive sources (FileType.video).
- Shared files come in through share_handler.
Preview card: thumbnail (fc_native_video_thumbnail, frame at 1s), duration and resolution read with a VideoPlayerController initialized then disposed, file size, container format. Tap to play inline. "Replace" and "Remove" actions.
Validation (before any network call), with inline errors on the card:
  extensions/mime mp4, mov, webm (video/mp4, video/quicktime, video/webm). Sniff the first bytes (ftyp / webm EBML) as well as the extension.
  size <= 500 MB (const kMaxUploadBytes), duration 3 s to 10 min, file readable
Declaration form: caption (required, 1 to 2200 chars, counter), "Paid or collab?" switch, brand name (required when on, 2 to 80 chars), borrowed clips (repeatable rows: optional URL validated as https, or an attached file, plus a short label), category segmented button (Health, Finance, General). Trim inputs and strip control characters. The submit button stays disabled until valid. Show errors after the user leaves a field or presses submit, never while they type.
Upload protocol (GCS resumable via a signed URL):
  1. POST /v1/uploads {fileName, contentType, sizeBytes, sha256?} -> {jobId, uploadUrl, uploadUrlExpiresAt, maxBytes, chunkSize}
     uploadUrl is a V4 signed URL for POST with header x-goog-resumable:start, signed with X-Upload-Content-Length = sizeBytes, expiring in 15 minutes.
  2. App POSTs to uploadUrl with headers x-goog-resumable:start, Content-Type, X-Upload-Content-Length. Reads the Location header = sessionUri.
  3. Upload chunks with dio PUT to sessionUri. chunkSize 8 MiB (must be a multiple of 262144). Header Content-Range: bytes start-end/total. 308 means continue; parse the Range header for the committed offset. 200/201 means done.
  4. Resume or retry: PUT with an empty body and Content-Range: bytes */total, read the committed offset, continue from there. Retry with exponential backoff and jitter (1s, 2s, 4s, 8s, max 5 tries) on network errors, 5xx and 429. A 4xx (other than 408 and 429) is fatal.
  5. POST /v1/jobs/{jobId}/submit {declaration, parentJobId?} -> 202 {jobId}. Then listen to Firestore jobs/{jobId}.
  Persist {jobId, sessionUri, filePath, total, committedOffset} in flutter_secure_storage. sessionUri works like a bearer credential: never log it or include it in crash reports. On app restart with a pending upload, Home shows a "Resume upload" banner. Sessions stay valid for up to a week, but we treat anything older than 24 h as expired.
Controls: Pause (cancel the in-flight chunk with a CancelToken and keep the offset), Resume, Cancel (DELETE the session with a request to sessionUri, clear state, confirm dialog), Retry.
Speed/ETA: bytes per second from dio onSendProgress deltas with an EMA. ETA = remaining / ema.
Connectivity: connectivity_plus drives an offline banner ("Waiting for connection, upload paused"). Pause automatically when offline and resume when back online. Never fake progress.
Background: keep the upload running while the app is in the foreground and briefly backgrounded. On AppLifecycleState.paused, persist the offset. STRETCH (Phase 7): hand the remaining file to background_downloader with an UploadTask (binary upload, TransferHint.userInitiated and largeFile for Android 14+ user-initiated data transfer) to the sessionUri with the correct Content-Range. Its docs say "Pausing is only possible for download GET requests", so keep dio as the pausable path.
Error states, each with an illustration-free icon, one sentence and one action: file too large, unsupported format, file unreadable, offline, upload link expired (auto-request a new uploadUrl and restart the session), server error, check failed (show the backend message plus "Try again").

6. BACKEND CONTRACTS
All requests: Authorization: Bearer <Firebase ID token> (getIdToken, auto refresh) and X-Firebase-AppCheck: <token>. Base URL from --dart-define=API_BASE_URL. JSON only, camelCase.
  POST   /v1/uploads                -> 201 {jobId, uploadUrl, uploadUrlExpiresAt, maxBytes, chunkSize}
  POST   /v1/jobs/{jobId}/submit    -> 202 {jobId}
  GET    /v1/jobs/{jobId}/video-url -> 200 {url, expiresAt}  (short-lived signed GET for report playback, 15 min)
  DELETE /v1/jobs/{jobId}           -> 204 (deletes the video, the job and its flags)
  POST   /v1/devices                -> 204 {fcmToken, platform}
Error shape: {error: {code, message, retryable}}
Firestore jobs/{jobId} (read-only for the client; the backend writes):
  ownerUid string, status "uploading"|"queued"|"processing"|"done"|"failed", stage "extract"|"claims"|"checking"|"evidence"|"report",
  stageDetail string?, version int (run number, 1 for the first), parentJobId string?, createdAt, updatedAt, expiresAt timestamp (TTL),
  video {durationMs, width, height}, summary {total, byCategory map}, comparison {previousJobId, resolved int, remaining int, newCount int}?,
  error {code, message}?,
  flags: [{id, fingerprint, category "disclosure"|"claims"|"visuals"|"borrowed"|"factcheck", severity "high"|"medium"|"low",
           startMs, endMs, title, evidence, citation {title, url, publisher}?, suggestedFix,
           factLabel "supported"|"contradicted"|"previously_fact_checked"|"insufficient_evidence"?,
           diff {clipTranscript, originalTranscript, segments [{op "equal"|"insert"|"delete", text}]}?}]
Client parsing: Freezed models with unknown enum values mapped to a fallback, never crashing. If comparison is absent, compute it client-side by matching flag.fingerprint between versions.
Firestore rules (I will deploy them): allow read if request.auth.uid == resource.data.ownerUid; deny all writes.
FCM: data payload {type "report_ready", jobId}. Request notification permission only after the first successful submit, with a pre-prompt explaining why.
Auth: anonymous sign-in on first launch. Optional "Sign in with Google" in Settings links the account (linkWithCredential) so history survives reinstall.

7. MOCK BACKEND FIRST
- Abstract interfaces in each feature's data folder: UploadRepository, JobRepository, AuthRepository, PushRepository.
- Implementations: Fake* (default) and Firebase* / Http*. A Riverpod provider chooses based on --dart-define=BACKEND=mock|real.
- FakeUploadRepository simulates chunked progress at about 4 MB/s with random jitter. It supports pause, resume and cancel, injects one transient failure when --dart-define=MOCK_FAIL=1, and goes offline when the connectivity mock says so.
- FakeJobRepository emits a Stream<Job> through the five stages over about 25 s (configurable), then "done" with fixtures from assets/mock/report_v1.json (8 flags covering all categories and all four fact labels, including one borrowed-clip diff) and report_v2.json (version 2, 3 of 4 resolved).
- A bundled sample video in assets/mock/sample.mp4 for the report player in mock mode.
- A debug-only menu (long-press the logo on Home) to jump to any screen state: upload error, offline, failed job, empty history.

8. SECURITY CHECKLIST
- No secrets in the app. Only Firebase client config (that config is public by design). API base URL via dart-define. No service account keys, no API keys for Gemini or Fact Check, all of that lives server-side.
- Firebase App Check: providerAndroid AndroidPlayIntegrityProvider (AndroidDebugProvider in debug), providerApple AppleAppAttestProvider (debug provider in debug).\[29\] Send the token to Cloud Run and enforce it there and on Firestore.
- Tokens: rely on the FirebaseAuth SDK for ID tokens and never persist them ourselves. flutter_secure_storage v11 (Android uses storageNamespace, not the removed encryptedSharedPreferences option) only for the pending upload session state.
- Signed URLs: 15 min upload-init expiry, 15 min playback GET expiry, bound to content type and length. Refresh on 403/expiry. Never cache them to disk.
- Network: Android network_security_config.xml with cleartextTrafficPermitted="false" and no user CAs in release. iOS keeps ATS defaults. No certificate pinning to Google endpoints (they rotate certificates). Optionally pin our Cloud Run custom domain with a backup pin.
- Input validation on the client (section 5), duplicated server-side. Treat all report text as untrusted: plain Text widgets, no HTML rendering. Open citation URLs only if they're https, via url_launcher in external mode.
- Privacy: videos and jobs are deleted after 24 h (GCS lifecycle rule plus a Firestore TTL on expiresAt plus a scheduled job; note that GCS lifecycle age works in days). "Delete my data" in Settings calls DELETE for every job, then signs out. Privacy screen: hide app content in the recents switcher (FLAG_SECURE on the report route via the Android sensitive content API or a small platform channel; a blur overlay on iOS when inactive). Keep the local copy of the picked file only in the app cache and delete it after upload.
- Permissions: none for gallery picks on Android 13+ and iOS PHPicker. Request POST_NOTIFICATIONS only when needed. No CAMERA, no READ_MEDIA_* unless the Android 12-and-below fallback strictly requires READ_EXTERNAL_STORAGE with maxSdkVersion 32.
- Release builds: flutter build appbundle --release --obfuscate --split-debug-info=build/symbols. Keep the symbols out of git. Obfuscation doesn't hide string literals, which is one more reason to keep no secrets in the app.
- Logging: a single log() wrapper that's a no-op in release. Never log URLs with query strings, tokens, captions or file paths.

9. FOLDER STRUCTURE (feature-first, keep it flat)
lib/
  main.dart                 bootstrap, ProviderScope, error handlers
  app.dart                  MaterialApp.router, themes
  router.dart
  core/
    theme/ (colors.dart, typography.dart, spacing.dart, motion.dart, app_theme.dart)
    widgets/ (app_button.dart, app_card.dart, section_header.dart, empty_state.dart)
    utils/ (formatters.dart for bytes, durations, ETA; validators.dart)
    config.dart (dart-defines)
  features/
    splash/   (splash_page.dart, lens_intro_painter.dart)
    home/     (home_page.dart, recent_runs.dart)
    compose/  (compose_page.dart, video_preview_card.dart, declaration_form.dart, compose_controller.dart)
    upload/   (upload_repository.dart, resumable_uploader.dart, fake_upload_repository.dart, upload_controller.dart)
    run/      (run_page.dart, upload_ring.dart, success_burst.dart, stage_stepper.dart)
    report/   (report_page.dart, flag_timeline.dart, flag_card.dart, flag_detail_page.dart, transcript_diff.dart, run_comparison.dart, job_repository.dart, fake_job_repository.dart, models.dart)
    settings/ (settings_page.dart, theme_controller.dart)
    share/    (share_intake.dart)
test/  integration_test/  assets/{fonts,mock,sounds}/

10. PACKAGES (versions checked on pub.dev Oct 2026 unless marked UNVERIFIED)
Flutter stable 3.47.x, Dart 3.12+ (go_router 18 requires Flutter 3.44 / Dart 3.12)
  flutter_riverpod ^3.4.3        state (Notifier/AsyncNotifier, no codegen needed)
  go_router ^18.0.2              routing
  animations UNVERIFIED          SharedAxis, FadeThrough, OpenContainer (flutter.dev publisher)
  flutter_animate UNVERIFIED     staggers and simple effects only
  image_picker ^1.2.4            gallery video via the system photo picker
  file_picker ^13.1.0            fallback source (v12+ API: pickFiles returns List<PlatformFile>, check the docs)
  video_player ^2.14.1           preview and report playback
  fc_native_video_thumbnail ^2.1.1  thumbnails (maintained, verified publisher)
  dio UNVERIFIED (5.x)           chunked uploads, CancelToken, onSendProgress
  background_downloader ^9.6.4   STRETCH only, background upload
  connectivity_plus UNVERIFIED   offline detection
  firebase_core ^4.15.0, firebase_auth ^6.7.0, cloud_firestore ^6.10.0, firebase_messaging ^16.7.0, firebase_app_check ^0.4.8\[30\]
  google_sign_in ^7.2.0          optional account linking (7.x API: GoogleSignIn.instance.initialize, authenticationEvents)
  flutter_secure_storage ^11.0.0 pending upload state
  shared_preferences UNVERIFIED  theme mode and reduce-motion override
  share_handler UNVERIFIED       Android share sheet intake (receive_sharing_intent is poorly maintained)\[31\]
  url_launcher UNVERIFIED, flutter_native_splash UNVERIFIED (dev), freezed + freezed_annotation + json_serializable + build_runner UNVERIFIED
Do NOT add: rive, lottie, confetti, google_fonts (runtime fetching), any HTTP logging interceptor in release, get/getx, provider.
Haptics: use the Flutter SDK HapticFeedback; no package.

11. CODE STYLE (it must read like a careful human wrote it)
- Follow Effective Dart, flutter_lints plus: prefer_const_constructors, prefer_final_locals, require_trailing_commas, always_use_package_imports, unawaited_futures, avoid_print.
- Small widgets as classes, not _buildX() methods. One public widget per file. Files snake_case, classes PascalCase, providers named fooProvider, controllers FooController.
- Comments only where the why isn't obvious (protocol quirks, magic numbers). No banner comments, no "// Widget for X" restating names, no TODO spam, no emoji.
- No unnecessary abstraction: interfaces only at the repository boundary. No base classes for pages. No "Manager"/"Helper"/"Utils" god classes.
- Extract magic numbers into tokens or named consts. No hardcoded colors or durations in widgets.
- Errors: typed sealed failures (UploadFailure.offline, .tooLarge, .expired, .server(code)). Map them to user copy in one place.
- Copy: short, sentence case, human. "Checking claims" not "Processing Claim Ledger Stage". Plain buttons: "Run check", "Pause", "Try again".
- Commit after each phase with a conventional message.

12. ACCESSIBILITY
- Reduced motion honored everywhere (section 4), plus a Settings override.
- Text scaling up to 200% without overflow. Test at 1.0, 1.3 and 2.0. Use Flexible/Wrap. No fixed-height text containers.
- Contrast test (section 3). Never use color alone: flags carry an icon, a category label and a severity word.
- Semantics: timeline markers are buttons labelled "Claims flag at 0:42, high severity". The progress ring exposes value and label. Live stage changes are announced politely.
- Touch targets >= 48dp. Focus order is logical. The keyboard's next/done actions move between form fields.

13. TESTING AND PERFORMANCE
- Unit: validators, byte/ETA formatters, Content-Range parsing and resume offset logic, EMA speed, comparison by fingerprint, model parsing with unknown enums.
- Widget: compose form validation states, upload ring states (running, paused, error, done), report renders all categories and fact labels from fixtures, transcript diff, theme switch persists.
- Integration (integration_test, mock backend): pick fixture -> declare -> upload -> success -> stages -> report -> re-upload -> comparison shows "3 of 4 issues resolved".
- Performance: run in --profile on a mid-range Android device. Target 60/120 fps with no frames over 16 ms during the success animation, report reveal and scrolling (DevTools performance view). Impeller is the default renderer; verify no shader jank on first run of the success animation. Use RepaintBoundary around the progress ring, success painter, timeline and video. Use const widgets. Use ListView.builder for flags. Dispose every controller (VideoPlayerController, AnimationController, StreamSubscription). Cache the thumbnail bytes. Never rebuild the video player on progress ticks (use select on providers).
- Analyzer clean: zero warnings. dart format applied.

14. BUILD ORDER (stop after each VERIFY and show me screenshots via the Dart MCP server)
Phase 0 Setup: flutter create --org app.contextlens --platforms android,ios contextlens. Packages, lints, fonts, folder structure, config.dart, mock flag.
  VERIFY: flutter analyze clean, app runs, blank Home in dark mode.
Phase 1 Design system: tokens, ThemeData dark and light, ThemeExtension, motion tokens, core widgets, theme controller persisted in shared_preferences (Dark default), Settings page.
  VERIFY: a hidden /gallery debug route renders every core widget in both themes. Contrast unit test passes. Screenshot both themes.
Phase 2 Navigation and splash: go_router routes, transitions (shared axis, fade through, container transform), splash intro, reduced-motion path.
  VERIFY: tap through every route. Screenshot the splash end frame. Toggling disable animations removes motion.
Phase 3 Compose: picker, preview card, thumbnail, metadata, validation, declaration form, share_handler intake (Android).
  VERIFY: pick valid and invalid files and show each error. Share a video from Google Photos into the app (cold and warm start).
Phase 4 Upload (mock): FakeUploadRepository, upload ring, speed/ETA, pause/resume/cancel/retry, offline banner, success animation, stage stepper with FakeJobRepository.
  VERIFY: record the success animation in profile mode with no jank. Show pause/resume and the forced failure path (MOCK_FAIL=1).
Phase 5 Report (mock): video player plus timeline markers, flag list, flag detail with evidence/citation/fix, fact labels, transcript diff, report reveal, run comparison from v2 fixture, re-upload flow.
  VERIFY: integration test passes end to end on mock. Screenshot the report at text scale 1.0 and 2.0.
Phase 6 Real backend: Firebase init, anonymous auth, App Check, Http repositories, ResumableUploader against a GCS signed URL, Firestore listener, FCM, Google sign-in linking, delete my data.
  VERIFY: BACKEND=real uploads a 100 MB file, survives airplane mode mid-upload, and resumes. Firestore stages stream live. The push opens the report.
Phase 7 Hardening: network security config, privacy screen, logging audit, release build with obfuscation, STRETCH background upload, app icon, store-ready splash.
  VERIFY: release APK runs. grep the build output for any secret-like strings. Check the size of the APK. Run the full test suite.
Phase 8 Demo polish: 90-second demo path, seeded mock data toggle, empty states, final pass on copy and motion.
  VERIFY: record the demo flow on device in mock and real modes.

Start with Phase 0. After every phase, list what you built, what you skipped and why, and anything I need to do manually (Firebase console, GCS CORS/lifecycle, App Check registration).
