import '../models/expense.dart';
import '../models/group.dart';
import '../models/overall_summary.dart';
import '../models/person_balance.dart';

/// Rolls up every group's expenses and balances into system-wide totals.
/// Mirrors [calculateGroupSummary]'s math exactly, just fed system-wide
/// inputs — [balances] must already be computed across every participant
/// and every payer/share row in the system (not scoped to one group), so
/// this performs no group-by-group aggregation itself: since participant
/// ids are shared across groups, summing balances that already span every
/// group's expenses is the correct cross-group total.
OverallSummary calculateOverallSummary({
  required List<Group> groups,
  required List<Expense> allExpenses,
  required List<PersonBalance> balances,
}) {
  final totalExpenseAmount = allExpenses.fold<int>(
    0,
    (sum, e) => sum + e.totalAmount,
  );
  final totalPaid = balances.fold<int>(0, (sum, b) => sum + b.totalPaid);
  final totalOutstanding = balances
      .where((b) => b.balance < 0)
      .fold<int>(0, (sum, b) => sum + (-b.balance));
  final isFullySettled = balances.every(
    (b) => b.status == BalanceStatus.settled,
  );

  return OverallSummary(
    groupCount: groups.length,
    totalExpenseAmount: totalExpenseAmount,
    participantCount: balances.length,
    totalPaid: totalPaid,
    totalOutstanding: totalOutstanding,
    isFullySettled: isFullySettled,
  );
}
