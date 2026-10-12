import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/report/models.dart';

/// Jobs from the [MockBackend]: checks created in this session, plus the
/// bundled fixtures when [seeded] (otherwise a fresh, empty account).
class FakeJobRepository implements JobRepository {
  FakeJobRepository({required this.seeded, required this.backend});

  final bool seeded;
  final MockBackend backend;

  Future<List<Job>> _snapshot() async =>
      [...backend.createdJobs, if (seeded) ...await backend.fixtures()]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Job>> watchRecentJobs() async* {
    yield await _snapshot();
    await for (final _ in backend.changes) {
      yield await _snapshot();
    }
  }

  @override
  Future<Job?> getJob(String jobId) async {
    final isCreated = backend.createdJobs.any((j) => j.id == jobId);
    if (!isCreated && !seeded) return null;
    return backend.find(jobId);
  }

  @override
  Stream<Job> watchJob(String jobId) => backend.watch(jobId);
}
