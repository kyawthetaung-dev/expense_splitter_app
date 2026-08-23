import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_summary.dart';
import '../models/person_balance.dart';
import '../models/settlement_transaction.dart';
import '../services/balance_calculator.dart';
import '../services/group_summary_calculator.dart';
import '../services/settlement_calculator.dart';
import 'group_providers.dart';
import 'repository_providers.dart';

final personBalancesProvider = Provider.family<List<PersonBalance>, String>((
  ref,
  groupId,
) {
  ref.watch(dataRevisionProvider);
  final participants = ref.watch(participantsProvider(groupId));
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final payers = expenseRepo.getPayersByGroup(groupId);
  final shares = expenseRepo.getSharesByGroup(groupId);
  return calculatePersonBalances(
    participants: participants,
    allPayers: payers,
    allShares: shares,
  );
});

final groupSummaryProvider = Provider.family<GroupSummary, String>((
  ref,
  groupId,
) {
  ref.watch(dataRevisionProvider);
  final expenses = ref.watch(expenseRepositoryProvider).getByGroup(groupId);
  final participants = ref.watch(participantsProvider(groupId));
  final balances = ref.watch(personBalancesProvider(groupId));
  return calculateGroupSummary(
    expenses: expenses,
    participants: participants,
    balances: balances,
  );
});

final settlementsProvider = Provider.family<List<SettlementTransaction>, String>((
  ref,
  groupId,
) {
  final balances = ref.watch(personBalancesProvider(groupId));
  return calculateSettlements(balances: balances);
});
