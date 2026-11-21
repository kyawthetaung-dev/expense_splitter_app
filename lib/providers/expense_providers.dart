import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/store/invoice_store.dart';
import '../models/expense.dart';
import '../models/expense_payer.dart';
import '../models/expense_share.dart';
import '../models/split_type.dart';
import '../services/expense_share_calculator.dart';
import '../services/validators/expense_validators.dart';
import 'store_providers.dart';

const _uuid = Uuid();

/// Identifies one expense. The group is needed to find it, since expenses are
/// loaded a group at a time.
typedef ExpenseKey = ({String groupId, String expenseId});

// Like the group providers, these read synchronously, after `gateOn` has
// waited for the group to load.

final expensesProvider = Provider.autoDispose.family<List<Expense>, String>((
  ref,
  groupId,
) {
  final snapshot = ref.watch(invoiceProvider(groupId)).requireValue;
  return [...?snapshot?.expenses]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final expenseProvider = Provider.autoDispose.family<Expense?, ExpenseKey>((
  ref,
  key,
) {
  final snapshot = ref.watch(invoiceProvider(key.groupId)).requireValue;
  return snapshot?.expenses.firstWhereOrNull((e) => e.id == key.expenseId);
});

final expensePayersProvider = Provider.autoDispose
    .family<List<ExpensePayer>, ExpenseKey>((ref, key) {
      final snapshot = ref.watch(invoiceProvider(key.groupId)).requireValue;
      return [...?snapshot?.payers.where((p) => p.expenseId == key.expenseId)];
    });

final expenseSharesProvider = Provider.autoDispose
    .family<List<ExpenseShare>, ExpenseKey>((ref, key) {
      final snapshot = ref.watch(invoiceProvider(key.groupId)).requireValue;
      return [...?snapshot?.shares.where((s) => s.expenseId == key.expenseId)];
    });

class ExpenseController {
  ExpenseController(this.ref);
  final Ref ref;

  /// Creates a new expense (when [expenseId] is null) or fully replaces an
  /// existing one's payers/shares. The pay/share invariants are checked here
  /// first, so a bad split throws [ArgumentError] before anything is sent.
  ///
  /// [newExpenseId] lets a retried create reuse its id, so it can't be saved
  /// twice; [expectedRevision] is the [Expense.revision] being edited.
  Future<void> saveExpense({
    required String groupId,
    String? expenseId,
    String? newExpenseId,
    int? expectedRevision,
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
    calculateExpenseShares(
      totalAmount: totalAmount,
      splitType: splitType,
      participantIds: participantIds,
      customAmounts: customAmounts,
      percentages: percentages,
    );

    await ref
        .read(invoiceStoreProvider)
        .saveExpense(
          ExpenseInput(
            groupId: groupId,
            expenseId: expenseId ?? newExpenseId ?? _uuid.v4(),
            isNew: expenseId == null,
            expectedRevision: expectedRevision,
            title: title,
            totalAmount: totalAmount,
            splitType: splitType,
            payerAmounts: payerAmounts,
            participantIds: participantIds,
            customAmounts: splitType == SplitType.custom ? customAmounts : null,
            percentages: splitType == SplitType.percentage ? percentages : null,
          ),
        );
  }

  Future<void> deleteExpense(String groupId, String expenseId) =>
      ref.read(invoiceStoreProvider).deleteExpense(groupId, expenseId);

  Future<void> clearAllExpenses(String groupId) =>
      ref.read(invoiceStoreProvider).clearExpenses(groupId);
}

final expenseControllerProvider = Provider((ref) => ExpenseController(ref));
