import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug: pretend the device is offline (debug menu).
class SimulatedOffline extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool offline}) => state = offline;
}

final simulatedOfflineProvider = NotifierProvider<SimulatedOffline, bool>(
  SimulatedOffline.new,
);

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Whether the device has a network connection. Assumes online when the
/// platform can't tell (for example in tests).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  if (ref.watch(simulatedOfflineProvider)) {
    yield false;
    return;
  }
  final connectivity = Connectivity();
  try {
    yield _hasNetwork(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(_hasNetwork);
  } on Object {
    yield true;
  }
});
