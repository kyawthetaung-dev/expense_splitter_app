import '../../models/participant.dart';
import '../hive/hive_boxes.dart';

class ParticipantReferencedException implements Exception {
  final String message;
  ParticipantReferencedException(this.message);

  @override
  String toString() => message;
}

/// A common participant list shared across every group — a participant is
/// created once here and reused by reference (via [GroupParticipant] rows)
/// wherever they're a member, never duplicated per group.
class ParticipantRepository {
  List<Participant> getAll() => HiveBoxes.participantsBox.values.toList();

  Participant? getById(String id) => HiveBoxes.participantsBox.get(id);

  List<Participant> getByIds(Iterable<String> ids) {
    final idSet = ids.toSet();
    return HiveBoxes.participantsBox.values
        .where((p) => idSet.contains(p.id))
        .toList();
  }

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
  /// [forceDelete] for an explicit destructive removal. Either way, their
  /// group-membership links are cleaned up so no group is left pointing at
  /// a deleted participant.
  Future<void> delete(String participantId) async {
    if (isReferenced(participantId)) {
      throw ParticipantReferencedException(
        'Cannot delete participant $participantId: referenced by existing '
        'expense payer/share records.',
      );
    }
    await _deleteMemberships(participantId);
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
    await _deleteMemberships(participantId);
    await HiveBoxes.participantsBox.delete(participantId);
  }

  Future<void> _deleteMemberships(String participantId) async {
    final membershipIds = HiveBoxes.groupParticipantsBox.values
        .where((gp) => gp.participantId == participantId)
        .map((gp) => gp.id)
        .toList();
    for (final id in membershipIds) {
      await HiveBoxes.groupParticipantsBox.delete(id);
    }
  }
}
