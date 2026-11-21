import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../providers/auth_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/require_role.dart';
import '../widgets/sign_out_button.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    return RequireRole(
      role: AppRole.admin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: const [SignOutButton()],
        ),
        body: EmptyState(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Signed in as admin',
          subtitle: session?.displayName ?? '',
        ),
      ),
    );
  }
}
