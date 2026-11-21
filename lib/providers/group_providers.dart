import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/store/invoice_store.dart';
import '../models/group.dart';
import '../models/participant.dart';
import 'store_providers.dart';

export '../data/store/invoice_store.dart'
    show GroupParticipantReferencedException, StoreException;

const _uuid = Uuid();

// These read synchronously from the store's streams, so a screen must wait
// for the stream first (see `gateOn`); reading before it has loaded throws.

final groupProvider = Provider.autoDispose.family<Group?, String>(
  (ref, groupId) => ref.watch(invoiceProvider(groupId)).requireValue?.group,
);

/// The participants who are members of [groupId], sorted by name. Only these
/// can be on the group's expenses.
final participantsProvider = Provider.autoDispose
    .family<List<Participant>, String>((ref, groupId) {
      final snapshot = ref.watch(invoiceProvider(groupId)).requireValue;
      return [...?snapshot?.participants]
        ..sort((a, b) => a.name.compareTo(b.name));
    });

/// This person's whole list of people, regardless of group, sorted by name.
final allParticipantsProvider = Provider.autoDispose<List<Participant>>((ref) {
  return [...ref.watch(contactsProvider).requireValue]
    ..sort((a, b) => a.name.compareTo(b.name));
});

class GroupController {
  GroupController(this.ref);
  final Ref ref;

  InvoiceStore get _store => ref.read(invoiceStoreProvider);

  /// Pass the same [groupId] when retrying, so a create whose response was
  /// lost isn't made twice.
  Future<Group> createGroup(
    String name, {
    required List<String> participantIds,
    String? groupId,
  }) {
    return _store.createGroup(
      groupId: groupId ?? _uuid.v4(),
      name: name,
      participantIds: participantIds,
    );
  }

  Future<void> renameGroup(String groupId, String newName) =>
      _store.renameGroup(groupId, newName);

  Future<void> deleteGroup(String groupId) => _store.deleteGroup(groupId);

  /// Throws [GroupParticipantReferencedException] (or [StoreException]) if
  /// someone in [remove] still has payer/share history in this group, whose
  /// balance would otherwise be silently orphaned.
  Future<void> updateGroupParticipants(
    String groupId, {
    Set<String> add = const {},
    Set<String> remove = const {},
  }) => _store.updateGroupParticipants(groupId, add: add, remove: remove);
}

final groupControllerProvider = Provider((ref) => GroupController(ref));

/// CRUD over this person's list of people (not scoped to any group).
class ParticipantController {
  ParticipantController(this.ref);
  final Ref ref;

  InvoiceStore get _store => ref.read(invoiceStoreProvider);

  Future<Participant> createParticipant(String name) =>
      _store.createContact(name);

  Future<void> renameParticipant(Participant participant, String newName) =>
      _store.renameContact(participant, newName);

  /// On this device, throws `ParticipantReferencedException` if the
  /// participant has expense history and [force] is false.
  Future<void> deleteParticipant(String participantId, {bool force = false}) =>
      _store.deleteContact(participantId, force: force);
}

final participantControllerProvider = Provider(
  (ref) => ParticipantController(ref),
);
