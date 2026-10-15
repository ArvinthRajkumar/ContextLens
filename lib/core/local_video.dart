import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// A player for a picked video: a file path on Android and iOS, a blob URL
/// on the web, or the signed URL of a Try a sample video.
VideoPlayerController localVideoController(String path) =>
    kIsWeb || path.startsWith('https://')
    ? VideoPlayerController.networkUrl(Uri.parse(path))
    : VideoPlayerController.file(File(path));
