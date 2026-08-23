import '../models/expense_payer.dart';
import '../models/expense_share.dart';
import '../models/participant.dart';
import '../models/person_balance.dart';

/// Computes each group member's total share, total paid, and resulting
/// balance across ALL expenses in the group.
///
/// `totalPaid` and `totalShare` are independent per-participant sums over
/// [allPayers] and [allShares] respectively — never joined per-expense. That
/// independence is what makes "someone paid for an expense they weren't a
/// participant in" (or paid for the group without being a share-participant
/// on anything) work correctly with no special-case code: they simply
/// accumulate `totalPaid` with `totalShare` staying at 0, which correctly
/// nets to a positive "Receive" balance.
List<PersonBalance> calculatePersonBalances({
  required List<Participant> participants,
  required List<ExpensePayer> allPayers,
  required List<ExpenseShare> allShares,
}) {
  final paidByParticipant = <String, int>{};
  for (final payer in allPayers) {
    paidByParticipant.update(
      payer.participantId,
      (v) => v + payer.paidAmount,
      ifAbsent: () => payer.paidAmount,
    );
  }

  final shareByParticipant = <String, int>{};
  for (final share in allShares) {
    shareByParticipant.update(
      share.participantId,
      (v) => v + share.shareAmount,
      ifAbsent: () => share.shareAmount,
    );
  }

  return [
    for (final p in participants)
      _balanceFor(
        p.id,
        shareByParticipant[p.id] ?? 0,
        paidByParticipant[p.id] ?? 0,
      ),
  ];
}

PersonBalance _balanceFor(String participantId, int totalShare, int totalPaid) {
  final balance = totalPaid - totalShare;
  final status = balance > 0
      ? BalanceStatus.receive
      : balance < 0
      ? BalanceStatus.pay
      : BalanceStatus.settled;
  return PersonBalance(
    participantId: participantId,
    totalShare: totalShare,
    totalPaid: totalPaid,
    balance: balance,
    status: status,
  );
}
