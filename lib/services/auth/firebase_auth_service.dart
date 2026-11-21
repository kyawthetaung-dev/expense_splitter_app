import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/firebase_config.dart';
import '../../models/auth_session.dart';
import 'admin_email.dart';
import 'auth_service.dart';
import 'profile_sync.dart';

const _googleProviderId = 'google.com';

/// Codes meaning the session is over for good, unlike a network failure.
const _sessionEndedCodes = {
  'user-token-expired',
  'user-disabled',
  'user-not-found',
  'invalid-user-token',
};

/// Firebase answers a wrong password and an unknown account alike when email
/// enumeration protection is on; older projects may still tell them apart, so
/// every such code gets the same message.
const _badCredentialCodes = {
  'invalid-credential',
  'wrong-password',
  'user-not-found',
  'invalid-email',
  'missing-password',
};

class FirebaseAuthService implements AuthService {
  FirebaseAuthService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _subscription;
  Future<void>? _googleReady;
  Future<void> _lastEmit = Future.value();
  bool _signingIn = false;
  bool _profileSynced = false;

  late final StreamController<AuthSession?> _sessions =
      StreamController<AuthSession?>.broadcast(
        onListen: () => _subscription ??= _auth.idTokenChanges().listen(_onUser),
      );

  @override
  Stream<AuthSession?> get sessions => _sessions.stream;

  void _onUser(User? user) {
    // Held back during sign-in, so a failed profile sync can still be reported
    // on the login screen instead of the app switching away from it.
    if (_signingIn) return;
    _lastEmit = _lastEmit.then((_) async {
      _sessions.add(await _resolve(user));
    });
  }

  bool _isGoogleUser(User user) =>
      user.providerData.any((p) => p.providerId == _googleProviderId);

  Future<AuthSession?> _resolve(User? user) async {
    if (user == null) return null;

    AuthSession session(AppRole role) => AuthSession(
      uid: user.uid,
      role: role,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );

    if (_isGoogleUser(user)) return session(AppRole.user);

    try {
      final token = await user.getIdTokenResult();
      if (token.claims?['role'] == 'admin') return session(AppRole.admin);
      await signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      if (_sessionEndedCodes.contains(e.code)) {
        await signOut();
        return null;
      }
      // Offline: keep the UI usable. The rules still check the real claim.
      return session(AppRole.admin);
    }
  }

  /// Runs [signIn], publishing the session only once it has fully succeeded.
  Future<void> _holdingSession(Future<void> Function() signIn) async {
    _signingIn = true;
    try {
      await signIn();
    } finally {
      _signingIn = false;
      _onUser(_auth.currentUser);
    }
  }

  @override
  Future<void> signInWithGoogle() {
    return _holdingSession(() async {
      try {
        await (_googleReady ??= GoogleSignIn.instance.initialize(
          serverClientId: FirebaseConfig.googleServerClientId.isEmpty
              ? null
              : FirebaseConfig.googleServerClientId,
        ));
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw const AuthFailure('Google sign-in failed. Please try again.');
        }
        final credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
        await syncProfile(FirebaseFirestore.instance, credential.user!);
        _profileSynced = true;
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw const AuthFailure('Cancelled.', cancelled: true);
        }
        debugPrint('Google sign-in failed: ${e.code}');
        throw const AuthFailure('Google sign-in failed. Please try again.');
      } on FirebaseAuthException catch (e) {
        throw AuthFailure(_authMessage(e));
      } on FirebaseException catch (e) {
        debugPrint('Profile sync failed: ${e.code}');
        await _signOutOfProviders();
        throw AuthFailure(
          e.code == 'unavailable'
              ? "Couldn't reach the server. Check your connection and try again."
              : 'Sign-in failed. Please try again.',
        );
      }
    });
  }

  @override
  Future<void> signInAsAdmin({
    required String username,
    required String password,
  }) {
    return _holdingSession(() async {
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: adminEmailFor(username, Firebase.app().options.projectId),
          password: password,
        );
        final token = await credential.user!.getIdTokenResult();
        if (token.claims?['role'] != 'admin') {
          await _signOutOfProviders();
          throw const AuthFailure('Incorrect username or password.');
        }
      } on FirebaseAuthException catch (e) {
        throw AuthFailure(_authMessage(e));
      }
    });
  }

  @override
  Future<void> refreshSession() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken(true);
      // Covers the app having closed between signing in and the first sync.
      if (_isGoogleUser(user) && !_profileSynced) {
        await syncProfile(FirebaseFirestore.instance, user);
        _profileSynced = true;
      }
    } on FirebaseAuthException catch (e) {
      if (_sessionEndedCodes.contains(e.code)) await signOut();
    } on FirebaseException catch (e) {
      debugPrint('Profile sync will retry later: ${e.code}');
    }
  }

  @override
  Future<void> signOut() async {
    _profileSynced = false;
    // Closes listeners first: the cache can only be cleared once nothing is
    // using it, and it mustn't outlive this person on a shared device.
    final firestore = FirebaseFirestore.instance;
    await firestore.terminate();
    await firestore.clearPersistence();
    await _signOutOfProviders();
  }

  Future<void> _signOutOfProviders() async {
    final user = _auth.currentUser;
    final wasGoogle = user != null && _isGoogleUser(user);
    await _auth.signOut();
    if (wasGoogle) {
      await (_googleReady ??= GoogleSignIn.instance.initialize());
      await GoogleSignIn.instance.signOut();
    }
  }

  String _authMessage(FirebaseAuthException e) {
    debugPrint('Firebase sign-in failed: ${e.code}');
    if (_badCredentialCodes.contains(e.code)) {
      return 'Incorrect username or password.';
    }
    return switch (e.code) {
      'too-many-requests' =>
        'Too many attempts. Wait a few minutes and try again.',
      'network-request-failed' =>
        "Couldn't reach the server. Check your connection and try again.",
      'user-disabled' => 'This account has been disabled.',
      _ => 'Sign-in failed. Please try again.',
    };
  }
}
