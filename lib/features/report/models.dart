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

/// Who stands behind a compliance clause.
enum Authority {
  @JsonValue('self_regulatory')
  selfRegulatory,
  statutory,
  unknown,
}

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

  List<Flag> get issues => [
    for (final flag in flags)
      if (flag.isIssue) flag,
  ];

  List<Flag> get checkedClaims => [
    for (final flag in flags)
      if (flag.isCheckedClaim) flag,
  ];

  /// Flags the evidence gate couldn't confirm: listed for a human look,
  /// never counted as issues.
  List<Flag> get uncertainFlags => [
    for (final flag in flags)
      if (flag.uncertain) flag,
  ];

  /// Issue counts by category in display order, skipping empty ones. Falls
  /// back to the backend summary when the flag list isn't loaded.
  Map<FlagCategory, int> get issueCounts {
    if (flags.isEmpty) {
      return summary?.counts ?? const <FlagCategory, int>{};
    }
    final counts = <FlagCategory, int>{};
    for (final flag in issues) {
      counts[flag.category] = (counts[flag.category] ?? 0) + 1;
    }
    return {
      for (final c in FlagCategory.values)
        if (counts[c] != null) c: counts[c]!,
    };
  }
}

@freezed
abstract class Flag with _$Flag {
  const factory Flag({
    required String id,
    required String fingerprint,
    @JsonKey(unknownEnumValue: FlagCategory.unknown)
    required FlagCategory category,
    required int startMs,
    required int endMs,
    required String title,
    required String evidence,
    required String suggestedFix,

    /// Absent for checked claims (fact label "supported"), which are not
    /// issues.
    @JsonKey(unknownEnumValue: Severity.unknown) Severity? severity,
    Citation? citation,

    /// The verbatim passage the evidence gate matched.
    SourceQuote? sourceQuote,
    @JsonKey(unknownEnumValue: FactLabel.unknown) FactLabel? factLabel,
    TranscriptDiff? diff,

    /// The evidence gate couldn't verify this flag, so it needs a human
    /// look instead of a fix.
    @Default(false) bool uncertain,
  }) = _Flag;

  const Flag._();

  factory Flag.fromJson(Map<String, dynamic> json) => _$FlagFromJson(json);

  /// A fact check that came back "supported" is shown as a checked claim,
  /// never as an issue, and is excluded from every count. So is an
  /// uncertain flag.
  bool get isIssue => !uncertain && factLabel != FactLabel.supported;

  bool get isCheckedClaim => !uncertain && factLabel == FactLabel.supported;
}

@freezed
abstract class Citation with _$Citation {
  const factory Citation({
    required String title,
    String? url,
    String? publisher,

    /// Stable ID of the clause in the backend's clause index.
    String? clauseId,

    /// Short name of the code or law, for example "ASCI Influencer
    /// Guidelines".
    String? instrument,

    /// The exact clause, for example "1.2(c)" or "s. 3(d)".
    String? clause,
    @JsonKey(unknownEnumValue: Authority.unknown) Authority? authority,
  }) = _Citation;

  const Citation._();

  factory Citation.fromJson(Map<String, dynamic> json) =>
      _$CitationFromJson(json);

  /// "ASCI Influencer Guidelines, 1.2(c)", or null when this cites a
  /// source rather than a rule.
  String? get clauseLabel {
    final clause = this.clause;
    if (clause == null) return null;
    return '${instrument ?? publisher ?? title}, $clause';
  }
}

@freezed
abstract class SourceQuote with _$SourceQuote {
  const factory SourceQuote({required String text, required String source}) =
      _SourceQuote;

  factory SourceQuote.fromJson(Map<String, dynamic> json) =>
      _$SourceQuoteFromJson(json);
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
