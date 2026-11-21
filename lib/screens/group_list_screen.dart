import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store/invoice_store.dart';
import '../providers/group_providers.dart';
import '../providers/store_providers.dart';
import '../widgets/data_gate.dart';
import '../widgets/empty_state.dart';
import '../widgets/show_failure.dart';
import '../widgets/sign_out_button.dart';
import 'common_participants_screen.dart';
import 'create_group_screen.dart';
import 'expense_summary_screen.dart';
import 'group_dashboard_screen.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  /// Hidden as soon as they're swiped away. The list itself can update after
  /// the swipe animation ends, and a dismissed card mustn't still be showing.
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupListProvider);

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
          const SignOutButton(),
        ],
      ),
      body: switch (groups) {
        AsyncValue(hasValue: true, :final value) => _buildList(
          value!.where((item) => !_dismissed.contains(item.group.id)).toList(),
        ),
        AsyncValue(isLoading: false, :final error?) => LoadFailed(
          error: error,
          onRetry: () => ref.invalidate(groupListProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
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

  Widget _buildList(List<GroupListItem> items) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'No groups yet',
        subtitle: 'Create a group to start splitting expenses with friends.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _GroupCard(
        item: items[index],
        onDismissed: () =>
            setState(() => _dismissed.add(items[index].group.id)),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final GroupListItem item;
  final VoidCallback onDismissed;

  const _GroupCard({required this.item, required this.onDismissed});

  /// Deletes before letting the card go, so a refused delete leaves it in place.
  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          '"${item.group.name}" and all of its expenses will be deleted. This cannot be undone.',
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
    if (confirmed != true) return false;
    try {
      await ref.read(groupControllerProvider).deleteGroup(item.group.id);
      return true;
    } catch (e) {
      if (context.mounted) showFailure(context, e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = item.group;

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
      confirmDismiss: (_) => _confirmDelete(context, ref),
      onDismissed: (_) => onDismissed(),
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
                        '${item.participantCount} participant${item.participantCount == 1 ? '' : 's'} · '
                        '${item.expenseCount} expense${item.expenseCount == 1 ? '' : 's'}',
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
                    color: item.isFullySettled
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.errorContainer.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.isFullySettled ? 'Settled' : 'Pending',
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
