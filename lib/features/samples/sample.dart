import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:flutter/foundation.dart';

/// A synthetic test video from Try a sample, with the declaration that
/// goes with it. The URLs are signed and short-lived.
@immutable
class Sample {
  const Sample({
    required this.id,
    required this.title,
    required this.hint,
    required this.language,
    required this.duration,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.declaration,
    this.clip,
    this.thumbnailUrl,
    this.videoUrl,
    this.downloadUrl,
  });

  factory Sample.fromJson(Map<String, dynamic> json) {
    final d = json['declaration'] as Map<String, dynamic>;
    final clip = json['clip'] as Map<String, dynamic>?;
    return Sample(
      id: json['id'] as String,
      title: json['title'] as String,
      hint: json['hint'] as String? ?? '',
      language: json['language'] as String? ?? 'English',
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      width: json['width'] as int? ?? 720,
      height: json['height'] as int? ?? 1280,
      declaration: SampleDeclaration(
        caption: d['caption'] as String? ?? '',
        isPaid: d['isPaid'] as bool? ?? false,
        brand: d['brandName'] as String? ?? '',
        category: ContentCategory.values.firstWhere(
          (c) => c.name == d['category'],
          orElse: () => ContentCategory.general,
        ),
      ),
      clip: clip == null
          ? null
          : SampleClip(
              id: clip['id'] as String,
              label: clip['label'] as String? ?? '',
              downloadUrl: clip['downloadUrl'] as String?,
            ),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
    );
  }

  final String id;
  final String title;
  final String hint;
  final String language;
  final Duration duration;
  final int sizeBytes;
  final int width;
  final int height;
  final SampleDeclaration declaration;

  /// The original a borrowed-clip sample was cut from.
  final SampleClip? clip;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? downloadUrl;

  /// The New check form as this sample fills it.
  DeclarationDraft toDraft() => DeclarationDraft(
    caption: declaration.caption,
    isPaid: declaration.isPaid,
    brand: declaration.brand,
    category: declaration.category,
    clips: [
      if (clip case final clip?)
        ClipDraft(
          id: 0,
          label: clip.label,
          fileName: '${clip.id}.mp4',
          sampleSourceId: clip.id,
        ),
    ],
  );

  /// The sample as the picked video; previews stream from [videoUrl].
  PickedVideo toVideo({Uint8List? thumbnail}) => PickedVideo(
    path: videoUrl ?? '',
    name: title,
    sizeBytes: sizeBytes,
    container: VideoContainer.mp4,
    duration: duration,
    width: width,
    height: height,
    thumbnail: thumbnail,
    sampleId: id,
  );
}

@immutable
class SampleDeclaration {
  const SampleDeclaration({
    required this.caption,
    required this.isPaid,
    required this.brand,
    required this.category,
  });

  final String caption;
  final bool isPaid;
  final String brand;
  final ContentCategory category;
}

@immutable
class SampleClip {
  const SampleClip({required this.id, required this.label, this.downloadUrl});

  final String id;
  final String label;
  final String? downloadUrl;
}
