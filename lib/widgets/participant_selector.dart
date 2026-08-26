import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/participant.dart';
import '../providers/group_providers.dart';
import 'empty_state.dart';

/// Checklist over the common/shared participant list, with an inline
/// "add new participant" affordance for people who aren't in the common
/// list yet — used by both group creation and group-membership editing, so
/// selecting participants for a group never requires leaving the flow to
/// create them first.
class ParticipantSelector extends ConsumerWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const ParticipantSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(allParticipantsProvider);

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
    final Participant created = await ref
        .read(participantControllerProvider)
        .createParticipant(name);
    onChanged({...selectedIds, created.id});
  }
}
