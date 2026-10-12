import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stub until Phase 3: picker, preview card and declaration form.
class ComposePage extends StatelessWidget {
  const ComposePage({this.parentJobId, super.key});

  final String? parentJobId;

  static const _demoJobId = 'job_demo_v1';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New check')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.screen),
        children: [
          const Center(
            child: Hero(
              tag: composeVideoHeroTag,
              child: VideoThumbnail(width: 160, height: 213, durationMs: 58000),
            ),
          ),
          const SizedBox(height: Spacing.space6),
          Text(
            'Pick a video and describe it',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: Spacing.space2),
          Text(
            'The video picker and declaration form go here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.screen),
          child: AppButton(
            label: 'Run check',
            expand: true,
            onPressed: () => context.push('/run/$_demoJobId'),
          ),
        ),
      ),
    );
  }
}
