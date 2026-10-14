import 'dart:async';

import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/run/lens_orbit.dart';
import 'package:contextlens/features/run/processing_progress.dart';
import 'package:contextlens/features/upload/upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Route id for a check that is still uploading and has no job id yet.
const pendingRunId = 'pending';

/// The wait while the backend checks the video: the orbiting lens, the
/// stage and its live detail, an honest progress bar and a rotating tip.
class ProcessingView extends StatefulWidget {
  const ProcessingView({
    required this.job,
    this.lensKey,
    this.hideLens = false,
    super.key,
  });

  final Job job;

  /// Where the upload's success disc lands.
  final GlobalKey? lensKey;
  final bool hideLens;

  @override
  State<ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<ProcessingView> {
  late int _stage = stageIndexOf(widget.job.stage);
  DateTime _stageStart = DateTime.now();

  @override
  void didUpdateWidget(ProcessingView old) {
    super.didUpdateWidget(old);
    final stage = stageIndexOf(widget.job.stage);
    if (stage > _stage) {
      _stage = stage;
      _stageStart = DateTime.now();
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          processingStages[stage].$2,
          TextDirection.ltr,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = widget.job;
    final error = job.error;
    final phase = switch (job.status) {
      JobStatus.done => OrbitPhase.done,
      JobStatus.failed => OrbitPhase.failed,
      _ => OrbitPhase.running,
    };
    final (_, title, icon) = processingStages[_stage];
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.screen,
              Spacing.space2,
              Spacing.screen,
              Spacing.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  job.title ?? 'Your video',
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                const SizedBox(height: Spacing.space6),
                Center(
                  child: LensOrbit(
                    stage: _stage,
                    icon: icon,
                    phase: phase,
                    lensKey: widget.lensKey,
                    hideLens: widget.hideLens,
                  ),
                ),
                const SizedBox(height: Spacing.space6),
                _StageText(
                  title: phase == OrbitPhase.failed ? 'Check failed' : title,
                  detail: phase == OrbitPhase.running ? job.stageDetail : null,
                ),
                const SizedBox(height: Spacing.space3),
                Text(
                  'Usually 1 to 3 minutes. You can leave, we will notify you.',
                  style: muted,
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: Spacing.space5),
                  _FailedCard(message: error.message),
                ],
                const Spacer(),
                const SizedBox(height: Spacing.space6),
                _ProgressStrip(
                  stage: _stage,
                  stageStart: _stageStart,
                  since: job.createdAt,
                  done: job.status == JobStatus.done,
                  failed: job.status == JobStatus.failed,
                ),
                const SizedBox(height: Spacing.space5),
                _TipRotator(since: job.createdAt),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Stage title and live detail, swapping with a fade and an 8dp rise.
class _StageText extends StatelessWidget {
  const _StageText({required this.title, required this.detail});

  final String title;
  final String? detail;

  static const double _rise = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motion = Motion.of(context);
    Widget swap(Widget child) => AnimatedSwitcher(
      duration: motion.medium2,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _rise * (1 - animation.value)),
            child: child,
          ),
          child: child,
        ),
      ),
      child: child,
    );
    final detail = this.detail;

    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          swap(
            Text(
              title,
              key: ValueKey(title),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Spacing.space1),
          swap(
            Text(
              detail ?? '',
              key: ValueKey(detail),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// A 4dp bar driven by [StageProgress], "Step n of 5" and the elapsed time.
class _ProgressStrip extends StatefulWidget {
  const _ProgressStrip({
    required this.stage,
    required this.stageStart,
    required this.since,
    required this.done,
    required this.failed,
  });

  final int stage;
  final DateTime stageStart;
  final DateTime since;
  final bool done;
  final bool failed;

  static const double height = 4;

  @override
  State<_ProgressStrip> createState() => _ProgressStripState();
}

class _ProgressStripState extends State<_ProgressStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  final _progress = MonotonicProgress();

  @override
  void didUpdateWidget(_ProgressStrip old) {
    super.didUpdateWidget(old);
    // Nothing left to ease toward: stop ticking.
    if (widget.failed || widget.done) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = AppTypography.monoOf(theme.textTheme.labelLarge)
        .copyWith(color: scheme.onSurfaceVariant);

    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final now = DateTime.now();
        final value = _progress.update(
          StageProgress.target(
            stage: widget.stage,
            inStage: now.difference(widget.stageStart),
            done: widget.done,
          ),
        );
        final elapsed = now.difference(widget.since);
        final percent = (value * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Check progress',
              value: '$percent%',
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(Radii.full),
                ),
                child: SizedBox(
                  height: _ProgressStrip.height,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: value),
                    duration: Motion.of(context).medium2,
                    curve: Motion.standard,
                    builder: (context, shown, _) => LinearProgressIndicator(
                      value: shown,
                      minHeight: _ProgressStrip.height,
                      backgroundColor: scheme.surfaceContainerHigh,
                      color: widget.failed ? scheme.error : scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.space2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Step ${widget.stage + 1} of ${processingStages.length}',
                    style: mono,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatDurationMs(
                    elapsed.isNegative ? 0 : elapsed.inMilliseconds,
                  ),
                  style: mono,
                  semanticsLabel: 'Elapsed ${elapsed.inSeconds} seconds',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "Did you know" lines, one every 6 seconds, crossfading.
class _TipRotator extends StatefulWidget {
  const _TipRotator({required this.since});

  final DateTime since;

  static const Duration every = Duration(seconds: 6);

  @override
  State<_TipRotator> createState() => _TipRotatorState();
}

class _TipRotatorState extends State<_TipRotator> {
  late final Timer _timer = Timer.periodic(
    _TipRotator.every,
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = tipIndexAt(DateTime.now().difference(widget.since));
    final tip = processingTips[index];

    return AnimatedSwitcher(
      duration: Motion.of(context).medium4,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Did you know: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: tip),
          ],
        ),
        key: ValueKey(index),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FailedCard extends ConsumerWidget {
  const _FailedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      borderColor: theme.colorScheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: Spacing.space3),
          AppButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: () {
              final submission = ref.read(uploadControllerProvider)?.submission;
              if (submission == null) {
                context.go('/');
                return;
              }
              ref.read(pendingSubmissionProvider.notifier).set(submission);
              unawaited(
                ref.read(uploadControllerProvider.notifier).start(submission),
              );
              context.pushReplacement('/run/$pendingRunId');
            },
          ),
        ],
      ),
    );
  }
}
