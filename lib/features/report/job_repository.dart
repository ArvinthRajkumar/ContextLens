import 'package:contextlens/core/api_client.dart';
import 'package:contextlens/core/config.dart';
import 'package:contextlens/features/auth/auth_repository.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/report/fake_job_repository.dart';
import 'package:contextlens/features/report/firestore_job_repository.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/playback.dart';
import 'package:contextlens/features/settings/mock_data_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class JobRepository {
  /// The signed-in user's recent runs, newest first, kept up to date.
  Stream<List<Job>> watchRecentJobs();

  Future<Job?> getJob(String jobId);

  /// One job's live state (Firestore `jobs/{jobId}` in the real backend).
  Stream<Job> watchJob(String jobId);

  /// Where to play the job's video (a signed URL in the real backend).
  Future<PlaybackSource> playback(String jobId);

  /// The declaration the check ran with, kept on the device so a fix can
  /// start from it. Null when it is no longer available.
  Future<DeclarationDraft?> declaration(String jobId);

  /// Deletes every job the user owns, with its video and report. Returns
  /// how many were deleted.
  Future<int> deleteAllJobs();
}

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return switch (AppConfig.backend) {
    BackendMode.mock => FakeJobRepository(
      seeded: ref.watch(mockDataControllerProvider),
      backend: ref.watch(mockBackendProvider),
    ),
    BackendMode.real => FirestoreJobRepository(
      auth: ref.watch(authRepositoryProvider),
      api: ref.watch(apiClientProvider),
    ),
  };
});

final recentRunsProvider = StreamProvider<List<Job>>((ref) {
  return ref.watch(jobRepositoryProvider).watchRecentJobs();
});

final jobProvider = FutureProvider.family<Job?, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).getJob(jobId);
});

final playbackSourceProvider = FutureProvider.family<PlaybackSource, String>(
  (ref, jobId) => ref.watch(jobRepositoryProvider).playback(jobId),
);

final declarationProvider = FutureProvider.family<DeclarationDraft?, String>(
  (ref, jobId) => ref.watch(jobRepositoryProvider).declaration(jobId),
);

final jobStreamProvider = StreamProvider.family<Job, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).watchJob(jobId);
});
