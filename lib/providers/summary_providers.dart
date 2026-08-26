import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/overall_summary.dart';
import '../models/person_balance.dart';
import '../models/settlement_transaction.dart';
import '../services/balance_calculator.dart';
import '../services/expense_summary_calculator.dart';
import '../services/settlement_calculator.dart';
import 'repository_providers.dart';

/// Every participant's balance across ALL groups at once. Deliberately uses
/// the full common participant list (not a union of group memberships) so
/// this can never silently drop a participant with payer/share history —
/// see the plan notes on why a membership-union approach would be fragile.
/// Feeding the existing, unmodified [calculatePersonBalances] with
/// system-wide payers/shares is enough: since participant ids are shared
/// across groups, no new cross-group aggregation math is needed.
final overallPersonBalancesProvider = Provider<List<PersonBalance>>((ref) {
  ref.watch(dataRevisionProvider);
  final participants = ref.watch(participantRepositoryProvider).getAll();
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  return calculatePersonBalances(
    participants: participants,
    allPayers: expenseRepo.getAllPayers(),
    allShares: expenseRepo.getAllShares(),
  );
});

final overallSettlementsProvider = Provider<List<SettlementTransaction>>((ref) {
  final balances = ref.watch(overallPersonBalancesProvider);
  return calculateSettlements(balances: balances);
});

final overallSummaryProvider = Provider<OverallSummary>((ref) {
  ref.watch(dataRevisionProvider);
  final groups = ref.watch(groupRepositoryProvider).getAll();
  final allExpenses = ref.watch(expenseRepositoryProvider).getAll();
  final balances = ref.watch(overallPersonBalancesProvider);
  return calculateOverallSummary(
    groups: groups,
    allExpenses: allExpenses,
    balances: balances,
  );
});
