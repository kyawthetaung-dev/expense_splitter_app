import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../providers/calculation_providers.dart';
import '../providers/group_providers.dart';
import '../widgets/empty_state.dart';
import 'common_participants_screen.dart';
import 'create_group_screen.dart';
import 'expense_summary_screen.dart';
import 'group_dashboard_screen.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo/logo.png', width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            const Text('Expense Splitter'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Participants',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommonParticipantsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Expense Summary',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseSummaryScreen()),
            ),
          ),
        ],
      ),
      body: groups.isEmpty
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No groups yet',
              subtitle:
                  'Create a group to start splitting expenses with friends.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _GroupCard(group: groups[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final Group group;
  const _GroupCard({required this.group});

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          '"${group.name}" and all of its expenses will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final participants = ref.watch(participantsProvider(group.id));
    final summary = ref.watch(groupSummaryProvider(group.id));

    return Dismissible(
      key: ValueKey(group.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          ref.read(groupControllerProvider).deleteGroup(group.id),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDashboardScreen(groupId: group.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.groups,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${participants.length} participant${participants.length == 1 ? '' : 's'} · '
                        '${summary.expenseCount} expense${summary.expenseCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: summary.isFullySettled
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.errorContainer.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    summary.isFullySettled ? 'Settled' : 'Pending',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
