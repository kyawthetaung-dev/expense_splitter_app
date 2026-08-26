import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/data/repositories/expense_repository.dart';
import 'package:expense_splitter_app/data/repositories/participant_repository.dart';
import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/group_participant.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Directory tempDir;
  late ParticipantRepository repository;
  late ExpenseRepository expenseRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_participant_repo_test');
    await HiveBoxes.initForTest(tempDir.path);
    repository = ParticipantRepository();
    expenseRepository = ExpenseRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('delete removes a participant with no expense history', () async {
    await repository.save(const Participant(id: 'p1', name: 'A'));
    await repository.delete('p1');
    expect(repository.getById('p1'), isNull);
  });

  test('delete throws when the participant has payer/share history', () async {
    await repository.save(const Participant(id: 'p1', name: 'A'));
    await expenseRepository.save(
      Expense(
        id: 'e1',
        groupId: 'g1',
        title: 'Dinner',
        totalAmount: 100,
        splitType: SplitType.equal,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p1', shareAmount: 100),
      ],
    );

    expect(() => repository.delete('p1'), throwsA(isA<ParticipantReferencedException>()));
    expect(repository.getById('p1'), isNotNull);
  });

  test('forceDelete removes the participant and their payer/share rows', () async {
    await repository.save(const Participant(id: 'p1', name: 'A'));
    await expenseRepository.save(
      Expense(
        id: 'e1',
        groupId: 'g1',
        title: 'Dinner',
        totalAmount: 100,
        splitType: SplitType.equal,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      payers: const [
        ExpensePayer(id: 'pay1', expenseId: 'e1', participantId: 'p1', paidAmount: 100),
      ],
      shares: const [
        ExpenseShare(id: 'sh1', expenseId: 'e1', participantId: 'p1', shareAmount: 100),
      ],
    );

    await repository.forceDelete('p1');

    expect(repository.getById('p1'), isNull);
    expect(expenseRepository.getPayers('e1'), isEmpty);
    expect(expenseRepository.getShares('e1'), isEmpty);
  });

  test('duplicate names are allowed — distinguished by id', () async {
    await repository.save(const Participant(id: 'p1', name: 'Alex'));
    await repository.save(const Participant(id: 'p2', name: 'Alex'));

    final all = repository.getAll();
    expect(all, hasLength(2));
    expect(all.map((p) => p.name), everyElement('Alex'));
  });

  test('getByIds returns only the requested participants', () async {
    await repository.save(const Participant(id: 'p1', name: 'A'));
    await repository.save(const Participant(id: 'p2', name: 'B'));
    await repository.save(const Participant(id: 'p3', name: 'C'));

    final result = repository.getByIds(['p1', 'p3']);
    expect(result.map((p) => p.id).toSet(), {'p1', 'p3'});
  });

  test('delete cascades to the participant\'s group membership links', () async {
    await repository.save(const Participant(id: 'p1', name: 'A'));
    await HiveBoxes.groupParticipantsBox.put(
      'gp1',
      const GroupParticipant(id: 'gp1', groupId: 'g1', participantId: 'p1'),
    );
    await HiveBoxes.groupParticipantsBox.put(
      'gp2',
      const GroupParticipant(id: 'gp2', groupId: 'g2', participantId: 'p1'),
    );

    await repository.delete('p1');

    expect(HiveBoxes.groupParticipantsBox.get('gp1'), isNull);
    expect(HiveBoxes.groupParticipantsBox.get('gp2'), isNull);
  });

  test('forceDelete cascades to the participant\'s group membership links', () async {
    await repository.save(const Participant(id: 'p1', name: 'A'));
    await HiveBoxes.groupParticipantsBox.put(
      'gp1',
      const GroupParticipant(id: 'gp1', groupId: 'g1', participantId: 'p1'),
    );

    await repository.forceDelete('p1');

    expect(HiveBoxes.groupParticipantsBox.get('gp1'), isNull);
  });
}
