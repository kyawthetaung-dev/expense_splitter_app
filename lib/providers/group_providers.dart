import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/participant_repository.dart';
import '../models/group.dart';
import '../models/participant.dart';
import 'repository_providers.dart';

const _uuid = Uuid();

final groupsProvider = Provider<List<Group>>((ref) {
  ref.watch(dataRevisionProvider);
  final groups = ref.watch(groupRepositoryProvider).getAll();
  return groups..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

final groupProvider = Provider.family<Group?, String>((ref, groupId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(groupRepositoryProvider).getById(groupId);
});

/// The participants who are members of [groupId] — resolved from the
/// group's membership links against the common participant list, sorted by
/// name. Only these participants are available for expense calculations
/// within this group.
final participantsProvider = Provider.family<List<Participant>, String>((
  ref,
  groupId,
) {
  ref.watch(dataRevisionProvider);
  final groupRepo = ref.watch(groupRepositoryProvider);
  final participantRepo = ref.watch(participantRepositoryProvider);
  final ids = groupRepo.getParticipantIds(groupId);
  final list = participantRepo.getByIds(ids);
  return list..sort((a, b) => a.name.compareTo(b.name));
});

/// Every participant in the common/shared list, regardless of group
/// membership — used for the common-participant management screen and the
/// group participant picker.
final allParticipantsProvider = Provider<List<Participant>>((ref) {
  ref.watch(dataRevisionProvider);
  final list = ref.watch(participantRepositoryProvider).getAll();
  return list..sort((a, b) => a.name.compareTo(b.name));
});

class GroupController {
  GroupController(this.ref);
  final Ref ref;

  Future<Group> createGroup(
    String name, {
    required List<String> participantIds,
  }) async {
    final now = DateTime.now();
    final group = Group(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(groupRepositoryProvider).save(group);
    await ref.read(groupRepositoryProvider).setParticipants(
      group.id,
      participantIds,
    );
    _bump();
    return group;
  }

  Future<void> renameGroup(Group group, String newName) async {
    await ref
        .read(groupRepositoryProvider)
        .save(group.copyWith(name: newName.trim(), updatedAt: DateTime.now()));
    _bump();
  }

  Future<void> deleteGroup(String groupId) async {
    await ref.read(groupRepositoryProvider).delete(groupId);
    _bump();
  }

  /// Replaces [groupId]'s membership with exactly [participantIds]. Throws
  /// [GroupParticipantReferencedException] if a participant being removed
  /// still has payer/share history on an expense in this group — their
  /// balance data would otherwise be silently orphaned.
  Future<void> updateGroupParticipants(
    String groupId,
    Set<String> participantIds,
  ) async {
    final groupRepo = ref.read(groupRepositoryProvider);
    final current = groupRepo.getParticipantIds(groupId).toSet();
    final removed = current.difference(participantIds);
    for (final participantId in removed) {
      if (groupRepo.isParticipantReferencedInGroup(groupId, participantId)) {
        throw GroupParticipantReferencedException(
          'Cannot remove participant $participantId from group $groupId: '
          'they have expense history in this group.',
        );
      }
    }
    await groupRepo.setParticipants(groupId, participantIds.toList());
    _bump();
  }

  void _bump() => ref.read(dataRevisionProvider.notifier).state++;
}

final groupControllerProvider = Provider((ref) => GroupController(ref));

class GroupParticipantReferencedException implements Exception {
  final String message;
  GroupParticipantReferencedException(this.message);

  @override
  String toString() => message;
}

/// CRUD over the common/shared participant list (not scoped to any group).
class ParticipantController {
  ParticipantController(this.ref);
  final Ref ref;

  Future<Participant> createParticipant(String name) async {
    final participant = Participant(id: _uuid.v4(), name: name.trim());
    await ref.read(participantRepositoryProvider).save(participant);
    _bump();
    return participant;
  }

  Future<void> renameParticipant(Participant participant, String newName) async {
    await ref
        .read(participantRepositoryProvider)
        .save(participant.copyWith(name: newName.trim()));
    _bump();
  }

  /// Throws [ParticipantReferencedException] if the participant has expense
  /// history and [force] is false.
  Future<void> deleteParticipant(String participantId, {bool force = false}) async {
    final repo = ref.read(participantRepositoryProvider);
    if (force) {
      await repo.forceDelete(participantId);
    } else {
      await repo.delete(participantId);
    }
    _bump();
  }

  void _bump() => ref.read(dataRevisionProvider.notifier).state++;
}

final participantControllerProvider = Provider((ref) => ParticipantController(ref));
