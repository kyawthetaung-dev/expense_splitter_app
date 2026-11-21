import 'dart:async';

import 'package:expense_splitter_app/data/store/invoice_store.dart';
import 'package:expense_splitter_app/models/group.dart';
import 'package:expense_splitter_app/models/participant.dart';

/// A store whose data a test pushes in by hand, to see how screens behave
/// while loading, after a change elsewhere, or when a change is refused.
class FakeInvoiceStore implements InvoiceStore {
  final groups = StreamController<List<GroupListItem>>.broadcast();
  final contacts = StreamController<List<Participant>>.broadcast();
  final overall = StreamController<OverallSnapshot>.broadcast();
  final _invoices = <String, StreamController<InvoiceSnapshot?>>{};

  StreamController<InvoiceSnapshot?> invoice(String groupId) =>
      _invoices.putIfAbsent(groupId, StreamController.broadcast);

  /// When set, every change throws this.
  Object? failure;

  final changes = <String>[];
  final savedExpenses = <ExpenseInput>[];
  final createdGroupIds = <String>[];
  final membershipChanges = <({Set<String> add, Set<String> remove})>[];

  Future<void> _change(String name) async {
    changes.add(name);
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Stream<List<GroupListItem>> watchGroups() => groups.stream;

  @override
  Stream<InvoiceSnapshot?> watchInvoice(String groupId) =>
      invoice(groupId).stream;

  @override
  Stream<List<Participant>> watchContacts() => contacts.stream;

  @override
  Stream<OverallSnapshot> watchOverall() => overall.stream;

  @override
  Future<Group> createGroup({
    required String groupId,
    required String name,
    required List<String> participantIds,
  }) async {
    createdGroupIds.add(groupId);
    await _change('createGroup');
    return Group(
      id: groupId,
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<void> renameGroup(String groupId, String name) =>
      _change('renameGroup');

  @override
  Future<void> deleteGroup(String groupId) => _change('deleteGroup');

  @override
  Future<void> updateGroupParticipants(
    String groupId, {
    Set<String> add = const {},
    Set<String> remove = const {},
  }) {
    membershipChanges.add((add: add, remove: remove));
    return _change('updateGroupParticipants');
  }

  @override
  Future<void> saveExpense(ExpenseInput input) {
    savedExpenses.add(input);
    return _change('saveExpense');
  }

  @override
  Future<void> deleteExpense(String groupId, String expenseId) =>
      _change('deleteExpense');

  @override
  Future<void> clearExpenses(String groupId) => _change('clearExpenses');

  @override
  Future<Participant> createContact(String name) async {
    await _change('createContact');
    return Participant(id: 'new-$name', name: name);
  }

  @override
  Future<void> renameContact(Participant contact, String name) =>
      _change('renameContact');

  @override
  Future<void> deleteContact(String contactId, {bool force = false}) =>
      _change('deleteContact');
}
