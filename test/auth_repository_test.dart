import 'dart:async';

import 'package:contextlens/features/auth/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  _User(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Signs in slowly, so two callers overlap, and makes a new account for
/// every call, as Firebase does.
class _SlowAuth implements FirebaseAuth {
  int signIns = 0;
  final _done = Completer<void>();

  @override
  User? currentUser;

  void finish() => _done.complete();

  @override
  Future<UserCredential> signInAnonymously() async {
    final user = _User('anon-${++signIns}');
    await _done.future;
    currentUser = user;
    return _Credential(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('concurrent sign-ins share one anonymous account', () async {
    final auth = _SlowAuth();
    final repository = FirebaseAuthRepository(auth);

    final first = repository.ensureSignedIn();
    final second = repository.ensureSignedIn();
    auth.finish();

    expect(await first, 'anon-1');
    expect(await second, 'anon-1');
    expect(auth.signIns, 1);
    expect(await repository.ensureSignedIn(), 'anon-1');
    expect(auth.signIns, 1);
  });
}
