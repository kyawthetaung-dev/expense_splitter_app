import '../../models/participant.dart';
import '../hive/hive_boxes.dart';

class ParticipantReferencedException implements Exception {
  final String message;
  ParticipantReferencedException(this.message);

  @override
  String toString() => message;
}

class ParticipantRepository {
  List<Participant> getByGroup(String groupId) => HiveBoxes.participantsBox
      .values
      .where((p) => p.groupId == groupId)
      .toList();

  Participant? getById(String id) => HiveBoxes.participantsBox.get(id);

  Future<void> save(Participant participant) =>
      HiveBoxes.participantsBox.put(participant.id, participant);

  bool isReferenced(String participantId) {
    final hasPayerRow = HiveBoxes.expensePayersBox.values.any(
      (p) => p.participantId == participantId,
    );
    final hasShareRow = HiveBoxes.expenseSharesBox.values.any(
      (s) => s.participantId == participantId,
    );
    return hasPayerRow || hasShareRow;
  }

  /// Deletes a participant. Throws [ParticipantReferencedException] if they
  /// have any payer/share history — remove them from those expenses first
  /// (safer than silently mutating historical totals), or call
  /// [forceDelete] for an explicit destructive removal.
  Future<void> delete(String participantId) async {
    if (isReferenced(participantId)) {
      throw ParticipantReferencedException(
        'Cannot delete participant $participantId: referenced by existing '
        'expense payer/share records.',
      );
    }
    await HiveBoxes.participantsBox.delete(participantId);
  }

  /// Deletes a participant along with every payer/share row that
  /// references them, even though this mutates historical expense totals.
  Future<void> forceDelete(String participantId) async {
    final payerIds = HiveBoxes.expensePayersBox.values
        .where((p) => p.participantId == participantId)
        .map((p) => p.id)
        .toList();
    for (final id in payerIds) {
      await HiveBoxes.expensePayersBox.delete(id);
    }
    final shareIds = HiveBoxes.expenseSharesBox.values
        .where((s) => s.participantId == participantId)
        .map((s) => s.id)
        .toList();
    for (final id in shareIds) {
      await HiveBoxes.expenseSharesBox.delete(id);
    }
    await HiveBoxes.participantsBox.delete(participantId);
  }
}
