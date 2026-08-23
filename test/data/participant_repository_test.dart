import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/data/repositories/expense_repository.dart';
import 'package:expense_splitter_app/data/repositories/participant_repository.dart';
import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
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
    await repository.save(const Participant(id: 'p1', groupId: 'g1', name: 'A'));
    await repository.delete('p1');
    expect(repository.getById('p1'), isNull);
  });

  test('delete throws when the participant has payer/share history', () async {
    await repository.save(const Participant(id: 'p1', groupId: 'g1', name: 'A'));
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
    await repository.save(const Participant(id: 'p1', groupId: 'g1', name: 'A'));
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
    await repository.save(const Participant(id: 'p1', groupId: 'g1', name: 'Alex'));
    await repository.save(const Participant(id: 'p2', groupId: 'g1', name: 'Alex'));

    final all = repository.getByGroup('g1');
    expect(all, hasLength(2));
    expect(all.map((p) => p.name), everyElement('Alex'));
  });
}
