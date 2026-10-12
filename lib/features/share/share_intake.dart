import 'dart:async';
import 'dart:io';

import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_handler/share_handler.dart';

/// Videos shared into the app from other apps (Android share sheet).
/// Handles both a cold start (the share launched the app) and a warm one.
class ShareIntake {
  ShareIntake(this._ref);

  final Ref _ref;
  StreamSubscription<SharedMedia>? _subscription;

  Future<void> start() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final handler = ShareHandlerPlatform.instance;
    _subscription = handler.sharedMediaStream.listen(
      _handle,
      onError: (Object _) {},
    );
    final initial = await handler.getInitialSharedMedia();
    if (initial != null) {
      _handle(initial);
      await handler.resetInitialSharedMedia();
    }
  }

  void _handle(SharedMedia media) {
    final attachments =
        media.attachments?.nonNulls ?? const <SharedAttachment>[];
    final video =
        attachments
            .where((a) => a.type == SharedAttachmentType.video)
            .firstOrNull ??
        attachments.firstOrNull;
    if (video == null) return;

    unawaited(
      _ref.read(composeControllerProvider.notifier).useSharedFile(video.path),
    );
    final router = _ref.read(routerProvider);
    if (router.routerDelegate.currentConfiguration.uri.path != '/new') {
      unawaited(router.push('/new'));
    }
  }

  void dispose() => unawaited(_subscription?.cancel());
}

final shareIntakeProvider = Provider<ShareIntake>((ref) {
  final intake = ShareIntake(ref);
  unawaited(intake.start());
  ref.onDispose(intake.dispose);
  return intake;
});
