import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/participant.dart';
import '../providers/group_providers.dart';
import 'empty_state.dart';
import 'show_failure.dart';

/// Checklist over this person's participant list, with an inline "add new
/// participant" affordance for people who aren't in the list yet — used by
/// both group creation and group-membership editing, so selecting
/// participants for a group never requires leaving the flow to create them
/// first. The screen using it must wait for `contactsProvider` first.
class ParticipantSelector extends ConsumerWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  /// Group members to list even when they aren't in this person's own list,
  /// such as someone another member added, so they can still be seen and
  /// kept.
  final List<Participant> alsoShow;

  const ParticipantSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    this.alsoShow = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(allParticipantsProvider);
    final contactIds = {for (final p in contacts) p.id};
    final participants = [
      ...contacts,
      ...alsoShow.where((p) => !contactIds.contains(p.id)),
    ]..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Column(
            children: [
              if (participants.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: EmptyState(
                    icon: Icons.person_add_alt_outlined,
                    title: 'No participants yet',
                    subtitle: 'Add someone below to get started.',
                  ),
                )
              else
                for (final p in participants)
                  CheckboxListTile(
                    value: selectedIds.contains(p.id),
                    title: Text(p.name),
                    onChanged: (checked) {
                      final next = Set<String>.from(selectedIds);
                      if (checked == true) {
                        next.add(p.id);
                      } else {
                        next.remove(p.id);
                      }
                      onChanged(next);
                    },
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addParticipant(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add new participant'),
        ),
      ],
    );
  }

  Future<void> _addParticipant(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add participant'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final Participant created = await ref
          .read(participantControllerProvider)
          .createParticipant(name);
      onChanged({...selectedIds, created.id});
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }
}
