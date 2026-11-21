import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../models/expense.dart';
import '../../models/expense_payer.dart';
import '../../models/expense_share.dart';
import '../../models/group.dart';
import '../../models/participant.dart';
import '../../models/person_balance.dart';
import '../../models/split_type.dart';
import '../../services/balance_calculator.dart';
import '../../services/expense_share_calculator.dart';
import '../repositories/expense_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/participant_repository.dart';
import 'invoice_store.dart';

const _uuid = Uuid();

/// Keeps everything on this device. Every stream re-reads after each write
/// made through this store, so one change recalculates everything derived
/// from it.
class HiveInvoiceStore implements InvoiceStore {
  HiveInvoiceStore({
    required this._expenses,
    required this._groups,
    required this._participants,
  });

  final ExpenseRepository _expenses;
  final GroupRepository _groups;
  final ParticipantRepository _participants;
  final _changes = StreamController<void>.broadcast();

  void dispose() => _changes.close();

  /// Emits [read] now and again after every write.
  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;

    void emit() {
      try {
        controller.add(read());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        emit();
        subscription = _changes.stream.listen((_) => emit());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Runs [write], then notifies even if it failed partway: Hive writes
  /// aren't atomic, and the screens should show what actually got saved.
  Future<T> _writing<T>(Future<T> Function() write) async {
    try {
      return await write();
    } finally {
      if (!_changes.isClosed) _changes.add(null);
    }
  }

  InvoiceSnapshot? _snapshot(String groupId) {
    final group = _groups.getById(groupId);
    if (group == null) return null;
    return InvoiceSnapshot(
      group: group,
      participants: _participants.getByIds(_groups.getParticipantIds(groupId)),
      expenses: _expenses.getByGroup(groupId),
      payers: _expenses.getPayersByGroup(groupId),
      shares: _expenses.getSharesByGroup(groupId),
    );
  }

  GroupListItem _listItem(Group group) {
    final snapshot = _snapshot(group.id)!;
    final balances = calculatePersonBalances(
      participants: snapshot.participants,
      allPayers: snapshot.payers,
      allShares: snapshot.shares,
    );
    return GroupListItem(
      group: group,
      participantCount: snapshot.participants.length,
      expenseCount: snapshot.expenses.length,
      isFullySettled: balances.every((b) => b.status == BalanceStatus.settled),
    );
  }

  @override
  Stream<List<GroupListItem>> watchGroups() => _watch(() {
    final groups = _groups.getAll()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [for (final group in groups) _listItem(group)];
  });

  @override
  Stream<InvoiceSnapshot?> watchInvoice(String groupId) =>
      _watch(() => _snapshot(groupId));

  @override
  Stream<List<Participant>> watchContacts() => _watch(_participants.getAll);

  @override
  Stream<OverallSnapshot> watchOverall() => _watch(
    () => OverallSnapshot(
      groups: _groups.getAll(),
      // The whole list rather than group members, so nobody with history
      // can drop out of the totals.
      participants: _participants.getAll(),
      expenses: _expenses.getAll(),
      payers: _expenses.getAllPayers(),
      shares: _expenses.getAllShares(),
    ),
  );

  @override
  Future<Group> createGroup({
    required String groupId,
    required String name,
    required List<String> participantIds,
  }) => _writing(() async {
    final now = DateTime.now();
    final group = Group(
      id: groupId,
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _groups.save(group);
    await _groups.setParticipants(group.id, participantIds);
    return group;
  });

  @override
  Future<void> renameGroup(String groupId, String name) => _writing(() async {
    final group = _groups.getById(groupId);
    if (group == null) throw const StoreException('This group no longer exists.');
    await _groups.save(
      group.copyWith(name: name.trim(), updatedAt: DateTime.now()),
    );
  });

  @override
  Future<void> deleteGroup(String groupId) =>
      _writing(() => _groups.delete(groupId));

  @override
  Future<void> updateGroupParticipants(
    String groupId, {
    Set<String> add = const {},
    Set<String> remove = const {},
  }) async {
    final current = _groups.getParticipantIds(groupId).toSet();
    final participantIds = current.union(add).difference(remove);
    // Checked before anything is written, so a refusal changes nothing.
    for (final participantId in current.intersection(remove)) {
      if (_groups.isParticipantReferencedInGroup(groupId, participantId)) {
        throw GroupParticipantReferencedException(
          'Cannot remove participant $participantId from group $groupId: '
          'they have expense history in this group.',
        );
      }
    }
    return _writing(
      () => _groups.setParticipants(groupId, participantIds.toList()),
    );
  }

  @override
  Future<void> saveExpense(ExpenseInput input) async {
    final shareResults = calculateExpenseShares(
      totalAmount: input.totalAmount,
      splitType: input.splitType,
      participantIds: input.participantIds,
      customAmounts: input.customAmounts,
      percentages: input.percentages,
    );
    final existing = input.isNew ? null : _expenses.getById(input.expenseId);
    final now = DateTime.now();
    final expense = Expense(
      id: input.expenseId,
      groupId: input.groupId,
      title: input.title.trim(),
      totalAmount: input.totalAmount,
      splitType: input.splitType,
      percentages: input.splitType == SplitType.percentage
          ? input.percentages
          : null,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final payers = [
      for (final MapEntry(key: participantId, value: amount)
          in input.payerAmounts.entries)
        ExpensePayer(
          id: _uuid.v4(),
          expenseId: expense.id,
          participantId: participantId,
          paidAmount: amount,
        ),
    ];
    final shares = [
      for (final s in shareResults)
        ExpenseShare(
          id: _uuid.v4(),
          expenseId: expense.id,
          participantId: s.participantId,
          shareAmount: s.shareAmount,
        ),
    ];
    return _writing(
      () => _expenses.save(expense, payers: payers, shares: shares),
    );
  }

  @override
  Future<void> deleteExpense(String groupId, String expenseId) =>
      _writing(() => _expenses.delete(expenseId));

  @override
  Future<void> clearExpenses(String groupId) =>
      _writing(() => _expenses.deleteAllForGroup(groupId));

  @override
  Future<Participant> createContact(String name) => _writing(() async {
    final participant = Participant(id: _uuid.v4(), name: name.trim());
    await _participants.save(participant);
    return participant;
  });

  @override
  Future<void> renameContact(Participant contact, String name) => _writing(
    () => _participants.save(contact.copyWith(name: name.trim())),
  );

  @override
  Future<void> deleteContact(String contactId, {bool force = false}) =>
      _writing(
        () => force
            ? _participants.forceDelete(contactId)
            : _participants.delete(contactId),
      );
}
