import 'dart:io';

import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/providers/group_providers.dart';
import 'package:expense_splitter_app/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

Expense _expense(String groupId) => Expense(
  id: 'e1',
  groupId: groupId,
  title: 'Dinner',
  totalAmount: 100,
  splitType: SplitType.equal,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ExpensePayer _payer(String participantId) => ExpensePayer(
  id: 'pay1',
  expenseId: 'e1',
  participantId: participantId,
  paidAmount: 100,
);

ExpenseShare _share(String participantId) => ExpenseShare(
  id: 'sh1',
  expenseId: 'e1',
  participantId: participantId,
  shareAmount: 100,
);

/// Provider-level coverage for the group-membership rules that don't fit
/// naturally as repository tests: creating a group directly with its
/// participant selection, and blocking removal of a participant who still
/// has expense history in that group (as opposed to the global
/// force-delete path, which is covered in participant_repository_test.dart).
void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_group_controller_test');
    await HiveBoxes.initForTest(tempDir.path);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('createGroup saves the group with the selected common participants', () async {
    final p1 = await container
        .read(participantControllerProvider)
        .createParticipant('Alex');
    final p2 = await container
        .read(participantControllerProvider)
        .createParticipant('Sam');

    final group = await container
        .read(groupControllerProvider)
        .createGroup('Trip', participantIds: [p1.id, p2.id]);

    final memberIds = container.read(groupRepositoryProvider).getParticipantIds(group.id);
    expect(memberIds.toSet(), {p1.id, p2.id});
  });

  test('the same participant can be selected into multiple groups', () async {
    final p1 = await container
        .read(participantControllerProvider)
        .createParticipant('Alex');

    final g1 = await container
        .read(groupControllerProvider)
        .createGroup('Trip 1', participantIds: [p1.id]);
    final g2 = await container
        .read(groupControllerProvider)
        .createGroup('Trip 2', participantIds: [p1.id]);

    final groupRepo = container.read(groupRepositoryProvider);
    expect(groupRepo.getParticipantIds(g1.id), [p1.id]);
    expect(groupRepo.getParticipantIds(g2.id), [p1.id]);
  });

  test(
    'updateGroupParticipants throws when removing a participant with expense '
    'history in this group, and leaves membership unchanged',
    () async {
      final p1 = await container
          .read(participantControllerProvider)
          .createParticipant('Alex');
      final p2 = await container
          .read(participantControllerProvider)
          .createParticipant('Sam');
      final group = await container
          .read(groupControllerProvider)
          .createGroup('Trip', participantIds: [p1.id, p2.id]);

      await container.read(expenseRepositoryProvider).save(
        _expense(group.id),
        payers: [_payer(p1.id)],
        shares: [_share(p1.id)],
      );

      await expectLater(
        container
            .read(groupControllerProvider)
            .updateGroupParticipants(group.id, remove: {p1.id}),
        throwsA(isA<GroupParticipantReferencedException>()),
      );

      final memberIds = container
          .read(groupRepositoryProvider)
          .getParticipantIds(group.id);
      expect(memberIds.toSet(), {p1.id, p2.id});
    },
  );

  test('updateGroupParticipants allows removing an unreferenced participant', () async {
    final p1 = await container
        .read(participantControllerProvider)
        .createParticipant('Alex');
    final p2 = await container
        .read(participantControllerProvider)
        .createParticipant('Sam');
    final group = await container
        .read(groupControllerProvider)
        .createGroup('Trip', participantIds: [p1.id, p2.id]);

    await container
        .read(groupControllerProvider)
        .updateGroupParticipants(group.id, remove: {p2.id});

    final memberIds = container
        .read(groupRepositoryProvider)
        .getParticipantIds(group.id);
    expect(memberIds, [p1.id]);
  });
}
