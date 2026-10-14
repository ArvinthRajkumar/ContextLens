import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/lens_mark.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/home/active_upload_card.dart';
import 'package:contextlens/features/home/check_video_card.dart';
import 'package:contextlens/features/home/debug_menu.dart';
import 'package:contextlens/features/home/drafts_section.dart';
import 'package:contextlens/features/home/recent_runs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          // Debug builds: long-press the logo for the state switcher.
          onLongPress: kDebugMode ? () => showDebugMenu(context) : null,
          child: Semantics(
            header: true,
            label: 'ContextLens',
            excludeSemantics: true,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LensMark(),
                SizedBox(width: Spacing.space3),
                Flexible(
                  child: Text('ContextLens', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
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
            sliver: SliverToBoxAdapter(child: DraftsSection()),
          ),
          SliverPadding(
            padding: Spacing.screenPadding,
            sliver: SliverToBoxAdapter(
              child: SectionHeader(title: 'Recent checks'),
            ),
          ),
          SliverPadding(
            padding: Spacing.screenPadding,
            sliver: SliverToBoxAdapter(child: ActiveUploadCard()),
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
