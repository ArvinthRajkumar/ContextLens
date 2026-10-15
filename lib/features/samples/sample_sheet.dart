import 'dart:async';
import 'dart:ui';

import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/glass_surface.dart';
import 'package:contextlens/core/widgets/video_thumbnail.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/samples/sample.dart';
import 'package:contextlens/features/samples/sample_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the Try a sample gallery. Picking a sample fills New check (and
/// opens it when [openCompose] is set, as from Home).
Future<void> showSampleSheet(BuildContext context, {bool openCompose = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (_) => SampleSheet(openCompose: openCompose),
  );
}

/// Synthetic test videos anyone can run a check on, on a glass sheet.
class SampleSheet extends ConsumerWidget {
  const SampleSheet({this.openCompose = false, super.key});

  final bool openCompose;

  static const double _blur = 24;
  static const double _maxHeightShare = 0.85;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    Sample sample,
  ) async {
    final thumbnail = await ref
        .read(sampleRepositoryProvider)
        .thumbnail(sample);
    if (!context.mounted) return;
    ref
        .read(composeControllerProvider.notifier)
        .useSample(sample, thumbnail: thumbnail);
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (openCompose) unawaited(router.push('/new'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final samples = ref.watch(samplesProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _maxHeightShare,
      ),
      child: ClipRRect(
        borderRadius: Radii.sheet,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassStrong,
              border: Border(top: BorderSide(color: colors.glassBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Handle(),
                  Padding(
                    padding: Spacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Try a sample video',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: Spacing.space1),
                        Text(
                          'Synthetic test videos with fictional brands. '
                          'Each one shows a different kind of problem.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.space3),
                  Flexible(
                    child: switch (samples) {
                      AsyncData(:final value) => ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.screen,
                          0,
                          Spacing.screen,
                          Spacing.space5,
                        ),
                        itemCount: value.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Spacing.space3),
                        itemBuilder: (context, i) => _SampleTile(
                          sample: value[i],
                          onChoose: () => _choose(context, ref, value[i]),
                        ),
                      ),
                      AsyncError() => _Message(
                        text: "Couldn't load the samples.",
                        onRetry: () => ref.invalidate(samplesProvider),
                      ),
                      _ => const Padding(
                        padding: EdgeInsets.all(Spacing.space8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  static const double _width = 36;
  static const double _height = 4;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Spacing.space3),
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.sample, required this.onChoose});

  final Sample sample;
  final VoidCallback onChoose;

  static const double _thumbWidth = 64;
  static const double _thumbHeight = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumbnail = sample.thumbnailUrl;
    final download = sample.downloadUrl;

    return Semantics(
      button: true,
      label: '${sample.title}. ${sample.hint}',
      child: ClipRRect(
        borderRadius: Radii.card,
        child: GlassSurface(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onChoose,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(Radii.sm),
                      ),
                      child: SizedBox(
                        width: _thumbWidth,
                        height: _thumbHeight,
                        child: thumbnail == null
                            ? const VideoThumbnail(
                                width: _thumbWidth,
                                height: _thumbHeight,
                              )
                            : Image.network(
                                thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const VideoThumbnail(
                                  width: _thumbWidth,
                                  height: _thumbHeight,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: Spacing.space3),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sample.title,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: Spacing.space1),
                            Text(
                              sample.hint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Spacing.space2),
                            Wrap(
                              spacing: Spacing.space2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  formatDurationMs(
                                    sample.duration.inMilliseconds,
                                  ),
                                  style: AppTypography.monoOf(
                                    theme.textTheme.labelMedium,
                                  ).copyWith(color: scheme.onSurfaceVariant),
                                ),
                                _LanguageChip(language: sample.language),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (download != null)
                      IconButton(
                        tooltip: 'Download ${sample.title}',
                        icon: const Icon(Icons.download_outlined),
                        onPressed: () => launchUrl(
                          Uri.parse(download),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space2,
          vertical: Spacing.space1 / 2,
        ),
        child: Text(
          language,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: Spacing.space3),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
