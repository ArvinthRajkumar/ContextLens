import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// A player for a video picked on this device: a file path on Android and
/// iOS, a blob URL on the web.
VideoPlayerController localVideoController(String path) => kIsWeb
    ? VideoPlayerController.networkUrl(Uri.parse(path))
    : VideoPlayerController.file(File(path));
