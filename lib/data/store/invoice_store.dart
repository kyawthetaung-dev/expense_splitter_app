import '../../models/expense.dart';
import '../../models/expense_payer.dart';
import '../../models/expense_share.dart';
import '../../models/group.dart';
import '../../models/participant.dart';
import '../../models/split_type.dart';

/// Where the app's groups and expenses live: on this device, or in Firestore
/// once data is moved there. Screens only see this, so both behave the same.
///
/// Naming trap: a [Group] is a Firestore invoice and an [Expense] is a
/// voucher, while the Firestore `expenses` collection holds payer and share
/// rows.
abstract class InvoiceStore {
  /// Every group this person can see, most recently changed first.
  Stream<List<GroupListItem>> watchGroups();

  /// One group with all its expenses; null once it's deleted or out of reach.
  Stream<InvoiceSnapshot?> watchInvoice(String groupId);

  /// The person's own list of people, to pick group members from.
  Stream<List<Participant>> watchContacts();

  /// Everything this person can see, for the cross-group summary.
  Stream<OverallSnapshot> watchOverall();

  /// [groupId] is chosen by the caller, so retrying after a lost response
  /// doesn't create a second group.
  Future<Group> createGroup({
    required String groupId,
    required String name,
    required List<String> participantIds,
  });

  Future<void> renameGroup(String groupId, String name);

  Future<void> deleteGroup(String groupId);

  /// Changes are sent as additions and removals rather than a full list, so
  /// someone else's change made meanwhile isn't undone. Throws
  /// [GroupParticipantReferencedException] or [StoreException] if someone
  /// being removed still has expenses in the group.
  Future<void> updateGroupParticipants(
    String groupId, {
    Set<String> add = const {},
    Set<String> remove = const {},
  });

  /// Shares are worked out from [input] by whichever side stores them, with
  /// the same calculator.
  Future<void> saveExpense(ExpenseInput input);

  Future<void> deleteExpense(String groupId, String expenseId);

  Future<void> clearExpenses(String groupId);

  Future<Participant> createContact(String name);

  Future<void> renameContact(Participant contact, String name);

  /// On this device, throws `ParticipantReferencedException` unless [force]
  /// when they have expense history. In Firestore it only removes the entry
  /// from this person's list, as each group keeps its own copy of members.
  Future<void> deleteContact(String contactId, {bool force = false});
}

/// What the group list shows for one group, without loading its expenses.
class GroupListItem {
  final Group group;
  final int participantCount;
  final int expenseCount;
  final bool isFullySettled;

  const GroupListItem({
    required this.group,
    required this.participantCount,
    required this.expenseCount,
    required this.isFullySettled,
  });
}

/// One group and everything in it.
class InvoiceSnapshot {
  final Group group;
  final List<Participant> participants;
  final List<Expense> expenses;
  final List<ExpensePayer> payers;
  final List<ExpenseShare> shares;

  const InvoiceSnapshot({
    required this.group,
    required this.participants,
    required this.expenses,
    required this.payers,
    required this.shares,
  });
}

/// Everything visible to this person, across all groups.
class OverallSnapshot {
  final List<Group> groups;

  /// Everyone who can appear in a balance, for names and balance rows.
  final List<Participant> participants;
  final List<Expense> expenses;
  final List<ExpensePayer> payers;
  final List<ExpenseShare> shares;

  const OverallSnapshot({
    required this.groups,
    required this.participants,
    required this.expenses,
    required this.payers,
    required this.shares,
  });
}

/// An expense as entered, before shares are worked out.
class ExpenseInput {
  final String groupId;
  final String expenseId;

  /// Chosen by the caller even when new, so a retried create is a no-op.
  final bool isNew;

  /// The [Expense.revision] being edited, so someone else's change in the
  /// meantime is refused instead of silently overwritten.
  final int? expectedRevision;
  final String title;
  final int totalAmount;
  final SplitType splitType;
  final Map<String, int> payerAmounts;
  final List<String> participantIds;
  final Map<String, int>? customAmounts;
  final Map<String, double>? percentages;

  const ExpenseInput({
    required this.groupId,
    required this.expenseId,
    required this.isNew,
    this.expectedRevision,
    required this.title,
    required this.totalAmount,
    required this.splitType,
    required this.payerAmounts,
    required this.participantIds,
    this.customAmounts,
    this.percentages,
  });
}

/// A change that was refused or couldn't be made, with a [message] that's
/// safe to show as-is.
class StoreException implements Exception {
  final String message;
  const StoreException(this.message);

  @override
  String toString() => message;
}

class GroupParticipantReferencedException implements Exception {
  final String message;
  GroupParticipantReferencedException(this.message);

  @override
  String toString() => message;
}
