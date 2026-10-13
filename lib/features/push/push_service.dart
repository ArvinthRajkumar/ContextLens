import 'dart:async';
import 'dart:io';

import 'package:contextlens/core/api_client.dart';
import 'package:contextlens/core/config.dart';
import 'package:contextlens/core/log.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:contextlens/router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Your report is ready" notifications. Permission is asked once, after
/// the first submitted check, behind our own pre-prompt.
abstract interface class PushService {
  /// Whether to show the pre-prompt now.
  bool get shouldAsk;

  /// The creator said yes in the pre-prompt: ask the OS, then register.
  Future<void> enable();

  /// The creator said not now; don't ask again.
  Future<void> decline();

  /// Re-registers when permission already exists, and routes taps on a
  /// notification to its report.
  Future<void> start();
}

class FirebasePushService implements PushService {
  FirebasePushService({
    required this._api,
    required this._prefs,
    required this._openReport,
  });

  static const _askedKey = 'push.asked';

  final ApiClient _api;
  final SharedPreferences _prefs;
  final void Function(String jobId) _openReport;
  final _subscriptions = <StreamSubscription<Object?>>[];

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  bool get shouldAsk => !(_prefs.getBool(_askedKey) ?? false);

  @override
  Future<void> enable() async {
    await _prefs.setBool(_askedKey, true);
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _register(await _messaging.getToken());
    }
  }

  @override
  Future<void> decline() => _prefs.setBool(_askedKey, true);

  @override
  Future<void> start() async {
    _subscriptions
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_open))
      ..add(_messaging.onTokenRefresh.listen(_register));
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _open(initial);

    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _register(await _messaging.getToken());
    }
  }

  void _open(RemoteMessage message) {
    final jobId = message.data['jobId'];
    if (message.data['type'] == 'report_ready' && jobId is String) {
      _openReport(jobId);
    }
  }

  Future<void> _register(String? token) async {
    if (token == null) return;
    try {
      await _api.post('/v1/devices', {
        'fcmToken': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } on ApiException catch (e) {
      log('Device registration failed: ${e.code}');
    }
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}

/// Mock mode: nothing to register, never asks.
class NoPushService implements PushService {
  @override
  bool get shouldAsk => false;

  @override
  Future<void> enable() async {}

  @override
  Future<void> decline() async {}

  @override
  Future<void> start() async {}
}

final pushServiceProvider = Provider<PushService>((ref) {
  if (AppConfig.isMock) return NoPushService();
  final service = FirebasePushService(
    api: ref.watch(apiClientProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    openReport: (jobId) => ref.read(routerProvider).go('/report/$jobId'),
  );
  unawaited(service.start());
  ref.onDispose(service.dispose);
  return service;
});
