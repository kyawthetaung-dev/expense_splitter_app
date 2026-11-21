import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/group.dart';
import '../../models/participant.dart';
import 'combine_latest.dart';
import 'firestore_mappers.dart';
import 'invoice_store.dart';

const _uuid = Uuid();

/// Firestore deletes are counted against a 500-write limit per transaction.
const _maxWritesPerTransaction = 450;

/// Reads and writes Firestore directly. The project is on the free Spark plan,
/// with no Cloud Functions, so firestore.rules is the server-side check.
///
/// Every change runs as a transaction, so it fails promptly when offline
/// rather than waiting to sync, and conflicting edits are caught. Some rules
/// can't be expressed in firestore.rules (no one with expense history may be
/// removed from a group), so they're checked here, from fresh reads.
class FirestoreInvoiceStore implements InvoiceStore {
  FirestoreInvoiceStore({
    required this.uid,
    required this.isAdmin,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;

  /// Admins see every invoice. Everyone else has to ask only for invoices
  /// they're assigned to: the rules refuse any query that might return more.
  final bool isAdmin;
  final FirebaseFirestore _db;

  CollectionReference<DocData> get _invoices => _db.collection('invoices');

  DocumentReference<DocData> _invoice(String id) => _invoices.doc(id);

  CollectionReference<DocData> _vouchers(String invoiceId) =>
      _invoice(invoiceId).collection('vouchers');

  CollectionReference<DocData> get _contactsRef =>
      _db.collection('users').doc(uid).collection('contacts');

  Query<DocData> get _visibleInvoices =>
      isAdmin ? _invoices : _invoices.where('assignedUids', arrayContains: uid);

  static List<Doc> _docs(QuerySnapshot<DocData> snapshot) => [
    for (final doc in snapshot.docs) (doc.id, doc.data()),
  ];

  static bool _isDenied(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';

  @override
  Stream<List<GroupListItem>> watchGroups() => _visibleInvoices
      .snapshots()
      .map((snapshot) => groupListFromInvoices(_docs(snapshot)));

  @override
  Stream<InvoiceSnapshot?> watchInvoice(String groupId) {
    return combineLatest2(
      _invoice(groupId).snapshots(),
      _vouchers(groupId).snapshots(),
      (invoice, vouchers) {
        final data = invoice.data();
        if (data == null) return null;
        return invoiceSnapshotFrom(
          invoice: (invoice.id, data),
          vouchers: _docs(vouchers),
        );
      },
    ).transform(
      // Being removed from an invoice, or it being deleted, takes away read
      // access: either way it's gone for this person.
      StreamTransformer.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (_isDenied(error)) {
            sink.add(null);
          } else {
            sink.addError(error, stackTrace);
          }
        },
      ),
    );
  }

  @override
  Stream<List<Participant>> watchContacts() => _contactsRef.snapshots().map(
    (snapshot) => [
      for (final doc in _docs(snapshot)) contactFrom(doc).toParticipant(),
    ],
  );

  /// Each visible invoice's vouchers are listened to separately, as the rules
  /// authorize vouchers through their own invoice. Invoices that appear or
  /// disappear start or stop their listener.
  @override
  Stream<OverallSnapshot> watchOverall() {
    late final StreamController<OverallSnapshot> controller;
    StreamSubscription<QuerySnapshot<DocData>>? invoicesSubscription;
    final voucherSubscriptions =
        <String, StreamSubscription<QuerySnapshot<DocData>>>{};
    final vouchersByInvoice = <String, List<Doc>>{};
    var invoices = <Doc>[];

    void emit() {
      // Wait for every invoice's first answer, so totals never come out short.
      if (invoices.any((doc) => !vouchersByInvoice.containsKey(doc.$1))) return;
      controller.add(
        overallSnapshotFrom(
          invoices: invoices,
          vouchersByInvoice: vouchersByInvoice,
        ),
      );
    }

    void onInvoices(QuerySnapshot<DocData> snapshot) {
      invoices = _docs(snapshot);
      final ids = {for (final (id, _) in invoices) id};
      for (final id in voucherSubscriptions.keys.toList()) {
        if (!ids.contains(id)) {
          voucherSubscriptions.remove(id)!.cancel();
          vouchersByInvoice.remove(id);
        }
      }
      for (final id in ids) {
        voucherSubscriptions[id] ??= _vouchers(id).snapshots().listen(
          (vouchers) {
            vouchersByInvoice[id] = _docs(vouchers);
            emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!_isDenied(error)) {
              controller.addError(error, stackTrace);
              return;
            }
            // Removed from this invoice; its listener above will drop it.
            vouchersByInvoice[id] = const [];
            emit();
          },
        );
      }
      emit();
    }

    controller = StreamController<OverallSnapshot>(
      onListen: () {
        invoicesSubscription = _visibleInvoices.snapshots().listen(
          onInvoices,
          onError: controller.addError,
        );
      },
      onCancel: () => Future.wait([
        ?invoicesSubscription?.cancel(),
        for (final subscription in voucherSubscriptions.values)
          subscription.cancel(),
      ]),
    );
    return controller.stream;
  }

  /// Runs [body] as a transaction, turning Firestore failures into messages
  /// that can be shown. A [StoreException] thrown by [body] passes through.
  Future<T> _run<T>(Future<T> Function(Transaction tx) body) async {
    try {
      return await _db.runTransaction(
        body,
        timeout: const Duration(seconds: 20),
      );
    } on StoreException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('Firestore change failed: ${e.code}');
      throw storeErrorFor(e.code);
    }
  }

  /// Read fresh rather than from a listener, which might not be running.
  Future<List<Doc>> _read(Query<DocData> query) async {
    try {
      return _docs(await query.get());
    } on FirebaseException catch (e) {
      debugPrint('Reading failed: ${e.code}');
      throw storeErrorFor(e.code);
    }
  }

  Future<Map<String, ContactEntry>> _contactsByParticipantId() async => {
    for (final doc in await _read(_contactsRef))
      contactFrom(doc).participantId: contactFrom(doc),
  };

  /// Loads an invoice inside [tx], refusing if it's gone.
  Future<DocData> _invoiceIn(Transaction tx, String groupId) async {
    final snapshot = await tx.get(_invoice(groupId));
    final data = snapshot.data();
    if (data == null) throw const StoreException('This group no longer exists.');
    return data;
  }

  @override
  Future<Group> createGroup({
    required String groupId,
    required String name,
    required List<String> participantIds,
  }) async {
    final participants = participantsFor(
      participantIds,
      await _contactsByParticipantId(),
    );
    if (participants.length > maxPeoplePerInvoice) {
      throw const StoreException(
        'A group can have at most $maxPeoplePerInvoice people.',
      );
    }
    await _run((tx) async {
      final existing = await tx.get(_invoice(groupId));
      // A retry after a lost response finds its own group already made.
      if (existing.exists) {
        if (existing.data()?['createdBy'] == uid) return;
        throw const StoreException('That group already exists.');
      }
      tx.set(_invoice(groupId), {
        'name': name.trim(),
        'status': 'open',
        'assignedUids': assignedUidsFor(uid, participants),
        'participants': participants,
        'createdBy': uid,
        'summary': summaryFor({'participants': participants}, const []),
        'completedBy': null,
        'completedAt': null,
        'settlements': const <Object?>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    final now = DateTime.now();
    return Group(id: groupId, name: name.trim(), createdAt: now, updatedAt: now);
  }

  @override
  Future<void> renameGroup(String groupId, String name) => _run((tx) async {
    await _invoiceIn(tx, groupId);
    tx.update(_invoice(groupId), {
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> deleteGroup(String groupId) async {
    final vouchers = await _read(_vouchers(groupId));
    // Very large groups are emptied in several steps first; the group itself
    // goes last, so it never disappears with vouchers left behind.
    var remaining = vouchers;
    while (remaining.length > _maxWritesPerTransaction) {
      final batch = remaining.take(_maxWritesPerTransaction).toList();
      await _run((tx) async {
        for (final (id, _) in batch) {
          tx.delete(_vouchers(groupId).doc(id));
        }
      });
      remaining = remaining.skip(_maxWritesPerTransaction).toList();
    }
    await _run((tx) async {
      final data = await _invoiceIn(tx, groupId);
      if (!isAdmin && data['createdBy'] != uid) {
        throw const StoreException(
          'Only the person who created this group, or an admin, can delete it.',
        );
      }
      for (final (id, _) in remaining) {
        tx.delete(_vouchers(groupId).doc(id));
      }
      tx.delete(_invoice(groupId));
    });
  }

  @override
  Future<void> updateGroupParticipants(
    String groupId, {
    Set<String> add = const {},
    Set<String> remove = const {},
  }) async {
    if (add.isEmpty && remove.isEmpty) return;
    final additions = add.isEmpty
        ? const <String, Map<String, Object?>>{}
        : participantsFor(add, await _contactsByParticipantId());
    final vouchers = await _read(_vouchers(groupId));
    final withHistory = peopleWithHistory(vouchers);

    await _run((tx) async {
      final data = await _invoiceIn(tx, groupId);
      final createdBy = data['createdBy'] as String;
      final participants = {
        for (final MapEntry(:key, :value)
            in (data['participants'] as Map).entries)
          key as String: value,
      };
      final isManager = isAdmin || createdBy == uid;

      for (final id in remove) {
        final person = participants[id] as Map?;
        if (person == null) continue;
        if (!isManager && id != uid) {
          throw const StoreException(
            'Only the person who created this group, or an admin, can remove '
            'others.',
          );
        }
        if (person['uid'] == createdBy) {
          throw const StoreException(
            "The person who created this group can't be removed.",
          );
        }
        if (withHistory.contains(id)) {
          throw StoreException(
            '${person['name']} has expense history in this group. Remove them '
            'from those expenses first.',
          );
        }
        participants.remove(id);
      }
      for (final MapEntry(:key, :value) in additions.entries) {
        participants.putIfAbsent(key, () => value);
      }
      if (participants.length > maxPeoplePerInvoice) {
        throw const StoreException(
          'A group can have at most $maxPeoplePerInvoice people.',
        );
      }

      tx.update(_invoice(groupId), {
        'participants': participants,
        'assignedUids': assignedUidsFor(createdBy, participants),
        'summary': summaryFor({'participants': participants}, vouchers),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> saveExpense(ExpenseInput input) async {
    // Checks the amounts before any network work, so a split that doesn't add
    // up is reported as such rather than as a refused write.
    voucherFields(
      input,
      uid: uid,
      revision: 1,
      createdBy: uid,
      createdAt: 0,
      updatedAt: 0,
    );
    final others = [
      for (final doc in await _read(_vouchers(input.groupId)))
        if (doc.$1 != input.expenseId) doc,
    ];
    final ref = _vouchers(input.groupId).doc(input.expenseId);

    await _run((tx) async {
      final invoice = await _invoiceIn(tx, input.groupId);
      final current = await tx.get(ref);
      final existing = current.data();

      final DocData fields;
      if (input.isNew) {
        // A retry after a lost response finds its own expense already saved.
        if (existing != null) {
          if (existing['createdBy'] == uid) return;
          throw const StoreException('That expense already exists.');
        }
        fields = voucherFields(
          input,
          uid: uid,
          revision: 1,
          createdBy: uid,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        );
      } else {
        if (existing == null) {
          throw const StoreException('This expense has been deleted.');
        }
        if (existing['revision'] != input.expectedRevision) {
          throw const StoreException(
            'Someone else changed this expense. Open it again to see their '
            'changes.',
          );
        }
        fields = voucherFields(
          input,
          uid: uid,
          revision: (input.expectedRevision ?? 0) + 1,
          createdBy: existing['createdBy'] as Object,
          createdAt: existing['createdAt'] as Object,
          updatedAt: FieldValue.serverTimestamp(),
        );
      }

      tx.set(ref, fields);
      tx.update(_invoice(input.groupId), {
        'summary': summaryFor(invoice, [...others, (input.expenseId, fields)]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteExpense(String groupId, String expenseId) async {
    final others = [
      for (final doc in await _read(_vouchers(groupId)))
        if (doc.$1 != expenseId) doc,
    ];
    await _run((tx) async {
      final invoice = await _invoiceIn(tx, groupId);
      tx.delete(_vouchers(groupId).doc(expenseId));
      tx.update(_invoice(groupId), {
        'summary': summaryFor(invoice, others),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> clearExpenses(String groupId) async {
    var remaining = await _read(_vouchers(groupId));
    while (remaining.isNotEmpty) {
      final batch = remaining.take(_maxWritesPerTransaction).toList();
      remaining = remaining.skip(_maxWritesPerTransaction).toList();
      final left = remaining;
      await _run((tx) async {
        final invoice = await _invoiceIn(tx, groupId);
        for (final (id, _) in batch) {
          tx.delete(_vouchers(groupId).doc(id));
        }
        tx.update(_invoice(groupId), {
          'summary': summaryFor(invoice, left),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  @override
  Future<Participant> createContact(String name) async {
    final contact = Participant(id: _uuid.v4(), name: name.trim());
    await _run((tx) async {
      tx.set(_contactsRef.doc(contact.id), {
        'name': contact.name,
        'kind': 'guest',
        'linkedUid': null,
      });
    });
    return contact;
  }

  @override
  Future<void> renameContact(Participant contact, String name) async {
    final entry = (await _contactsByParticipantId())[contact.id];
    if (entry == null) {
      throw const StoreException('This person is no longer in your list.');
    }
    await _run((tx) async {
      tx.update(_contactsRef.doc(entry.id), {'name': name.trim()});
    });
  }

  /// Only removes the entry from this person's list: each group keeps its own
  /// copy of the people on it.
  @override
  Future<void> deleteContact(String contactId, {bool force = false}) async {
    final entry = (await _contactsByParticipantId())[contactId];
    await _run((tx) async {
      tx.delete(_contactsRef.doc(entry?.id ?? contactId));
    });
  }
}
