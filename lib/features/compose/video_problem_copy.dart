import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:flutter/material.dart';

/// The one place video problems become user copy.
extension VideoProblemCopy on VideoProblem {
  String get title => switch (this) {
    VideoTooLarge() => 'File too large',
    VideoUnsupported() => 'Unsupported format',
    VideoTooShort() => 'Video too short',
    VideoTooLong() => 'Video too long',
    VideoUnreadable() => "Can't open this file",
    VideoDecodeTimeout() => 'Took too long to read',
  };

  String get message => switch (this) {
    VideoTooLarge(:final sizeBytes) =>
      'This video is ${formatBytes(sizeBytes)}. '
          'The limit is ${formatBytes(kMaxUploadBytes)}.',
    VideoUnsupported() => 'Use an MP4, MOV or WebM video.',
    VideoTooShort() =>
      'Videos need to be at least ${kMinVideoDuration.inSeconds} seconds long.',
    VideoTooLong() =>
      'Videos can be up to ${kMaxVideoDuration.inMinutes} minutes long.',
    VideoUnreadable() => 'This file looks damaged. Try exporting it again, then pick it once more.',
    VideoDecodeTimeout() => "Couldn't read this video in time. Try again.",
  };

  IconData get icon => switch (this) {
    VideoTooLarge() => Icons.sd_card_alert_outlined,
    VideoUnsupported() => Icons.block,
    VideoTooShort() || VideoTooLong() => Icons.timer_off_outlined,
    VideoUnreadable() => Icons.broken_image_outlined,
    VideoDecodeTimeout() => Icons.hourglass_empty,
  };
}
