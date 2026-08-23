import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/data/repositories/expense_repository.dart';
import 'package:expense_splitter_app/data/repositories/group_repository.dart';
import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/group.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Directory tempDir;
  late GroupRepository groupRepository;
  late ExpenseRepository expenseRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_group_repo_test');
    await HiveBoxes.initForTest(tempDir.path);
    expenseRepository = ExpenseRepository();
    groupRepository = GroupRepository(expenseRepository: expenseRepository);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('save and getById round-trip a group', () async {
    final group = Group(
      id: 'g1',
      name: 'Weekend Trip',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await groupRepository.save(group);

    final loaded = groupRepository.getById('g1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Weekend Trip');
  });

  test('delete cascades to participants, expenses, payers, and shares', () async {
    final group = Group(
      id: 'g1',
      name: 'Trip',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await groupRepository.save(group);
    await HiveBoxes.participantsBox.put(
      'p1',
      const Participant(id: 'p1', groupId: 'g1', name: 'A'),
    );

    final expense = Expense(
      id: 'e1',
      groupId: 'g1',
      title: 'Dinner',
      totalAmount: 100,
      splitType: SplitType.equal,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await expenseRepository.save(
      expense,
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p1', shareAmount: 100),
      ],
    );

    await groupRepository.delete('g1');

    expect(groupRepository.getById('g1'), isNull);
    expect(HiveBoxes.participantsBox.get('p1'), isNull);
    expect(HiveBoxes.expensesBox.get('e1'), isNull);
    expect(HiveBoxes.expensePayersBox.get('pay1'), isNull);
    expect(HiveBoxes.expenseSharesBox.get('sh1'), isNull);
  });

  test('getAll returns only saved groups, unaffected by other groups deletion', () async {
    await groupRepository.save(
      Group(
        id: 'g1',
        name: 'A',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await groupRepository.save(
      Group(
        id: 'g2',
        name: 'B',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    await groupRepository.delete('g1');

    final all = groupRepository.getAll();
    expect(all, hasLength(1));
    expect(all.single.id, 'g2');
  });
}
