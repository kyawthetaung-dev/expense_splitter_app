import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/group.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/models/split_type.dart';
import 'package:expense_splitter_app/services/balance_calculator.dart';
import 'package:expense_splitter_app/services/expense_share_calculator.dart';
import 'package:expense_splitter_app/services/expense_summary_calculator.dart';
import 'package:expense_splitter_app/services/settlement_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the requirement's worked example: three groups with partially
/// overlapping membership (A/B/C, A/C/D, B/C/D), each fully fronted by one
/// payer. Asserts that the cross-group rollup correctly attributes each
/// expense's share only to the participants actually in that expense —
/// never a naive even split of the grand total across everyone — and that
/// the resulting settlement always balances (sum to pay == sum to receive).
void main() {
  const a = 'a', b = 'b', c = 'c', d = 'd';
  const participants = [
    Participant(id: a, name: 'A'),
    Participant(id: b, name: 'B'),
    Participant(id: c, name: 'C'),
    Participant(id: d, name: 'D'),
  ];

  final groups = [
    Group(id: 'g1', name: 'Group 1', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Group(id: 'g2', name: 'Group 2', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Group(id: 'g3', name: 'Group 3', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
  ];

  final expenses = [
    Expense(id: 'e1', groupId: 'g1', title: 'Group 1 expense', totalAmount: 150000, splitType: SplitType.equal, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Expense(id: 'e2', groupId: 'g2', title: 'Group 2 expense', totalAmount: 210000, splitType: SplitType.equal, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Expense(id: 'e3', groupId: 'g3', title: 'Group 3 expense', totalAmount: 90000, splitType: SplitType.equal, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
  ];

  final payers = const [
    ExpensePayer(id: 'p1', expenseId: 'e1', participantId: a, paidAmount: 150000),
    ExpensePayer(id: 'p2', expenseId: 'e2', participantId: d, paidAmount: 210000),
    ExpensePayer(id: 'p3', expenseId: 'e3', participantId: c, paidAmount: 90000),
  ];

  List<ExpenseShare> sharesFor(String expenseId, int total, List<String> ids) => [
    for (final r in calculateExpenseShares(
      totalAmount: total,
      splitType: SplitType.equal,
      participantIds: ids,
    ))
      ExpenseShare(
        id: '$expenseId-${r.participantId}',
        expenseId: expenseId,
        participantId: r.participantId,
        shareAmount: r.shareAmount,
      ),
  ];

  final shares = [
    ...sharesFor('e1', 150000, [a, b, c]),
    ...sharesFor('e2', 210000, [a, c, d]),
    ...sharesFor('e3', 90000, [b, c, d]),
  ];

  test('cross-group balances attribute shares only to actual participants, not an even split', () {
    final balances = calculatePersonBalances(
      participants: participants,
      allPayers: payers,
      allShares: shares,
    );
    final byId = {for (final bal in balances) bal.participantId: bal};

    // A: 50,000 (g1) + 70,000 (g2) = 120,000 share; paid 150,000.
    expect(byId[a]!.totalShare, 120000);
    expect(byId[a]!.totalPaid, 150000);
    expect(byId[a]!.balance, 30000);

    // B: 50,000 (g1) + 30,000 (g3) = 80,000 share; paid nothing.
    expect(byId[b]!.totalShare, 80000);
    expect(byId[b]!.totalPaid, 0);
    expect(byId[b]!.balance, -80000);

    // C: in all three groups — 50,000 + 70,000 + 30,000 = 150,000 share.
    expect(byId[c]!.totalShare, 150000);
    expect(byId[c]!.totalPaid, 90000);
    expect(byId[c]!.balance, -60000);

    // D: 70,000 (g2) + 30,000 (g3) = 100,000 share; paid 210,000.
    expect(byId[d]!.totalShare, 100000);
    expect(byId[d]!.totalPaid, 210000);
    expect(byId[d]!.balance, 110000);

    // Grand total is 450,000 — an even split across 4 people would be
    // 112,500 each, which matches none of the actual per-participant totals.
    const grandTotal = 150000 + 210000 + 90000;
    const evenSplit = grandTotal / 4;
    for (final bal in balances) {
      expect(bal.totalShare, isNot(evenSplit));
    }
  });

  test('settlement always balances: total to pay equals total to receive', () {
    final balances = calculatePersonBalances(
      participants: participants,
      allPayers: payers,
      allShares: shares,
    );
    final settlements = calculateSettlements(balances: balances);

    final totalSettled = settlements.fold<int>(0, (sum, s) => sum + s.amount);
    final totalToReceive = balances
        .where((b) => b.balance > 0)
        .fold<int>(0, (sum, b) => sum + b.balance);
    final totalToPay = balances
        .where((b) => b.balance < 0)
        .fold<int>(0, (sum, b) => sum + -b.balance);

    expect(totalToReceive, totalToPay);
    expect(totalSettled, totalToReceive);
  });

  test('calculateOverallSummary rolls up group count, grand total, and outstanding', () {
    final balances = calculatePersonBalances(
      participants: participants,
      allPayers: payers,
      allShares: shares,
    );
    final summary = calculateOverallSummary(
      groups: groups,
      allExpenses: expenses,
      balances: balances,
    );

    expect(summary.groupCount, 3);
    expect(summary.totalExpenseAmount, 450000);
    expect(summary.participantCount, 4);
    expect(summary.totalPaid, 450000);
    expect(summary.totalOutstanding, 140000);
    expect(summary.isFullySettled, isFalse);
  });
}
