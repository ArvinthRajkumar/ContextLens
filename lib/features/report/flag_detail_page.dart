import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/info_pill.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/report/clause_chips.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/transcript_diff.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Everything about one flag. Pops with `true` when the creator asks to
/// watch that part of the video.
class FlagDetailPage extends StatelessWidget {
  const FlagDetailPage({required this.flag, super.key});

  final Flag flag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(flag.category.label)),
      body: FlagDetailContent(flag: flag),
    );
  }
}

/// The detail body, shared by the full page and the small-screen sheet.
class FlagDetailContent extends StatelessWidget {
  const FlagDetailContent({
    required this.flag,
    this.scrollController,
    super.key,
  });

  final Flag flag;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final label = flag.factLabel;
    final uncertain = flag.uncertain;
    final severity = uncertain ? null : flag.severity;
    final citation = flag.citation;
    final quote = flag.sourceQuote;
    final diff = flag.diff;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        Spacing.screen,
        Spacing.space2,
        Spacing.screen,
        Spacing.space8,
      ),
      children: [
        Text(flag.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Spacing.space3),
        Wrap(
          spacing: Spacing.space2,
          runSpacing: Spacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InfoPill(
              icon: flag.category.icon,
              label: flag.category.label,
              color: flag.category.color(colors),
            ),
            if (uncertain)
              InfoPill(
                icon: UncertainPresentation.icon,
                label: UncertainPresentation.label,
                color: colors.insufficientEvidence,
              )
            else if (label != null)
              InfoPill(
                icon: label.icon,
                label: label.label,
                color: label.color(colors),
              ),
            if (severity != null) Text(severity.label, style: muted),
          ],
        ),
        if (citation?.clauseLabel != null) ...[
          const SizedBox(height: Spacing.space2),
          ClauseChips(citation: citation),
        ],
        if (uncertain) ...[
          const SizedBox(height: Spacing.space4),
          const _UncertainNote(),
        ],
        const SizedBox(height: Spacing.space4),
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.space2),
            Expanded(
              child: Text(
                '${formatDurationMs(flag.startMs)} to ${formatDurationMs(flag.endMs)}',
                style: AppTypography.monoOf(theme.textTheme.bodyMedium),
              ),
            ),
            AppButton(
              label: 'Watch this part',
              icon: Icons.play_arrow_rounded,
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
        const SectionHeader(title: 'What we found'),
        Text(flag.evidence, style: theme.textTheme.bodyLarge),
        if (quote != null) ...[
          const SectionHeader(title: 'From the source'),
          _SourceQuoteBlock(quote: quote),
        ],
        const SectionHeader(title: 'Suggested fix'),
        AppCard(
          color: theme.colorScheme.primaryContainer,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: Text(
                  flag.suggestedFix,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (diff != null) ...[
          const SectionHeader(title: 'Clip compared with the original'),
          TranscriptDiffView(diff: diff),
        ],
        if (citation != null) ...[
          const SectionHeader(title: 'Source'),
          _CitationTile(citation: citation),
        ],
      ],
    );
  }
}

class _CitationTile extends StatelessWidget {
  const _CitationTile({required this.citation});

  final Citation citation;

  /// Report text is untrusted: only https links open, and always outside
  /// the app.
  Uri? get _safeUrl {
    final url = citation.url;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _safeUrl;
    final publisher = citation.publisher;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: url == null
          ? null
          : () => launchUrl(url, mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.space4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(citation.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: Spacing.space1),
                  Text(
                    [?publisher, ?url?.host].join('  ·  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (url != null) ...[
              const SizedBox(width: Spacing.space3),
              Icon(
                Icons.open_in_new,
                size: 20,
                semanticLabel: 'Opens in your browser',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UncertainNote extends StatelessWidget {
  const _UncertainNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerLow,
      borderColor: colors.insufficientEvidence,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(UncertainPresentation.icon, color: colors.insufficientEvidence),
          const SizedBox(width: Spacing.space3),
          Expanded(
            child: Text(
              UncertainPresentation.explainer,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The verbatim passage the evidence gate matched, set apart from our own
/// words with a rule on the left.
class _SourceQuoteBlock extends StatelessWidget {
  const _SourceQuoteBlock({required this.quote});

  final SourceQuote quote;

  static const double _rule = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: 'Quote from ${quote.source}',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: scheme.primary,
                child: const SizedBox(width: _rule),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u201c${quote.text}\u201d',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: Spacing.space2),
                      Text(
                        quote.source,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
