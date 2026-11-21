import 'dart:async';
import 'dart:convert';

import 'package:expense_splitter_app/app.dart';
import 'package:expense_splitter_app/config/firebase_config.dart';
import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/data/store/firestore_invoice_store.dart';
import 'package:expense_splitter_app/data/store/invoice_store.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/screens/group_dashboard_screen.dart';
import 'package:expense_splitter_app/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_splitter_app/services/auth/profile_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs the Firestore store on a real Android runtime against the local
/// Firebase emulators, so every query and change meets the real security
/// rules:
///
///   npm --prefix firebase run test:store
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final run = DateTime.now().microsecondsSinceEpoch;

  /// Signs in through the Auth emulator's Google flow, which accepts an
  /// unsigned ID token, and creates the profile as the app does. Clears the
  /// cache first, as the app's sign-out does, so nothing carries over from
  /// the previous person.
  Future<String> signInWithGoogle(String name) async {
    await FirebaseFirestore.instance.terminate();
    await FirebaseFirestore.instance.clearPersistence();
    await FirebaseAuth.instance.signOut();
    final credential = await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: jsonEncode({
          'sub': '$name-$run',
          'email': '$name-$run@example.com',
          'email_verified': true,
          'name': name,
        }),
      ),
    );
    await syncProfile(FirebaseFirestore.instance, credential.user!);
    return credential.user!.uid;
  }

  /// The first value [stream] emits that passes [test], failing rather than
  /// hanging if it never comes.
  Future<T> eventually<T>(Stream<T> stream, bool Function(T) test) =>
      stream.firstWhere(test).timeout(const Duration(seconds: 20));

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(finder, findsOneWidget);
  }

  ExpenseInput dinner(
    String groupId,
    String expenseId, {
    required bool isNew,
    int? expectedRevision,
    required Map<String, int> payers,
    required List<String> participants,
    int total = 3000,
    SplitType splitType = SplitType.equal,
    Map<String, double>? percentages,
  }) => ExpenseInput(
    groupId: groupId,
    expenseId: expenseId,
    isNew: isNew,
    expectedRevision: expectedRevision,
    title: 'Dinner',
    totalAmount: total,
    splitType: splitType,
    payerAmounts: payers,
    participantIds: participants,
    percentages: percentages,
  );

  testWidgets('a user works with groups and expenses through Firestore', (
    tester,
  ) async {
    await FirebaseConfig.initialize();
    await HiveBoxes.init();
    final alice = await signInWithGoogle('alice');
    final store = FirestoreInvoiceStore(uid: alice, isAdmin: false);

    // Contacts.
    final bob = await store.createContact('Bob');
    final cat = await store.createContact('Cat');
    await eventually(store.watchContacts(), (c) => c.length == 2);

    // Creating a group, and retrying the same create, makes one group.
    final tripId = 'trip-$run';
    final keptId = 'kept-$run';
    for (var attempt = 0; attempt < 2; attempt++) {
      await store.createGroup(
        groupId: tripId,
        name: 'Trip',
        participantIds: [bob.id, cat.id],
      );
    }
    await store.createGroup(
      groupId: keptId,
      name: 'Kept',
      participantIds: [bob.id],
    );
    final groups = await eventually(store.watchGroups(), (g) => g.length == 2);
    expect({for (final g in groups) g.group.name}, {'Trip', 'Kept'});

    // Shares are worked out by the shared calculator and must pass the rules'
    // totals check: 33.33% and 66.67% of 3,000 leave 999.9 and 2,000.1, and
    // the leftover goes to the larger remainder.
    await store.saveExpense(
      dinner(
        tripId,
        'v1-$run',
        isNew: true,
        payers: {bob.id: 3000},
        participants: [bob.id, cat.id],
        splitType: SplitType.percentage,
        percentages: {bob.id: 33.33, cat.id: 66.67},
      ),
    );
    var trip = (await eventually(
      store.watchInvoice(tripId),
      (s) => s != null && s.shares.length == 2,
    ))!;
    expect({for (final s in trip.shares) s.participantId: s.shareAmount}, {
      bob.id: 1000,
      cat.id: 2000,
    });
    final voucher = trip.expenses.single;
    expect(voucher.percentages, {bob.id: 33.33, cat.id: 66.67});
    expect(voucher.revision, 1);

    // An edit based on an old revision is refused, not silently applied.
    await expectLater(
      store.saveExpense(
        dinner(
          tripId,
          voucher.id,
          isNew: false,
          expectedRevision: 0,
          payers: {cat.id: 3000},
          participants: [bob.id, cat.id],
        ),
      ),
      throwsA(isA<StoreException>()),
    );
    await store.saveExpense(
      dinner(
        tripId,
        voucher.id,
        isNew: false,
        expectedRevision: voucher.revision,
        total: 6000,
        payers: {cat.id: 6000},
        participants: [bob.id, cat.id],
      ),
    );
    trip = (await eventually(
      store.watchInvoice(tripId),
      (s) => s!.expenses.single.revision == 2 && s.payers.length == 1,
    ))!;
    expect({for (final s in trip.shares) s.participantId: s.shareAmount}, {
      bob.id: 3000,
      cat.id: 3000,
    });
    expect(trip.payers.single.participantId, cat.id);

    // The list reads the summary kept on the invoice.
    final listed = await eventually(
      store.watchGroups(),
      (g) => g.any((i) => i.group.id == tripId && i.expenseCount == 1),
    );
    expect(
      listed.firstWhere((i) => i.group.id == tripId).isFullySettled,
      isFalse,
    );

    // Someone with expenses can't be removed; anyone else can be added.
    await expectLater(
      store.updateGroupParticipants(tripId, remove: {bob.id}),
      throwsA(
        isA<StoreException>().having(
          (e) => e.message,
          'message',
          contains('expense history'),
        ),
      ),
    );
    final dan = await store.createContact('Dan');
    await store.updateGroupParticipants(tripId, add: {dan.id});
    await eventually(
      store.watchInvoice(tripId),
      (s) => s!.participants.length == 3,
    );

    // The overall view sees every visible group's rows.
    final overall = await eventually(
      store.watchOverall(),
      (o) => o.groups.length == 2 && o.payers.length == 1,
    );
    expect(overall.shares, hasLength(2));
    expect({for (final p in overall.participants) p.id}, {
      bob.id,
      cat.id,
      dan.id,
    });

    // The app itself, choosing the Firestore store from the signed-in session.
    await tester.pumpWidget(const ProviderScope(child: ExpenseSplitterApp()));
    await pumpUntil(tester, find.text('3 participants · 1 expense'));
    await tester.tap(find.text('Trip'));
    await pumpUntil(tester, find.text('Cat'));
    expect(find.byType(GroupDashboardScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    // Deleting the expense, then the group, which then reads as gone.
    await store.deleteExpense(tripId, voucher.id);
    await eventually(store.watchInvoice(tripId), (s) => s!.expenses.isEmpty);
    await store.deleteGroup(tripId);
    await eventually(store.watchInvoice(tripId), (s) => s == null);

    // Another user can neither list nor open Alice's group.
    final eve = await signInWithGoogle('eve');
    final eveStore = FirestoreInvoiceStore(uid: eve, isAdmin: false);
    expect(await eveStore.watchGroups().first, isEmpty);
    await eventually(eveStore.watchInvoice(keptId), (s) => s == null);
    await expectLater(
      eveStore.deleteGroup(keptId),
      throwsA(isA<StoreException>()),
    );

    // Signing out while a screen is listening shuts Firestore down under
    // those listeners; it should still land cleanly on the login screen.
    await signInWithGoogle('alice');
    await tester.pumpWidget(const ProviderScope(child: ExpenseSplitterApp()));
    await pumpUntil(tester, find.text('1 participant · 0 expenses'));
    await tester.tap(find.byTooltip('Sign out'));
    await pumpUntil(tester, find.byType(LoginScreen));
    expect(find.text('Kept'), findsNothing);
  });
}
