import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/expense_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/participant_repository.dart';

// Local storage only. Screens go through `invoiceStoreProvider` instead, so
// they work the same whichever store is in use.

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
