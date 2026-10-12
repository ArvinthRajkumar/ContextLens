import 'package:contextlens/core/connectivity.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/settings/mock_data_controller.dart';
import 'package:contextlens/features/splash/intro_controller.dart';
import 'package:contextlens/features/upload/upload_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Debug builds only: jump to states that are hard to reach by hand
/// (offline, upload failure, failed check, empty history).
Future<void> showDebugMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DebugMenu(),
  );
}

class _DebugMenu extends ConsumerStatefulWidget {
  const _DebugMenu();

  @override
  ConsumerState<_DebugMenu> createState() => _DebugMenuState();
}

class _DebugMenuState extends ConsumerState<_DebugMenu> {
  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(mockBackendProvider);

    void go(String location) {
      Navigator.pop(context);
      context.push(location);
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Simulate offline'),
              value: ref.watch(simulatedOfflineProvider),
              onChanged: (value) => ref
                  .read(simulatedOfflineProvider.notifier)
                  .set(offline: value),
            ),
            SwitchListTile(
              title: const Text('Fail the next upload once'),
              subtitle: const Text('A transient error at 40%'),
              value: ref.watch(mockFailNextUploadProvider),
              onChanged: (value) => ref
                  .read(mockFailNextUploadProvider.notifier)
                  .set(fail: value),
            ),
            SwitchListTile(
              title: const Text('Fail the next check'),
              subtitle: const Text('The pipeline stops at the evidence stage'),
              value: backend.failNextCheck,
              onChanged: (value) =>
                  setState(() => backend.failNextCheck = value),
            ),
            SwitchListTile(
              title: const Text('Seed mock data'),
              subtitle: const Text('Off shows the empty history'),
              value: ref.watch(mockDataControllerProvider),
              onChanged: (value) => ref
                  .read(mockDataControllerProvider.notifier)
                  .setSeeded(seeded: value),
            ),
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Open a failed check'),
              onTap: () => go('/report/job_demo_failed'),
            ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('Replay intro'),
              onTap: () {
                Navigator.pop(context);
                ref.read(introControllerProvider.notifier).replay(hold: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Component gallery'),
              onTap: () => go('/gallery'),
            ),
          ],
        ),
      ),
    );
  }
}
