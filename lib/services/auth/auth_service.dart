import '../../models/auth_session.dart';

/// A sign-in that didn't succeed, with a [message] safe to show as-is.
class AuthFailure implements Exception {
  final String message;

  /// The person backed out themselves, so nothing needs to be shown.
  final bool cancelled;

  const AuthFailure(this.message, {this.cancelled = false});

  @override
  String toString() => message;
}

abstract class AuthService {
  /// The current session, restored on launch; null when signed out.
  Stream<AuthSession?> get sessions;

  /// Throws [AuthFailure]. Has either fully succeeded or left the person signed
  /// out by the time it returns, and [sessions] only reports the new session
  /// after that.
  Future<void> signInWithGoogle();

  /// Throws [AuthFailure], with the same guarantee as [signInWithGoogle].
  Future<void> signInAsAdmin({
    required String username,
    required String password,
  });

  /// Re-checks the session with the server, picking up revoked sessions and
  /// changed claims. Being offline is not treated as a failure.
  Future<void> refreshSession();

  /// Signs out and clears anything cached on this device.
  Future<void> signOut();
}
