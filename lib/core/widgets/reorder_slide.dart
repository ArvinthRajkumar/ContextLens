import 'package:contextlens/core/theme/motion.dart';
import 'package:flutter/material.dart';

/// Slides its child from where it was to where it is now whenever [order]
/// changes (a list reorder), so cards glide to their new places instead of
/// jumping. Give each child a stable key so its state follows it.
class ReorderSlide extends StatefulWidget {
  const ReorderSlide({required this.order, required this.child, super.key});

  /// Changes when the surrounding list is reordered.
  final Object order;
  final Widget child;

  @override
  State<ReorderSlide> createState() => _ReorderSlideState();
}

class _ReorderSlideState extends State<ReorderSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Durations.medium2,
  );
  Offset _from = Offset.zero;

  Offset? _position() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero);
  }

  @override
  void didUpdateWidget(ReorderSlide old) {
    super.didUpdateWidget(old);
    if (widget.order == old.order) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    // Layout hasn't run yet, so this is still last frame's position.
    final before = _position();
    if (before == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final after = _position();
      if (after == null) return;
      final delta = before - after;
      if (delta.distanceSquared < 1) return;
      setState(() => _from = delta);
      _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Motion.standard.transform(_controller.value);
        final offset = _controller.isAnimating ? _from * (1 - t) : Offset.zero;
        return Transform.translate(offset: offset, child: child);
      },
      child: widget.child,
    );
  }
}
