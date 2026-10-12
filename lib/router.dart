import 'package:contextlens/features/home/home_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => const HomePage())],
  );
  ref.onDispose(router.dispose);
  return router;
});
