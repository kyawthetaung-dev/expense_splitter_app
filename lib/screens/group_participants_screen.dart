import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/group_providers.dart';
import '../widgets/participant_selector.dart';

/// Lets a group select which of the common participants are its members.
/// This never creates or deletes participant records — it only edits the
/// group's membership links, so the same participant stays reusable across
/// every other group they belong to.
class GroupParticipantsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupParticipantsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupParticipantsScreen> createState() =>
      _GroupParticipantsScreenState();
}

class _GroupParticipantsScreenState
    extends ConsumerState<GroupParticipantsScreen> {
  Set<String>? _selectedParticipantIds;
  String? _errorText;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final currentIds = ref
        .watch(participantsProvider(widget.groupId))
        .map((p) => p.id)
        .toSet();
    _selectedParticipantIds ??= currentIds;
    final theme = Theme.of(context);
    final dirty = !setEquals(_selectedParticipantIds, currentIds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Participants'),
        actions: [
          TextButton(
            onPressed: (dirty && !_saving) ? _save : null,
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
            selectedIds: _selectedParticipantIds!,
            onChanged: (next) => setState(() => _selectedParticipantIds = next),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 16),
            Text(_errorText!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _errorText = null;
      _saving = true;
    });
    try {
      await ref
          .read(groupControllerProvider)
          .updateGroupParticipants(widget.groupId, _selectedParticipantIds!);
      if (mounted) setState(() => _saving = false);
    } on GroupParticipantReferencedException {
      setState(() {
        _saving = false;
        _errorText =
            'One or more removed participants have expense history in this '
            'group. Remove them from those expenses first, or delete the '
            'participant entirely from the common participant list.';
      });
    }
  }
}
