import 'package:contextlens/core/config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who the app is acting as. Anonymous on first launch; the token is
/// managed and refreshed by the Firebase SDK and never stored by us.
abstract interface class AuthRepository {
  /// Signs in anonymously if nobody is signed in. Returns the uid.
  Future<String> ensureSignedIn();

  /// Like [ensureSignedIn], but also waits until the SDK has announced the
  /// user, so listeners that read the auth state (Firestore) see it too.
  /// Use it before any Firestore read.
  Future<String> whenSignedIn();

  String? get uid;

  /// A fresh ID token for the API (the SDK refreshes it when needed).
  Future<String> idToken();

  /// Forgets this account on the device. The next [ensureSignedIn] starts
  /// a new anonymous one.
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// The sign-in in progress. Callers that arrive while it runs share it:
  /// two concurrent anonymous sign-ins would create two accounts, and a
  /// query made for the first one is denied once the second replaces it.
  Future<String>? _signingIn;

  @override
  Future<String> ensureSignedIn() {
    final current = _auth.currentUser;
    if (current != null) return Future.value(current.uid);
    return _signingIn ??= _auth
        .signInAnonymously()
        .then((credential) => credential.user!.uid)
        .whenComplete(() => _signingIn = null);
  }

  @override
  Future<String> whenSignedIn() async {
    final uid = await ensureSignedIn();
    // A fresh anonymous sign-in returns before every auth listener has run;
    // a query sent in that gap reaches Firestore without credentials.
    final user = await _auth.authStateChanges().firstWhere(
      (user) => user?.uid == uid,
    );
    await user!.getIdToken();
    return uid;
  }

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  Future<String> idToken() async {
    await ensureSignedIn();
    final token = await _auth.currentUser!.getIdToken();
    if (token == null) throw StateError('No ID token');
    return token;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class FakeAuthRepository implements AuthRepository {
  static const mockUid = 'mock-user';

  @override
  Future<String> ensureSignedIn() async => mockUid;

  @override
  Future<String> whenSignedIn() async => mockUid;

  @override
  String? get uid => mockUid;

  @override
  Future<String> idToken() async => 'mock-token';

  @override
  Future<void> signOut() async {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return switch (AppConfig.backend) {
    BackendMode.mock => FakeAuthRepository(),
    BackendMode.real => FirebaseAuthRepository(),
  };
});
