enum AppRole { user, admin }

/// Who is signed in. [role] only decides what the UI shows — Security Rules and
/// Cloud Functions make their own checks, so changing it on a device grants
/// nothing.
class AuthSession {
  final String uid;
  final AppRole role;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const AuthSession({
    required this.uid,
    required this.role,
    this.displayName,
    this.email,
    this.photoUrl,
  });
}
