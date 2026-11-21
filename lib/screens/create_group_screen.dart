import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/group.dart';
import '../providers/group_providers.dart';
import '../providers/store_providers.dart';
import '../widgets/data_gate.dart';
import '../widgets/participant_selector.dart';
import 'group_dashboard_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Set<String> _selectedParticipantIds = {};
  String? _errorText;
  bool _saving = false;

  /// Kept for the life of the screen, so retrying a failed create can't make
  /// the group twice.
  final String _groupId = const Uuid().v4();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gate = gateOn(ref, [contactsProvider], title: 'New Group');
    if (gate != null) return gate;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'e.g. Weekend Trip',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 24),
            Text('Participants', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Select who is in this group from your common participant list.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ParticipantSelector(
              selectedIds: _selectedParticipantIds,
              onChanged: (next) => setState(() {
                _selectedParticipantIds
                  ..clear()
                  ..addAll(next);
              }),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(_errorText!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: const Text('Create Group'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedParticipantIds.isEmpty) {
      setState(() => _errorText = 'Select at least one participant.');
      return;
    }

    setState(() => _saving = true);
    final Group group;
    try {
      group = await ref
          .read(groupControllerProvider)
          .createGroup(
            _nameController.text,
            participantIds: _selectedParticipantIds.toList(),
            groupId: _groupId,
          );
    } on StoreException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = e.message;
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GroupDashboardScreen(groupId: group.id)),
    );
  }
}
