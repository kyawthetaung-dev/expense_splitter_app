import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_splitter_app/app.dart';
import 'package:expense_splitter_app/config/firebase_config.dart';
import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/models/auth_session.dart';
import 'package:expense_splitter_app/screens/admin_dashboard_screen.dart';
import 'package:expense_splitter_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs the real app on a real Android runtime against the local Firebase
/// emulators, set up by firebase/src/__tests__/device_fixture.ts:
///
///   npm --prefix firebase run test:device
///
/// Covers the admin path only: the Google flow needs a real Firebase project
/// and an account on the device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    final onScreen = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toList();
    fail('Timed out waiting for $finder. On screen: $onScreen');
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> signInAsAdmin(WidgetTester tester, String password) async {
    await pumpUntil(tester, find.byType(LoginScreen));
    if (field('Username').evaluate().isEmpty) {
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RadioListTile<AppRole> && w.value == AppRole.admin,
        ),
      );
      await tester.pump();
    }
    await tester.enterText(field('Username'), 'device-admin');
    await tester.enterText(field('Password'), password);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
  }

  testWidgets('admin login, access rules, sign-out and signing in again', (
    tester,
  ) async {
    await FirebaseConfig.initialize();
    await HiveBoxes.init();
    await tester.pumpWidget(const ProviderScope(child: ExpenseSplitterApp()));

    // A wrong password is refused, with the same message as an unknown name.
    await signInAsAdmin(tester, 'wrong password');
    await pumpUntil(tester, find.text('Incorrect username or password.'));
    expect(find.byType(AdminDashboardScreen), findsNothing);

    // The right one reaches the admin dashboard, through Firebase's own
    // email/password sign-in and the admin claim.
    await signInAsAdmin(tester, 'device-test-password');
    await pumpUntil(tester, find.byType(AdminDashboardScreen));

    // The admin can read an invoice they aren't assigned to...
    final invoice = FirebaseFirestore.instance.doc('invoices/device-invoice');
    expect((await invoice.get()).data()?['name'], 'Device test invoice');

    // ...but even they can't complete it by writing to it directly.
    await expectLater(
      invoice.update({'status': 'completed'}),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );

    // Signing out returns to login and clears this device's cache.
    await tester.tap(find.byTooltip('Sign out'));
    await pumpUntil(tester, find.byType(LoginScreen));
    expect(find.byType(AdminDashboardScreen), findsNothing);

    // Signed out, the same read is refused.
    await expectLater(
      FirebaseFirestore.instance.doc('invoices/device-invoice').get(),
      throwsA(isA<FirebaseException>()),
    );

    // Firestore has to come back working after being shut down for sign-out.
    await signInAsAdmin(tester, 'device-test-password');
    await pumpUntil(tester, find.byType(AdminDashboardScreen));
    final again = await FirebaseFirestore.instance
        .doc('invoices/device-invoice')
        .get();
    expect(again.data()?['name'], 'Device test invoice');
  });
}
