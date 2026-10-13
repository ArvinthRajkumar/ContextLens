import 'dart:async';

import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/declaration_form.dart';
import 'package:contextlens/features/compose/video_preview_card.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Video preview and declaration on one scrolling page, with a sticky
/// "Run check" that stays disabled until everything is valid.
class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({this.parentJobId, super.key});

  /// Set when fixing a previous run; the new run is compared against it.
  final String? parentJobId;

  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  final _formKey = GlobalKey<FormState>();

  /// False while a fix loads the earlier run's declaration; the form reads
  /// its starting values once, so it waits.
  late bool _ready = widget.parentJobId == null;

  @override
  void initState() {
    super.initState();
    final parent = widget.parentJobId;
    if (parent != null) unawaited(_prefill(parent));
  }

  Future<void> _prefill(String parentJobId) async {
    final declaration = await ref
        .read(declarationProvider(parentJobId).future)
        .catchError((Object _) => null);
    if (!mounted) return;
    ref.read(composeControllerProvider.notifier).startFix(declaration);
    setState(() => _ready = true);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final submission = ref
        .read(composeControllerProvider.notifier)
        .buildSubmission(parentJobId: widget.parentJobId);
    if (submission == null) return;
    ref.read(pendingSubmissionProvider.notifier).set(submission);
    context.push('/run/pending');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocker = ref.watch(
      composeControllerProvider.select((s) => s.blocker),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parentJobId == null ? 'New check' : 'Check the fix'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.screen,
            Spacing.space2,
            Spacing.screen,
            Spacing.space8,
          ),
          children: [
            if (widget.parentJobId case final parent?) ...[
              _FixBanner(parentJobId: parent),
              const SizedBox(height: Spacing.space4),
            ],
            const VideoPreviewCard(),
            const SectionHeader(title: 'About this video'),
            if (_ready)
              const DeclarationForm()
            else
              const Padding(
                padding: EdgeInsets.all(Spacing.space6),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
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
              Spacing.space2,
              Spacing.screen,
              Spacing.space3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (blocker != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      blocker,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: Spacing.space2),
                ],
                AppButton(
                  label: 'Run check',
                  expand: true,
                  onPressed: blocker == null ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Says which run this fix is for and what carried over.
class _FixBanner extends ConsumerWidget {
  const _FixBanner({required this.parentJobId});

  final String parentJobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parent = ref.watch(jobProvider(parentJobId)).value;
    final title = parent?.title;

    return AppCard(
      color: scheme.primaryContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_fix_high, color: scheme.onPrimaryContainer),
          const SizedBox(width: Spacing.space3),
          Expanded(
            child: Text(
              title == null
                  ? 'Pick the edited video. Your caption and details are '
                        'carried over from the last run.'
                  : 'Checking a fix for "$title". Pick the edited video; '
                        'your caption and details are carried over.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
