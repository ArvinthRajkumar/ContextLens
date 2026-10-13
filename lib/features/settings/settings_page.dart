import 'package:contextlens/core/config.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/settings/delete_data_tile.dart';
import 'package:contextlens/features/settings/mock_data_controller.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:contextlens/features/splash/intro_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: Spacing.screenPadding,
            child: SectionHeader(title: 'Appearance'),
          ),
          Padding(
            padding: Spacing.screenPadding,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  controller.setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: Spacing.space2),
          SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text('Replace animations with simple fades'),
            value: settings.reduceMotion,
            onChanged: (enabled) =>
                controller.setReduceMotion(enabled: enabled),
          ),
          const Padding(
            padding: Spacing.screenPadding,
            child: SectionHeader(title: 'Privacy'),
          ),
          const DeleteDataTile(),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Privacy policy'),
            subtitle: Text('Videos and reports are deleted after 24 hours'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'ContextLens',
              applicationVersion: '0.1.0',
            ),
          ),
          if (kDebugMode) ...[
            const Padding(
              padding: Spacing.screenPadding,
              child: SectionHeader(title: 'Developer'),
            ),
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
              onTap: () =>
                  ref.read(introControllerProvider.notifier).replay(hold: true),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Component gallery'),
              onTap: () => context.push('/gallery'),
            ),
          ],
          const SizedBox(height: Spacing.space8),
        ],
      ),
    );
  }
}
