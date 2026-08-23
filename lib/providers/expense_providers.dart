import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import '../models/expense_payer.dart';
import '../models/expense_share.dart';
import '../models/split_type.dart';
import '../services/expense_share_calculator.dart';
import '../services/validators/expense_validators.dart';
import 'repository_providers.dart';

const _uuid = Uuid();

final expensesProvider = Provider.family<List<Expense>, String>((ref, groupId) {
  ref.watch(dataRevisionProvider);
  final list = ref.watch(expenseRepositoryProvider).getByGroup(groupId);
  return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final expenseProvider = Provider.family<Expense?, String>((ref, expenseId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(expenseRepositoryProvider).getById(expenseId);
});

final expensePayersProvider = Provider.family<List<ExpensePayer>, String>((
  ref,
  expenseId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(expenseRepositoryProvider).getPayers(expenseId);
});

final expenseSharesProvider = Provider.family<List<ExpenseShare>, String>((
  ref,
  expenseId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(expenseRepositoryProvider).getShares(expenseId);
});

class ExpenseController {
  ExpenseController(this.ref);
  final Ref ref;

  /// Creates a new expense (when [expenseId] is null) or fully replaces an
  /// existing one's payers/shares (when editing) — validates the
  /// pay/share invariants, computes shares via the pure calculation
  /// service, then persists everything as one unit.
  Future<void> saveExpense({
    required String groupId,
    String? expenseId,
    required String title,
    required int totalAmount,
    required SplitType splitType,
    required Map<String, int> payerAmounts,
    required List<String> participantIds,
    Map<String, int>? customAmounts,
    Map<String, double>? percentages,
  }) async {
    validateExpenseAmount(totalAmount);
    validatePayersSumToTotal(payerAmounts, totalAmount);

    final shareResults = calculateExpenseShares(
      totalAmount: totalAmount,
      splitType: splitType,
      participantIds: participantIds,
      customAmounts: customAmounts,
      percentages: percentages,
    );

    final repo = ref.read(expenseRepositoryProvider);
    final existing = expenseId != null ? repo.getById(expenseId) : null;
    final now = DateTime.now();
    final id = expenseId ?? _uuid.v4();

    final expense = Expense(
      id: id,
      groupId: groupId,
      title: title.trim(),
      totalAmount: totalAmount,
      splitType: splitType,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final payers = [
      for (final entry in payerAmounts.entries)
        ExpensePayer(
          id: _uuid.v4(),
          expenseId: id,
          participantId: entry.key,
          paidAmount: entry.value,
        ),
    ];
    final shares = [
      for (final s in shareResults)
        ExpenseShare(
          id: _uuid.v4(),
          expenseId: id,
          participantId: s.participantId,
          shareAmount: s.shareAmount,
        ),
    ];

    await repo.save(expense, payers: payers, shares: shares);
    _bump();
  }

  Future<void> deleteExpense(String expenseId) async {
    await ref.read(expenseRepositoryProvider).delete(expenseId);
    _bump();
  }

  void _bump() => ref.read(dataRevisionProvider.notifier).state++;
}

final expenseControllerProvider = Provider((ref) => ExpenseController(ref));
