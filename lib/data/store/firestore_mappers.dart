import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../models/expense.dart';
import '../../models/expense_payer.dart';
import '../../models/expense_share.dart';
import '../../models/group.dart';
import '../../models/participant.dart';
import '../../models/split_type.dart';
import '../../services/balance_calculator.dart';
import '../../services/expense_share_calculator.dart';
import '../../services/group_summary_calculator.dart';
import 'invoice_store.dart';

/// Converts between Firestore documents (shaped as firestore.rules expects)
/// and the app's models. Kept free of Firebase calls so it can be unit tested.
///
/// An invoice is `invoices/{id}`; its vouchers are `invoices/{id}/vouchers`,
/// each holding its own payers and shares, so the rules can check they add up.

typedef DocData = Map<String, dynamic>;
typedef Doc = (String id, DocData data);

/// The most people one voucher can include: the rules check each amount one
/// by one, and evaluating more would exceed their per-request limit.
const maxPeoplePerVoucher = 20;

/// The most people on one invoice, as the rules allow.
const maxPeoplePerInvoice = 100;

/// Someone in this person's contacts.
class ContactEntry {
  final String id;
  final String name;
  final String? linkedUid;

  const ContactEntry({required this.id, required this.name, this.linkedUid});

  /// How they appear on an invoice: under their account once linked, and
  /// under the contact's own id while a guest.
  String get participantId => linkedUid ?? id;

  Participant toParticipant() => Participant(id: participantId, name: name);
}

DateTime _time(Object? value) => value is Timestamp
    ? value.toDate()
    : DateTime.fromMillisecondsSinceEpoch(0);

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

Map<Object?, Object?> _map(Object? value) =>
    value is Map ? value : const <Object?, Object?>{};

ContactEntry contactFrom(Doc doc) {
  final (id, data) = doc;
  return ContactEntry(
    id: id,
    name: data['name'] as String? ?? '',
    linkedUid: data['linkedUid'] as String?,
  );
}

Group groupFromInvoice(Doc doc) {
  final (id, data) = doc;
  return Group(
    id: id,
    name: data['name'] as String? ?? '',
    createdAt: _time(data['createdAt']),
    updatedAt: _time(data['updatedAt']),
  );
}

List<Participant> participantsFromInvoice(DocData data) => [
  for (final MapEntry(:key, :value) in _map(data['participants']).entries)
    Participant(id: key! as String, name: _map(value)['name'] as String? ?? ''),
];

/// Read from the invoice's stored summary, so listing groups doesn't need
/// every group's expenses.
GroupListItem groupListItemFromInvoice(Doc doc) {
  final summary = _map(doc.$2['summary']);
  return GroupListItem(
    group: groupFromInvoice(doc),
    participantCount: _map(doc.$2['participants']).length,
    expenseCount: _int(summary['voucherCount']),
    isFullySettled: summary['isFullySettled'] as bool? ?? true,
  );
}

List<GroupListItem> groupListFromInvoices(Iterable<Doc> invoices) =>
    [for (final doc in invoices) groupListItemFromInvoice(doc)]
      ..sort((a, b) => b.group.updatedAt.compareTo(a.group.updatedAt));

Expense expenseFromVoucher(String invoiceId, Doc doc) {
  final (id, data) = doc;
  final percentages = data['percentages'] as Map?;
  return Expense(
    id: id,
    groupId: invoiceId,
    title: data['title'] as String? ?? '',
    totalAmount: _int(data['totalAmount']),
    splitType:
        SplitType.values.asNameMap()[data['splitType']] ?? SplitType.equal,
    // Whole numbers come back from Firestore as ints.
    percentages: percentages?.map(
      (id, value) => MapEntry(id as String, (value as num).toDouble()),
    ),
    createdAt: _time(data['createdAt']),
    updatedAt: _time(data['updatedAt']),
    revision: _int(data['revision']),
  );
}

/// A voucher's payers and shares, as the rows the calculators work with.
({List<ExpensePayer> payers, List<ExpenseShare> shares}) rowsFromVoucher(
  Doc doc,
) {
  final (id, data) = doc;
  return (
    payers: [
      for (final MapEntry(:key, :value) in _map(data['payers']).entries)
        ExpensePayer(
          id: '${id}_p_$key',
          expenseId: id,
          participantId: key! as String,
          paidAmount: _int(value),
        ),
    ],
    shares: [
      for (final MapEntry(:key, :value) in _map(data['shares']).entries)
        ExpenseShare(
          id: '${id}_s_$key',
          expenseId: id,
          participantId: key! as String,
          shareAmount: _int(value),
        ),
    ],
  );
}

InvoiceSnapshot invoiceSnapshotFrom({
  required Doc invoice,
  required Iterable<Doc> vouchers,
}) {
  final rows = [for (final doc in vouchers) rowsFromVoucher(doc)];
  return InvoiceSnapshot(
    group: groupFromInvoice(invoice),
    participants: participantsFromInvoice(invoice.$2),
    expenses: [for (final doc in vouchers) expenseFromVoucher(invoice.$1, doc)],
    payers: [for (final r in rows) ...r.payers],
    shares: [for (final r in rows) ...r.shares],
  );
}

/// Each invoice's vouchers arrive on their own listener, so some can still be
/// missing, and an invoice can briefly be gone while its vouchers aren't.
/// Only vouchers of invoices currently visible are counted.
OverallSnapshot overallSnapshotFrom({
  required Iterable<Doc> invoices,
  required Map<String, List<Doc>> vouchersByInvoice,
}) {
  // The same person can be on several invoices; the first name found wins.
  final participants = <String, Participant>{};
  final expenses = <Expense>[];
  final payers = <ExpensePayer>[];
  final shares = <ExpenseShare>[];
  for (final (id, data) in invoices) {
    for (final p in participantsFromInvoice(data)) {
      participants.putIfAbsent(p.id, () => p);
    }
    for (final voucher in vouchersByInvoice[id] ?? const <Doc>[]) {
      expenses.add(expenseFromVoucher(id, voucher));
      final rows = rowsFromVoucher(voucher);
      payers.addAll(rows.payers);
      shares.addAll(rows.shares);
    }
  }
  return OverallSnapshot(
    groups: [for (final doc in invoices) groupFromInvoice(doc)],
    participants: participants.values.toList(),
    expenses: expenses,
    payers: payers,
    shares: shares,
  );
}

/// An invoice's participants, from the people picked out of this person's
/// contacts: linked people under their account, guests under the contact id.
Map<String, Map<String, Object?>> participantsFor(
  Iterable<String> participantIds,
  Map<String, ContactEntry> contactsByParticipantId,
) => {
  for (final id in participantIds)
    id: switch (contactsByParticipantId[id]) {
      null => throw const StoreException(
        "Someone you picked isn't in your participants list any more.",
      ),
      ContactEntry(linkedUid: final String uid, :final name) => {
        'name': name,
        'kind': 'user',
        'uid': uid,
      },
      final contact => {'name': contact.name, 'kind': 'guest', 'uid': null},
    },
};

/// Who can open the invoice: its creator, and everyone on it with an account.
List<String> assignedUidsFor(
  String createdBy,
  Map<Object?, Object?> participants,
) => {
  createdBy,
  for (final person in participants.values)
    if (_map(person)['uid'] case final String uid) uid,
}.toList();

/// The fields stored on a voucher. Shares are worked out here, with the same
/// calculator the app shows them with; the rules then check they add up.
DocData voucherFields(
  ExpenseInput input, {
  required String uid,
  required int revision,
  required Object createdBy,
  required Object createdAt,
  required Object updatedAt,
}) {
  final payers = {
    for (final MapEntry(:key, :value) in input.payerAmounts.entries)
      if (value > 0) key: value,
  };
  if (input.participantIds.length > maxPeoplePerVoucher ||
      payers.length > maxPeoplePerVoucher) {
    throw const StoreException(
      'An expense can include at most $maxPeoplePerVoucher people.',
    );
  }
  final shares = calculateExpenseShares(
    totalAmount: input.totalAmount,
    splitType: input.splitType,
    participantIds: input.participantIds,
    customAmounts: input.customAmounts,
    percentages: input.percentages,
  );
  return {
    'title': input.title.trim(),
    'totalAmount': input.totalAmount,
    'splitType': input.splitType.name,
    'percentages': input.splitType == SplitType.percentage
        ? input.percentages
        : null,
    'payers': payers,
    'shares': {for (final s in shares) s.participantId: s.shareAmount},
    'integrity': 'ok',
    'revision': revision,
    'createdBy': createdBy,
    'updatedBy': uid,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// What the group list shows, stored on the invoice so the list doesn't need
/// every group's vouchers. Recomputed in full on every change.
DocData summaryFor(DocData invoice, Iterable<Doc> vouchers) {
  final snapshot = invoiceSnapshotFrom(invoice: ('', invoice), vouchers: vouchers);
  final summary = calculateGroupSummary(
    expenses: snapshot.expenses,
    participants: snapshot.participants,
    balances: calculatePersonBalances(
      participants: snapshot.participants,
      allPayers: snapshot.payers,
      allShares: snapshot.shares,
    ),
  );
  return {
    'voucherCount': summary.expenseCount,
    'totalAmount': summary.totalExpenseAmount,
    'totalPaid': summary.totalPaid,
    'totalOutstanding': summary.totalOutstanding,
    'isFullySettled': summary.isFullySettled,
  };
}

/// Everyone named on any voucher, to stop removing someone with history.
Set<String> peopleWithHistory(Iterable<Doc> vouchers) => {
  for (final (_, data) in vouchers) ...[
    ..._map(data['payers']).keys.cast<String>(),
    ..._map(data['shares']).keys.cast<String>(),
  ],
};

const _genericFailure = "That didn't work. Please try again.";

/// Turns a Firestore failure into something to show. A refusal by the rules
/// gives no reason, so the message names the usual ones.
StoreException storeErrorFor(String code) {
  return switch (code) {
    'unavailable' || 'deadline-exceeded' => const StoreException(
      "Couldn't reach the server. Check your connection and try again.",
    ),
    'unauthenticated' => const StoreException(
      'Your session has ended. Sign in again.',
    ),
    'permission-denied' => const StoreException(
      "That change isn't allowed. The group may be completed, or you may no "
      'longer be in it.',
    ),
    'not-found' => const StoreException('That no longer exists.'),
    'aborted' => const StoreException(
      'Someone else changed this at the same time. Please try again.',
    ),
    _ => const StoreException(_genericFailure),
  };
}
