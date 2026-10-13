import 'dart:async';

import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/empty_state.dart';
import 'package:contextlens/core/widgets/info_pill.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/report/comparison.dart';
import 'package:contextlens/features/report/flag_card.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/flag_timeline.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/playback.dart';
import 'package:contextlens/features/report/report_video.dart';
import 'package:contextlens/features/report/run_comparison.dart';
import 'package:contextlens/features/report/run_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Reports already revealed this session; the stagger plays once each.
class RevealedReports extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String jobId) => state = {...state, jobId};
}

final revealedReportsProvider = NotifierProvider<RevealedReports, Set<String>>(
  RevealedReports.new,
);

class ReportPage extends ConsumerWidget {
  const ReportPage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobProvider(jobId));

    return switch (job) {
      AsyncData(value: final Job job) when job.status == JobStatus.failed =>
        _FailedReport(job: job),
      AsyncData(value: final Job job) => _Report(job: job),
      AsyncData() => const _Message(
        icon: Icons.search_off,
        title: 'Report not found',
        body: 'It may have expired. Reports are kept for 24 hours.',
      ),
      AsyncError() => const _Message(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load this report",
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Center(
        child: EmptyState(icon: icon, title: title, body: body),
      ),
    );
  }
}

class _FailedReport extends StatelessWidget {
  const _FailedReport({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Center(
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'Check failed',
          body: job.error?.message,
          action: AppButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: () => context.push('/new?parent=${job.id}'),
          ),
        ),
      ),
    );
  }
}

class _Report extends ConsumerStatefulWidget {
  const _Report({required this.job});

  final Job job;

  @override
  ConsumerState<_Report> createState() => _ReportState();
}

class _ReportState extends ConsumerState<_Report> {
  static const _videoShare = 0.36;
  static const _videoShareLargeText = 0.24;
  static const _videoMin = 160.0;
  static const _videoMax = 320.0;
  static const _maxStaggered = 8;

  final _scroll = ScrollController();
  final _cardKeys = <String, GlobalKey>{};
  final _pulses = <String, int>{};
  ReportPlayer? _player;
  String? _selectedId;

  /// The video's real length once the player knows it; markers and the
  /// playhead must share one scale.
  int? _playerDurationMs;
  late final bool _reveal;

  Job get job => widget.job;

  @override
  void initState() {
    super.initState();
    _reveal = !ref.read(revealedReportsProvider).contains(job.id);
    if (_reveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(revealedReportsProvider.notifier).add(job.id);
      });
    }
    unawaited(_loadPlayer());
  }

  Future<void> _loadPlayer() async {
    final PlaybackSource source;
    try {
      source = await ref.read(playbackSourceProvider(job.id).future);
    } on Object {
      return;
    }
    if (!mounted) return;
    final player = ref.read(reportPlayerFactoryProvider)(source);
    setState(() => _player = player);
    player.state.addListener(_onPlayback);
    await player.initialize();
  }

  void _onPlayback() {
    final ms = _player?.state.value.duration.inMilliseconds ?? 0;
    if (ms > 0 && ms != _playerDurationMs && mounted) {
      setState(() => _playerDurationMs = ms);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _player?.state.removeListener(_onPlayback);
    unawaited(_player?.dispose());
    super.dispose();
  }

  GlobalKey _keyFor(Flag flag) => _cardKeys.putIfAbsent(flag.id, GlobalKey.new);

  Future<void> _seek(Flag flag, {bool play = false}) async {
    final player = _player;
    if (player == null) return;
    await player.seekTo(Duration(milliseconds: flag.startMs));
    if (play) await player.play();
  }

  void _onCardTap(Flag flag) {
    setState(() => _selectedId = flag.id);
    unawaited(_seek(flag));
  }

  void _onMarkerTap(Flag flag) {
    setState(() {
      _selectedId = flag.id;
      _pulses[flag.id] = (_pulses[flag.id] ?? 0) + 1;
    });
    unawaited(_seek(flag));
    final card = _keyFor(flag).currentContext;
    if (card != null) {
      unawaited(
        Scrollable.ensureVisible(
          card,
          alignment: 0.1,
          duration: Motion.of(context).medium2,
          curve: Motion.standard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final issues = job.issues;
    final checked = job.checkedClaims;
    final runs = ref.watch(runHistoryProvider(job.id));
    final parentId = job.parentJobId;
    final parent = parentId == null
        ? null
        : ref.watch(jobProvider(parentId)).value;
    final comparison =
        job.comparison ?? (parent == null ? null : compareRuns(parent, job));
    final motion = Motion.of(context);
    final stagger = _reveal && !motion.reduced;

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Large text needs the room more than the video does.
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final videoHeight =
              (constraints.maxHeight *
                      (largeText ? _videoShareLargeText : _videoShare))
                  .clamp(_videoMin, _videoMax);
          return Column(
            children: [
              if (player != null)
                ReportVideo(player: player, height: videoHeight)
              else
                SizedBox(
                  height: videoHeight,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              if (player != null && issues.isNotEmpty)
                FlagTimeline(
                  flags: issues,
                  durationMs: _playerDurationMs ?? job.video?.durationMs ?? 0,
                  playback: player.state,
                  selectedId: _selectedId,
                  onSelect: _onMarkerTap,
                  reveal: _reveal,
                ),
              const Divider(height: 1),
              Expanded(
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.screen,
                        Spacing.space4,
                        Spacing.screen,
                        Spacing.space8,
                      ),
                      // Not lazy: timeline taps scroll to cards that must
                      // already be built. Reports hold a few dozen flags.
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Summary(job: job, reveal: stagger),
                            if (comparison != null) ...[
                              const SizedBox(height: Spacing.space4),
                              RunComparisonCard(
                                comparison: comparison,
                                previousVersion: job.version - 1,
                              ),
                            ],
                            if (issues.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: Spacing.space4),
                                child: EmptyState(
                                  icon: Icons.verified_outlined,
                                  title: 'No issues found',
                                  body: 'Nothing here needs a fix before you post.',
                                ),
                              )
                            else ...[
                              SectionHeader(
                                title: issues.length == 1
                                    ? '1 flag'
                                    : '${issues.length} flags',
                              ),
                              for (final (i, flag) in issues.indexed) ...[
                                FlagCard(
                                  key: _keyFor(flag),
                                  flag: flag,
                                  selected: flag.id == _selectedId,
                                  pulse: _pulses[flag.id] ?? 0,
                                  onTap: () => _onCardTap(flag),
                                  onWatch: () => _seek(flag, play: true),
                                )._rise(
                                  enabled: stagger && i < _maxStaggered,
                                  index: i,
                                ),
                                const SizedBox(height: Spacing.space3),
                              ],
                            ],
                            if (checked.isNotEmpty) ...[
                              const SectionHeader(title: 'Claims checked'),
                              for (final claim in checked) ...[
                                FlagCard(
                                  key: _keyFor(claim),
                                  flag: claim,
                                  selected: claim.id == _selectedId,
                                  pulse: _pulses[claim.id] ?? 0,
                                  onTap: () => _onCardTap(claim),
                                  onWatch: () => _seek(claim, play: true),
                                ),
                                const SizedBox(height: Spacing.space3),
                              ],
                            ],
                            if (runs.length > 1) ...[
                              const SectionHeader(title: 'Runs of this video'),
                              AppCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    for (final run in runs)
                                      _RunTile(
                                        run: run,
                                        isCurrent: run.id == job.id,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: issues.isEmpty
          ? null
          : _FixBar(onFix: () => context.push('/new?parent=${job.id}')),
    );
  }
}

extension on Widget {
  Widget _rise({required bool enabled, required int index}) {
    if (!enabled) return this;
    return animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn(duration: Durations.medium2, curve: Motion.enter)
        .moveY(
          begin: Spacing.space4,
          end: 0,
          duration: Durations.medium2,
          curve: Motion.enter,
        );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.job, required this.reveal});

  final Job job;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final counts = job.issueCounts;
    final total = job.issues.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(job.title ?? 'Untitled video', style: theme.textTheme.titleLarge),
        const SizedBox(height: Spacing.space1),
        Text(
          [
            formatRunDate(job.createdAt),
            if (job.version > 1) 'Run ${job.version}',
          ].join('  ·  '),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: reveal ? 0 : total.toDouble(),
                end: total.toDouble(),
              ),
              duration: Durations.extralong1 - Durations.short2,
              curve: Motion.enter,
              builder: (context, value, _) =>
                  Text('${value.round()}', style: theme.textTheme.displaySmall),
            ),
            const SizedBox(width: Spacing.space2),
            Expanded(
              child: Text(
                total == 1 ? 'issue to fix' : 'issues to fix',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (counts.isNotEmpty) ...[
          const SizedBox(height: Spacing.space3),
          Wrap(
            spacing: Spacing.space2,
            runSpacing: Spacing.space2,
            children: [
              for (final MapEntry(key: category, value: count)
                  in counts.entries)
                InfoPill(
                  icon: category.icon,
                  // "Claims 2" reads right for every category; "2 claims"
                  // breaks for "fact check" and singulars.
                  label: '${category.label} $count',
                  semanticsLabel:
                      '$count ${category.label.toLowerCase()} '
                      '${count == 1 ? 'flag' : 'flags'}',
                  color: category.color(colors),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FixBar extends StatelessWidget {
  const _FixBar({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.screen,
            Spacing.space3,
            Spacing.screen,
            Spacing.space3,
          ),
          child: AppButton(
            label: 'Fix and re-upload',
            icon: Icons.upload_outlined,
            expand: true,
            onPressed: onFix,
          ),
        ),
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run, required this.isCurrent});

  final Job run;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final issues = run.issues.length;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.space4),
      leading: Icon(isCurrent ? Icons.visibility_outlined : Icons.history),
      title: Text('Run ${run.version}${isCurrent ? ', this report' : ''}'),
      subtitle: Text(
        '${formatRunDate(run.createdAt)}  ·  '
        '${issues == 1 ? '1 flag' : '$issues flags'}',
      ),
      trailing: isCurrent ? null : const Icon(Icons.chevron_right),
      onTap: isCurrent ? null : () => context.push('/report/${run.id}'),
    );
  }
}
