import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/lens_mark.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/home/check_video_card.dart';
import 'package:contextlens/features/home/recent_runs.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: 'ContextLens',
          excludeSemantics: true,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LensMark(),
              SizedBox(width: Spacing.space3),
              Text('ContextLens'),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: Spacing.space1),
        ],
      ),
      body: const CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Spacing.screen,
              Spacing.space2,
              Spacing.screen,
              0,
            ),
            sliver: SliverToBoxAdapter(child: CheckVideoCard()),
          ),
          SliverPadding(
            padding: Spacing.screenPadding,
            sliver: SliverToBoxAdapter(
              child: SectionHeader(title: 'Recent checks'),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Spacing.screen,
              0,
              Spacing.screen,
              Spacing.space8,
            ),
            sliver: RecentRuns(),
          ),
        ],
      ),
    );
  }
}
