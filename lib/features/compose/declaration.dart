import 'package:contextlens/core/utils/validators.dart';
import 'package:flutter/foundation.dart';

enum ContentCategory {
  health('Health'),
  finance('Finance'),
  general('General');

  const ContentCategory(this.label);

  final String label;
}

@immutable
class ClipDraft {
  const ClipDraft({
    required this.id,
    this.label = '',
    this.url = '',
    this.filePath,
    this.fileName,
  });

  /// Stable key for the row's widgets while rows are added and removed.
  final int id;
  final String label;
  final String url;
  final String? filePath;
  final String? fileName;

  bool get hasSource => sanitizeText(url).isNotEmpty || filePath != null;

  /// First problem with the row, or null when it can be submitted.
  String? get error =>
      validateClipLabel(label) ??
      validateClipUrl(url) ??
      (hasSource ? null : 'Add a link or attach the clip');

  ClipDraft copyWith({
    String? label,
    String? url,
    String? filePath,
    String? fileName,
    bool clearFile = false,
  }) {
    return ClipDraft(
      id: id,
      label: label ?? this.label,
      url: url ?? this.url,
      filePath: clearFile ? null : (filePath ?? this.filePath),
      fileName: clearFile ? null : (fileName ?? this.fileName),
    );
  }

  Map<String, Object?> toJson() {
    final link = sanitizeText(url);
    return {
      'label': sanitizeText(label),
      if (link.isNotEmpty) 'url': link,
      if (fileName != null) 'fileName': fileName,
    };
  }
}

/// What the creator tells us about the video. Raw text is kept as typed;
/// [toJson] trims and strips control characters.
@immutable
class DeclarationDraft {
  const DeclarationDraft({
    this.caption = '',
    this.isPaid = false,
    this.brand = '',
    this.clips = const [],
    this.category = ContentCategory.general,
  });

  final String caption;
  final bool isPaid;
  final String brand;
  final List<ClipDraft> clips;
  final ContentCategory category;

  /// The first thing stopping submission, phrased as an instruction.
  String? get firstProblem =>
      validateCaption(caption) ??
      validateBrand(brand, isPaid: isPaid) ??
      [for (final clip in clips) clip.error].nonNulls.firstOrNull;

  bool get isValid => firstProblem == null;

  DeclarationDraft copyWith({
    String? caption,
    bool? isPaid,
    String? brand,
    List<ClipDraft>? clips,
    ContentCategory? category,
  }) {
    return DeclarationDraft(
      caption: caption ?? this.caption,
      isPaid: isPaid ?? this.isPaid,
      brand: brand ?? this.brand,
      clips: clips ?? this.clips,
      category: category ?? this.category,
    );
  }

  Map<String, Object?> toJson() => {
    'caption': sanitizeText(caption),
    'isPaid': isPaid,
    if (isPaid) 'brandName': sanitizeText(brand),
    'borrowedClips': [for (final clip in clips) clip.toJson()],
    'category': category.name,
  };
}
