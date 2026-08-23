import 'package:flutter/material.dart';

import 'screens/group_list_screen.dart';
import 'theme/app_theme.dart';

class ExpenseSplitterApp extends StatelessWidget {
  const ExpenseSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Splitter',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const GroupListScreen(),
    );
  }
}
