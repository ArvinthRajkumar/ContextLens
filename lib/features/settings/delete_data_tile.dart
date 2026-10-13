import 'package:contextlens/core/api_client.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/features/settings/delete_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings row for "Delete my data": confirms, deletes, then says so.
class DeleteDataTile extends ConsumerWidget {
  const DeleteDataTile({super.key});

  static String _failureCopy(Object error) => switch (error) {
    ApiException(retryable: true) =>
      "Couldn't reach ContextLens. Check your connection and try again.",
    _ => "Couldn't delete everything. Try again.",
  };

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ConfirmDialog(),
    );
    if (!(confirmed ?? false) || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(deleteDataControllerProvider.notifier).deleteEverything();
    final result = ref.read(deleteDataControllerProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.hasError
              ? _failureCopy(result.error!)
              : 'Your data is deleted.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(deleteDataControllerProvider).isLoading;

    return ListTile(
      leading: const Icon(Icons.delete_outline),
      title: const Text('Delete my data'),
      subtitle: Text(
        busy ? 'Deleting...' : 'Removes your videos, reports and run history',
      ),
      trailing: busy
          ? const SizedBox.square(
              dimension: Spacing.space6,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      enabled: !busy,
      onTap: () => _confirmAndDelete(context, ref),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Delete your data?'),
      content: const Text(
        'This deletes your videos, reports and run history from ContextLens '
        "and signs you out on this phone. You can't undo it.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
