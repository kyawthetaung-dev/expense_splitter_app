import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/group.dart';
import 'package:expense_splitter_app/models/group_participant.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/screens/expense_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// Editing a percentage expense must prefill values that can be saved again:
/// a 3,000 expense split 33.33/33.33/33.34 has shares of 1,000 each, and
/// deriving those back naively gives 33.33 three times, which is rejected.
void main() {
  late Directory tempDir;

  const ids = ['p1', 'p2', 'p3'];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense_form_prefill_test');
    await HiveBoxes.initForTest(tempDir.path);
    // The form loads its group and finds the expense's shares through it.
    final created = DateTime(2026, 1, 1);
    await HiveBoxes.groupsBox.put(
      'g1',
      Group(id: 'g1', name: 'Trip', createdAt: created, updatedAt: created),
    );
    await HiveBoxes.expensesBox.put(
      'e1',
      Expense(
        id: 'e1',
        groupId: 'g1',
        title: 'Hotel',
        totalAmount: 3000,
        splitType: SplitType.percentage,
        createdAt: created,
        updatedAt: created,
      ),
    );
    for (final id in ids) {
      await HiveBoxes.participantsBox.put(id, Participant(id: id, name: id));
      await HiveBoxes.groupParticipantsBox.put(
        'gp-$id',
        GroupParticipant(id: 'gp-$id', groupId: 'g1', participantId: id),
      );
      await HiveBoxes.expenseSharesBox.put(
        's-$id',
        ExpenseShare(
          id: 's-$id',
          expenseId: 'e1',
          participantId: id,
          shareAmount: 1000,
        ),
      );
    }
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Expense expense({Map<String, double>? percentages}) => Expense(
    id: 'e1',
    groupId: 'g1',
    title: 'Hotel',
    totalAmount: 3000,
    splitType: SplitType.percentage,
    percentages: percentages,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpForm(WidgetTester tester, Expense expense) async {
    // Tall enough that the lazy ListView builds the percentage inputs.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ExpenseFormScreen(groupId: 'g1', expense: expense),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('prefills the percentages exactly as they were entered', (tester) async {
    await pumpForm(
      tester,
      expense(percentages: {'p1': 33.33, 'p2': 33.33, 'p3': 33.34}),
    );

    expect(find.text('33.33'), findsNWidgets(2));
    expect(find.text('33.34'), findsOneWidget);
    expect(find.text('Fully allocated'), findsWidgets);
  });

  testWidgets('keeps more than two decimals when that is what was entered', (tester) async {
    await pumpForm(
      tester,
      expense(percentages: {'p1': 33.333, 'p2': 33.333, 'p3': 33.334}),
    );

    expect(find.text('33.333'), findsNWidgets(2));
    expect(find.text('33.334'), findsOneWidget);
  });

  testWidgets('an older expense with no stored percentages still sums to 100', (tester) async {
    await pumpForm(tester, expense());

    expect(find.text('33.34'), findsOneWidget);
    expect(find.text('33.33'), findsNWidgets(2));
  });
}
