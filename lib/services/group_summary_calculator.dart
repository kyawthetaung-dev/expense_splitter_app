import '../models/expense.dart';
import '../models/group_summary.dart';
import '../models/participant.dart';
import '../models/person_balance.dart';

/// Rolls up a group's expenses and balances into dashboard-ready totals.
/// Reuses [balances] from [calculatePersonBalances] rather than recomputing.
GroupSummary calculateGroupSummary({
  required List<Expense> expenses,
  required List<Participant> participants,
  required List<PersonBalance> balances,
}) {
  final totalExpenseAmount = expenses.fold<int>(
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

  return GroupSummary(
    expenseCount: expenses.length,
    totalExpenseAmount: totalExpenseAmount,
    participantCount: participants.length,
    totalPaid: totalPaid,
    totalOutstanding: totalOutstanding,
    isFullySettled: isFullySettled,
  );
}
