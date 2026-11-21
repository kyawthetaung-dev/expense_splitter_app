import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_summary.dart';
import '../models/person_balance.dart';
import '../models/settlement_transaction.dart';
import '../services/balance_calculator.dart';
import '../services/group_summary_calculator.dart';
import '../services/settlement_calculator.dart';
import 'expense_providers.dart';
import 'group_providers.dart';
import 'store_providers.dart';

// Everything here recalculates from the group's latest data whenever any of
// it changes, so editing anything recalculates everything.

final personBalancesProvider = Provider.autoDispose
    .family<List<PersonBalance>, String>((ref, groupId) {
      final snapshot = ref.watch(invoiceProvider(groupId)).requireValue;
      return calculatePersonBalances(
        participants: ref.watch(participantsProvider(groupId)),
        allPayers: snapshot?.payers ?? const [],
        allShares: snapshot?.shares ?? const [],
      );
    });

final groupSummaryProvider = Provider.autoDispose.family<GroupSummary, String>((
  ref,
  groupId,
) {
  return calculateGroupSummary(
    expenses: ref.watch(expensesProvider(groupId)),
    participants: ref.watch(participantsProvider(groupId)),
    balances: ref.watch(personBalancesProvider(groupId)),
  );
});

final settlementsProvider = Provider.autoDispose
    .family<List<SettlementTransaction>, String>((ref, groupId) {
      final balances = ref.watch(personBalancesProvider(groupId));
      return calculateSettlements(balances: balances);
    });
