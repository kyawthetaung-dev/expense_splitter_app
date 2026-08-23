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

final participantsProvider = Provider.family<List<Participant>, String>((
  ref,
  groupId,
) {
  ref.watch(dataRevisionProvider);
  final list = ref.watch(participantRepositoryProvider).getByGroup(groupId);
  return list..sort((a, b) => a.name.compareTo(b.name));
});

class GroupController {
  GroupController(this.ref);
  final Ref ref;

  Future<Group> createGroup(String name) async {
    final now = DateTime.now();
    final group = Group(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(groupRepositoryProvider).save(group);
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

  Future<Participant> addParticipant(String groupId, String name) async {
    final participant = Participant(
      id: _uuid.v4(),
      groupId: groupId,
      name: name.trim(),
    );
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
  Future<void> removeParticipant(String participantId, {bool force = false}) async {
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

final groupControllerProvider = Provider((ref) => GroupController(ref));
