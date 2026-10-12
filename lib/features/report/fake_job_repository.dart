import 'dart:convert';

import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/services.dart';

/// Serves bundled fixtures. When [seeded] is false the user has no history,
/// which is the first-launch state.
class FakeJobRepository implements JobRepository {
  FakeJobRepository({required this.seeded, AssetBundle? bundle, this._now})
    : _bundle = bundle ?? rootBundle;

  static const fixtures = [
    'assets/mock/report_v2.json',
    'assets/mock/report_v1.json',
    'assets/mock/report_finance.json',
    'assets/mock/run_failed.json',
  ];

  // Fixtures carry fixed dates; the newest is rebased to this long ago so
  // seeded history always reads as recent.
  static const _newestAge = Duration(hours: 1);

  final bool seeded;
  final AssetBundle _bundle;
  final DateTime? _now;
  List<Job>? _cache;

  Future<List<Job>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final jobs = <Job>[
      for (final path in fixtures)
        Job.fromJson(
          jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final now = _now ?? DateTime.now();
    final shift = now.subtract(_newestAge).difference(jobs.first.createdAt);
    return _cache = [
      for (final job in jobs)
        job.copyWith(
          createdAt: job.createdAt.add(shift),
          updatedAt: job.updatedAt?.add(shift),
          expiresAt: job.expiresAt?.add(shift),
        ),
    ];
  }

  @override
  Stream<List<Job>> watchRecentJobs() async* {
    yield seeded ? await _load() : const <Job>[];
  }

  @override
  Future<Job?> getJob(String jobId) async {
    for (final job in await _load()) {
      if (job.id == jobId) return job;
    }
    return null;
  }
}
