class ExpenseShare {
  final String id;
  final String expenseId;
  final String participantId;
  final int shareAmount;

  const ExpenseShare({
    required this.id,
    required this.expenseId,
    required this.participantId,
    required this.shareAmount,
  });
}
