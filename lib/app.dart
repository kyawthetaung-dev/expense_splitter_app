import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_providers.dart';
import 'screens/group_list_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

class ExpenseSplitterApp extends ConsumerWidget {
  const ExpenseSplitterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authEnabledProvider)) return const AuthGate();

    return MaterialApp(
      title: 'Expense Splitter',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const GroupListScreen(),
    );
  }
}
