import 'dart:async';

import 'package:contextlens/core/log.dart';
import 'package:contextlens/core/widgets/app_background.dart';
import 'package:contextlens/core/widgets/lens_mark.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps a report out of the app switcher. While any [PrivacyScreen] is
/// mounted, Android 13+ leaves the recents thumbnail blank, and whenever
/// the app stops being in front the content is covered by the brand mark
/// (which is what iOS and older Android capture). Screenshots still work.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({required this.child, super.key});

  final Widget child;

  static const _channel = MethodChannel('contextlens/privacy');

  /// Open private screens; the platform flag is on while this is above 0.
  static int _open = 0;

  static Future<void> _setPrivate({required bool private}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setPrivate', private);
    } on Object catch (error) {
      log('Privacy flag unavailable: ${error.runtimeType}');
    }
  }

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _covered = false;

  static const double _markSize = 72;

  @override
  void initState() {
    super.initState();
    if (PrivacyScreen._open++ == 0) {
      unawaited(PrivacyScreen._setPrivate(private: true));
    }
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final covered = state != AppLifecycleState.resumed;
        if (covered != _covered) setState(() => _covered = covered);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (--PrivacyScreen._open == 0) {
      unawaited(PrivacyScreen._setPrivate(private: false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_covered)
          const Positioned.fill(
            child: AppBackground(
              child: Center(child: LensMark(size: _markSize)),
            ),
          ),
      ],
    );
  }
}
