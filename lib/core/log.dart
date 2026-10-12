import 'package:flutter/foundation.dart';

/// The app's only logger. A no-op in release builds. Never pass URLs with
/// query strings, tokens, captions or file paths.
void log(String message) {
  if (kReleaseMode) return;
  debugPrint('[ContextLens] $message');
}
