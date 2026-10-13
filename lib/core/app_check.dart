import 'dart:developer';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Debug builds attest with a debug token registered in App Check (passed
/// with --dart-define=APP_CHECK_DEBUG_TOKEN, never committed); release
/// builds use Play Integrity.
const _debugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

Future<void> activateAppCheck() => FirebaseAppCheck.instance.activate(
  providerAndroid: kDebugMode
      ? AndroidDebugProvider(
          debugToken: _debugToken.isEmpty ? null : _debugToken,
        )
      : const AndroidPlayIntegrityProvider(),
  providerApple: kDebugMode
      ? const AppleDebugProvider()
      : const AppleAppAttestWithDeviceCheckFallbackProvider(),
);

/// The current App Check token, or null when attestation failed. The API
/// decides whether a request without one is allowed.
Future<String?> appCheckToken() async {
  try {
    return await FirebaseAppCheck.instance.getToken();
  } on Object catch (error) {
    log('App Check token unavailable: ${error.runtimeType}');
    return null;
  }
}
