import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

/// Stadium button with a loading state. Width follows its parent when
/// [expand] is true, otherwise it hugs its label.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.loadingLabel,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;

  /// Shown next to the spinner while loading, for example "Uploading".
  final String? loadingLabel;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    // While loading, keep the enabled look but swallow taps.
    final onTap = isLoading && onPressed != null ? _ignore : onPressed;
    final Widget child = Text(
      isLoading ? (loadingLabel ?? label) : label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final Widget? leading = isLoading
        ? const _ButtonSpinner()
        : (icon == null ? null : Icon(icon));

    final Widget button = switch (variant) {
      AppButtonVariant.primary =>
        leading == null
            ? FilledButton(onPressed: onTap, child: child)
            : FilledButton.icon(onPressed: onTap, icon: leading, label: child),
      AppButtonVariant.secondary =>
        leading == null
            ? OutlinedButton(onPressed: onTap, child: child)
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: leading,
                label: child,
              ),
      AppButtonVariant.text =>
        leading == null
            ? TextButton(onPressed: onTap, child: child)
            : TextButton.icon(onPressed: onTap, icon: leading, label: child),
    };

    return Semantics(
      liveRegion: isLoading,
      child: AbsorbPointer(
        absorbing: isLoading,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }

  static void _ignore() {}
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  static const double _size = 20;
  static const double _stroke = 2.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: CircularProgressIndicator(
        strokeWidth: _stroke,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: _size, height: _size),
        color: IconTheme.of(context).color,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
