/// System-wide rollup across every expense group — the same shape as
/// [GroupSummary], just fed system-wide inputs instead of one group's.
class OverallSummary {
  final int groupCount;
  final int totalExpenseAmount;
  final int participantCount;
  final int totalPaid;
  final int totalOutstanding;
  final bool isFullySettled;

  const OverallSummary({
    required this.groupCount,
    required this.totalExpenseAmount,
    required this.participantCount,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.isFullySettled,
  });
}
