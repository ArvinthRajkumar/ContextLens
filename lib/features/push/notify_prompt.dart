import 'package:contextlens/features/push/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explains why before the system permission dialog, once.
Future<void> maybeAskForNotifications(
  BuildContext context,
  WidgetRef ref,
) async {
  final push = ref.read(pushServiceProvider);
  if (!push.shouldAsk) return;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_outlined),
      title: const Text('Get told when it is ready?'),
      content: const Text(
        'Checks take a minute or two. We can send one notification when '
        'your report is ready, so you can leave the app meanwhile. Nothing '
        'else, ever.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Notify me'),
        ),
      ],
    ),
  );
  if (yes ?? false) {
    await push.enable();
  } else {
    await push.decline();
  }
}
