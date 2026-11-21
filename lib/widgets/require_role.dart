import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../providers/auth_providers.dart';
import 'empty_state.dart';

/// Shows [child] only to [role]. A second line of defence for role-specific
/// screens, on top of the auth gate; the server enforces the real permissions.
class RequireRole extends ConsumerWidget {
  final AppRole role;
  final Widget child;

  const RequireRole({super.key, required this.role, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    if (session?.role == role) return child;
    return const Scaffold(
      body: EmptyState(
        icon: Icons.lock_outline,
        title: 'Not available',
        subtitle: "This account doesn't have access to this screen.",
      ),
    );
  }
}
