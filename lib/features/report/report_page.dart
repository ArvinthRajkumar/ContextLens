import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/empty_state.dart';
import 'package:contextlens/core/widgets/info_pill.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/run_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Stub until Phase 5: lists issues, checked claims and the video's other
/// runs, without player or timeline.
class ReportPage extends ConsumerWidget {
  const ReportPage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobProvider(jobId));

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: switch (job) {
        AsyncData(value: final Job job) => _ReportBody(job: job),
        AsyncData() => const Center(
          child: EmptyState(
            icon: Icons.search_off,
            title: 'Report not found',
            body: 'It may have expired. Reports are kept for 24 hours.',
          ),
        ),
        AsyncError() => const Center(
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load this report",
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final error = job.error;
    final issues = job.issues;
    final checked = job.checkedClaims;
    final runs = ref.watch(runHistoryProvider(job.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.screen,
        Spacing.space2,
        Spacing.screen,
        Spacing.space8,
      ),
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
        if (error != null)
          EmptyState(
            icon: Icons.error_outline,
            title: 'Check failed',
            body: error.message,
          )
        else ...[
          SectionHeader(
            title: issues.length == 1 ? '1 flag' : '${issues.length} flags',
          ),
          for (final flag in issues) ...[
            _FlagRow(flag: flag),
            const SizedBox(height: Spacing.space3),
          ],
          if (checked.isNotEmpty) ...[
            const SectionHeader(title: 'Claims checked'),
            for (final claim in checked) ...[
              _FlagRow(flag: claim),
              const SizedBox(height: Spacing.space3),
            ],
          ],
        ],
        if (runs.length > 1) ...[
          const SectionHeader(title: 'Runs of this video'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final run in runs)
                  _RunTile(run: run, isCurrent: run.id == job.id),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.flag});

  final Flag flag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final label = flag.factLabel;
    final severity = flag.severity;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(flag.category.icon, color: flag.category.color(colors)),
          const SizedBox(width: Spacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(flag.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.space2),
                Wrap(
                  spacing: Spacing.space2,
                  runSpacing: Spacing.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      [
                        flag.category.label,
                        if (severity != null) severity.label,
                      ].join('  ·  '),
                      style: muted,
                    ),
                    if (label != null)
                      InfoPill(
                        icon: label.icon,
                        label: label.label,
                        color: label.color(colors),
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
