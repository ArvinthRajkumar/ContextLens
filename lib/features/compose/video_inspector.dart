import 'dart:async';
import 'dart:io';

import 'package:contextlens/core/log.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

@immutable
class PickedVideo {
  const PickedVideo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.container,
    required this.duration,
    required this.width,
    required this.height,
    this.thumbnail,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final VideoContainer container;
  final Duration duration;
  final int width;
  final int height;
  final Uint8List? thumbnail;

  /// The same video at another path (a draft's private copy).
  PickedVideo atPath(String path) => PickedVideo(
    path: path,
    name: name,
    sizeBytes: sizeBytes,
    container: container,
    duration: duration,
    width: width,
    height: height,
    thumbnail: thumbnail,
  );
}

sealed class Inspection {
  const Inspection();
}

final class InspectionPassed extends Inspection {
  const InspectionPassed(this.video);

  final PickedVideo video;
}

final class InspectionFailed extends Inspection {
  const InspectionFailed(this.problem);

  final VideoProblem problem;
}

/// Reads a local video's size, container, duration, resolution and a
/// thumbnail, and validates it. No network.
abstract interface class VideoInspector {
  Future<Inspection> inspect(
    String path, {
    required String name,
    String? mimeType,
  });
}

typedef VideoMetadata = ({Duration duration, int width, int height});

/// Reads duration and resolution by starting a player on the file.
Future<VideoMetadata> readMetadataWithPlayer(
  File file,
  Duration timeout,
) async {
  final controller = VideoPlayerController.file(file);
  try {
    await controller.initialize().timeout(timeout);
    final value = controller.value;
    return (
      duration: value.duration,
      width: value.size.width.round(),
      height: value.size.height.round(),
    );
  } finally {
    unawaited(controller.dispose());
  }
}

class DeviceVideoInspector implements VideoInspector {
  DeviceVideoInspector({
    this.readMetadata = readMetadataWithPlayer,
    this.decodeTimeout = const Duration(seconds: 15),
    this.thumbnails = true,
  });

  /// Injectable for tests; the default starts a real player.
  final Future<VideoMetadata> Function(File file, Duration timeout)
  readMetadata;
  final Duration decodeTimeout;
  final bool thumbnails;

  static const _thumbnailBox = 480;

  // A cold decoder can miss the first deadline on a healthy file, so a
  // timeout gets one automatic retry before it is reported.
  static const _decodeAttempts = 2;

  @override
  Future<Inspection> inspect(
    String path, {
    required String name,
    String? mimeType,
  }) async {
    final file = File(path);
    final int size;
    final List<int> header;
    try {
      size = await file.length();
      final raf = await file.open();
      try {
        header = await raf.read(kSniffBytes);
      } finally {
        await raf.close();
      }
    } on FileSystemException {
      return const InspectionFailed(VideoUnreadable());
    }

    final check = checkVideoFile(
      name: name,
      sizeBytes: size,
      header: header,
      mimeType: mimeType,
    );
    final problem = check.problem;
    if (problem != null) return InspectionFailed(problem);

    VideoMetadata? metadata;
    for (var attempt = 1; attempt <= _decodeAttempts; attempt++) {
      try {
        metadata = await readMetadata(file, decodeTimeout);
        break;
      } on TimeoutException {
        log('Video metadata timed out (attempt $attempt of $_decodeAttempts)');
      } on Object catch (error) {
        log('Video decode failed: ${error.runtimeType}');
        return const InspectionFailed(VideoUnreadable());
      }
    }
    if (metadata == null) return const InspectionFailed(VideoDecodeTimeout());
    final duration = metadata.duration;

    final durationProblem = checkVideoDuration(duration);
    if (durationProblem != null) return InspectionFailed(durationProblem);

    return InspectionPassed(
      PickedVideo(
        path: path,
        name: name,
        sizeBytes: size,
        container: check.container!,
        duration: duration,
        width: metadata.width,
        height: metadata.height,
        thumbnail: thumbnails ? await _thumbnail(path) : null,
      ),
    );
  }

  /// A missing thumbnail is cosmetic, so failures fall back to the placeholder.
  Future<Uint8List?> _thumbnail(String path) async {
    try {
      return await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: path,
        width: _thumbnailBox,
        height: _thumbnailBox,
        format: 'jpeg',
        quality: 85,
      );
    } on Object {
      return null;
    }
  }
}

final videoInspectorProvider = Provider<VideoInspector>(
  (ref) => DeviceVideoInspector(),
);
