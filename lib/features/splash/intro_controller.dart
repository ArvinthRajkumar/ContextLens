import 'package:contextlens/features/report/job_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App start work that runs while the intro plays. In mock mode this warms
/// Home's data; the real backend adds Firebase init and sign-in here.
final appBootstrapProvider = FutureProvider<void>((ref) async {
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
