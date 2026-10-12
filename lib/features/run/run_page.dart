import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stub until Phase 4: upload ring, success burst and stage stepper.
class RunPage extends StatelessWidget {
  const RunPage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Checking')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.screen),
        child: Column(
          children: [
            const Hero(
              tag: composeVideoHeroTag,
              child: VideoThumbnail(width: 96, height: 128, durationMs: 58000),
            ),
            const SizedBox(height: Spacing.space6),
            Text(
              'Upload progress and live stages go here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.screen),
          child: AppButton(
            label: 'View report',
            expand: true,
            // Replaces the stack so back from the report goes Home.
            onPressed: () => context.go('/report/$jobId'),
          ),
        ),
      ),
    );
  }
}
