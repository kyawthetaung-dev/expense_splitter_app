enum SettlementStatus { pending, paid }

/// Persisted audit-trail entity. NOT consumed by the live balance/settlement
/// calculation — `calculateSettlements()` always recomputes from current
/// balances. This entity exists for a future "mark suggested settlement as
/// paid" feature and is out of scope for v1 calculation logic.
class Settlement {
  final String id;
  final String groupId;
  final String fromParticipantId;
  final String toParticipantId;
  final int amount;
  final SettlementStatus status;
  final DateTime createdAt;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  Settlement copyWith({SettlementStatus? status}) {
    return Settlement(
      id: id,
      groupId: groupId,
      fromParticipantId: fromParticipantId,
      toParticipantId: toParticipantId,
      amount: amount,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
