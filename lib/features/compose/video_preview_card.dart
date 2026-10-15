import 'dart:async';

import 'package:contextlens/core/local_video.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/video_thumbnail.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/compose/video_problem_copy.dart';
import 'package:contextlens/features/samples/sample_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// The picked video: an empty picker, a checking state, a preview with
/// metadata, or an inline error. Validation happens before any upload.
class VideoPreviewCard extends ConsumerWidget {
  const VideoPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = ref.watch(composeControllerProvider.select((s) => s.video));
    return switch (slot) {
      VideoEmpty() => const _EmptyPicker(),
      VideoInspecting(:final name) => _Inspecting(name: name),
      VideoReady(:final video, :final name) => _ReadyCard(
        video: video,
        name: name,
      ),
      VideoRejected() => _RejectedCard(slot: slot),
    };
  }
}

Future<void> _showSourceSheet(BuildContext context, WidgetRef ref) {
  final controller = ref.read(composeControllerProvider.notifier);
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(sheetContext);
              unawaited(controller.pickFromGallery());
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Browse files'),
            onTap: () {
              Navigator.pop(sheetContext);
              unawaited(controller.pickFromFiles());
            },
          ),
          const SizedBox(height: Spacing.space2),
        ],
      ),
    ),
  );
}

class _EmptyPicker extends ConsumerWidget {
  const _EmptyPicker();

  static const double _badge = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(composeControllerProvider.notifier);

    return AppCard(
      padding: const EdgeInsets.all(Spacing.space5),
      child: Column(
        children: [
          Container(
            width: _badge,
            height: _badge,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.video_call_outlined,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: Spacing.space3),
          Text('Pick a video', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.space1),
          Text(
            'MP4, MOV or WebM, up to ${formatBytes(kMaxUploadBytes)} '
            'and ${kMaxVideoDuration.inMinutes} minutes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.space4),
          AppButton(
            label: 'Choose from gallery',
            icon: Icons.photo_library_outlined,
            expand: true,
            onPressed: controller.pickFromGallery,
          ),
          const SizedBox(height: Spacing.space2),
          AppButton(
            label: 'Browse files',
            icon: Icons.folder_open_outlined,
            variant: AppButtonVariant.text,
            onPressed: controller.pickFromFiles,
          ),
          AppButton(
            label: 'Try a sample video',
            icon: Icons.play_circle_outline,
            variant: AppButtonVariant.text,
            onPressed: () => showSampleSheet(context),
          ),
        ],
      ),
    );
  }
}

class _Inspecting extends StatelessWidget {
  const _Inspecting({required this.name});

  final String name;

  static const double _spinner = 20;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: _spinner,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: Spacing.space3),
            Expanded(
              child: Text(
                'Checking $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyCard extends ConsumerWidget {
  const _ReadyCard({required this.video, required this.name});

  final PickedVideo video;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mono = AppTypography.monoOf(theme.textTheme.bodySmall)
        .copyWith(color: theme.colorScheme.onSurfaceVariant);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlinePreview(video: video),
          const SizedBox(width: Spacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.space2),
                Text(
                  '${formatDurationMs(video.duration.inMilliseconds)}  ·  '
                  '${video.width} × ${video.height}',
                  style: mono,
                ),
                Text(
                  '${formatBytes(video.sizeBytes)}  ·  ${video.container.label}',
                  style: mono,
                ),
                const SizedBox(height: Spacing.space2),
                Wrap(
                  spacing: Spacing.space1,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showSourceSheet(context, ref),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Replace'),
                    ),
                    TextButton.icon(
                      onPressed: ref
                          .read(composeControllerProvider.notifier)
                          .removeVideo,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail that plays the video in place when tapped.
class _InlinePreview extends StatefulWidget {
  const _InlinePreview({required this.video});

  final PickedVideo video;

  @override
  State<_InlinePreview> createState() => _InlinePreviewState();
}

class _InlinePreviewState extends State<_InlinePreview> {
  static const double _width = 96;
  static const double _height = 128;
  static const _scrim = Color(0x66000000);
  static const _onScrim = Color(0xFFFFFFFF);

  VideoPlayerController? _controller;
  bool _loading = false;

  @override
  void didUpdateWidget(_InlinePreview old) {
    super.didUpdateWidget(old);
    if (old.video.path != widget.video.path) _disposePlayer();
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
  }

  Future<void> _toggle() async {
    final existing = _controller;
    if (existing != null) {
      await (existing.value.isPlaying ? existing.pause() : existing.play());
      if (mounted) setState(() {});
      return;
    }
    setState(() => _loading = true);
    final controller = localVideoController(widget.video.path);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } on Object {
      unawaited(controller.dispose());
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) {
      unawaited(controller.dispose());
      return;
    }
    controller.addListener(_onTick);
    setState(() {
      _controller = controller;
      _loading = false;
    });
  }

  void _onTick() {
    // Only the play/pause overlay depends on the controller.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final playing = controller?.value.isPlaying ?? false;
    final thumbnail = widget.video.thumbnail;

    final Widget picture = controller != null
        ? FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          )
        : thumbnail != null
        ? Image.memory(thumbnail, fit: BoxFit.cover, gaplessPlayback: true)
        : const VideoThumbnail(width: _width, height: _height);

    return Semantics(
      button: true,
      label: playing ? 'Pause preview' : 'Play preview',
      child: GestureDetector(
        onTap: _loading ? null : _toggle,
        child: Hero(
          tag: composeVideoHeroTag,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
            child: SizedBox(
              width: _width,
              height: _height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: picture),
                  if (!playing)
                    Center(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: _scrim,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.space2),
                          child: _loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _onScrim,
                                  ),
                                )
                              : const Icon(
                                  Icons.play_arrow_rounded,
                                  color: _onScrim,
                                ),
                        ),
                      ),
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

class _RejectedCard extends ConsumerWidget {
  const _RejectedCard({required this.slot});

  final VideoRejected slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(composeControllerProvider.notifier);
    final VideoRejected(:name, :problem) = slot;

    return AppCard(
      borderColor: scheme.error,
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(problem.icon, color: scheme.error),
                const SizedBox(width: Spacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(problem.title, style: theme.textTheme.titleMedium),
                      Text(
                        name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Spacing.space2),
                      Text(problem.message, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.space2),
            Wrap(
              spacing: Spacing.space1,
              children: [
                if (slot.canRetry)
                  TextButton.icon(
                    onPressed: controller.retryInspection,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                TextButton.icon(
                  onPressed: () => _showSourceSheet(context, ref),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Choose another'),
                ),
                TextButton.icon(
                  onPressed: controller.removeVideo,
                  icon: const Icon(Icons.close),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
