import 'package:contextlens/core/theme/colors.dart';
import 'package:flutter/material.dart';

/// The sky to white gradient behind every route. Routes paint it themselves
/// so a page in transition never shows the one beneath it.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.of(context).background),
      child: child,
    );
  }
}
