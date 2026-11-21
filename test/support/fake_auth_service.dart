import 'dart:async';

import 'package:expense_splitter_app/models/auth_session.dart';
import 'package:expense_splitter_app/services/auth/auth_service.dart';

class FakeAuthService implements AuthService {
  final _sessions = StreamController<AuthSession?>.broadcast();

  int googleAttempts = 0;
  int adminAttempts = 0;
  int refreshes = 0;
  int signOuts = 0;
  String? lastUsername;
  String? lastPassword;

  /// When set, sign-ins wait on this, to observe the in-progress state.
  Completer<void>? gate;

  /// When set, sign-ins throw this.
  AuthFailure? failure;

  void emit(AuthSession? session) => _sessions.add(session);

  Future<void> _run() async {
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Stream<AuthSession?> get sessions => _sessions.stream;

  @override
  Future<void> signInWithGoogle() {
    googleAttempts++;
    return _run();
  }

  @override
  Future<void> signInAsAdmin({
    required String username,
    required String password,
  }) {
    adminAttempts++;
    lastUsername = username;
    lastPassword = password;
    return _run();
  }

  @override
  Future<void> refreshSession() async => refreshes++;

  @override
  Future<void> signOut() async {
    signOuts++;
    emit(null);
  }
}
