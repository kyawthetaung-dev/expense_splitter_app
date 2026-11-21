import 'dart:io';

import 'package:expense_splitter_app/app.dart';
import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/models/auth_session.dart';
import 'package:expense_splitter_app/providers/auth_providers.dart';
import 'package:expense_splitter_app/screens/admin_dashboard_screen.dart';
import 'package:expense_splitter_app/screens/group_list_screen.dart';
import 'package:expense_splitter_app/screens/login_screen.dart';
import 'package:expense_splitter_app/widgets/require_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../support/fake_auth_service.dart';

const _alice = AuthSession(uid: 'alice', role: AppRole.user, displayName: 'Alice');
const _bob = AuthSession(uid: 'bob', role: AppRole.user, displayName: 'Bob');
const _root = AuthSession(uid: 'root', role: AppRole.admin, displayName: 'root');

void main() {
  late Directory tempDir;
  late FakeAuthService auth;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('auth_gate_test');
    await HiveBoxes.initForTest(tempDir.path);
    auth = FakeAuthService();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpApp(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authEnabledProvider.overrideWithValue(enabled),
          authServiceProvider.overrideWithValue(auth),
        ],
        child: const ExpenseSplitterApp(),
      ),
    );
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, AuthSession? session) async {
    auth.emit(session);
    await tester.pump();
    await tester.pump();
  }

  /// Pushes a screen, standing in for someone being deep in the app.
  void pushScreen(WidgetTester tester, Type onTopOf) {
    final context = tester.element(find.byType(onTopOf));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Deep screen')),
      ),
    );
  }

  testWidgets('with sign-in off, the app opens directly as before', (tester) async {
    await pumpApp(tester, enabled: false);

    expect(find.byType(GroupListScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byTooltip('Sign out'), findsNothing);
  });

  testWidgets('waits for the session before showing anything protected', (tester) async {
    await pumpApp(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GroupListScreen), findsNothing);
    expect(find.byType(AdminDashboardScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('signed out goes to the login screen', (tester) async {
    await pumpApp(tester);
    await emit(tester, null);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(GroupListScreen), findsNothing);
  });

  testWidgets('each role reaches only its own dashboard', (tester) async {
    await pumpApp(tester);

    await emit(tester, _alice);
    expect(find.byType(GroupListScreen), findsOneWidget);
    expect(find.byType(AdminDashboardScreen), findsNothing);

    await emit(tester, null);
    await emit(tester, _root);
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.byType(GroupListScreen), findsNothing);
  });

  testWidgets('signing out from a deep screen leaves nothing on the stack', (tester) async {
    await pumpApp(tester);
    await emit(tester, _alice);
    pushScreen(tester, GroupListScreen);
    await tester.pumpAndSettle();
    expect(find.text('Deep screen'), findsOneWidget);

    await emit(tester, null);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Deep screen'), findsNothing);
    expect(find.byType(GroupListScreen, skipOffstage: false), findsNothing);
  });

  testWidgets("one person's screens don't survive into another's session", (tester) async {
    await pumpApp(tester);
    await emit(tester, _alice);
    pushScreen(tester, GroupListScreen);
    await tester.pumpAndSettle();

    await emit(tester, _bob);
    await tester.pumpAndSettle();

    expect(find.text('Deep screen'), findsNothing);
    expect(find.byType(GroupListScreen), findsOneWidget);
  });

  testWidgets('a token refresh for the same person keeps their place', (tester) async {
    await pumpApp(tester);
    await emit(tester, _alice);
    pushScreen(tester, GroupListScreen);
    await tester.pumpAndSettle();

    await emit(tester, _alice);
    await tester.pumpAndSettle();

    expect(find.text('Deep screen'), findsOneWidget);
  });

  testWidgets('losing the admin role ends the admin screens', (tester) async {
    await pumpApp(tester);
    await emit(tester, _root);
    pushScreen(tester, AdminDashboardScreen);
    await tester.pumpAndSettle();

    await emit(tester, const AuthSession(uid: 'root', role: AppRole.user));
    await tester.pumpAndSettle();

    expect(find.text('Deep screen'), findsNothing);
    expect(find.byType(AdminDashboardScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('the sign-out button signs out and returns to login', (tester) async {
    await pumpApp(tester);
    await emit(tester, _alice);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();
    await tester.pump();

    expect(auth.signOuts, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('re-checks the session on launch and when the app resumes', (tester) async {
    await pumpApp(tester);
    expect(auth.refreshes, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(auth.refreshes, 2);
  });

  group('RequireRole', () {
    Future<void> pumpGuarded(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(auth)],
          child: const MaterialApp(
            home: RequireRole(role: AppRole.admin, child: Text('Admin only')),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('blocks a user who navigates directly to an admin screen', (tester) async {
      await pumpGuarded(tester);
      await emit(tester, _alice);

      expect(find.text('Admin only'), findsNothing);
      expect(find.text('Not available'), findsOneWidget);
    });

    testWidgets('blocks when signed out', (tester) async {
      await pumpGuarded(tester);
      await emit(tester, null);

      expect(find.text('Admin only'), findsNothing);
    });

    testWidgets('allows the right role', (tester) async {
      await pumpGuarded(tester);
      await emit(tester, _root);

      expect(find.text('Admin only'), findsOneWidget);
    });
  });
}
