import 'dart:async';
import 'dart:convert';

import 'package:contextlens/core/config.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory stand-in for Firestore `jobs/*` and the Cloud Run pipeline.
/// Holds the bundled fixtures and the jobs created by mock uploads, and
/// walks new jobs through the five stages.
class MockBackend {
  MockBackend({
    AssetBundle? bundle,
    DateTime Function()? clock,
    Duration? stageDuration,
  }) : _bundle = bundle ?? rootBundle,
       _clock = clock ?? DateTime.now,
       stageDuration =
           stageDuration ??
           const Duration(milliseconds: AppConfig.mockStageSeconds * 1000 ~/ 5);

  static const fixtureAssets = [
    'assets/mock/report_v2.json',
    'assets/mock/report_v1.json',
    'assets/mock/report_finance.json',
    'assets/mock/run_failed.json',
  ];

  // Fixtures carry fixed dates; the newest is rebased to this long ago so
  // seeded history always reads as recent.
  static const _newestAge = Duration(hours: 1);

  static const _stages = [
    JobStage.extract,
    JobStage.claims,
    JobStage.checking,
    JobStage.evidence,
    JobStage.report,
  ];

  final AssetBundle _bundle;
  final DateTime Function() _clock;
  final Duration stageDuration;

  final _created = <String, Job>{};
  final _timers = <Timer>[];
  final _changes = StreamController<String>.broadcast();
  List<Job>? _fixtures;

  /// The next submitted check fails at the evidence stage (debug menu).
  bool failNextCheck = false;

  /// Emits the id of every job that changed.
  Stream<String> get changes => _changes.stream;

  List<Job> get createdJobs => _created.values.toList();

  Future<List<Job>> fixtures() async {
    final cached = _fixtures;
    if (cached != null) return cached;
    final jobs = <Job>[
      for (final path in fixtureAssets)
        Job.fromJson(
          jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shift = _clock()
        .subtract(_newestAge)
        .difference(jobs.first.createdAt);
    return _fixtures = [
      for (final job in jobs)
        job.copyWith(
          createdAt: job.createdAt.add(shift),
          updatedAt: job.updatedAt?.add(shift),
          expiresAt: job.expiresAt?.add(shift),
        ),
    ];
  }

  Future<Job?> find(String jobId) async {
    final created = _created[jobId];
    if (created != null) return created;
    for (final job in await fixtures()) {
      if (job.id == jobId) return job;
    }
    return null;
  }

  /// The latest state of [jobId], then every change to it.
  Stream<Job> watch(String jobId) async* {
    final current = await find(jobId);
    if (current == null) return;
    yield current;
    if (!_created.containsKey(jobId)) return;
    await for (final id in _changes.stream) {
      if (id != jobId) continue;
      final job = _created[jobId]!;
      yield job;
      if (!job.isActive) return;
    }
  }

  /// Registers a submitted check and starts processing it.
  Future<void> submit({
    required String jobId,
    required String? title,
    required VideoMeta video,
    String? parentJobId,
  }) async {
    final parent = parentJobId == null ? null : await find(parentJobId);
    final now = _clock();
    _created[jobId] = Job(
      id: jobId,
      status: JobStatus.queued,
      stage: JobStage.extract,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      version: (parent?.version ?? 0) + 1,
      parentJobId: parent?.id,
      title: title,
      video: video,
    );
    _changes.add(jobId);

    final fail = failNextCheck;
    failNextCheck = false;
    final template = await _template(isRerun: parent != null);
    for (var i = 0; i < _stages.length; i++) {
      _timers.add(
        Timer(stageDuration * i, () => _enterStage(jobId, i, template)),
      );
    }
    _timers.add(
      Timer(stageDuration * _stages.length, () {
        fail ? _fail(jobId) : _finish(jobId, template, parent);
      }),
    );
  }

  Future<Job> _template({required bool isRerun}) async {
    final id = isRerun ? 'job_demo_v2' : 'job_demo_v1';
    return (await fixtures()).firstWhere((job) => job.id == id);
  }

  void _enterStage(String jobId, int index, Job template) {
    final job = _created[jobId];
    if (job == null || !job.isActive) return;
    final claims = template.flags.length + 9;
    final detail = switch (_stages[index]) {
      JobStage.extract => 'Transcribing audio and reading on-screen text',
      JobStage.claims => '$claims claims found',
      JobStage.checking => 'Checking ${template.flags.length + 3} claims',
      JobStage.evidence => 'Weighing ${claims - 2} sources',
      JobStage.report || JobStage.unknown => 'Writing your report',
    };
    _update(
      job.copyWith(
        status: JobStatus.processing,
        stage: _stages[index],
        stageDetail: detail,
      ),
    );
  }

  void _finish(String jobId, Job template, Job? parent) {
    final job = _created[jobId];
    if (job == null) return;
    final issues = template.issues;
    final counts = <String, int>{};
    for (final flag in issues) {
      counts[flag.category.name] = (counts[flag.category.name] ?? 0) + 1;
    }
    _update(
      job.copyWith(
        status: JobStatus.done,
        stage: JobStage.report,
        stageDetail: null,
        flags: template.flags,
        summary: JobSummary(total: issues.length, byCategory: counts),
        comparison: parent == null
            ? null
            : RunComparison(
                previousJobId: parent.id,
                resolved: parent.issues.length > issues.length
                    ? parent.issues.length - issues.length
                    : 0,
                remaining: issues.length,
              ),
      ),
    );
  }

  void _fail(String jobId) {
    final job = _created[jobId];
    if (job == null) return;
    _update(
      job.copyWith(
        status: JobStatus.failed,
        stageDetail: null,
        error: const JobError(
          code: 'evidence_unavailable',
          message:
              "We couldn't reach our fact-check sources. Nothing was charged; "
              'try the check again.',
        ),
      ),
    );
  }

  void _update(Job job) {
    _created[job.id] = job.copyWith(updatedAt: _clock());
    _changes.add(job.id);
  }

  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    unawaited(_changes.close());
  }
}

final mockBackendProvider = Provider<MockBackend>((ref) {
  final backend = MockBackend();
  ref.onDispose(backend.dispose);
  return backend;
});
