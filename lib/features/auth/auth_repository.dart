import 'package:contextlens/core/config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who the app is acting as. Anonymous on first launch; the token is
/// managed and refreshed by the Firebase SDK and never stored by us.
abstract interface class AuthRepository {
  /// Signs in anonymously if nobody is signed in. Returns the uid.
  Future<String> ensureSignedIn();

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

  @override
  Future<String> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
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
