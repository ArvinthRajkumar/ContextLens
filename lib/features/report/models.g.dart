// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Job _$JobFromJson(Map<String, dynamic> json) => _Job(
  id: json['id'] as String,
  status: $enumDecode(
    _$JobStatusEnumMap,
    json['status'],
    unknownValue: JobStatus.unknown,
  ),
  createdAt: DateTime.parse(json['createdAt'] as String),
  ownerUid: json['ownerUid'] as String?,
  stage: $enumDecodeNullable(
    _$JobStageEnumMap,
    json['stage'],
    unknownValue: JobStage.unknown,
  ),
  stageDetail: json['stageDetail'] as String?,
  version: (json['version'] as num?)?.toInt() ?? 1,
  parentJobId: json['parentJobId'] as String?,
  title: json['title'] as String?,
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  video: json['video'] == null
      ? null
      : VideoMeta.fromJson(json['video'] as Map<String, dynamic>),
  summary: json['summary'] == null
      ? null
      : JobSummary.fromJson(json['summary'] as Map<String, dynamic>),
  comparison: json['comparison'] == null
      ? null
      : RunComparison.fromJson(json['comparison'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : JobError.fromJson(json['error'] as Map<String, dynamic>),
  flags:
      (json['flags'] as List<dynamic>?)
          ?.map((e) => Flag.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Flag>[],
);

Map<String, dynamic> _$JobToJson(_Job instance) => <String, dynamic>{
  'id': instance.id,
  'status': _$JobStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'ownerUid': instance.ownerUid,
  'stage': _$JobStageEnumMap[instance.stage],
  'stageDetail': instance.stageDetail,
  'version': instance.version,
  'parentJobId': instance.parentJobId,
  'title': instance.title,
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'video': instance.video?.toJson(),
  'summary': instance.summary?.toJson(),
  'comparison': instance.comparison?.toJson(),
  'error': instance.error?.toJson(),
  'flags': instance.flags.map((e) => e.toJson()).toList(),
};

const _$JobStatusEnumMap = {
  JobStatus.uploading: 'uploading',
  JobStatus.queued: 'queued',
  JobStatus.processing: 'processing',
  JobStatus.done: 'done',
  JobStatus.failed: 'failed',
  JobStatus.unknown: 'unknown',
};

const _$JobStageEnumMap = {
  JobStage.extract: 'extract',
  JobStage.claims: 'claims',
  JobStage.checking: 'checking',
  JobStage.evidence: 'evidence',
  JobStage.report: 'report',
  JobStage.unknown: 'unknown',
};

_Flag _$FlagFromJson(Map<String, dynamic> json) => _Flag(
  id: json['id'] as String,
  fingerprint: json['fingerprint'] as String,
  category: $enumDecode(
    _$FlagCategoryEnumMap,
    json['category'],
    unknownValue: FlagCategory.unknown,
  ),
  startMs: (json['startMs'] as num).toInt(),
  endMs: (json['endMs'] as num).toInt(),
  title: json['title'] as String,
  evidence: json['evidence'] as String,
  suggestedFix: json['suggestedFix'] as String,
  severity: $enumDecodeNullable(
    _$SeverityEnumMap,
    json['severity'],
    unknownValue: Severity.unknown,
  ),
  citation: json['citation'] == null
      ? null
      : Citation.fromJson(json['citation'] as Map<String, dynamic>),
  sourceQuote: json['sourceQuote'] == null
      ? null
      : SourceQuote.fromJson(json['sourceQuote'] as Map<String, dynamic>),
  factLabel: $enumDecodeNullable(
    _$FactLabelEnumMap,
    json['factLabel'],
    unknownValue: FactLabel.unknown,
  ),
  diff: json['diff'] == null
      ? null
      : TranscriptDiff.fromJson(json['diff'] as Map<String, dynamic>),
  uncertain: json['uncertain'] as bool? ?? false,
);

Map<String, dynamic> _$FlagToJson(_Flag instance) => <String, dynamic>{
  'id': instance.id,
  'fingerprint': instance.fingerprint,
  'category': _$FlagCategoryEnumMap[instance.category]!,
  'startMs': instance.startMs,
  'endMs': instance.endMs,
  'title': instance.title,
  'evidence': instance.evidence,
  'suggestedFix': instance.suggestedFix,
  'severity': _$SeverityEnumMap[instance.severity],
  'citation': instance.citation?.toJson(),
  'sourceQuote': instance.sourceQuote?.toJson(),
  'factLabel': _$FactLabelEnumMap[instance.factLabel],
  'diff': instance.diff?.toJson(),
  'uncertain': instance.uncertain,
};

const _$FlagCategoryEnumMap = {
  FlagCategory.disclosure: 'disclosure',
  FlagCategory.claims: 'claims',
  FlagCategory.visuals: 'visuals',
  FlagCategory.borrowed: 'borrowed',
  FlagCategory.factcheck: 'factcheck',
  FlagCategory.unknown: 'unknown',
};

const _$SeverityEnumMap = {
  Severity.high: 'high',
  Severity.medium: 'medium',
  Severity.low: 'low',
  Severity.unknown: 'unknown',
};

const _$FactLabelEnumMap = {
  FactLabel.supported: 'supported',
  FactLabel.contradicted: 'contradicted',
  FactLabel.previouslyFactChecked: 'previously_fact_checked',
  FactLabel.insufficientEvidence: 'insufficient_evidence',
  FactLabel.unknown: 'unknown',
};

_Citation _$CitationFromJson(Map<String, dynamic> json) => _Citation(
  title: json['title'] as String,
  url: json['url'] as String?,
  publisher: json['publisher'] as String?,
  clauseId: json['clauseId'] as String?,
  instrument: json['instrument'] as String?,
  clause: json['clause'] as String?,
  authority: $enumDecodeNullable(
    _$AuthorityEnumMap,
    json['authority'],
    unknownValue: Authority.unknown,
  ),
);

Map<String, dynamic> _$CitationToJson(_Citation instance) => <String, dynamic>{
  'title': instance.title,
  'url': instance.url,
  'publisher': instance.publisher,
  'clauseId': instance.clauseId,
  'instrument': instance.instrument,
  'clause': instance.clause,
  'authority': _$AuthorityEnumMap[instance.authority],
};

const _$AuthorityEnumMap = {
  Authority.selfRegulatory: 'self_regulatory',
  Authority.statutory: 'statutory',
  Authority.unknown: 'unknown',
};

_SourceQuote _$SourceQuoteFromJson(Map<String, dynamic> json) => _SourceQuote(
  text: json['text'] as String,
  source: json['source'] as String,
);

Map<String, dynamic> _$SourceQuoteToJson(_SourceQuote instance) =>
    <String, dynamic>{'text': instance.text, 'source': instance.source};

_TranscriptDiff _$TranscriptDiffFromJson(Map<String, dynamic> json) =>
    _TranscriptDiff(
      clipTranscript: json['clipTranscript'] as String,
      originalTranscript: json['originalTranscript'] as String,
      segments:
          (json['segments'] as List<dynamic>?)
              ?.map((e) => DiffSegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <DiffSegment>[],
    );

Map<String, dynamic> _$TranscriptDiffToJson(_TranscriptDiff instance) =>
    <String, dynamic>{
      'clipTranscript': instance.clipTranscript,
      'originalTranscript': instance.originalTranscript,
      'segments': instance.segments.map((e) => e.toJson()).toList(),
    };

_DiffSegment _$DiffSegmentFromJson(Map<String, dynamic> json) => _DiffSegment(
  op: $enumDecode(_$DiffOpEnumMap, json['op'], unknownValue: DiffOp.equal),
  text: json['text'] as String,
);

Map<String, dynamic> _$DiffSegmentToJson(_DiffSegment instance) =>
    <String, dynamic>{
      'op': _$DiffOpEnumMap[instance.op]!,
      'text': instance.text,
    };

const _$DiffOpEnumMap = {
  DiffOp.equal: 'equal',
  DiffOp.insert: 'insert',
  DiffOp.delete: 'delete',
};

_VideoMeta _$VideoMetaFromJson(Map<String, dynamic> json) => _VideoMeta(
  durationMs: (json['durationMs'] as num).toInt(),
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
);

Map<String, dynamic> _$VideoMetaToJson(_VideoMeta instance) =>
    <String, dynamic>{
      'durationMs': instance.durationMs,
      'width': instance.width,
      'height': instance.height,
    };

_JobSummary _$JobSummaryFromJson(Map<String, dynamic> json) => _JobSummary(
  total: (json['total'] as num).toInt(),
  byCategory:
      (json['byCategory'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const <String, int>{},
);

Map<String, dynamic> _$JobSummaryToJson(_JobSummary instance) =>
    <String, dynamic>{
      'total': instance.total,
      'byCategory': instance.byCategory,
    };

_RunComparison _$RunComparisonFromJson(Map<String, dynamic> json) =>
    _RunComparison(
      previousJobId: json['previousJobId'] as String,
      resolved: (json['resolved'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      newCount: (json['newCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RunComparisonToJson(_RunComparison instance) =>
    <String, dynamic>{
      'previousJobId': instance.previousJobId,
      'resolved': instance.resolved,
      'remaining': instance.remaining,
      'newCount': instance.newCount,
    };

_JobError _$JobErrorFromJson(Map<String, dynamic> json) =>
    _JobError(code: json['code'] as String, message: json['message'] as String);

Map<String, dynamic> _$JobErrorToJson(_JobError instance) => <String, dynamic>{
  'code': instance.code,
  'message': instance.message,
};
