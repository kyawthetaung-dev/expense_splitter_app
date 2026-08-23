class SettlementTransaction {
  final String fromParticipantId;
  final String toParticipantId;
  final int amount;

  const SettlementTransaction({
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.amount,
  });
}
