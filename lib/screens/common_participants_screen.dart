import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/participant_repository.dart';
import '../models/participant.dart';
import '../providers/group_providers.dart';
import '../providers/store_providers.dart';
import '../widgets/data_gate.dart';
import '../widgets/empty_state.dart';
import '../widgets/show_failure.dart';

/// The common/shared participant master list — participants created here
/// can be selected into any number of groups; they're never duplicated per
/// group.
class CommonParticipantsScreen extends ConsumerWidget {
  const CommonParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = gateOn(ref, [contactsProvider], title: 'Participants');
    if (gate != null) return gate;

    final participants = ref.watch(allParticipantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Participants')),
      body: participants.isEmpty
          ? const EmptyState(
              icon: Icons.person_add_alt_outlined,
              title: 'No participants yet',
              subtitle: 'Add the people you split expenses with.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: participants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final participant = participants[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        participant.name.isEmpty ? '?' : participant.name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(participant.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(context, ref, participant),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, ref, participant),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Participant'),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context, title: 'Add participant', hint: 'Name');
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(participantControllerProvider).createParticipant(name);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Participant participant) async {
    final name = await _promptForName(
      context,
      title: 'Rename participant',
      hint: 'Name',
      initialValue: participant.name,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref
          .read(participantControllerProvider)
          .renameParticipant(participant, name);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Participant participant) async {
    final controller = ref.read(participantControllerProvider);
    try {
      await controller.deleteParticipant(participant.id);
    } on ParticipantReferencedException {
      // Only local storage refuses this way: in Firestore, each group keeps
      // its own copy of its members, so removing someone here is harmless.
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove participant?'),
          content: Text(
            '${participant.name} has expense history in one or more groups. Removing '
            'them will also delete their payments and shares on those expenses, and '
            'existing expense totals will no longer match their recorded payer '
            'amounts. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await controller.deleteParticipant(participant.id, force: true);
      } catch (e) {
        if (context.mounted) showFailure(context, e);
      }
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }
}

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  required String hint,
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
