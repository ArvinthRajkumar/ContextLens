import 'dart:convert';

import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:flutter/foundation.dart';

/// A New check the creator left before running it: the picked video (a
/// private copy) and the declaration as typed.
@immutable
class Draft {
  const Draft({
    required this.id,
    required this.updatedAt,
    required this.declaration,
    this.video,
    this.videoName,
  });

  final String id;
  final DateTime updatedAt;
  final DeclarationDraft declaration;
  final PickedVideo? video;

  /// The name shown for the video ("Video from gallery, 14 Oct").
  final String? videoName;

  /// From the caption's first line, else the video's name.
  String get title =>
      titleFromCaption(declaration.caption) ?? videoName ?? 'Untitled draft';

  Uint8List? get thumbnail => video?.thumbnail;

  Draft copyWith({
    DateTime? updatedAt,
    DeclarationDraft? declaration,
    PickedVideo? video,
    String? videoName,
  }) {
    return Draft(
      id: id,
      updatedAt: updatedAt ?? this.updatedAt,
      declaration: declaration ?? this.declaration,
      video: video ?? this.video,
      videoName: videoName ?? this.videoName,
    );
  }

  /// Everything but the thumbnail bytes, which are stored beside it.
  Map<String, Object?> toJson() => {
    'id': id,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'videoName': videoName,
    if (video case final v?)
      'video': {
        'path': v.path,
        'name': v.name,
        'sizeBytes': v.sizeBytes,
        'container': v.container.name,
        'durationMs': v.duration.inMilliseconds,
        'width': v.width,
        'height': v.height,
        'sampleId': v.sampleId,
      },
    'declaration': {
      'caption': declaration.caption,
      'isPaid': declaration.isPaid,
      'brand': declaration.brand,
      'category': declaration.category.name,
      'clips': [
        for (final clip in declaration.clips)
          {
            'id': clip.id,
            'label': clip.label,
            'url': clip.url,
            'filePath': clip.filePath,
            'fileName': clip.fileName,
            'sampleSourceId': clip.sampleSourceId,
          },
      ],
    },
  };

  static Draft fromJson(Map<String, Object?> json, {Uint8List? thumbnail}) {
    final video = json['video'] as Map<String, Object?>?;
    final d = json['declaration']! as Map<String, Object?>;
    return Draft(
      id: json['id']! as String,
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      videoName: json['videoName'] as String?,
      video: video == null
          ? null
          : PickedVideo(
              path: video['path']! as String,
              name: video['name']! as String,
              sizeBytes: video['sizeBytes']! as int,
              container: VideoContainer.values.byName(
                video['container']! as String,
              ),
              duration: Duration(milliseconds: video['durationMs']! as int),
              width: video['width']! as int,
              height: video['height']! as int,
              thumbnail: thumbnail,
              sampleId: video['sampleId'] as String?,
            ),
      declaration: DeclarationDraft(
        caption: d['caption']! as String,
        isPaid: d['isPaid']! as bool,
        brand: d['brand']! as String,
        category: ContentCategory.values.byName(d['category']! as String),
        clips: [
          for (final raw in (d['clips']! as List).cast<Map<String, Object?>>())
            ClipDraft(
              id: raw['id']! as int,
              label: raw['label']! as String,
              url: raw['url']! as String,
              filePath: raw['filePath'] as String?,
              fileName: raw['fileName'] as String?,
              sampleSourceId: raw['sampleSourceId'] as String?,
            ),
        ],
      ),
    );
  }

  String encode() => jsonEncode(toJson());
}

/// "Edited just now", "Edited 5 min ago", "Edited 3 h ago", then the date.
String editedAgo(DateTime when, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(when);
  if (elapsed.inMinutes < 1) return 'Edited just now';
  if (elapsed.inMinutes < 60) return 'Edited ${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return 'Edited ${elapsed.inHours} h ago';
  return 'Edited ${formatRunDate(when, now: now)}';
}

/// Whether a declaration has anything worth keeping.
bool hasContent(DeclarationDraft d) =>
    sanitizeText(d.caption).isNotEmpty ||
    sanitizeText(d.brand).isNotEmpty ||
    d.clips.isNotEmpty;
