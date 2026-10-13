import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

/// What the creator's clip says next to the original, with the words the
/// clip left out (or added) marked. Marks use weight and a tint plus a
/// legend, never color alone.
class TranscriptDiffView extends StatelessWidget {
  const TranscriptDiffView({required this.diff, super.key});

  final TranscriptDiff diff;

  static const double _tint = 0.18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge;
    final removed = body?.copyWith(
      fontWeight: FontWeight.w600,
      backgroundColor: scheme.error.withValues(alpha: _tint),
      decoration: TextDecoration.underline,
      decorationColor: scheme.error,
    );
    final added = body?.copyWith(
      fontWeight: FontWeight.w600,
      backgroundColor: scheme.primary.withValues(alpha: _tint),
    );
    final hasAdded = diff.segments.any((s) => s.op == DiffOp.insert);
    final leftOut = [
      for (final s in diff.segments)
        if (s.op == DiffOp.delete) s.text.trim(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Quote(
          label: 'In your clip',
          text: Text(diff.clipTranscript, style: body),
        ),
        const SizedBox(height: Spacing.space3),
        _Quote(
          label: 'Original',
          text: Text.rich(
            TextSpan(
              children: [
                for (final segment in diff.segments)
                  TextSpan(
                    text: segment.text,
                    style: switch (segment.op) {
                      DiffOp.equal => body,
                      DiffOp.delete => removed,
                      DiffOp.insert => added,
                    },
                  ),
              ],
            ),
            semanticsLabel:
                'Original: ${diff.originalTranscript}. '
                '${leftOut.isEmpty ? '' : 'Left out of your clip: ${leftOut.join(', ')}.'}',
          ),
        ),
        const SizedBox(height: Spacing.space2),
        ExcludeSemantics(
          child: Wrap(
            spacing: Spacing.space4,
            children: [
              _Legend(style: removed, label: 'Left out of your clip'),
              if (hasAdded) _Legend(style: added, label: 'Added in your clip'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.label, required this.text});

  final String label;
  final Widget text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Radii.chip,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.space1),
            text,
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.style, required this.label});

  final TextStyle? style;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('abc', style: style),
        const SizedBox(width: Spacing.space1),
        Text(label, style: muted),
      ],
    );
  }
}
