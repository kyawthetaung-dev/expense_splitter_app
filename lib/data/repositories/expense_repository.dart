import '../../models/expense.dart';
import '../../models/expense_payer.dart';
import '../../models/expense_share.dart';
import '../hive/hive_boxes.dart';

class ExpenseRepository {
  List<Expense> getByGroup(String groupId) => HiveBoxes.expensesBox.values
      .where((e) => e.groupId == groupId)
      .toList();

  Expense? getById(String id) => HiveBoxes.expensesBox.get(id);

  List<ExpensePayer> getPayers(String expenseId) => HiveBoxes
      .expensePayersBox
      .values
      .where((p) => p.expenseId == expenseId)
      .toList();

  List<ExpenseShare> getShares(String expenseId) => HiveBoxes
      .expenseSharesBox
      .values
      .where((s) => s.expenseId == expenseId)
      .toList();

  List<ExpensePayer> getPayersByGroup(String groupId) {
    final expenseIds = getByGroup(groupId).map((e) => e.id).toSet();
    return HiveBoxes.expensePayersBox.values
        .where((p) => expenseIds.contains(p.expenseId))
        .toList();
  }

  List<ExpenseShare> getSharesByGroup(String groupId) {
    final expenseIds = getByGroup(groupId).map((e) => e.id).toSet();
    return HiveBoxes.expenseSharesBox.values
        .where((s) => expenseIds.contains(s.expenseId))
        .toList();
  }

  /// Saves an expense along with its full set of payer/share rows,
  /// replacing any existing ones for this expense — the caller always
  /// passes the complete recomputed set, so an edit fully replaces rather
  /// than merges.
  Future<void> save(
    Expense expense, {
    required List<ExpensePayer> payers,
    required List<ExpenseShare> shares,
  }) async {
    await _replacePayers(expense.id, payers);
    await _replaceShares(expense.id, shares);
    await HiveBoxes.expensesBox.put(expense.id, expense);
  }

  Future<void> _replacePayers(
    String expenseId,
    List<ExpensePayer> payers,
  ) async {
    final existingIds = HiveBoxes.expensePayersBox.values
        .where((p) => p.expenseId == expenseId)
        .map((p) => p.id)
        .toList();
    for (final id in existingIds) {
      await HiveBoxes.expensePayersBox.delete(id);
    }
    for (final payer in payers) {
      await HiveBoxes.expensePayersBox.put(payer.id, payer);
    }
  }

  Future<void> _replaceShares(
    String expenseId,
    List<ExpenseShare> shares,
  ) async {
    final existingIds = HiveBoxes.expenseSharesBox.values
        .where((s) => s.expenseId == expenseId)
        .map((s) => s.id)
        .toList();
    for (final id in existingIds) {
      await HiveBoxes.expenseSharesBox.delete(id);
    }
    for (final share in shares) {
      await HiveBoxes.expenseSharesBox.put(share.id, share);
    }
  }

  /// Deletes an expense and cascades to its payer/share rows.
  Future<void> delete(String expenseId) async {
    final payerIds = HiveBoxes.expensePayersBox.values
        .where((p) => p.expenseId == expenseId)
        .map((p) => p.id)
        .toList();
    for (final id in payerIds) {
      await HiveBoxes.expensePayersBox.delete(id);
    }
    final shareIds = HiveBoxes.expenseSharesBox.values
        .where((s) => s.expenseId == expenseId)
        .map((s) => s.id)
        .toList();
    for (final id in shareIds) {
      await HiveBoxes.expenseSharesBox.delete(id);
    }
    await HiveBoxes.expensesBox.delete(expenseId);
  }
}
