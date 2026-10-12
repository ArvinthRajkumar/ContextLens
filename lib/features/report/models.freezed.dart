// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Job {

 String get id;@JsonKey(unknownEnumValue: JobStatus.unknown) JobStatus get status; DateTime get createdAt; String? get ownerUid;@JsonKey(unknownEnumValue: JobStage.unknown) JobStage? get stage; String? get stageDetail; int get version; String? get parentJobId;/// Client-side label (first line of the caption). Not part of the
/// backend schema yet.
 String? get title; DateTime? get updatedAt; DateTime? get expiresAt; VideoMeta? get video; JobSummary? get summary; RunComparison? get comparison; JobError? get error; List<Flag> get flags;
/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobCopyWith<Job> get copyWith => _$JobCopyWithImpl<Job>(this as Job, _$identity);

  /// Serializes this Job to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Job;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Job&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.ownerUid, _this.ownerUid) || other.ownerUid == _this.ownerUid)&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.stageDetail, _this.stageDetail) || other.stageDetail == _this.stageDetail)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.parentJobId, _this.parentJobId) || other.parentJobId == _this.parentJobId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.video, _this.video) || other.video == _this.video)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.comparison, _this.comparison) || other.comparison == _this.comparison)&&(identical(other.error, _this.error) || other.error == _this.error)&&const DeepCollectionEquality().equals(other.flags, _this.flags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Job;
  return Object.hash(runtimeType,_this.id,_this.status,_this.createdAt,_this.ownerUid,_this.stage,_this.stageDetail,_this.version,_this.parentJobId,_this.title,_this.updatedAt,_this.expiresAt,_this.video,_this.summary,_this.comparison,_this.error,const DeepCollectionEquality().hash(_this.flags));
}

@override
String toString() {
  final _this = this as Job;
  return 'Job(id: ${_this.id}, status: ${_this.status}, createdAt: ${_this.createdAt}, ownerUid: ${_this.ownerUid}, stage: ${_this.stage}, stageDetail: ${_this.stageDetail}, version: ${_this.version}, parentJobId: ${_this.parentJobId}, title: ${_this.title}, updatedAt: ${_this.updatedAt}, expiresAt: ${_this.expiresAt}, video: ${_this.video}, summary: ${_this.summary}, comparison: ${_this.comparison}, error: ${_this.error}, flags: ${_this.flags})';
}


}

/// @nodoc
abstract mixin class $JobCopyWith<$Res>  {
  factory $JobCopyWith(Job value, $Res Function(Job) _then) = _$JobCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: JobStatus.unknown) JobStatus status, DateTime createdAt, String? ownerUid,@JsonKey(unknownEnumValue: JobStage.unknown) JobStage? stage, String? stageDetail, int version, String? parentJobId, String? title, DateTime? updatedAt, DateTime? expiresAt, VideoMeta? video, JobSummary? summary, RunComparison? comparison, JobError? error, List<Flag> flags
});


$VideoMetaCopyWith<$Res>? get video;$JobSummaryCopyWith<$Res>? get summary;$RunComparisonCopyWith<$Res>? get comparison;$JobErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$JobCopyWithImpl<$Res>
    implements $JobCopyWith<$Res> {
  _$JobCopyWithImpl(this._self, this._then);

  final Job _self;
  final $Res Function(Job) _then;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? createdAt = null,Object? ownerUid = freezed,Object? stage = freezed,Object? stageDetail = freezed,Object? version = null,Object? parentJobId = freezed,Object? title = freezed,Object? updatedAt = freezed,Object? expiresAt = freezed,Object? video = freezed,Object? summary = freezed,Object? comparison = freezed,Object? error = freezed,Object? flags = null,}) {
  return _then(Job(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ownerUid: freezed == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as String?,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as JobStage?,stageDetail: freezed == stageDetail ? _self.stageDetail : stageDetail // ignore: cast_nullable_to_non_nullable
as String?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,parentJobId: freezed == parentJobId ? _self.parentJobId : parentJobId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,video: freezed == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as VideoMeta?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as JobSummary?,comparison: freezed == comparison ? _self.comparison : comparison // ignore: cast_nullable_to_non_nullable
as RunComparison?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as JobError?,flags: null == flags ? _self.flags : flags // ignore: cast_nullable_to_non_nullable
as List<Flag>,
  ));
}
/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VideoMetaCopyWith<$Res>? get video {
    if (_self.video == null) {
    return null;
  }

  return $VideoMetaCopyWith<$Res>(_self.video!, (value) {
    return _then(_self.copyWith(video: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $JobSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RunComparisonCopyWith<$Res>? get comparison {
    if (_self.comparison == null) {
    return null;
  }

  return $RunComparisonCopyWith<$Res>(_self.comparison!, (value) {
    return _then(_self.copyWith(comparison: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $JobErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [Job].
extension JobPatterns on Job {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Job value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Job value)  $default,){
final _that = this;
switch (_that) {
case _Job():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Job value)?  $default,){
final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: JobStatus.unknown)  JobStatus status,  DateTime createdAt,  String? ownerUid, @JsonKey(unknownEnumValue: JobStage.unknown)  JobStage? stage,  String? stageDetail,  int version,  String? parentJobId,  String? title,  DateTime? updatedAt,  DateTime? expiresAt,  VideoMeta? video,  JobSummary? summary,  RunComparison? comparison,  JobError? error,  List<Flag> flags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that.id,_that.status,_that.createdAt,_that.ownerUid,_that.stage,_that.stageDetail,_that.version,_that.parentJobId,_that.title,_that.updatedAt,_that.expiresAt,_that.video,_that.summary,_that.comparison,_that.error,_that.flags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: JobStatus.unknown)  JobStatus status,  DateTime createdAt,  String? ownerUid, @JsonKey(unknownEnumValue: JobStage.unknown)  JobStage? stage,  String? stageDetail,  int version,  String? parentJobId,  String? title,  DateTime? updatedAt,  DateTime? expiresAt,  VideoMeta? video,  JobSummary? summary,  RunComparison? comparison,  JobError? error,  List<Flag> flags)  $default,) {final _that = this;
switch (_that) {
case _Job():
return $default(_that.id,_that.status,_that.createdAt,_that.ownerUid,_that.stage,_that.stageDetail,_that.version,_that.parentJobId,_that.title,_that.updatedAt,_that.expiresAt,_that.video,_that.summary,_that.comparison,_that.error,_that.flags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(unknownEnumValue: JobStatus.unknown)  JobStatus status,  DateTime createdAt,  String? ownerUid, @JsonKey(unknownEnumValue: JobStage.unknown)  JobStage? stage,  String? stageDetail,  int version,  String? parentJobId,  String? title,  DateTime? updatedAt,  DateTime? expiresAt,  VideoMeta? video,  JobSummary? summary,  RunComparison? comparison,  JobError? error,  List<Flag> flags)?  $default,) {final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that.id,_that.status,_that.createdAt,_that.ownerUid,_that.stage,_that.stageDetail,_that.version,_that.parentJobId,_that.title,_that.updatedAt,_that.expiresAt,_that.video,_that.summary,_that.comparison,_that.error,_that.flags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Job extends Job {
  const _Job({required this.id, @JsonKey(unknownEnumValue: JobStatus.unknown) required this.status, required this.createdAt, this.ownerUid, @JsonKey(unknownEnumValue: JobStage.unknown) this.stage, this.stageDetail, this.version = 1, this.parentJobId, this.title, this.updatedAt, this.expiresAt, this.video, this.summary, this.comparison, this.error,  List<Flag> flags = const <Flag>[]}): _flags = flags,super._();
  factory _Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

@override final  String id;
@override@JsonKey(unknownEnumValue: JobStatus.unknown) final  JobStatus status;
@override final  DateTime createdAt;
@override final  String? ownerUid;
@override@JsonKey(unknownEnumValue: JobStage.unknown) final  JobStage? stage;
@override final  String? stageDetail;
@override@JsonKey() final  int version;
@override final  String? parentJobId;
/// Client-side label (first line of the caption). Not part of the
/// backend schema yet.
@override final  String? title;
@override final  DateTime? updatedAt;
@override final  DateTime? expiresAt;
@override final  VideoMeta? video;
@override final  JobSummary? summary;
@override final  RunComparison? comparison;
@override final  JobError? error;
 final  List<Flag> _flags;
@override@JsonKey() List<Flag> get flags {
  if (_flags is EqualUnmodifiableListView) return _flags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_flags);
}


/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobCopyWith<_Job> get copyWith => __$JobCopyWithImpl<_Job>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Job&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.stageDetail, stageDetail) || other.stageDetail == stageDetail)&&(identical(other.version, version) || other.version == version)&&(identical(other.parentJobId, parentJobId) || other.parentJobId == parentJobId)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.video, video) || other.video == video)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.comparison, comparison) || other.comparison == comparison)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.flags, _flags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,status,createdAt,ownerUid,stage,stageDetail,version,parentJobId,title,updatedAt,expiresAt,video,summary,comparison,error,const DeepCollectionEquality().hash(_flags));
}

@override
String toString() {
    return 'Job(id: $id, status: $status, createdAt: $createdAt, ownerUid: $ownerUid, stage: $stage, stageDetail: $stageDetail, version: $version, parentJobId: $parentJobId, title: $title, updatedAt: $updatedAt, expiresAt: $expiresAt, video: $video, summary: $summary, comparison: $comparison, error: $error, flags: $flags)';
}


}

/// @nodoc
abstract mixin class _$JobCopyWith<$Res> implements $JobCopyWith<$Res> {
  factory _$JobCopyWith(_Job value, $Res Function(_Job) _then) = __$JobCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: JobStatus.unknown) JobStatus status, DateTime createdAt, String? ownerUid,@JsonKey(unknownEnumValue: JobStage.unknown) JobStage? stage, String? stageDetail, int version, String? parentJobId, String? title, DateTime? updatedAt, DateTime? expiresAt, VideoMeta? video, JobSummary? summary, RunComparison? comparison, JobError? error, List<Flag> flags
});


@override $VideoMetaCopyWith<$Res>? get video;@override $JobSummaryCopyWith<$Res>? get summary;@override $RunComparisonCopyWith<$Res>? get comparison;@override $JobErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$JobCopyWithImpl<$Res>
    implements _$JobCopyWith<$Res> {
  __$JobCopyWithImpl(this._self, this._then);

  final _Job _self;
  final $Res Function(_Job) _then;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? createdAt = null,Object? ownerUid = freezed,Object? stage = freezed,Object? stageDetail = freezed,Object? version = null,Object? parentJobId = freezed,Object? title = freezed,Object? updatedAt = freezed,Object? expiresAt = freezed,Object? video = freezed,Object? summary = freezed,Object? comparison = freezed,Object? error = freezed,Object? flags = null,}) {
  return _then(_Job(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ownerUid: freezed == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as String?,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as JobStage?,stageDetail: freezed == stageDetail ? _self.stageDetail : stageDetail // ignore: cast_nullable_to_non_nullable
as String?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,parentJobId: freezed == parentJobId ? _self.parentJobId : parentJobId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,video: freezed == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as VideoMeta?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as JobSummary?,comparison: freezed == comparison ? _self.comparison : comparison // ignore: cast_nullable_to_non_nullable
as RunComparison?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as JobError?,flags: null == flags ? _self._flags : flags // ignore: cast_nullable_to_non_nullable
as List<Flag>,
  ));
}

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VideoMetaCopyWith<$Res>? get video {
    if (_self.video == null) {
    return null;
  }

  return $VideoMetaCopyWith<$Res>(_self.video!, (value) {
    return _then(_self.copyWith(video: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $JobSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RunComparisonCopyWith<$Res>? get comparison {
    if (_self.comparison == null) {
    return null;
  }

  return $RunComparisonCopyWith<$Res>(_self.comparison!, (value) {
    return _then(_self.copyWith(comparison: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $JobErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$Flag {

 String get id; String get fingerprint;@JsonKey(unknownEnumValue: FlagCategory.unknown) FlagCategory get category; int get startMs; int get endMs; String get title; String get evidence; String get suggestedFix;/// Absent for checked claims (fact label "supported"), which are not
/// issues.
@JsonKey(unknownEnumValue: Severity.unknown) Severity? get severity; Citation? get citation;@JsonKey(unknownEnumValue: FactLabel.unknown) FactLabel? get factLabel; TranscriptDiff? get diff;
/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlagCopyWith<Flag> get copyWith => _$FlagCopyWithImpl<Flag>(this as Flag, _$identity);

  /// Serializes this Flag to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Flag;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Flag&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.fingerprint, _this.fingerprint) || other.fingerprint == _this.fingerprint)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.startMs, _this.startMs) || other.startMs == _this.startMs)&&(identical(other.endMs, _this.endMs) || other.endMs == _this.endMs)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.evidence, _this.evidence) || other.evidence == _this.evidence)&&(identical(other.suggestedFix, _this.suggestedFix) || other.suggestedFix == _this.suggestedFix)&&(identical(other.severity, _this.severity) || other.severity == _this.severity)&&(identical(other.citation, _this.citation) || other.citation == _this.citation)&&(identical(other.factLabel, _this.factLabel) || other.factLabel == _this.factLabel)&&(identical(other.diff, _this.diff) || other.diff == _this.diff));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Flag;
  return Object.hash(runtimeType,_this.id,_this.fingerprint,_this.category,_this.startMs,_this.endMs,_this.title,_this.evidence,_this.suggestedFix,_this.severity,_this.citation,_this.factLabel,_this.diff);
}

@override
String toString() {
  final _this = this as Flag;
  return 'Flag(id: ${_this.id}, fingerprint: ${_this.fingerprint}, category: ${_this.category}, startMs: ${_this.startMs}, endMs: ${_this.endMs}, title: ${_this.title}, evidence: ${_this.evidence}, suggestedFix: ${_this.suggestedFix}, severity: ${_this.severity}, citation: ${_this.citation}, factLabel: ${_this.factLabel}, diff: ${_this.diff})';
}


}

/// @nodoc
abstract mixin class $FlagCopyWith<$Res>  {
  factory $FlagCopyWith(Flag value, $Res Function(Flag) _then) = _$FlagCopyWithImpl;
@useResult
$Res call({
 String id, String fingerprint,@JsonKey(unknownEnumValue: FlagCategory.unknown) FlagCategory category, int startMs, int endMs, String title, String evidence, String suggestedFix,@JsonKey(unknownEnumValue: Severity.unknown) Severity? severity, Citation? citation,@JsonKey(unknownEnumValue: FactLabel.unknown) FactLabel? factLabel, TranscriptDiff? diff
});


$CitationCopyWith<$Res>? get citation;$TranscriptDiffCopyWith<$Res>? get diff;

}
/// @nodoc
class _$FlagCopyWithImpl<$Res>
    implements $FlagCopyWith<$Res> {
  _$FlagCopyWithImpl(this._self, this._then);

  final Flag _self;
  final $Res Function(Flag) _then;

/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fingerprint = null,Object? category = null,Object? startMs = null,Object? endMs = null,Object? title = null,Object? evidence = null,Object? suggestedFix = null,Object? severity = freezed,Object? citation = freezed,Object? factLabel = freezed,Object? diff = freezed,}) {
  return _then(Flag(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as FlagCategory,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,evidence: null == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as String,suggestedFix: null == suggestedFix ? _self.suggestedFix : suggestedFix // ignore: cast_nullable_to_non_nullable
as String,severity: freezed == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as Severity?,citation: freezed == citation ? _self.citation : citation // ignore: cast_nullable_to_non_nullable
as Citation?,factLabel: freezed == factLabel ? _self.factLabel : factLabel // ignore: cast_nullable_to_non_nullable
as FactLabel?,diff: freezed == diff ? _self.diff : diff // ignore: cast_nullable_to_non_nullable
as TranscriptDiff?,
  ));
}
/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CitationCopyWith<$Res>? get citation {
    if (_self.citation == null) {
    return null;
  }

  return $CitationCopyWith<$Res>(_self.citation!, (value) {
    return _then(_self.copyWith(citation: value));
  });
}/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TranscriptDiffCopyWith<$Res>? get diff {
    if (_self.diff == null) {
    return null;
  }

  return $TranscriptDiffCopyWith<$Res>(_self.diff!, (value) {
    return _then(_self.copyWith(diff: value));
  });
}
}


/// Adds pattern-matching-related methods to [Flag].
extension FlagPatterns on Flag {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Flag value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Flag() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Flag value)  $default,){
final _that = this;
switch (_that) {
case _Flag():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Flag value)?  $default,){
final _that = this;
switch (_that) {
case _Flag() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fingerprint, @JsonKey(unknownEnumValue: FlagCategory.unknown)  FlagCategory category,  int startMs,  int endMs,  String title,  String evidence,  String suggestedFix, @JsonKey(unknownEnumValue: Severity.unknown)  Severity? severity,  Citation? citation, @JsonKey(unknownEnumValue: FactLabel.unknown)  FactLabel? factLabel,  TranscriptDiff? diff)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Flag() when $default != null:
return $default(_that.id,_that.fingerprint,_that.category,_that.startMs,_that.endMs,_that.title,_that.evidence,_that.suggestedFix,_that.severity,_that.citation,_that.factLabel,_that.diff);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fingerprint, @JsonKey(unknownEnumValue: FlagCategory.unknown)  FlagCategory category,  int startMs,  int endMs,  String title,  String evidence,  String suggestedFix, @JsonKey(unknownEnumValue: Severity.unknown)  Severity? severity,  Citation? citation, @JsonKey(unknownEnumValue: FactLabel.unknown)  FactLabel? factLabel,  TranscriptDiff? diff)  $default,) {final _that = this;
switch (_that) {
case _Flag():
return $default(_that.id,_that.fingerprint,_that.category,_that.startMs,_that.endMs,_that.title,_that.evidence,_that.suggestedFix,_that.severity,_that.citation,_that.factLabel,_that.diff);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fingerprint, @JsonKey(unknownEnumValue: FlagCategory.unknown)  FlagCategory category,  int startMs,  int endMs,  String title,  String evidence,  String suggestedFix, @JsonKey(unknownEnumValue: Severity.unknown)  Severity? severity,  Citation? citation, @JsonKey(unknownEnumValue: FactLabel.unknown)  FactLabel? factLabel,  TranscriptDiff? diff)?  $default,) {final _that = this;
switch (_that) {
case _Flag() when $default != null:
return $default(_that.id,_that.fingerprint,_that.category,_that.startMs,_that.endMs,_that.title,_that.evidence,_that.suggestedFix,_that.severity,_that.citation,_that.factLabel,_that.diff);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Flag extends Flag {
  const _Flag({required this.id, required this.fingerprint, @JsonKey(unknownEnumValue: FlagCategory.unknown) required this.category, required this.startMs, required this.endMs, required this.title, required this.evidence, required this.suggestedFix, @JsonKey(unknownEnumValue: Severity.unknown) this.severity, this.citation, @JsonKey(unknownEnumValue: FactLabel.unknown) this.factLabel, this.diff}): super._();
  factory _Flag.fromJson(Map<String, dynamic> json) => _$FlagFromJson(json);

@override final  String id;
@override final  String fingerprint;
@override@JsonKey(unknownEnumValue: FlagCategory.unknown) final  FlagCategory category;
@override final  int startMs;
@override final  int endMs;
@override final  String title;
@override final  String evidence;
@override final  String suggestedFix;
/// Absent for checked claims (fact label "supported"), which are not
/// issues.
@override@JsonKey(unknownEnumValue: Severity.unknown) final  Severity? severity;
@override final  Citation? citation;
@override@JsonKey(unknownEnumValue: FactLabel.unknown) final  FactLabel? factLabel;
@override final  TranscriptDiff? diff;

/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlagCopyWith<_Flag> get copyWith => __$FlagCopyWithImpl<_Flag>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlagToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Flag&&(identical(other.id, id) || other.id == id)&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.category, category) || other.category == category)&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.title, title) || other.title == title)&&(identical(other.evidence, evidence) || other.evidence == evidence)&&(identical(other.suggestedFix, suggestedFix) || other.suggestedFix == suggestedFix)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.citation, citation) || other.citation == citation)&&(identical(other.factLabel, factLabel) || other.factLabel == factLabel)&&(identical(other.diff, diff) || other.diff == diff));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,fingerprint,category,startMs,endMs,title,evidence,suggestedFix,severity,citation,factLabel,diff);
}

@override
String toString() {
    return 'Flag(id: $id, fingerprint: $fingerprint, category: $category, startMs: $startMs, endMs: $endMs, title: $title, evidence: $evidence, suggestedFix: $suggestedFix, severity: $severity, citation: $citation, factLabel: $factLabel, diff: $diff)';
}


}

/// @nodoc
abstract mixin class _$FlagCopyWith<$Res> implements $FlagCopyWith<$Res> {
  factory _$FlagCopyWith(_Flag value, $Res Function(_Flag) _then) = __$FlagCopyWithImpl;
@override @useResult
$Res call({
 String id, String fingerprint,@JsonKey(unknownEnumValue: FlagCategory.unknown) FlagCategory category, int startMs, int endMs, String title, String evidence, String suggestedFix,@JsonKey(unknownEnumValue: Severity.unknown) Severity? severity, Citation? citation,@JsonKey(unknownEnumValue: FactLabel.unknown) FactLabel? factLabel, TranscriptDiff? diff
});


@override $CitationCopyWith<$Res>? get citation;@override $TranscriptDiffCopyWith<$Res>? get diff;

}
/// @nodoc
class __$FlagCopyWithImpl<$Res>
    implements _$FlagCopyWith<$Res> {
  __$FlagCopyWithImpl(this._self, this._then);

  final _Flag _self;
  final $Res Function(_Flag) _then;

/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fingerprint = null,Object? category = null,Object? startMs = null,Object? endMs = null,Object? title = null,Object? evidence = null,Object? suggestedFix = null,Object? severity = freezed,Object? citation = freezed,Object? factLabel = freezed,Object? diff = freezed,}) {
  return _then(_Flag(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as FlagCategory,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,evidence: null == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as String,suggestedFix: null == suggestedFix ? _self.suggestedFix : suggestedFix // ignore: cast_nullable_to_non_nullable
as String,severity: freezed == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as Severity?,citation: freezed == citation ? _self.citation : citation // ignore: cast_nullable_to_non_nullable
as Citation?,factLabel: freezed == factLabel ? _self.factLabel : factLabel // ignore: cast_nullable_to_non_nullable
as FactLabel?,diff: freezed == diff ? _self.diff : diff // ignore: cast_nullable_to_non_nullable
as TranscriptDiff?,
  ));
}

/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CitationCopyWith<$Res>? get citation {
    if (_self.citation == null) {
    return null;
  }

  return $CitationCopyWith<$Res>(_self.citation!, (value) {
    return _then(_self.copyWith(citation: value));
  });
}/// Create a copy of Flag
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TranscriptDiffCopyWith<$Res>? get diff {
    if (_self.diff == null) {
    return null;
  }

  return $TranscriptDiffCopyWith<$Res>(_self.diff!, (value) {
    return _then(_self.copyWith(diff: value));
  });
}
}


/// @nodoc
mixin _$Citation {

 String get title; String get url; String? get publisher;
/// Create a copy of Citation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CitationCopyWith<Citation> get copyWith => _$CitationCopyWithImpl<Citation>(this as Citation, _$identity);

  /// Serializes this Citation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Citation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Citation&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.publisher, _this.publisher) || other.publisher == _this.publisher));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Citation;
  return Object.hash(runtimeType,_this.title,_this.url,_this.publisher);
}

@override
String toString() {
  final _this = this as Citation;
  return 'Citation(title: ${_this.title}, url: ${_this.url}, publisher: ${_this.publisher})';
}


}

/// @nodoc
abstract mixin class $CitationCopyWith<$Res>  {
  factory $CitationCopyWith(Citation value, $Res Function(Citation) _then) = _$CitationCopyWithImpl;
@useResult
$Res call({
 String title, String url, String? publisher
});




}
/// @nodoc
class _$CitationCopyWithImpl<$Res>
    implements $CitationCopyWith<$Res> {
  _$CitationCopyWithImpl(this._self, this._then);

  final Citation _self;
  final $Res Function(Citation) _then;

/// Create a copy of Citation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? url = null,Object? publisher = freezed,}) {
  return _then(Citation(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Citation].
extension CitationPatterns on Citation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Citation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Citation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Citation value)  $default,){
final _that = this;
switch (_that) {
case _Citation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Citation value)?  $default,){
final _that = this;
switch (_that) {
case _Citation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String url,  String? publisher)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Citation() when $default != null:
return $default(_that.title,_that.url,_that.publisher);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String url,  String? publisher)  $default,) {final _that = this;
switch (_that) {
case _Citation():
return $default(_that.title,_that.url,_that.publisher);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String url,  String? publisher)?  $default,) {final _that = this;
switch (_that) {
case _Citation() when $default != null:
return $default(_that.title,_that.url,_that.publisher);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Citation implements Citation {
  const _Citation({required this.title, required this.url, this.publisher});
  factory _Citation.fromJson(Map<String, dynamic> json) => _$CitationFromJson(json);

@override final  String title;
@override final  String url;
@override final  String? publisher;

/// Create a copy of Citation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CitationCopyWith<_Citation> get copyWith => __$CitationCopyWithImpl<_Citation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CitationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Citation&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.publisher, publisher) || other.publisher == publisher));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,title,url,publisher);
}

@override
String toString() {
    return 'Citation(title: $title, url: $url, publisher: $publisher)';
}


}

/// @nodoc
abstract mixin class _$CitationCopyWith<$Res> implements $CitationCopyWith<$Res> {
  factory _$CitationCopyWith(_Citation value, $Res Function(_Citation) _then) = __$CitationCopyWithImpl;
@override @useResult
$Res call({
 String title, String url, String? publisher
});




}
/// @nodoc
class __$CitationCopyWithImpl<$Res>
    implements _$CitationCopyWith<$Res> {
  __$CitationCopyWithImpl(this._self, this._then);

  final _Citation _self;
  final $Res Function(_Citation) _then;

/// Create a copy of Citation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? url = null,Object? publisher = freezed,}) {
  return _then(_Citation(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TranscriptDiff {

 String get clipTranscript; String get originalTranscript; List<DiffSegment> get segments;
/// Create a copy of TranscriptDiff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscriptDiffCopyWith<TranscriptDiff> get copyWith => _$TranscriptDiffCopyWithImpl<TranscriptDiff>(this as TranscriptDiff, _$identity);

  /// Serializes this TranscriptDiff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TranscriptDiff;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscriptDiff&&(identical(other.clipTranscript, _this.clipTranscript) || other.clipTranscript == _this.clipTranscript)&&(identical(other.originalTranscript, _this.originalTranscript) || other.originalTranscript == _this.originalTranscript)&&const DeepCollectionEquality().equals(other.segments, _this.segments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TranscriptDiff;
  return Object.hash(runtimeType,_this.clipTranscript,_this.originalTranscript,const DeepCollectionEquality().hash(_this.segments));
}

@override
String toString() {
  final _this = this as TranscriptDiff;
  return 'TranscriptDiff(clipTranscript: ${_this.clipTranscript}, originalTranscript: ${_this.originalTranscript}, segments: ${_this.segments})';
}


}

/// @nodoc
abstract mixin class $TranscriptDiffCopyWith<$Res>  {
  factory $TranscriptDiffCopyWith(TranscriptDiff value, $Res Function(TranscriptDiff) _then) = _$TranscriptDiffCopyWithImpl;
@useResult
$Res call({
 String clipTranscript, String originalTranscript, List<DiffSegment> segments
});




}
/// @nodoc
class _$TranscriptDiffCopyWithImpl<$Res>
    implements $TranscriptDiffCopyWith<$Res> {
  _$TranscriptDiffCopyWithImpl(this._self, this._then);

  final TranscriptDiff _self;
  final $Res Function(TranscriptDiff) _then;

/// Create a copy of TranscriptDiff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clipTranscript = null,Object? originalTranscript = null,Object? segments = null,}) {
  return _then(TranscriptDiff(
clipTranscript: null == clipTranscript ? _self.clipTranscript : clipTranscript // ignore: cast_nullable_to_non_nullable
as String,originalTranscript: null == originalTranscript ? _self.originalTranscript : originalTranscript // ignore: cast_nullable_to_non_nullable
as String,segments: null == segments ? _self.segments : segments // ignore: cast_nullable_to_non_nullable
as List<DiffSegment>,
  ));
}

}


/// Adds pattern-matching-related methods to [TranscriptDiff].
extension TranscriptDiffPatterns on TranscriptDiff {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TranscriptDiff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TranscriptDiff() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TranscriptDiff value)  $default,){
final _that = this;
switch (_that) {
case _TranscriptDiff():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TranscriptDiff value)?  $default,){
final _that = this;
switch (_that) {
case _TranscriptDiff() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String clipTranscript,  String originalTranscript,  List<DiffSegment> segments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TranscriptDiff() when $default != null:
return $default(_that.clipTranscript,_that.originalTranscript,_that.segments);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String clipTranscript,  String originalTranscript,  List<DiffSegment> segments)  $default,) {final _that = this;
switch (_that) {
case _TranscriptDiff():
return $default(_that.clipTranscript,_that.originalTranscript,_that.segments);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String clipTranscript,  String originalTranscript,  List<DiffSegment> segments)?  $default,) {final _that = this;
switch (_that) {
case _TranscriptDiff() when $default != null:
return $default(_that.clipTranscript,_that.originalTranscript,_that.segments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TranscriptDiff implements TranscriptDiff {
  const _TranscriptDiff({required this.clipTranscript, required this.originalTranscript,  List<DiffSegment> segments = const <DiffSegment>[]}): _segments = segments;
  factory _TranscriptDiff.fromJson(Map<String, dynamic> json) => _$TranscriptDiffFromJson(json);

@override final  String clipTranscript;
@override final  String originalTranscript;
 final  List<DiffSegment> _segments;
@override@JsonKey() List<DiffSegment> get segments {
  if (_segments is EqualUnmodifiableListView) return _segments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_segments);
}


/// Create a copy of TranscriptDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TranscriptDiffCopyWith<_TranscriptDiff> get copyWith => __$TranscriptDiffCopyWithImpl<_TranscriptDiff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TranscriptDiffToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TranscriptDiff&&(identical(other.clipTranscript, clipTranscript) || other.clipTranscript == clipTranscript)&&(identical(other.originalTranscript, originalTranscript) || other.originalTranscript == originalTranscript)&&const DeepCollectionEquality().equals(other.segments, _segments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,clipTranscript,originalTranscript,const DeepCollectionEquality().hash(_segments));
}

@override
String toString() {
    return 'TranscriptDiff(clipTranscript: $clipTranscript, originalTranscript: $originalTranscript, segments: $segments)';
}


}

/// @nodoc
abstract mixin class _$TranscriptDiffCopyWith<$Res> implements $TranscriptDiffCopyWith<$Res> {
  factory _$TranscriptDiffCopyWith(_TranscriptDiff value, $Res Function(_TranscriptDiff) _then) = __$TranscriptDiffCopyWithImpl;
@override @useResult
$Res call({
 String clipTranscript, String originalTranscript, List<DiffSegment> segments
});




}
/// @nodoc
class __$TranscriptDiffCopyWithImpl<$Res>
    implements _$TranscriptDiffCopyWith<$Res> {
  __$TranscriptDiffCopyWithImpl(this._self, this._then);

  final _TranscriptDiff _self;
  final $Res Function(_TranscriptDiff) _then;

/// Create a copy of TranscriptDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clipTranscript = null,Object? originalTranscript = null,Object? segments = null,}) {
  return _then(_TranscriptDiff(
clipTranscript: null == clipTranscript ? _self.clipTranscript : clipTranscript // ignore: cast_nullable_to_non_nullable
as String,originalTranscript: null == originalTranscript ? _self.originalTranscript : originalTranscript // ignore: cast_nullable_to_non_nullable
as String,segments: null == segments ? _self._segments : segments // ignore: cast_nullable_to_non_nullable
as List<DiffSegment>,
  ));
}


}


/// @nodoc
mixin _$DiffSegment {

@JsonKey(unknownEnumValue: DiffOp.equal) DiffOp get op; String get text;
/// Create a copy of DiffSegment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiffSegmentCopyWith<DiffSegment> get copyWith => _$DiffSegmentCopyWithImpl<DiffSegment>(this as DiffSegment, _$identity);

  /// Serializes this DiffSegment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DiffSegment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffSegment&&(identical(other.op, _this.op) || other.op == _this.op)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DiffSegment;
  return Object.hash(runtimeType,_this.op,_this.text);
}

@override
String toString() {
  final _this = this as DiffSegment;
  return 'DiffSegment(op: ${_this.op}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $DiffSegmentCopyWith<$Res>  {
  factory $DiffSegmentCopyWith(DiffSegment value, $Res Function(DiffSegment) _then) = _$DiffSegmentCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: DiffOp.equal) DiffOp op, String text
});




}
/// @nodoc
class _$DiffSegmentCopyWithImpl<$Res>
    implements $DiffSegmentCopyWith<$Res> {
  _$DiffSegmentCopyWithImpl(this._self, this._then);

  final DiffSegment _self;
  final $Res Function(DiffSegment) _then;

/// Create a copy of DiffSegment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? op = null,Object? text = null,}) {
  return _then(DiffSegment(
op: null == op ? _self.op : op // ignore: cast_nullable_to_non_nullable
as DiffOp,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DiffSegment].
extension DiffSegmentPatterns on DiffSegment {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiffSegment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiffSegment() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiffSegment value)  $default,){
final _that = this;
switch (_that) {
case _DiffSegment():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiffSegment value)?  $default,){
final _that = this;
switch (_that) {
case _DiffSegment() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: DiffOp.equal)  DiffOp op,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiffSegment() when $default != null:
return $default(_that.op,_that.text);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: DiffOp.equal)  DiffOp op,  String text)  $default,) {final _that = this;
switch (_that) {
case _DiffSegment():
return $default(_that.op,_that.text);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: DiffOp.equal)  DiffOp op,  String text)?  $default,) {final _that = this;
switch (_that) {
case _DiffSegment() when $default != null:
return $default(_that.op,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiffSegment implements DiffSegment {
  const _DiffSegment({@JsonKey(unknownEnumValue: DiffOp.equal) required this.op, required this.text});
  factory _DiffSegment.fromJson(Map<String, dynamic> json) => _$DiffSegmentFromJson(json);

@override@JsonKey(unknownEnumValue: DiffOp.equal) final  DiffOp op;
@override final  String text;

/// Create a copy of DiffSegment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiffSegmentCopyWith<_DiffSegment> get copyWith => __$DiffSegmentCopyWithImpl<_DiffSegment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiffSegmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiffSegment&&(identical(other.op, op) || other.op == op)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,op,text);
}

@override
String toString() {
    return 'DiffSegment(op: $op, text: $text)';
}


}

/// @nodoc
abstract mixin class _$DiffSegmentCopyWith<$Res> implements $DiffSegmentCopyWith<$Res> {
  factory _$DiffSegmentCopyWith(_DiffSegment value, $Res Function(_DiffSegment) _then) = __$DiffSegmentCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: DiffOp.equal) DiffOp op, String text
});




}
/// @nodoc
class __$DiffSegmentCopyWithImpl<$Res>
    implements _$DiffSegmentCopyWith<$Res> {
  __$DiffSegmentCopyWithImpl(this._self, this._then);

  final _DiffSegment _self;
  final $Res Function(_DiffSegment) _then;

/// Create a copy of DiffSegment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? op = null,Object? text = null,}) {
  return _then(_DiffSegment(
op: null == op ? _self.op : op // ignore: cast_nullable_to_non_nullable
as DiffOp,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VideoMeta {

 int get durationMs; int get width; int get height;
/// Create a copy of VideoMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoMetaCopyWith<VideoMeta> get copyWith => _$VideoMetaCopyWithImpl<VideoMeta>(this as VideoMeta, _$identity);

  /// Serializes this VideoMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VideoMeta;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoMeta&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VideoMeta;
  return Object.hash(runtimeType,_this.durationMs,_this.width,_this.height);
}

@override
String toString() {
  final _this = this as VideoMeta;
  return 'VideoMeta(durationMs: ${_this.durationMs}, width: ${_this.width}, height: ${_this.height})';
}


}

/// @nodoc
abstract mixin class $VideoMetaCopyWith<$Res>  {
  factory $VideoMetaCopyWith(VideoMeta value, $Res Function(VideoMeta) _then) = _$VideoMetaCopyWithImpl;
@useResult
$Res call({
 int durationMs, int width, int height
});




}
/// @nodoc
class _$VideoMetaCopyWithImpl<$Res>
    implements $VideoMetaCopyWith<$Res> {
  _$VideoMetaCopyWithImpl(this._self, this._then);

  final VideoMeta _self;
  final $Res Function(VideoMeta) _then;

/// Create a copy of VideoMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? durationMs = null,Object? width = null,Object? height = null,}) {
  return _then(VideoMeta(
durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoMeta].
extension VideoMetaPatterns on VideoMeta {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoMeta() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoMeta value)  $default,){
final _that = this;
switch (_that) {
case _VideoMeta():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoMeta value)?  $default,){
final _that = this;
switch (_that) {
case _VideoMeta() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int durationMs,  int width,  int height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoMeta() when $default != null:
return $default(_that.durationMs,_that.width,_that.height);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int durationMs,  int width,  int height)  $default,) {final _that = this;
switch (_that) {
case _VideoMeta():
return $default(_that.durationMs,_that.width,_that.height);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int durationMs,  int width,  int height)?  $default,) {final _that = this;
switch (_that) {
case _VideoMeta() when $default != null:
return $default(_that.durationMs,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VideoMeta implements VideoMeta {
  const _VideoMeta({required this.durationMs, required this.width, required this.height});
  factory _VideoMeta.fromJson(Map<String, dynamic> json) => _$VideoMetaFromJson(json);

@override final  int durationMs;
@override final  int width;
@override final  int height;

/// Create a copy of VideoMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoMetaCopyWith<_VideoMeta> get copyWith => __$VideoMetaCopyWithImpl<_VideoMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoMetaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoMeta&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,durationMs,width,height);
}

@override
String toString() {
    return 'VideoMeta(durationMs: $durationMs, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$VideoMetaCopyWith<$Res> implements $VideoMetaCopyWith<$Res> {
  factory _$VideoMetaCopyWith(_VideoMeta value, $Res Function(_VideoMeta) _then) = __$VideoMetaCopyWithImpl;
@override @useResult
$Res call({
 int durationMs, int width, int height
});




}
/// @nodoc
class __$VideoMetaCopyWithImpl<$Res>
    implements _$VideoMetaCopyWith<$Res> {
  __$VideoMetaCopyWithImpl(this._self, this._then);

  final _VideoMeta _self;
  final $Res Function(_VideoMeta) _then;

/// Create a copy of VideoMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? durationMs = null,Object? width = null,Object? height = null,}) {
  return _then(_VideoMeta(
durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$JobSummary {

 int get total; Map<String, int> get byCategory;
/// Create a copy of JobSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobSummaryCopyWith<JobSummary> get copyWith => _$JobSummaryCopyWithImpl<JobSummary>(this as JobSummary, _$identity);

  /// Serializes this JobSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as JobSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobSummary&&(identical(other.total, _this.total) || other.total == _this.total)&&const DeepCollectionEquality().equals(other.byCategory, _this.byCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as JobSummary;
  return Object.hash(runtimeType,_this.total,const DeepCollectionEquality().hash(_this.byCategory));
}

@override
String toString() {
  final _this = this as JobSummary;
  return 'JobSummary(total: ${_this.total}, byCategory: ${_this.byCategory})';
}


}

/// @nodoc
abstract mixin class $JobSummaryCopyWith<$Res>  {
  factory $JobSummaryCopyWith(JobSummary value, $Res Function(JobSummary) _then) = _$JobSummaryCopyWithImpl;
@useResult
$Res call({
 int total, Map<String, int> byCategory
});




}
/// @nodoc
class _$JobSummaryCopyWithImpl<$Res>
    implements $JobSummaryCopyWith<$Res> {
  _$JobSummaryCopyWithImpl(this._self, this._then);

  final JobSummary _self;
  final $Res Function(JobSummary) _then;

/// Create a copy of JobSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? byCategory = null,}) {
  return _then(JobSummary(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,byCategory: null == byCategory ? _self.byCategory : byCategory // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [JobSummary].
extension JobSummaryPatterns on JobSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JobSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JobSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JobSummary value)  $default,){
final _that = this;
switch (_that) {
case _JobSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JobSummary value)?  $default,){
final _that = this;
switch (_that) {
case _JobSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  Map<String, int> byCategory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JobSummary() when $default != null:
return $default(_that.total,_that.byCategory);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  Map<String, int> byCategory)  $default,) {final _that = this;
switch (_that) {
case _JobSummary():
return $default(_that.total,_that.byCategory);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  Map<String, int> byCategory)?  $default,) {final _that = this;
switch (_that) {
case _JobSummary() when $default != null:
return $default(_that.total,_that.byCategory);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JobSummary extends JobSummary {
  const _JobSummary({required this.total,  Map<String, int> byCategory = const <String, int>{}}): _byCategory = byCategory,super._();
  factory _JobSummary.fromJson(Map<String, dynamic> json) => _$JobSummaryFromJson(json);

@override final  int total;
 final  Map<String, int> _byCategory;
@override@JsonKey() Map<String, int> get byCategory {
  if (_byCategory is EqualUnmodifiableMapView) return _byCategory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_byCategory);
}


/// Create a copy of JobSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobSummaryCopyWith<_JobSummary> get copyWith => __$JobSummaryCopyWithImpl<_JobSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _JobSummary&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other.byCategory, _byCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,total,const DeepCollectionEquality().hash(_byCategory));
}

@override
String toString() {
    return 'JobSummary(total: $total, byCategory: $byCategory)';
}


}

/// @nodoc
abstract mixin class _$JobSummaryCopyWith<$Res> implements $JobSummaryCopyWith<$Res> {
  factory _$JobSummaryCopyWith(_JobSummary value, $Res Function(_JobSummary) _then) = __$JobSummaryCopyWithImpl;
@override @useResult
$Res call({
 int total, Map<String, int> byCategory
});




}
/// @nodoc
class __$JobSummaryCopyWithImpl<$Res>
    implements _$JobSummaryCopyWith<$Res> {
  __$JobSummaryCopyWithImpl(this._self, this._then);

  final _JobSummary _self;
  final $Res Function(_JobSummary) _then;

/// Create a copy of JobSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? byCategory = null,}) {
  return _then(_JobSummary(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,byCategory: null == byCategory ? _self._byCategory : byCategory // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}


/// @nodoc
mixin _$RunComparison {

 String get previousJobId; int get resolved; int get remaining; int get newCount;
/// Create a copy of RunComparison
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunComparisonCopyWith<RunComparison> get copyWith => _$RunComparisonCopyWithImpl<RunComparison>(this as RunComparison, _$identity);

  /// Serializes this RunComparison to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RunComparison;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunComparison&&(identical(other.previousJobId, _this.previousJobId) || other.previousJobId == _this.previousJobId)&&(identical(other.resolved, _this.resolved) || other.resolved == _this.resolved)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.newCount, _this.newCount) || other.newCount == _this.newCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RunComparison;
  return Object.hash(runtimeType,_this.previousJobId,_this.resolved,_this.remaining,_this.newCount);
}

@override
String toString() {
  final _this = this as RunComparison;
  return 'RunComparison(previousJobId: ${_this.previousJobId}, resolved: ${_this.resolved}, remaining: ${_this.remaining}, newCount: ${_this.newCount})';
}


}

/// @nodoc
abstract mixin class $RunComparisonCopyWith<$Res>  {
  factory $RunComparisonCopyWith(RunComparison value, $Res Function(RunComparison) _then) = _$RunComparisonCopyWithImpl;
@useResult
$Res call({
 String previousJobId, int resolved, int remaining, int newCount
});




}
/// @nodoc
class _$RunComparisonCopyWithImpl<$Res>
    implements $RunComparisonCopyWith<$Res> {
  _$RunComparisonCopyWithImpl(this._self, this._then);

  final RunComparison _self;
  final $Res Function(RunComparison) _then;

/// Create a copy of RunComparison
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? previousJobId = null,Object? resolved = null,Object? remaining = null,Object? newCount = null,}) {
  return _then(RunComparison(
previousJobId: null == previousJobId ? _self.previousJobId : previousJobId // ignore: cast_nullable_to_non_nullable
as String,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,newCount: null == newCount ? _self.newCount : newCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RunComparison].
extension RunComparisonPatterns on RunComparison {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunComparison value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunComparison() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunComparison value)  $default,){
final _that = this;
switch (_that) {
case _RunComparison():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunComparison value)?  $default,){
final _that = this;
switch (_that) {
case _RunComparison() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String previousJobId,  int resolved,  int remaining,  int newCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunComparison() when $default != null:
return $default(_that.previousJobId,_that.resolved,_that.remaining,_that.newCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String previousJobId,  int resolved,  int remaining,  int newCount)  $default,) {final _that = this;
switch (_that) {
case _RunComparison():
return $default(_that.previousJobId,_that.resolved,_that.remaining,_that.newCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String previousJobId,  int resolved,  int remaining,  int newCount)?  $default,) {final _that = this;
switch (_that) {
case _RunComparison() when $default != null:
return $default(_that.previousJobId,_that.resolved,_that.remaining,_that.newCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RunComparison implements RunComparison {
  const _RunComparison({required this.previousJobId, required this.resolved, required this.remaining, this.newCount = 0});
  factory _RunComparison.fromJson(Map<String, dynamic> json) => _$RunComparisonFromJson(json);

@override final  String previousJobId;
@override final  int resolved;
@override final  int remaining;
@override@JsonKey() final  int newCount;

/// Create a copy of RunComparison
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunComparisonCopyWith<_RunComparison> get copyWith => __$RunComparisonCopyWithImpl<_RunComparison>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunComparisonToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunComparison&&(identical(other.previousJobId, previousJobId) || other.previousJobId == previousJobId)&&(identical(other.resolved, resolved) || other.resolved == resolved)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.newCount, newCount) || other.newCount == newCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,previousJobId,resolved,remaining,newCount);
}

@override
String toString() {
    return 'RunComparison(previousJobId: $previousJobId, resolved: $resolved, remaining: $remaining, newCount: $newCount)';
}


}

/// @nodoc
abstract mixin class _$RunComparisonCopyWith<$Res> implements $RunComparisonCopyWith<$Res> {
  factory _$RunComparisonCopyWith(_RunComparison value, $Res Function(_RunComparison) _then) = __$RunComparisonCopyWithImpl;
@override @useResult
$Res call({
 String previousJobId, int resolved, int remaining, int newCount
});




}
/// @nodoc
class __$RunComparisonCopyWithImpl<$Res>
    implements _$RunComparisonCopyWith<$Res> {
  __$RunComparisonCopyWithImpl(this._self, this._then);

  final _RunComparison _self;
  final $Res Function(_RunComparison) _then;

/// Create a copy of RunComparison
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? previousJobId = null,Object? resolved = null,Object? remaining = null,Object? newCount = null,}) {
  return _then(_RunComparison(
previousJobId: null == previousJobId ? _self.previousJobId : previousJobId // ignore: cast_nullable_to_non_nullable
as String,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,newCount: null == newCount ? _self.newCount : newCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$JobError {

 String get code; String get message;
/// Create a copy of JobError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobErrorCopyWith<JobError> get copyWith => _$JobErrorCopyWithImpl<JobError>(this as JobError, _$identity);

  /// Serializes this JobError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as JobError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobError&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as JobError;
  return Object.hash(runtimeType,_this.code,_this.message);
}

@override
String toString() {
  final _this = this as JobError;
  return 'JobError(code: ${_this.code}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $JobErrorCopyWith<$Res>  {
  factory $JobErrorCopyWith(JobError value, $Res Function(JobError) _then) = _$JobErrorCopyWithImpl;
@useResult
$Res call({
 String code, String message
});




}
/// @nodoc
class _$JobErrorCopyWithImpl<$Res>
    implements $JobErrorCopyWith<$Res> {
  _$JobErrorCopyWithImpl(this._self, this._then);

  final JobError _self;
  final $Res Function(JobError) _then;

/// Create a copy of JobError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = null,}) {
  return _then(JobError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [JobError].
extension JobErrorPatterns on JobError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JobError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JobError() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JobError value)  $default,){
final _that = this;
switch (_that) {
case _JobError():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JobError value)?  $default,){
final _that = this;
switch (_that) {
case _JobError() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JobError() when $default != null:
return $default(_that.code,_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String message)  $default,) {final _that = this;
switch (_that) {
case _JobError():
return $default(_that.code,_that.message);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String message)?  $default,) {final _that = this;
switch (_that) {
case _JobError() when $default != null:
return $default(_that.code,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JobError implements JobError {
  const _JobError({required this.code, required this.message});
  factory _JobError.fromJson(Map<String, dynamic> json) => _$JobErrorFromJson(json);

@override final  String code;
@override final  String message;

/// Create a copy of JobError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobErrorCopyWith<_JobError> get copyWith => __$JobErrorCopyWithImpl<_JobError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobErrorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _JobError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,message);
}

@override
String toString() {
    return 'JobError(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class _$JobErrorCopyWith<$Res> implements $JobErrorCopyWith<$Res> {
  factory _$JobErrorCopyWith(_JobError value, $Res Function(_JobError) _then) = __$JobErrorCopyWithImpl;
@override @useResult
$Res call({
 String code, String message
});




}
/// @nodoc
class __$JobErrorCopyWithImpl<$Res>
    implements _$JobErrorCopyWith<$Res> {
  __$JobErrorCopyWithImpl(this._self, this._then);

  final _JobError _self;
  final $Res Function(_JobError) _then;

/// Create a copy of JobError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,}) {
  return _then(_JobError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
