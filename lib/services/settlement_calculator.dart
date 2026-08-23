import '../models/person_balance.dart';
import '../models/settlement_transaction.dart';

/// Computes a minimal-ish set of settlement transactions that resolve all
/// non-zero balances, using the standard greedy "largest debtor pays
/// largest creditor" debt-simplification heuristic. Bounded at
/// `debtors + creditors - 1` transactions. True minimum-transaction-count
/// settlement is NP-hard in general; this greedy approach is the accepted
/// standard (used by Splitwise-style apps) and is what the spec's worked
/// example matches exactly.
///
/// If `sum(debts) != sum(credits)` (a data-inconsistency case — e.g. an
/// expense's payers didn't sum to its total), one bucket empties before the
/// other and the loop stops cleanly rather than crashing.
List<SettlementTransaction> calculateSettlements({
  required List<PersonBalance> balances,
}) {
  final debtors =
      balances
          .where((b) => b.balance < 0)
          .map((b) => _Entry(b.participantId, -b.balance))
          .toList()
        ..sort(_byAmountDescThenIdAsc);
  final creditors =
      balances
          .where((b) => b.balance > 0)
          .map((b) => _Entry(b.participantId, b.balance))
          .toList()
        ..sort(_byAmountDescThenIdAsc);

  final transactions = <SettlementTransaction>[];
  var i = 0;
  var j = 0;
  while (i < debtors.length && j < creditors.length) {
    final debtor = debtors[i];
    final creditor = creditors[j];
    final amount = debtor.amount < creditor.amount
        ? debtor.amount
        : creditor.amount;

    transactions.add(
      SettlementTransaction(
        fromParticipantId: debtor.participantId,
        toParticipantId: creditor.participantId,
        amount: amount,
      ),
    );

    debtors[i] = _Entry(debtor.participantId, debtor.amount - amount);
    creditors[j] = _Entry(creditor.participantId, creditor.amount - amount);
    if (debtors[i].amount == 0) i++;
    if (creditors[j].amount == 0) j++;
  }

  return transactions;
}

int _byAmountDescThenIdAsc(_Entry a, _Entry b) {
  final cmp = b.amount.compareTo(a.amount);
  return cmp != 0 ? cmp : a.participantId.compareTo(b.participantId);
}

class _Entry {
  final String participantId;
  final int amount;
  const _Entry(this.participantId, this.amount);
}
