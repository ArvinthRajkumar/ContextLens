import 'dart:async';
import 'dart:math' as math;

import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/video_thumbnail.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/push/notify_prompt.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/run/stage_stepper.dart';
import 'package:contextlens/features/run/success_burst.dart';
import 'package:contextlens/features/run/upload_ring.dart';
import 'package:contextlens/features/run/upload_stats.dart';
import 'package:contextlens/features/upload/upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Route id for a check that is still uploading and has no job id yet.
const pendingRunId = 'pending';

enum _View { upload, success, stages }

/// Upload, then the success moment, then live processing stages. Moves to
/// the report on its own when the check is done.
class RunPage extends ConsumerStatefulWidget {
  const RunPage({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<RunPage> createState() => _RunPageState();
}

class _RunPageState extends ConsumerState<RunPage>
    with TickerProviderStateMixin {
  // Caption height under the burst ("Uploaded" plus one line), and the
  // margin kept between the burst's outer reach and the body edges.
  static const _captionHeight = 56.0;
  static const _burstMargin = Spacing.space3;
  static const _reportDelay = Duration(milliseconds: 700);

  late final AnimationController _success = AnimationController(
    vsync: this,
    duration: SuccessBurst.total,
  );
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: Durations.medium4,
  );

  final _firstDotKey = GlobalKey();
  final _ringKey = GlobalKey();
  final _stackKey = GlobalKey();

  late _View _view;
  String? _jobId;
  Rect? _morphTo;

  /// Where the upload ring was when the upload finished; the burst starts
  /// there and glides to the center of the body.
  Rect? _ringStart;
  bool _openedReport = false;
  bool _mediumBuzzed = false;
  bool _lightBuzzed = false;

  @override
  void initState() {
    super.initState();
    _success.addListener(_onSuccessTick);

    if (widget.jobId != pendingRunId) {
      _view = _View.stages;
      _jobId = widget.jobId;
      return;
    }
    final upload = ref.read(uploadControllerProvider);
    final submission = ref.read(pendingSubmissionProvider);
    if (upload?.phase == UploadPhase.done) {
      _view = _View.stages;
      _jobId = upload!.jobId;
    } else {
      _view = _View.upload;
      if (submission != null && upload?.submission != submission) {
        // Providers can't change while the tree builds, so start after it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref.read(uploadControllerProvider.notifier).start(submission),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _success.dispose();
    _morph.dispose();
    super.dispose();
  }

  Future<void> _celebrate(String jobId) async {
    _ringStart = _rectInStack(_ringKey);
    setState(() {
      _view = _View.success;
      _jobId = jobId;
    });
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Upload complete',
        TextDirection.ltr,
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) {
      // Static check, one haptic, no burst or flight.
      _success.value = 1;
      unawaited(HapticFeedback.mediumImpact());
      await Future<void>.delayed(Durations.long2);
      if (mounted) setState(() => _view = _View.stages);
      return;
    }

    await _success.forward(from: 0);
    if (!mounted) return;
    _morphTo = _rectInStack(_firstDotKey);
    await _morph.forward(from: 0);
    if (!mounted) return;
    setState(() => _view = _View.stages);
    // The check is running: the moment a notification is worth asking for.
    unawaited(maybeAskForNotifications(context, ref));
  }

  void _onSuccessTick() {
    final ms = _success.value * SuccessBurst.total.inMilliseconds;
    if (!_mediumBuzzed && ms >= 200) {
      _mediumBuzzed = true;
      unawaited(HapticFeedback.mediumImpact());
    }
    if (!_lightBuzzed && ms >= 750) {
      _lightBuzzed = true;
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// Where the widget with [key] sits inside the page's stack.
  Rect? _rectInStack(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: stack);
    return topLeft & box.size;
  }

  void _onJob(Job job) {
    if (job.status != JobStatus.done || _openedReport) return;
    _openedReport = true;
    Future<void>.delayed(_reportDelay, () {
      if (!mounted) return;
      ref.read(uploadControllerProvider.notifier).clear();
      context.go('/report/${job.id}');
    });
  }

  Future<void> _onBack() async {
    final upload = ref.read(uploadControllerProvider);
    final unfinished =
        _view == _View.upload && (upload?.phase.isUnfinished ?? false);
    if (!unfinished) {
      if (mounted) context.pop();
      return;
    }
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep uploading in background?'),
        content: const Text(
          'You can use the app while it uploads. Your report shows up on '
          'Home when it is ready.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel upload'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep'),
          ),
        ],
      ),
    );
    if (!mounted || keep == null) return;
    if (keep) {
      context.go('/');
    } else {
      await ref.read(uploadControllerProvider.notifier).cancel();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(uploadControllerProvider, (previous, next) {
      final jobId = next?.jobId;
      if (_view == _View.upload &&
          next?.phase == UploadPhase.done &&
          jobId != null) {
        unawaited(_celebrate(jobId));
      }
    });
    final jobId = _jobId;
    if (jobId != null) {
      ref.listen(jobStreamProvider(jobId), (_, next) {
        final job = next.value;
        if (job != null) _onJob(job);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        appBar: AppBar(
          // Stays "Uploading" until the disc has landed in the stepper.
          title: Text(_view == _View.stages ? 'Checking' : 'Uploading'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _BurstLayout.fit(
              constraints.biggest,
              captionHeight: _captionHeight,
              margin: _burstMargin,
            );
            return Stack(
              key: _stackKey,
              children: [
                if (jobId != null && _view != _View.upload)
                  _StagesLayer(
                    jobId: jobId,
                    firstDotKey: _firstDotKey,
                    reveal: _view == _View.stages ? null : _morph,
                    hideFirstDot: _view == _View.success,
                  ),
                if (_view == _View.upload) _UploadLayer(ringKey: _ringKey),
                if (_view == _View.success) ...[
                  _FlyingBurst(
                    success: _success,
                    morph: _morph,
                    start: _ringStart ?? layout.disc,
                    center: layout.disc,
                    reach: layout.reach,
                    to: () => _morphTo,
                  ),
                  // After the burst, so the caption paints above it.
                  _SuccessCaption(
                    animation: _success,
                    morph: _morph,
                    top: layout.captionTop,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UploadLayer extends ConsumerWidget {
  const _UploadLayer({required this.ringKey});

  /// Lets the success burst start exactly where the ring is.
  final GlobalKey ringKey;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this upload?'),
        content: const Text("What's uploaded so far is discarded."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep uploading'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel upload'),
          ),
        ],
      ),
    );
    if (cancel != true) return;
    await ref.read(uploadControllerProvider.notifier).cancel();
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final upload = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);
    if (upload == null) {
      return const Center(child: Text('Nothing is uploading.'));
    }
    final phase = upload.phase;
    final thumbnail = upload.submission.video.thumbnail;
    final percent = (upload.progress * 100).floor();

    return _CenteredScroll(
      children: [
        Center(
          child: UploadRing(
            key: ringKey,
            progress: upload.progress,
            mode: switch (phase) {
              UploadPhase.failed || UploadPhase.retrying => RingMode.error,
              UploadPhase.paused ||
              UploadPhase.waitingForNetwork => RingMode.paused,
              _ => RingMode.running,
            },
            child: Hero(
              tag: composeVideoHeroTag,
              child: ClipOval(
                child: SizedBox.square(
                  dimension: UploadRing.size - 2 * UploadRing.stroke - 16,
                  child: thumbnail == null
                      ? const VideoThumbnail(width: 112, height: 112)
                      : Image.memory(thumbnail, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.space5),
        Text(
          '$percent%',
          style: AppTypography.monoOf(theme.textTheme.displaySmall),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.space2),
        UploadStats(upload: upload),
        const SizedBox(height: Spacing.space6),
        if (phase == UploadPhase.waitingForNetwork) ...[
          const _OfflineBanner(),
          const SizedBox(height: Spacing.space4),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Spacing.space3,
          runSpacing: Spacing.space2,
          children: [
            ...switch (phase) {
              UploadPhase.uploading => [
                AppButton(
                  label: 'Pause',
                  icon: Icons.pause,
                  variant: AppButtonVariant.secondary,
                  onPressed: controller.pause,
                ),
              ],
              UploadPhase.paused => [
                AppButton(
                  label: 'Resume',
                  icon: Icons.play_arrow,
                  onPressed: controller.resume,
                ),
              ],
              UploadPhase.retrying => [
                AppButton(
                  label: 'Try now',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  onPressed: controller.retryNow,
                ),
              ],
              UploadPhase.failed => [
                AppButton(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: controller.resume,
                ),
              ],
              _ => const <Widget>[],
            },
            if (phase.isUnfinished && phase != UploadPhase.submitting)
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: () => _confirmCancel(context, ref),
              ),
          ],
        ),
      ],
    );
  }
}

/// Centers its column vertically in the body, and scrolls instead of
/// overflowing when text is scaled up or the screen is short.
class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.screen,
          vertical: Spacing.space6,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 2 * Spacing.space6,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Places the success burst and its caption as one block centered in the
/// body, with the burst's reach capped so ripples and particles stay fully
/// visible and clear of the caption.
@immutable
class _BurstLayout {
  const _BurstLayout({
    required this.disc,
    required this.reach,
    required this.captionTop,
  });

  factory _BurstLayout.fit(
    Size body, {
    required double captionHeight,
    required double margin,
  }) {
    const radius = UploadRing.size / 2;
    const gap = Spacing.space4;
    final maxReachPx = math.min(
      body.width / 2 - margin,
      (body.height - gap - captionHeight) / 2 - margin,
    );
    final reach = (maxReachPx / radius).clamp(
      1.4,
      SuccessBurstPainter.defaultReach,
    );
    final reachPx = reach * radius;
    final block = 2 * reachPx + gap + captionHeight;
    final top = (body.height - block) / 2;
    final center = Offset(body.width / 2, top + reachPx);
    return _BurstLayout(
      disc: Rect.fromCircle(center: center, radius: radius),
      reach: reach,
      captionTop: top + 2 * reachPx + gap,
    );
  }

  /// The disc's box while the burst plays.
  final Rect disc;

  /// Ripple and particle limit, in disc radii.
  final double reach;
  final double captionTop;
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Spacing.space3),
          const Expanded(
            child: Text(
              "You're offline. The upload picks up where it left off when "
              "you're back.",
            ),
          ),
        ],
      ),
    );
  }
}

/// The burst: starts where the ring was, glides to the center of the body
/// while the ring tightens, then shrinks into the first stage dot.
class _FlyingBurst extends StatelessWidget {
  const _FlyingBurst({
    required this.success,
    required this.morph,
    required this.start,
    required this.center,
    required this.reach,
    required this.to,
  });

  final Animation<double> success;
  final Animation<double> morph;
  final Rect start;
  final Rect center;
  final double reach;
  final Rect? Function() to;

  // The glide finishes as the disc starts to expand (350 of 1200 ms).
  static const _glide = Interval(0, 350 / 1200, curve: Motion.emphasized);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([success, morph]),
      builder: (context, child) {
        final settled = Rect.lerp(
          start,
          center,
          _glide.transform(success.value),
        )!;
        final target = to() ?? settled;
        final t = Motion.emphasized.transform(morph.value);
        return Positioned.fromRect(
          rect: Rect.lerp(settled, target, t)!,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: SuccessBurst(animation: success, reach: reach),
      ),
    );
  }
}

/// "Uploaded" and "Starting checks", fading in 700 to 1000 ms and rising 8dp,
/// then fading out as the disc flies to the stepper.
class _SuccessCaption extends StatelessWidget {
  const _SuccessCaption({
    required this.animation,
    required this.morph,
    required this.top,
  });

  final Animation<double> animation;
  final Animation<double> morph;
  final double top;

  static const _rise = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: AnimatedBuilder(
        animation: Listenable.merge([animation, morph]),
        builder: (context, child) {
          final ms = animation.value * SuccessBurst.total.inMilliseconds;
          final t = Motion.enter.transform(((ms - 700) / 300).clamp(0.0, 1.0));
          return Opacity(
            // Gone within the first third of the flight, before the stepper
            // fades in underneath.
            opacity: t * (1 - (morph.value * 3).clamp(0.0, 1.0)),
            child: Transform.translate(
              offset: Offset(0, _rise * (1 - t)),
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            Text('Uploaded', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.space1),
            Text(
              'Starting checks',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StagesLayer extends ConsumerWidget {
  const _StagesLayer({
    required this.jobId,
    required this.firstDotKey,
    required this.reveal,
    required this.hideFirstDot,
  });

  final String jobId;
  final GlobalKey firstDotKey;

  /// Fades the stepper in while the success disc flies; null when settled.
  final Animation<double>? reveal;
  final bool hideFirstDot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobStreamProvider(jobId));
    final content = switch (job) {
      AsyncData(:final value) => _Stages(
        job: value,
        firstDotKey: firstDotKey,
        hideFirstDot: hideFirstDot,
      ),
      AsyncError() => const Center(child: Text("Couldn't load this check.")),
      _ => const Center(child: CircularProgressIndicator()),
    };
    final fade = reveal;
    if (fade == null) return content;
    return AnimatedBuilder(
      animation: fade,
      builder: (context, child) => Opacity(opacity: fade.value, child: child),
      child: content,
    );
  }
}

class _Stages extends ConsumerWidget {
  const _Stages({
    required this.job,
    required this.firstDotKey,
    required this.hideFirstDot,
  });

  final Job job;
  final GlobalKey firstDotKey;
  final bool hideFirstDot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final error = job.error;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.screen,
        Spacing.space2,
        Spacing.screen,
        Spacing.space8,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                job.title ?? 'Your video',
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Spacing.space3),
            if (job.isActive) _Elapsed(since: job.createdAt),
          ],
        ),
        const SizedBox(height: Spacing.space1),
        Text(
          'Usually 1 to 3 minutes. You can leave, we will notify you.',
          style: muted,
        ),
        const SizedBox(height: Spacing.space6),
        StageStepper(
          job: job,
          firstDotKey: firstDotKey,
          hideFirstDot: hideFirstDot,
        ),
        if (error != null) ...[
          const SizedBox(height: Spacing.space6),
          AppCard(
            borderColor: theme.colorScheme.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Check failed', style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.space1),
                Text(error.message),
                const SizedBox(height: Spacing.space3),
                AppButton(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: () {
                    final submission = ref
                        .read(uploadControllerProvider)
                        ?.submission;
                    if (submission == null) {
                      context.go('/');
                      return;
                    }
                    ref
                        .read(pendingSubmissionProvider.notifier)
                        .set(submission);
                    unawaited(
                      ref
                          .read(uploadControllerProvider.notifier)
                          .start(submission),
                    );
                    context.pushReplacement('/run/$pendingRunId');
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Time since the check started, ticking each second.
class _Elapsed extends StatelessWidget {
  const _Elapsed({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final elapsed = DateTime.now().difference(since);
        return Text(
          formatDurationMs(elapsed.isNegative ? 0 : elapsed.inMilliseconds),
          style: AppTypography.monoOf(theme.textTheme.titleMedium)
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
          semanticsLabel: 'Elapsed ${elapsed.inSeconds} seconds',
        );
      },
    );
  }
}
