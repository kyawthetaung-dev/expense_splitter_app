import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/data/repositories/expense_repository.dart';
import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Directory tempDir;
  late ExpenseRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_expense_repo_test');
    await HiveBoxes.initForTest(tempDir.path);
    repository = ExpenseRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Expense buildExpense(String id, {int totalAmount = 100}) => Expense(
    id: id,
    groupId: 'g1',
    title: 'Dinner',
    totalAmount: totalAmount,
    splitType: SplitType.equal,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('save persists payers and shares alongside the expense', () async {
    await repository.save(
      buildExpense('e1'),
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p1', shareAmount: 50),
        ExpenseShare(id: 'sh2', expenseId: 'e1', participantId: 'p2', shareAmount: 50),
      ],
    );

    expect(repository.getPayers('e1'), hasLength(1));
    expect(repository.getShares('e1'), hasLength(2));
  });

  test('re-saving an expense replaces its payers/shares rather than appending', () async {
    await repository.save(
      buildExpense('e1'),
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p1', shareAmount: 100),
      ],
    );

    // Edit: now split three ways with new share/payer rows.
    await repository.save(
      buildExpense('e1'),
      payers: const [
        ExpensePayer(id: 'pay2', expenseId: 'e1', participantId: 'p2', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh2', expenseId: 'e1', participantId: 'p1', shareAmount: 34),
        ExpenseShare(id: 'sh3', expenseId: 'e1', participantId: 'p2', shareAmount: 33),
        ExpenseShare(id: 'sh4', expenseId: 'e1', participantId: 'p3', shareAmount: 33),
      ],
    );

    expect(repository.getPayers('e1'), hasLength(1));
    expect(repository.getPayers('e1').single.id, 'pay2');
    expect(repository.getShares('e1'), hasLength(3));
  });

  test('delete cascades to payers and shares', () async {
    await repository.save(
      buildExpense('e1'),
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p1', shareAmount: 100),
      ],
    );

    await repository.delete('e1');

    expect(repository.getById('e1'), isNull);
    expect(repository.getPayers('e1'), isEmpty);
    expect(repository.getShares('e1'), isEmpty);
  });

  test('getByGroup / getPayersByGroup / getSharesByGroup scope to the given group', () async {
    await repository.save(
      buildExpense('e1'),
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p1', shareAmount: 100),
      ],
    );

    final otherGroupExpense = Expense(
      id: 'e2',
      groupId: 'g2',
      title: 'Other group expense',
      totalAmount: 50,
      splitType: SplitType.equal,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await repository.save(
      otherGroupExpense,
      payers: const [
        ExpensePayer(id: 'pay2', expenseId: 'e2', participantId: 'p9', paidAmount: 50),
      ],
      shares: const [
        ExpenseShare(id: 'sh2', expenseId: 'e2', participantId: 'p9', shareAmount: 50),
      ],
    );

    expect(repository.getByGroup('g1'), hasLength(1));
    expect(repository.getPayersByGroup('g1'), hasLength(1));
    expect(repository.getSharesByGroup('g1'), hasLength(1));
    expect(repository.getPayersByGroup('g1').single.id, 'pay1');
  });
}
