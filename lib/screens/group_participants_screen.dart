import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/group_providers.dart';
import '../providers/store_providers.dart';
import '../widgets/data_gate.dart';
import '../widgets/participant_selector.dart';

/// Lets a group select which of the person's participants are its members.
/// This never creates or deletes participant records — it only edits the
/// group's membership, so the same participant stays reusable across every
/// other group they belong to.
class GroupParticipantsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupParticipantsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupParticipantsScreen> createState() =>
      _GroupParticipantsScreenState();
}

class _GroupParticipantsScreenState
    extends ConsumerState<GroupParticipantsScreen> {
  // Kept as changes on top of the current members rather than a full list,
  // so someone else's change made meanwhile still shows, and saving doesn't
  // undo it.
  final Set<String> _added = {};
  final Set<String> _removed = {};
  String? _errorText;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final gate = gateOn(ref, [
      invoiceProvider(widget.groupId),
      contactsProvider,
    ], title: 'Group Participants');
    if (gate != null) return gate;

    final members = ref.watch(participantsProvider(widget.groupId));
    final currentIds = {for (final p in members) p.id};
    final selected = currentIds.union(_added).difference(_removed);
    final add = selected.difference(currentIds);
    final remove = currentIds.difference(selected);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Participants'),
        actions: [
          TextButton(
            onPressed: (add.isNotEmpty || remove.isNotEmpty) && !_saving
                ? () => _save(add: add, remove: remove)
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Select who is in this group. Only selected participants are '
            'available for expenses in this group.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ParticipantSelector(
            selectedIds: selected,
            alsoShow: members,
            onChanged: (next) => setState(() {
              _added
                ..clear()
                ..addAll(next.difference(currentIds));
              _removed
                ..clear()
                ..addAll(currentIds.difference(next));
            }),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 16),
            Text(_errorText!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Future<void> _save({
    required Set<String> add,
    required Set<String> remove,
  }) async {
    setState(() {
      _errorText = null;
      _saving = true;
    });
    String? error;
    try {
      await ref
          .read(groupControllerProvider)
          .updateGroupParticipants(widget.groupId, add: add, remove: remove);
    } on GroupParticipantReferencedException {
      error =
          'One or more removed participants have expense history in this '
          'group. Remove them from those expenses first, or delete the '
          'participant entirely from the common participant list.';
    } on StoreException catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errorText = error;
      if (error == null) {
        _added.clear();
        _removed.clear();
      }
    });
  }
}
