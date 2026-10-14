import 'dart:async';

import 'package:contextlens/core/config.dart';
import 'package:contextlens/features/auth/auth_repository.dart';
import 'package:contextlens/features/drafts/drafts_controller.dart';
import 'package:contextlens/features/push/push_service.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/settings/mock_data_controller.dart';
import 'package:contextlens/features/upload/upload_controller.dart';
import 'package:contextlens/features/upload/upload_session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Delete my data": deletes every job on the server, unregisters the
/// device, clears what the app kept locally, then signs out. The state
/// holds how many checks were deleted once it's done.
class DeleteDataController extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() => null;

  Future<void> deleteEverything() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final upload = ref.read(uploadControllerProvider);
      if (upload != null && upload.phase.isUnfinished) {
        await ref.read(uploadControllerProvider.notifier).cancel();
      }
      // Jobs first: if this fails the account stays signed in, so trying
      // again reaches the same data.
      final count = await ref.read(jobRepositoryProvider).deleteAllJobs();
      await ref.read(pushServiceProvider).forget();
      await ref.read(uploadSessionStoreProvider).clear();
      await ref.read(draftsControllerProvider.notifier).deleteAll();
      ref.read(uploadControllerProvider.notifier).clear();
      if (AppConfig.isMock) {
        await ref
            .read(mockDataControllerProvider.notifier)
            .setSeeded(seeded: false);
      }
      final auth = ref.read(authRepositoryProvider);
      await auth.signOut();
      // A fresh anonymous account, and every listener re-subscribed to it.
      await auth.ensureSignedIn();
      ref
        ..invalidate(jobRepositoryProvider)
        ..invalidate(pushServiceProvider);
      return count;
    });
  }
}

final deleteDataControllerProvider =
    AsyncNotifierProvider<DeleteDataController, int?>(DeleteDataController.new);
