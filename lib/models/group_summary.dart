class GroupSummary {
  final int expenseCount;
  final int totalExpenseAmount;
  final int participantCount;
  final int totalPaid;
  final int totalOutstanding;
  final bool isFullySettled;

  const GroupSummary({
    required this.expenseCount,
    required this.totalExpenseAmount,
    required this.participantCount,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.isFullySettled,
  });
}
