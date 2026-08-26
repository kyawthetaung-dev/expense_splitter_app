import 'package:uuid/uuid.dart';

import '../../models/group.dart';
import '../../models/group_participant.dart';
import '../hive/hive_boxes.dart';
import 'expense_repository.dart';

const _uuid = Uuid();

class GroupRepository {
  final ExpenseRepository expenseRepository;

  GroupRepository({required this.expenseRepository});

  List<Group> getAll() => HiveBoxes.groupsBox.values.toList();

  Group? getById(String id) => HiveBoxes.groupsBox.get(id);

  Future<void> save(Group group) => HiveBoxes.groupsBox.put(group.id, group);

  List<String> getParticipantIds(String groupId) => HiveBoxes
      .groupParticipantsBox
      .values
      .where((gp) => gp.groupId == groupId)
      .map((gp) => gp.participantId)
      .toList();

  /// `true` if [participantId] has any payer or share row on an expense
  /// belonging to [groupId] — checked before letting them be removed from
  /// the group's membership, so their historical balance data is never
  /// silently orphaned. Checks both payers and shares, since a participant
  /// can pay for an expense without being one of its share-participants.
  bool isParticipantReferencedInGroup(String groupId, String participantId) {
    final hasPayerRow = expenseRepository
        .getPayersByGroup(groupId)
        .any((p) => p.participantId == participantId);
    final hasShareRow = expenseRepository
        .getSharesByGroup(groupId)
        .any((s) => s.participantId == participantId);
    return hasPayerRow || hasShareRow;
  }

  /// Fully replaces [groupId]'s membership with [participantIds] —
  /// existing membership rows for the group are deleted first, mirroring
  /// how [ExpenseRepository] replaces a whole expense's payer/share rows on
  /// every save.
  Future<void> setParticipants(
    String groupId,
    List<String> participantIds,
  ) async {
    final existingIds = HiveBoxes.groupParticipantsBox.values
        .where((gp) => gp.groupId == groupId)
        .map((gp) => gp.id)
        .toList();
    for (final id in existingIds) {
      await HiveBoxes.groupParticipantsBox.delete(id);
    }
    for (final participantId in participantIds) {
      final membership = GroupParticipant(
        id: _uuid.v4(),
        groupId: groupId,
        participantId: participantId,
      );
      await HiveBoxes.groupParticipantsBox.put(membership.id, membership);
    }
  }

  /// Deletes the group and cascades to its expenses (which themselves
  /// cascade to payers/shares), its membership links (NOT the shared
  /// [Participant] records themselves — those may belong to other groups),
  /// and any settlement audit rows.
  Future<void> delete(String groupId) async {
    final expenseIds = HiveBoxes.expensesBox.values
        .where((e) => e.groupId == groupId)
        .map((e) => e.id)
        .toList();
    for (final expenseId in expenseIds) {
      await expenseRepository.delete(expenseId);
    }

    final membershipIds = HiveBoxes.groupParticipantsBox.values
        .where((gp) => gp.groupId == groupId)
        .map((gp) => gp.id)
        .toList();
    for (final id in membershipIds) {
      await HiveBoxes.groupParticipantsBox.delete(id);
    }

    final settlementIds = HiveBoxes.settlementsBox.values
        .where((s) => s.groupId == groupId)
        .map((s) => s.id)
        .toList();
    for (final id in settlementIds) {
      await HiveBoxes.settlementsBox.delete(id);
    }

    await HiveBoxes.groupsBox.delete(groupId);
  }
}
