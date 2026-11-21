import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/overall_summary.dart';
import '../models/participant.dart';
import '../models/person_balance.dart';
import '../models/settlement_transaction.dart';
import '../services/balance_calculator.dart';
import '../services/expense_summary_calculator.dart';
import '../services/settlement_calculator.dart';
import 'store_providers.dart';

// Read synchronously after `gateOn` has waited for [overallProvider].

/// Everyone who can appear in the overall summary, sorted by name.
final overallParticipantsProvider = Provider.autoDispose<List<Participant>>((
  ref,
) {
  return [...ref.watch(overallProvider).requireValue.participants]
    ..sort((a, b) => a.name.compareTo(b.name));
});

/// Every participant's balance across all visible groups at once. Since
/// participant ids are shared across groups, feeding the unchanged
/// [calculatePersonBalances] every payer/share row is enough: no cross-group
/// aggregation is needed.
final overallPersonBalancesProvider = Provider.autoDispose<List<PersonBalance>>(
  (ref) {
    final overall = ref.watch(overallProvider).requireValue;
    return calculatePersonBalances(
      participants: overall.participants,
      allPayers: overall.payers,
      allShares: overall.shares,
    );
  },
);

final overallSettlementsProvider =
    Provider.autoDispose<List<SettlementTransaction>>((ref) {
      final balances = ref.watch(overallPersonBalancesProvider);
      return calculateSettlements(balances: balances);
    });

final overallSummaryProvider = Provider.autoDispose<OverallSummary>((ref) {
  final overall = ref.watch(overallProvider).requireValue;
  return calculateOverallSummary(
    groups: overall.groups,
    allExpenses: overall.expenses,
    balances: ref.watch(overallPersonBalancesProvider),
  );
});
