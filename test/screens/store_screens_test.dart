import 'package:expense_splitter_app/data/store/invoice_store.dart';
import 'package:expense_splitter_app/models/group.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/providers/store_providers.dart';
import 'package:expense_splitter_app/screens/expense_form_screen.dart';
import 'package:expense_splitter_app/screens/group_dashboard_screen.dart';
import 'package:expense_splitter_app/screens/group_list_screen.dart';
import 'package:expense_splitter_app/screens/group_participants_screen.dart';
import 'package:expense_splitter_app/screens/settlements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_invoice_store.dart';

const _alex = Participant(id: 'alex', name: 'Alex');
const _sam = Participant(id: 'sam', name: 'Sam');
const _kim = Participant(id: 'kim', name: 'Kim');
final _group = Group(
  id: 'g1',
  name: 'Trip',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

InvoiceSnapshot _trip({List<Participant> participants = const [_alex]}) =>
    InvoiceSnapshot(
      group: _group,
      participants: participants,
      expenses: const [],
      payers: const [],
      shares: const [],
    );

/// How screens behave when data arrives late, changes underneath them, or a
/// change is refused — none of which happens with local storage, but all of
/// which does with Firestore.
void main() {
  late FakeInvoiceStore store;

  setUp(() => store = FakeInvoiceStore());

  Future<void> pumpApp(WidgetTester tester, Widget home) => tester.pumpWidget(
    ProviderScope(
      overrides: [invoiceStoreProvider.overrideWithValue(store)],
      child: MaterialApp(home: home),
    ),
  );

  /// Lets stream events and route transitions finish. pumpAndSettle can't be
  /// used while a loading spinner is showing, as it never stops animating.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // A screen that leaves by itself does so after a frame.
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Opens [screen] over a home screen, so leaving it can be seen.
  Future<void> open(WidgetTester tester, Widget screen) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => screen),
            ),
            child: const Text('Home'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await settle(tester);
  }

  Finder checkbox(String name) => find.widgetWithText(CheckboxListTile, name);

  testWidgets('a group screen waits for its data instead of leaving', (tester) async {
    await open(tester, const GroupDashboardScreen(groupId: 'g1'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    store.invoice('g1').add(_trip());
    await settle(tester);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);

    // Deleted, or this person was removed from it.
    store.invoice('g1').add(null);
    await settle(tester);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    await open(tester, const SettlementsScreen(groupId: 'g1'));

    store.invoice('g1').addError(Exception('offline'));
    await settle(tester);
    expect(find.text("Couldn't load this"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    store.invoice('g1').add(_trip());
    await settle(tester);
    expect(find.text('All settled'), findsOneWidget);
  });

  group('deleting from the group list', () {
    final item = GroupListItem(
      group: _group,
      participantCount: 1,
      expenseCount: 0,
      isFullySettled: true,
    );

    Future<void> swipeAndConfirm(WidgetTester tester) async {
      await pumpApp(tester, const GroupListScreen());
      store.groups.add([item]);
      await settle(tester);

      await tester.drag(find.text('Trip'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('a refused delete keeps the group and says why', (tester) async {
      store.failure = const StoreException(
        'Only the creator or an admin can do that.',
      );
      await swipeAndConfirm(tester);

      expect(store.changes, ['deleteGroup']);
      expect(find.text('Trip'), findsOneWidget);
      expect(
        find.text('Only the creator or an admin can do that.'),
        findsOneWidget,
      );
    });

    testWidgets('an accepted delete hides it before the list updates', (tester) async {
      await swipeAndConfirm(tester);

      expect(store.changes, ['deleteGroup']);
      expect(find.text('Trip'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('expense form', () {
    setUp(() {
      // Tall enough that the lazy list builds every field.
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1000, 3000);
      view.devicePixelRatio = 1;
      addTearDown(view.reset);
    });

    testWidgets('shows a refused save, and retries under the same id', (tester) async {
      await open(tester, const ExpenseFormScreen(groupId: 'g1'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      store.invoice('g1').add(_trip());
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expense name'),
        'Dinner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Total amount (MMK)'),
        '3000',
      );
      await tester.tap(checkbox('Alex'));
      // Title, total, then Alex's paid amount.
      await tester.enterText(find.byType(TextFormField).last, '3000');

      store.failure = const StoreException(
        "This invoice is completed and can't be changed.",
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
      await settle(tester);
      expect(
        find.text("This invoice is completed and can't be changed."),
        findsOneWidget,
      );

      store.failure = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
      await settle(tester);

      expect(store.savedExpenses, hasLength(2));
      expect(store.savedExpenses.first.expenseId, store.savedExpenses.last.expenseId);
      expect(store.savedExpenses.every((e) => e.isNew), isTrue);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('someone joining while it is open gets fields too', (tester) async {
      await open(tester, const ExpenseFormScreen(groupId: 'g1'));
      store.invoice('g1').add(_trip());
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expense name'),
        'Dinner',
      );

      store.invoice('g1').add(_trip(participants: [_alex, _kim]));
      await settle(tester);

      expect(checkbox('Kim'), findsOneWidget);
      // Title, total, and a paid amount for each person.
      expect(find.byType(TextFormField), findsNWidgets(4));
      // What was already typed is kept.
      expect(find.text('Dinner'), findsOneWidget);
    });
  });

  testWidgets("saving members doesn't undo someone else's change", (tester) async {
    await open(tester, const GroupParticipantsScreen(groupId: 'g1'));
    store.invoice('g1').add(_trip());
    store.contacts.add([_alex, _sam]);
    await settle(tester);

    await tester.tap(checkbox('Sam'));
    await tester.pump();

    // Meanwhile, another member adds Kim, who isn't in this person's list.
    store.invoice('g1').add(_trip(participants: [_alex, _kim]));
    await settle(tester);
    expect(checkbox('Kim'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(checkbox('Kim')).value, isTrue);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(store.membershipChanges.single.add, {'sam'});
    expect(store.membershipChanges.single.remove, isEmpty);
  });
}
