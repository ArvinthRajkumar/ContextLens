import 'package:contextlens/core/config.dart';
import 'package:contextlens/features/report/fake_job_repository.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/settings/mock_data_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class JobRepository {
  /// The signed-in user's recent runs, newest first, kept up to date.
  Stream<List<Job>> watchRecentJobs();

  Future<Job?> getJob(String jobId);

  /// One job's live state (Firestore `jobs/{jobId}` in the real backend).
  Stream<Job> watchJob(String jobId);
}

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return switch (AppConfig.backend) {
    BackendMode.mock => FakeJobRepository(
      seeded: ref.watch(mockDataControllerProvider),
      backend: ref.watch(mockBackendProvider),
    ),
    // Wired in Phase 6 (Firestore jobs/{jobId}).
    BackendMode.real => throw UnimplementedError('Real backend not wired yet'),
  };
});

final recentRunsProvider = StreamProvider<List<Job>>((ref) {
  return ref.watch(jobRepositoryProvider).watchRecentJobs();
});

final jobProvider = FutureProvider.family<Job?, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).getJob(jobId);
});

final jobStreamProvider = StreamProvider.family<Job, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).watchJob(jobId);
});
