import 'dart:math' as math;

import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

/// The five processing stages, in order, with what the screen calls them.
const processingStages = [
  (JobStage.extract, 'Reading your video', Icons.subtitles_outlined),
  (JobStage.claims, 'Finding claims', Icons.format_list_bulleted),
  (JobStage.checking, 'Checking claims', Icons.fact_check_outlined),
  (JobStage.evidence, 'Weighing the evidence', Icons.balance_outlined),
  (JobStage.report, 'Writing your report', Icons.description_outlined),
];

/// Index of [stage] in [processingStages]; a queued job is on the first.
int stageIndexOf(JobStage? stage) {
  final index = processingStages.indexWhere((s) => s.$1 == stage);
  return index < 0 ? 0 : index;
}

/// Honest, stage based progress: each stage is a fifth of the bar. Inside a
/// stage the bar eases toward 90% of that stage's share and waits there, so
/// it never claims more than the backend has done; it jumps to the stage's
/// end when Firestore moves on, and only reaches 100% when the job is done.
abstract final class StageProgress {
  /// How long each stage usually takes: the easing time constant.
  static const List<Duration> typical = [
    Duration(seconds: 8),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 1),
    Duration(milliseconds: 500),
  ];

  static const double _withinShare = 0.9;

  static double target({
    required int stage,
    required Duration inStage,
    required bool done,
  }) {
    if (done) return 1;
    final count = processingStages.length;
    final index = stage.clamp(0, count - 1);
    final tau = typical[index].inMilliseconds;
    final eased = 1 - math.exp(-inStage.inMilliseconds / tau);
    return (index + _withinShare * eased) / count;
  }
}

/// Keeps the shown value from ever going backwards (a stage that restarts,
/// a clock that jumps) while following [StageProgress.target].
class MonotonicProgress {
  double _value = 0;

  double get value => _value;

  double update(double target) => _value = math.max(_value, target);
}

/// "Did you know" lines for the wait, under 110 characters each. Every one
/// comes from the clause index (backend/app/clauses/index.json) or the
/// sources listed in docs/INFRA.md and README.md.
const processingTips = [
  'Paid, gifted or affiliate posts need a label like Ad, Sponsored or Collaboration.',
  'The label goes up front: a label only in your bio or at the end of a post is easy to miss.',
  'In videos up to 15 seconds, an on-screen label must stay for at least 3 seconds.',
  'Videos under 2 minutes should show the label for a third of their length.',
  'A label buried in a group of hashtags does not count as a clear disclosure.',
  'Diabetes is on the Drugs and Magic Remedies Act schedule: ads cannot claim to treat it.',
  'Stock tips need your SEBI registration number, stated up front.',
  'ASCI found 98% of the influencer ads it investigated needed changes, Apr to Sep 2025.',
];

/// Which tip shows after [elapsed], one every [every].
int tipIndexAt(
  Duration elapsed, {
  Duration every = const Duration(seconds: 6),
}) {
  return (elapsed.inMilliseconds ~/ every.inMilliseconds) %
      processingTips.length;
}
