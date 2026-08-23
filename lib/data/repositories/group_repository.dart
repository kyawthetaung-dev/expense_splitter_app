import '../../models/group.dart';
import '../hive/hive_boxes.dart';
import 'expense_repository.dart';

class GroupRepository {
  final ExpenseRepository expenseRepository;

  GroupRepository({required this.expenseRepository});

  List<Group> getAll() => HiveBoxes.groupsBox.values.toList();

  Group? getById(String id) => HiveBoxes.groupsBox.get(id);

  Future<void> save(Group group) => HiveBoxes.groupsBox.put(group.id, group);

  /// Deletes the group and cascades to its expenses (which themselves
  /// cascade to payers/shares), participants, and any settlement audit
  /// rows.
  Future<void> delete(String groupId) async {
    final expenseIds = HiveBoxes.expensesBox.values
        .where((e) => e.groupId == groupId)
        .map((e) => e.id)
        .toList();
    for (final expenseId in expenseIds) {
      await expenseRepository.delete(expenseId);
    }

    final participantIds = HiveBoxes.participantsBox.values
        .where((p) => p.groupId == groupId)
        .map((p) => p.id)
        .toList();
    for (final participantId in participantIds) {
      await HiveBoxes.participantsBox.delete(participantId);
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
