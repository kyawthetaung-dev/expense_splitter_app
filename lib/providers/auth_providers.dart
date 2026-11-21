import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/firebase_config.dart';
import '../models/auth_session.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/firebase_auth_service.dart';

/// Whether sign-in is part of this build. See [FirebaseConfig.enabled].
final authEnabledProvider = Provider<bool>((ref) => FirebaseConfig.enabled);

final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(),
);

final authSessionProvider = StreamProvider<AuthSession?>(
  (ref) => ref.watch(authServiceProvider).sessions,
);
