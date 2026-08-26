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
import 'package:expense_splitter_app/data/repositories/participant_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Directory tempDir;
  late GroupRepository groupRepository;
  late ExpenseRepository expenseRepository;
  late ParticipantRepository participantRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_group_repo_test');
    await HiveBoxes.initForTest(tempDir.path);
    expenseRepository = ExpenseRepository();
    groupRepository = GroupRepository(expenseRepository: expenseRepository);
    participantRepository = ParticipantRepository();
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

  test(
    'delete cascades to expenses/payers/shares/membership, but the shared '
    'participant itself survives (it may belong to other groups)',
    () async {
      final group = Group(
        id: 'g1',
        name: 'Trip',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await groupRepository.save(group);
      await participantRepository.save(const Participant(id: 'p1', name: 'A'));
      await groupRepository.setParticipants('g1', ['p1']);

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
      expect(participantRepository.getById('p1'), isNotNull);
      expect(groupRepository.getParticipantIds('g1'), isEmpty);
      expect(HiveBoxes.expensesBox.get('e1'), isNull);
      expect(HiveBoxes.expensePayersBox.get('pay1'), isNull);
      expect(HiveBoxes.expenseSharesBox.get('sh1'), isNull);
    },
  );

  test('a participant shared across two groups keeps its membership in the other group', () async {
    await groupRepository.save(
      Group(id: 'g1', name: 'A', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    );
    await groupRepository.save(
      Group(id: 'g2', name: 'B', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    );
    await participantRepository.save(const Participant(id: 'p1', name: 'A'));
    await groupRepository.setParticipants('g1', ['p1']);
    await groupRepository.setParticipants('g2', ['p1']);

    await groupRepository.delete('g1');

    expect(groupRepository.getParticipantIds('g1'), isEmpty);
    expect(groupRepository.getParticipantIds('g2'), ['p1']);
  });

  test('setParticipants fully replaces a group\'s membership', () async {
    await groupRepository.save(
      Group(id: 'g1', name: 'A', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    );
    await groupRepository.setParticipants('g1', ['p1', 'p2']);
    expect(groupRepository.getParticipantIds('g1').toSet(), {'p1', 'p2'});

    await groupRepository.setParticipants('g1', ['p2', 'p3']);
    expect(groupRepository.getParticipantIds('g1').toSet(), {'p2', 'p3'});
  });

  test('isParticipantReferencedInGroup is true for a payer with no share row', () async {
    await groupRepository.save(
      Group(id: 'g1', name: 'A', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    );
    await groupRepository.setParticipants('g1', ['p1', 'p2']);
    await expenseRepository.save(
      Expense(
        id: 'e1',
        groupId: 'g1',
        title: 'Pool',
        totalAmount: 100,
        splitType: SplitType.equal,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p2', shareAmount: 100),
      ],
    );

    expect(groupRepository.isParticipantReferencedInGroup('g1', 'p1'), isTrue);
    expect(groupRepository.isParticipantReferencedInGroup('g1', 'p2'), isTrue);
    expect(groupRepository.isParticipantReferencedInGroup('g1', 'p3'), isFalse);
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
