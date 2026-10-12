import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/empty_state.dart';
import 'package:contextlens/features/home/run_card.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/run_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sliver with one card per video (its latest run), or an empty or error
/// state.
class RecentRuns extends ConsumerWidget {
  const RecentRuns({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(recentVideosProvider);

    return switch (runs) {
      AsyncData(value: final jobs) when jobs.isEmpty =>
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.video_library_outlined,
            title: 'No checks yet',
            body: 'Your reports show up here. They are deleted after 24 hours.',
          ),
        ),
      AsyncData(value: final jobs) => SliverList.separated(
        itemCount: jobs.length,
        itemBuilder: (context, index) => RunCard(job: jobs[index]),
        separatorBuilder: (context, index) =>
            const SizedBox(height: Spacing.space3),
      ),
      AsyncError() => SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load your checks",
          action: AppButton(
            label: 'Try again',
            variant: AppButtonVariant.secondary,
            onPressed: () => ref.invalidate(recentRunsProvider),
          ),
        ),
      ),
      _ => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(Spacing.space8),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    };
  }
}
