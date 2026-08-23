import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/expense_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/participant_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(),
);

final participantRepositoryProvider = Provider<ParticipantRepository>(
  (ref) => ParticipantRepository(),
);

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    expenseRepository: ref.watch(expenseRepositoryProvider),
  );
});

/// Bumped after every write. Everything derived from the (synchronous)
/// Hive-backed repositories watches this, directly or transitively, so a
/// single write fully recomputes shares/balances/summary/settlements with
/// no stale state anywhere — the "editing anything recalculates
/// everything" requirement, implemented as a dependency graph rather than
/// bespoke invalidation logic per screen.
final dataRevisionProvider = StateProvider<int>((ref) => 0);
