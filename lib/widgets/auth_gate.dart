import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../providers/auth_providers.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/group_list_screen.dart';
import '../screens/login_screen.dart';
import '../theme/app_theme.dart';

/// The app's root when sign-in is enabled. Keying [MaterialApp] by identity
/// rebuilds the whole Navigator whenever the person or role changes, so no
/// screen from a previous session or another role can stay on the stack.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(authServiceProvider).refreshSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authServiceProvider).refreshSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    final (Key key, Widget home) = session.when(
      loading: () => (
        const ValueKey('loading'),
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, _) => (const ValueKey('signed-out'), const LoginScreen()),
      data: (session) => switch (session) {
        null => (const ValueKey('signed-out'), const LoginScreen()),
        AuthSession(role: AppRole.admin) => (
          ValueKey('${session.uid}:admin'),
          const AdminDashboardScreen(),
        ),
        AuthSession(role: AppRole.user) => (
          ValueKey('${session.uid}:user'),
          const GroupListScreen(),
        ),
      },
    );

    return MaterialApp(
      key: key,
      title: 'Expense Splitter',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: home,
    );
  }
}
