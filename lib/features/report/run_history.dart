import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// A video's runs form a chain through parentJobId (each re-upload points at
// the run it fixes). The chain's root identifies the video.

String _rootId(Job job, Map<String, Job> byId) {
  var current = job;
  final seen = <String>{current.id};
  while (true) {
    final parent = byId[current.parentJobId];
    if (parent == null) return current.id;
    // A cycle should never happen; pick a stable root so its runs group.
    if (!seen.add(parent.id)) return (seen.toList()..sort()).first;
    current = parent;
  }
}

bool _isNewer(Job a, Job b) => a.version != b.version
    ? a.version > b.version
    : a.createdAt.isAfter(b.createdAt);

/// One entry per video, its latest run, newest video first.
List<Job> latestRunPerVideo(List<Job> jobs) {
  final byId = {for (final job in jobs) job.id: job};
  final latest = <String, Job>{};
  for (final job in jobs) {
    final root = _rootId(job, byId);
    final current = latest[root];
    if (current == null || _isNewer(job, current)) latest[root] = job;
  }
  return latest.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Every run of the video [jobId] belongs to, latest first.
List<Job> runsOfVideo(List<Job> jobs, String jobId) {
  final byId = {for (final job in jobs) job.id: job};
  final target = byId[jobId];
  if (target == null) return const [];
  final root = _rootId(target, byId);
  return [
    for (final job in jobs)
      if (_rootId(job, byId) == root) job,
  ]..sort((a, b) => _isNewer(a, b) ? -1 : 1);
}

final recentVideosProvider = Provider<AsyncValue<List<Job>>>((ref) {
  return ref.watch(recentRunsProvider).whenData(latestRunPerVideo);
});

final runHistoryProvider = Provider.family<List<Job>, String>((ref, jobId) {
  final jobs = ref.watch(recentRunsProvider).value ?? const <Job>[];
  return runsOfVideo(jobs, jobId);
});
