import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/section_header.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Caption, paid partnership, borrowed clips and topic. Must sit inside a
/// [Form] with [AutovalidateMode.onUnfocus], so errors appear when a field
/// loses focus or on submit, never while typing.
class DeclarationForm extends ConsumerStatefulWidget {
  const DeclarationForm({super.key});

  @override
  ConsumerState<DeclarationForm> createState() => _DeclarationFormState();
}

class _DeclarationFormState extends ConsumerState<DeclarationForm> {
  late final DeclarationDraft _initial = ref
      .read(composeControllerProvider)
      .declaration;
  late final _caption = TextEditingController(text: _initial.caption);
  late final _brand = TextEditingController(text: _initial.brand);
  final _brandFocus = FocusNode();

  ComposeController get _controller =>
      ref.read(composeControllerProvider.notifier);

  @override
  void dispose() {
    _caption.dispose();
    _brand.dispose();
    _brandFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motion = Motion.of(context);
    final declaration = ref.watch(
      composeControllerProvider.select((s) => s.declaration),
    );
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _caption,
          decoration: const InputDecoration(
            labelText: 'Caption',
            helperText:
                "Paste the exact caption you'll post, hashtags included.",
            helperMaxLines: 2,
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 8,
          maxLength: kCaptionMaxLength,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => validateCaption(value ?? ''),
          onChanged: (value) =>
              _controller.updateDeclaration((d) => d.copyWith(caption: value)),
        ),
        const SizedBox(height: Spacing.space5),
        _PaidSwitch(
          value: declaration.isPaid,
          onChanged: (isPaid) {
            _controller.updateDeclaration((d) => d.copyWith(isPaid: isPaid));
            if (isPaid) _brandFocus.requestFocus();
          },
        ),
        AnimatedSize(
          duration: motion.medium2,
          curve: Motion.standard,
          alignment: Alignment.topCenter,
          child: declaration.isPaid
              ? Padding(
                  padding: const EdgeInsets.only(top: Spacing.space2),
                  child: TextFormField(
                    controller: _brand,
                    focusNode: _brandFocus,
                    decoration: const InputDecoration(
                      labelText: 'Brand or partner',
                    ),
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        validateBrand(value ?? '', isPaid: true),
                    onChanged: (value) => _controller.updateDeclaration(
                      (d) => d.copyWith(brand: value),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        SectionHeader(
          title: 'Borrowed clips',
          actionLabel: 'Add clip',
          onAction: _controller.addClip,
        ),
        Text(
          'Footage, audio or quotes from other creators, shows or podcasts.',
          style: muted,
        ),
        for (final clip in declaration.clips) ...[
          const SizedBox(height: Spacing.space3),
          _ClipRow(key: ValueKey(clip.id), clip: clip),
        ],
        const SectionHeader(title: 'Topic'),
        SegmentedButton<ContentCategory>(
          segments: [
            for (final category in ContentCategory.values)
              ButtonSegment(value: category, label: Text(category.label)),
          ],
          selected: {declaration.category},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => _controller.updateDeclaration(
            (d) => d.copyWith(category: selection.first),
          ),
        ),
        const SizedBox(height: Spacing.space1),
        Text(
          'Health and finance videos get stricter claim checks.',
          style: muted,
        ),
      ],
    );
  }
}

/// A switch row without [SwitchListTile]'s list padding, so the form's
/// section rhythm stays even.
class _PaidSwitch extends StatelessWidget {
  const _PaidSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: InkWell(
        borderRadius: Radii.chip,
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paid or collab?', style: theme.textTheme.bodyLarge),
                  Text(
                    'Sponsored, gifted or affiliate content',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.space3),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _ClipRow extends ConsumerStatefulWidget {
  const _ClipRow({required this.clip, super.key});

  final ClipDraft clip;

  @override
  ConsumerState<_ClipRow> createState() => _ClipRowState();
}

class _ClipRowState extends ConsumerState<_ClipRow> {
  late final _label = TextEditingController(text: widget.clip.label);
  late final _url = TextEditingController(text: widget.clip.url);
  final _urlFocus = FocusNode();

  ComposeController get _controller =>
      ref.read(composeControllerProvider.notifier);

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final fileName = clip.fileName;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        Spacing.space4,
        Spacing.space3,
        Spacing.space1,
        Spacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: 'What is it?',
                    hintText: 'Podcast clip, song, news segment',
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _urlFocus.requestFocus(),
                  validator: (value) => validateClipLabel(value ?? ''),
                  onChanged: (value) => _controller.updateClip(
                    clip.id,
                    (c) => c.copyWith(label: value),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove clip',
                icon: const Icon(Icons.close),
                onPressed: () => _controller.removeClip(clip.id),
              ),
            ],
          ),
          const SizedBox(height: Spacing.space3),
          Padding(
            padding: const EdgeInsets.only(right: Spacing.space3),
            child: TextFormField(
              controller: _url,
              focusNode: _urlFocus,
              decoration: const InputDecoration(
                labelText: 'Link to the original',
                hintText: 'https://',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              validator: (value) {
                final text = value ?? '';
                return validateClipUrl(text) ??
                    (sanitizeText(text).isEmpty && !clip.hasSource
                        ? 'Add a link or attach the clip'
                        : null);
              },
              onChanged: (value) => _controller.updateClip(
                clip.id,
                (c) => c.copyWith(url: value),
              ),
            ),
          ),
          const SizedBox(height: Spacing.space1),
          if (fileName != null)
            InputChip(
              avatar: const Icon(Icons.attach_file, size: 18),
              label: Text(fileName, overflow: TextOverflow.ellipsis),
              onDeleted: () => _controller.updateClip(
                clip.id,
                (c) => c.copyWith(clearFile: true),
              ),
              deleteButtonTooltipMessage: 'Remove attachment',
            )
          else
            TextButton.icon(
              onPressed: () => _controller.attachClipFile(clip.id),
              icon: const Icon(Icons.attach_file),
              label: const Text('Or attach the clip'),
            ),
        ],
      ),
    );
  }
}
