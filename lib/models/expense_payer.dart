class ExpensePayer {
  final String id;
  final String expenseId;
  final String participantId;
  final int paidAmount;

  const ExpensePayer({
    required this.id,
    required this.expenseId,
    required this.participantId,
    required this.paidAmount,
  });
}
