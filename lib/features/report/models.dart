import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

// Every enum has an `unknown` member so a newer backend value never crashes
// parsing; widgets render it with neutral styling.

enum JobStatus { uploading, queued, processing, done, failed, unknown }

enum JobStage { extract, claims, checking, evidence, report, unknown }

enum FlagCategory { disclosure, claims, visuals, borrowed, factcheck, unknown }

enum Severity { high, medium, low, unknown }

enum FactLabel {
  supported,
  contradicted,
  @JsonValue('previously_fact_checked')
  previouslyFactChecked,
  @JsonValue('insufficient_evidence')
  insufficientEvidence,
  unknown,
}

enum DiffOp { equal, insert, delete }

@freezed
abstract class Job with _$Job {
  const factory Job({
    required String id,
    @JsonKey(unknownEnumValue: JobStatus.unknown) required JobStatus status,
    required DateTime createdAt,
    String? ownerUid,
    @JsonKey(unknownEnumValue: JobStage.unknown) JobStage? stage,
    String? stageDetail,
    @Default(1) int version,
    String? parentJobId,

    /// Client-side label (first line of the caption). Not part of the
    /// backend schema yet.
    String? title,
    DateTime? updatedAt,
    DateTime? expiresAt,
    VideoMeta? video,
    JobSummary? summary,
    RunComparison? comparison,
    JobError? error,
    @Default(<Flag>[]) List<Flag> flags,
  }) = _Job;

  const Job._();

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  bool get isActive =>
      status == JobStatus.uploading ||
      status == JobStatus.queued ||
      status == JobStatus.processing;
}

@freezed
abstract class Flag with _$Flag {
  const factory Flag({
    required String id,
    required String fingerprint,
    @JsonKey(unknownEnumValue: FlagCategory.unknown)
    required FlagCategory category,
    @JsonKey(unknownEnumValue: Severity.unknown) required Severity severity,
    required int startMs,
    required int endMs,
    required String title,
    required String evidence,
    required String suggestedFix,
    Citation? citation,
    @JsonKey(unknownEnumValue: FactLabel.unknown) FactLabel? factLabel,
    TranscriptDiff? diff,
  }) = _Flag;

  factory Flag.fromJson(Map<String, dynamic> json) => _$FlagFromJson(json);
}

@freezed
abstract class Citation with _$Citation {
  const factory Citation({
    required String title,
    required String url,
    String? publisher,
  }) = _Citation;

  factory Citation.fromJson(Map<String, dynamic> json) =>
      _$CitationFromJson(json);
}

@freezed
abstract class TranscriptDiff with _$TranscriptDiff {
  const factory TranscriptDiff({
    required String clipTranscript,
    required String originalTranscript,
    @Default(<DiffSegment>[]) List<DiffSegment> segments,
  }) = _TranscriptDiff;

  factory TranscriptDiff.fromJson(Map<String, dynamic> json) =>
      _$TranscriptDiffFromJson(json);
}

@freezed
abstract class DiffSegment with _$DiffSegment {
  const factory DiffSegment({
    @JsonKey(unknownEnumValue: DiffOp.equal) required DiffOp op,
    required String text,
  }) = _DiffSegment;

  factory DiffSegment.fromJson(Map<String, dynamic> json) =>
      _$DiffSegmentFromJson(json);
}

@freezed
abstract class VideoMeta with _$VideoMeta {
  const factory VideoMeta({
    required int durationMs,
    required int width,
    required int height,
  }) = _VideoMeta;

  factory VideoMeta.fromJson(Map<String, dynamic> json) =>
      _$VideoMetaFromJson(json);
}

@freezed
abstract class JobSummary with _$JobSummary {
  const factory JobSummary({
    required int total,
    @Default(<String, int>{}) Map<String, int> byCategory,
  }) = _JobSummary;

  const JobSummary._();

  factory JobSummary.fromJson(Map<String, dynamic> json) =>
      _$JobSummaryFromJson(json);

  /// Counts keyed by category, in display order, skipping empty ones.
  /// Unrecognized keys are folded into [FlagCategory.unknown].
  Map<FlagCategory, int> get counts {
    final result = <FlagCategory, int>{};
    for (final entry in byCategory.entries) {
      if (entry.value <= 0) continue;
      final category = FlagCategory.values.firstWhere(
        (c) => c.name == entry.key,
        orElse: () => FlagCategory.unknown,
      );
      result[category] = (result[category] ?? 0) + entry.value;
    }
    return {
      for (final c in FlagCategory.values)
        if (result[c] != null) c: result[c]!,
    };
  }
}

@freezed
abstract class RunComparison with _$RunComparison {
  const factory RunComparison({
    required String previousJobId,
    required int resolved,
    required int remaining,
    @Default(0) int newCount,
  }) = _RunComparison;

  factory RunComparison.fromJson(Map<String, dynamic> json) =>
      _$RunComparisonFromJson(json);
}

@freezed
abstract class JobError with _$JobError {
  const factory JobError({required String code, required String message}) =
      _JobError;

  factory JobError.fromJson(Map<String, dynamic> json) =>
      _$JobErrorFromJson(json);
}
