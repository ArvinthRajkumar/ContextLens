import 'dart:async';

import 'package:contextlens/core/log.dart';
import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/declaration_form.dart';
import 'package:contextlens/features/compose/video_preview_card.dart';
import 'package:contextlens/features/drafts/drafts_controller.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/samples/sample.dart';
import 'package:contextlens/features/samples/sample_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Video preview and declaration on one scrolling page, with a sticky
/// "Run check" that stays disabled until everything is valid.
class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({this.parentJobId, this.draftId, super.key});

  /// Set when fixing a previous run; the new run is compared against it.
  final String? parentJobId;

  /// Set when reopening a draft.
  final String? draftId;

  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  final _formKey = GlobalKey<FormState>();

  /// False while a fix loads the earlier run's declaration; the form reads
  /// its starting values once, so it waits.
  late bool _ready = widget.parentJobId == null && widget.draftId == null;

  @override
  void initState() {
    super.initState();
    final parent = widget.parentJobId;
    if (parent != null) unawaited(_prefill(parent));
    final draft = widget.draftId;
    if (draft != null) unawaited(_restore(draft));
  }

  Future<void> _restore(String draftId) async {
    await ref.read(draftsControllerProvider.future);
    if (!mounted) return;
    var draft = ref.read(draftsControllerProvider.notifier).byId(draftId);
    // A sample draft keeps only the sample's id: its signed URLs have
    // expired, so fetch fresh ones.
    if (draft?.video case final video? when video.isSample) {
      final fresh = await _freshSample(video.sampleId!);
      if (!mounted) return;
      if (fresh != null) {
        draft = draft!.copyWith(
          video: fresh.toVideo(thumbnail: video.thumbnail),
        );
      }
    }
    final compose = ref.read(composeControllerProvider.notifier);
    if (draft == null) {
      compose.reset();
    } else {
      compose.restore(draft);
    }
    setState(() => _ready = true);
  }

  Future<Sample?> _freshSample(String id) async {
    try {
      final samples = await ref.read(sampleRepositoryProvider).list();
      return samples.where((s) => s.id == id).firstOrNull;
    } on Object catch (error) {
      log('Samples unavailable: ${error.runtimeType}');
      return null;
    }
  }

  /// Leaving with something worth keeping saves it as a draft. At the
  /// limit, the creator chooses whether to replace the oldest one.
  Future<void> _leave() async {
    final draft = ref.read(composeControllerProvider.notifier).currentDraft();
    final drafts = ref.read(draftsControllerProvider.notifier);
    if (draft != null) {
      await ref.read(draftsControllerProvider.future);
      final evict = drafts.evictionFor(draft);
      var save = true;
      if (evict != null) {
        if (!mounted) return;
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => _ReplaceDraftDialog(oldest: evict.title),
        );
        if (choice == null) return;
        save = choice;
      }
      if (save) await drafts.save(draft);
    }
    if (mounted) context.pop();
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
    final draftId = ref.read(composeControllerProvider.notifier).draftId;
    if (draftId != null) {
      unawaited(ref.read(draftsControllerProvider.notifier).delete(draftId));
    }
    ref.read(pendingSubmissionProvider.notifier).set(submission);
    context.push('/run/pending');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocker = ref.watch(
      composeControllerProvider.select((s) => s.blocker),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.parentJobId == null ? 'New check' : 'Check the fix',
          ),
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
            color: AppColors.of(context).glassStrong,
            border: Border(
              top: BorderSide(color: AppColors.of(context).glassBorder),
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

class _ReplaceDraftDialog extends StatelessWidget {
  const _ReplaceDraftDialog({required this.oldest});

  final String oldest;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save as a draft?'),
      content: Text(
        'You can keep ${DraftsController.limit} drafts. Saving this will '
        "delete your oldest draft, '$oldest'.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
