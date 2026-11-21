import 'dart:async';

import 'package:expense_splitter_app/models/auth_session.dart';
import 'package:expense_splitter_app/providers/auth_providers.dart';
import 'package:expense_splitter_app/screens/login_screen.dart';
import 'package:expense_splitter_app/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_service.dart';

void main() {
  late FakeAuthService auth;

  setUp(() => auth = FakeAuthService());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> chooseAdmin(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate(
      (w) => w is RadioListTile<AppRole> && w.value == AppRole.admin,
    ));
    await tester.pump();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillIn(WidgetTester tester) async {
    await tester.enterText(field('Username'), '  root  ');
    await tester.enterText(field('Password'), ' secret pass ');
  }

  TextField passwordField(WidgetTester tester) => tester.widget<TextField>(
    find.descendant(of: field('Password'), matching: find.byType(TextField)),
  );

  group('role selector', () {
    testWidgets('starts on User, showing only the Google button', (tester) async {
      await pumpLogin(tester);

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(field('Username'), findsNothing);
      expect(field('Password'), findsNothing);
    });

    testWidgets('Admin swaps to username and password, and back', (tester) async {
      await pumpLogin(tester);
      await chooseAdmin(tester);

      expect(find.text('Sign in with Google'), findsNothing);
      expect(field('Username'), findsOneWidget);
      expect(field('Password'), findsOneWidget);

      await tester.tap(find.byWidgetPredicate(
        (w) => w is RadioListTile<AppRole> && w.value == AppRole.user,
      ));
      await tester.pump();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(field('Username'), findsNothing);
    });

    testWidgets("can't be changed while signing in", (tester) async {
      auth.gate = Completer();
      await pumpLogin(tester);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      await chooseAdmin(tester);

      expect(find.text('Sign in with Google'), findsOneWidget);
      auth.gate!.complete();
      await tester.pump();
    });
  });

  group('User login', () {
    testWidgets('signs in with Google', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(auth.googleAttempts, 1);
      expect(auth.adminAttempts, 0);
    });

    testWidgets('backing out of Google shows no error', (tester) async {
      auth.failure = const AuthFailure('Cancelled.', cancelled: true);
      await pumpLogin(tester);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(find.text('Cancelled.'), findsNothing);
    });

    testWidgets('shows a failure message', (tester) async {
      auth.failure = const AuthFailure('Google sign-in failed.');
      await pumpLogin(tester);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(find.text('Google sign-in failed.'), findsOneWidget);
    });
  });

  group('Admin login', () {
    testWidgets('sends nothing until both fields are filled in', (tester) async {
      await pumpLogin(tester);
      await chooseAdmin(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Enter your username'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(auth.adminAttempts, 0);
    });

    testWidgets('trims the username but never the password', (tester) async {
      await pumpLogin(tester);
      await chooseAdmin(tester);
      await fillIn(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(auth.adminAttempts, 1);
      expect(auth.googleAttempts, 0);
      expect(auth.lastUsername, 'root');
      expect(auth.lastPassword, ' secret pass ');
    });

    testWidgets('the password is hidden until toggled', (tester) async {
      await pumpLogin(tester);
      await chooseAdmin(tester);
      expect(passwordField(tester).obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(passwordField(tester).obscureText, isFalse);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(passwordField(tester).obscureText, isTrue);
    });

    testWidgets('shows the failure and allows another try', (tester) async {
      auth.failure = const AuthFailure('Incorrect username or password.');
      await pumpLogin(tester);
      await chooseAdmin(tester);
      await fillIn(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Incorrect username or password.'), findsOneWidget);

      auth.failure = null;
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(auth.adminAttempts, 2);
      expect(find.text('Incorrect username or password.'), findsNothing);
    });
  });

  group('while a sign-in is in progress', () {
    testWidgets('shows a spinner and ignores repeat taps', (tester) async {
      auth.gate = Completer();
      await pumpLogin(tester);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Sign in with Google'), warnIfMissed: false);
      await tester.pump();
      expect(auth.googleAttempts, 1);

      auth.gate!.complete();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('pressing done on the keyboard can\'t send a second admin request', (tester) async {
      auth.gate = Completer();
      await pumpLogin(tester);
      await chooseAdmin(tester);
      await fillIn(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(auth.adminAttempts, 1);

      auth.gate!.complete();
      await tester.pump();
    });
  });
}
