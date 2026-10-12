import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/features/run/run_page.dart';
import 'package:contextlens/features/upload/upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// An upload that is still going after the user left the Run screen.
class ActiveUploadCard extends ConsumerWidget {
  const ActiveUploadCard({super.key});

  static const double _indicator = 36;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    if (upload == null ||
        !upload.phase.isUnfinished ||
        upload.phase == UploadPhase.submitting) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final percent = (upload.progress * 100).floor();
    final title = switch (upload.phase) {
      UploadPhase.paused => 'Upload paused at $percent%',
      UploadPhase.waitingForNetwork => 'Waiting for connection',
      UploadPhase.failed => 'Upload stopped at $percent%',
      UploadPhase.retrying => 'Reconnecting',
      _ => 'Uploading, $percent%',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.space3),
      child: AppCard(
        onTap: () => context.push('/run/$pendingRunId'),
        child: Row(
          children: [
            SizedBox.square(
              dimension: _indicator,
              child: CircularProgressIndicator(
                value: upload.progress,
                strokeWidth: 4,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: Spacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(
                    titleFromCaption(upload.submission.declaration.caption) ??
                        'Your video',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
