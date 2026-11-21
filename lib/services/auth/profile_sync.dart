import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Creates or refreshes a Google user's profile, and publishes their address
/// so others can assign them by exact email. The security rules only accept
/// this as the signed-in person, with the email from their verified token and
/// the plain `user` role, so it can't be used to claim anything more.
Future<void> syncProfile(FirebaseFirestore db, User user) async {
  final email = (user.email ?? '').toLowerCase();
  final displayName = user.displayName ?? user.email ?? 'User';
  final profileRef = db.collection('users').doc(user.uid);

  await db.runTransaction((tx) async {
    final existing = await tx.get(profileRef);
    tx.set(profileRef, {
      'emailLower': email,
      'displayName': displayName,
      'photoUrl': user.photoURL,
      'role': 'user',
      'lastLoginAt': FieldValue.serverTimestamp(),
      'createdAt': existing.exists
          ? existing.data()!['createdAt']
          : FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('userLookup').doc(email), {
      'uid': user.uid,
      'displayName': displayName,
    });
  });
}
