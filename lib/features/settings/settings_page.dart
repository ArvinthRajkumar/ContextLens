import 'package:contextlens/core/config.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/settings/delete_data_tile.dart';
import 'package:contextlens/features/settings/mock_data_controller.dart';
import 'package:contextlens/features/settings/team_card.dart';
import 'package:contextlens/features/splash/intro_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: Spacing.screenPadding,
            child: SectionHeader(title: 'Privacy'),
          ),
          const _Group(
            children: [
              DeleteDataTile(),
              ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Privacy policy'),
                subtitle: Text('Videos and reports are deleted after 24 hours'),
              ),
            ],
          ),
          const Padding(
            padding: Spacing.screenPadding,
            child: SectionHeader(title: 'About'),
          ),
          const Padding(padding: Spacing.screenPadding, child: TeamCard()),
          const SizedBox(height: Spacing.space3),
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version and licences'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'ContextLens',
                  applicationVersion: '0.1.0',
                  applicationLegalese:
                      'Team Tekken: ${TeamCard.members.join(', ')}',
                ),
              ),
            ],
          ),
          if (kDebugMode) ...[
            const Padding(
              padding: Spacing.screenPadding,
              child: SectionHeader(title: 'Developer'),
            ),
            _Group(
              children: [
                if (AppConfig.isMock)
                  SwitchListTile(
                    title: const Text('Seed mock data'),
                    subtitle: const Text('Show sample checks on Home'),
                    value: ref.watch(mockDataControllerProvider),
                    onChanged: (seeded) => ref
                        .read(mockDataControllerProvider.notifier)
                        .setSeeded(seeded: seeded),
                  ),
                ListTile(
                  leading: const Icon(Icons.replay),
                  title: const Text('Replay intro'),
                  subtitle: const Text('Holds on the last frame until tapped'),
                  onTap: () => ref
                      .read(introControllerProvider.notifier)
                      .replay(hold: true),
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Component gallery'),
                  onTap: () => context.push('/gallery'),
                ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.space8),
        ],
      ),
    );
  }
}

/// Settings rows on one glass card.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.screenPadding,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: Spacing.space1),
        child: ListTileTheme.merge(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.space4,
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}
