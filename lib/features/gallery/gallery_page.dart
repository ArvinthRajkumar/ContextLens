import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/empty_state.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _noop() {}

/// Debug-only route that renders every core widget for visual review.
class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          0,
          Spacing.screen,
          Spacing.space12,
        ),
        children: const [
          SectionHeader(title: 'Colors'),
          _Swatches(),
          SectionHeader(title: 'Type'),
          _TypeScale(),
          SectionHeader(
            title: 'Buttons',
            actionLabel: 'See all',
            onAction: _noop,
          ),
          _Buttons(),
          SectionHeader(title: 'Cards'),
          _Cards(),
          SectionHeader(title: 'Inputs'),
          _Inputs(),
          SectionHeader(title: 'Empty state'),
          AppCard(
            child: EmptyState(
              icon: Icons.video_library_outlined,
              title: 'No checks yet',
              body: 'Pick a draft video to see what we flag.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final swatches = <(String, Color)>[
      ('Primary', scheme.primary),
      ('Container', scheme.primaryContainer),
      ('Surface', scheme.surface),
      ('High', scheme.surfaceContainerHigh),
      ('Error', scheme.error),
      for (final category in FlagCategory.values)
        if (category != FlagCategory.unknown)
          (category.label, category.color(c)),
      for (final label in FactLabel.values)
        if (label != FactLabel.unknown) (label.label, label.color(c)),
    ];

    return Wrap(
      spacing: Spacing.space2,
      runSpacing: Spacing.space2,
      children: [
        for (final (name, color) in swatches) _Swatch(name: name, color: color),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  static const double _size = 40;

  // Three per row on a 360dp screen, wide enough for two-line labels.
  static const double _width = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _width,
      child: Column(
        children: [
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: Spacing.space1),
          Text(
            name,
            style: theme.textTheme.labelSmall,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('86%', style: AppTypography.monoOf(t.displaySmall)),
        Text('Headline small', style: t.headlineSmall),
        Text('Title large', style: t.titleLarge),
        Text('Title medium', style: t.titleMedium),
        Text('Body large reads like this.', style: t.bodyLarge),
        Text('Body medium reads like this.', style: t.bodyMedium),
        Text('Label large', style: t.labelLarge),
        Text('LABEL SMALL', style: t.labelSmall),
        Text(
          '12.4 MB of 86.0 MB  3.2 MB/s  0:42',
          style: AppTypography.monoOf(t.bodyMedium),
        ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(label: 'Run check', onPressed: () {}, expand: true),
        const SizedBox(height: Spacing.space3),
        Wrap(
          spacing: Spacing.space2,
          runSpacing: Spacing.space2,
          children: [
            AppButton(
              label: 'Pause',
              icon: Icons.pause,
              variant: AppButtonVariant.secondary,
              onPressed: () {},
            ),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.text,
              onPressed: () {},
            ),
            const AppButton(label: 'Disabled', onPressed: null),
          ],
        ),
        const SizedBox(height: Spacing.space3),
        AppButton(
          label: 'Upload',
          loadingLabel: 'Uploading',
          isLoading: true,
          expand: true,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          Icon(Icons.campaign_outlined, color: c.disclosure),
          const SizedBox(width: Spacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missing paid partnership label',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'Disclosure, high severity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text('0:42', style: AppTypography.monoOf(theme.textTheme.labelLarge)),
        ],
      ),
    );
  }
}

class _Inputs extends StatelessWidget {
  const _Inputs();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Caption',
            helperText: '0 / 2200',
          ),
        ),
        const SizedBox(height: Spacing.space3),
        Wrap(
          spacing: Spacing.space2,
          children: [
            FilterChip(
              label: const Text('Health'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Finance'),
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Paid or collab?'),
          value: true,
          onChanged: (_) {},
        ),
        const LinearProgressIndicator(value: 0.42),
      ],
    );
  }
}
