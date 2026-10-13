import 'package:contextlens/features/auth/auth_repository.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App start work that runs while the intro plays: sign-in, then Home's
/// data, so Home is ready when the intro hands off.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  // Anonymous sign-in on first launch; a no-op afterwards.
  await ref.read(authRepositoryProvider).ensureSignedIn();
  await ref.read(recentRunsProvider.future);
});

@immutable
class IntroState {
  const IntroState({this.visible = true, this.hold = false});

  final bool visible;

  /// Debug replay: stay on the final frame until tapped.
  final bool hold;
}

class IntroController extends Notifier<IntroState> {
  @override
  IntroState build() => const IntroState();

  void finish() => state = const IntroState(visible: false);

  void replay({bool hold = false}) => state = IntroState(hold: hold);
}

final introControllerProvider = NotifierProvider<IntroController, IntroState>(
  IntroController.new,
);
