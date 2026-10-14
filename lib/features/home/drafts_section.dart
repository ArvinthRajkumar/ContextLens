import 'dart:async';

import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/core/widgets/video_thumbnail.dart';
import 'package:contextlens/features/drafts/draft.dart';
import 'package:contextlens/features/drafts/drafts_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Unfinished checks on Home, above Recent checks. Nothing when empty.
class DraftsSection extends ConsumerWidget {
  const DraftsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsControllerProvider).value ?? const [];
    if (drafts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Drafts'),
        for (final draft in drafts) ...[
          _DraftTile(draft: draft),
          const SizedBox(height: Spacing.space3),
        ],
      ],
    );
  }
}

class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.draft});

  final Draft draft;

  static const double _thumbWidth = 56;
  static const double _thumbHeight = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final thumbnail = draft.thumbnail;
    void delete() =>
        unawaited(ref.read(draftsControllerProvider.notifier).delete(draft.id));

    return Dismissible(
      key: ValueKey('draft-${draft.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => delete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.space5),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: Radii.card,
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
          semanticLabel: 'Delete draft',
        ),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(Spacing.space3),
        onTap: () => context.push('/new?draft=${draft.id}'),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
              child: SizedBox(
                width: _thumbWidth,
                height: _thumbHeight,
                child: thumbnail == null
                    ? const VideoThumbnail(
                        width: _thumbWidth,
                        height: _thumbHeight,
                      )
                    : Image.memory(thumbnail, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: Spacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Spacing.space1),
                  Text(
                    editedAgo(draft.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Draft options',
              onSelected: (_) => delete(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete draft')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
