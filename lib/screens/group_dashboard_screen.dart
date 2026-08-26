import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/calculation_providers.dart';
import '../providers/group_providers.dart';
import '../widgets/currency_text.dart';
import '../widgets/empty_state.dart';
import '../widgets/person_balance_tile.dart';
import '../widgets/summary_card.dart';
import 'expense_form_screen.dart';
import 'expense_history_screen.dart';
import 'group_participants_screen.dart';
import 'settlements_screen.dart';

class GroupDashboardScreen extends ConsumerWidget {
  final String groupId;
  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    if (group == null) {
      // Group was deleted (e.g. from another screen) — bail out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final summary = ref.watch(groupSummaryProvider(groupId));
    final participants = ref.watch(participantsProvider(groupId));
    final balances = ref.watch(personBalancesProvider(groupId));
    final balanceByParticipant = {for (final b in balances) b.participantId: b};

    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            tooltip: 'Participants',
            icon: const Icon(Icons.people_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupParticipantsScreen(groupId: groupId),
              ),
            ),
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExpenseHistoryScreen(groupId: groupId),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Settlements',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettlementsScreen(groupId: groupId),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: wide ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                SummaryCard(
                  label: 'Total Expenses',
                  icon: Icons.receipt_long_outlined,
                  value: CurrencyText(summary.totalExpenseAmount),
                ),
                SummaryCard(
                  label: 'Participants',
                  icon: Icons.people_outline,
                  value: Text('${summary.participantCount}'),
                ),
                SummaryCard(
                  label: 'Total Paid',
                  icon: Icons.payments_outlined,
                  value: CurrencyText(summary.totalPaid),
                ),
                SummaryCard(
                  label: 'Outstanding',
                  icon: Icons.hourglass_bottom_outlined,
                  value: CurrencyText(
                    summary.totalOutstanding,
                    color: summary.totalOutstanding > 0
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balances', style: Theme.of(context).textTheme.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: summary.isFullySettled
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    summary.isFullySettled ? 'All settled' : 'Pending settlement',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (participants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.person_add_alt_outlined,
                  title: 'No participants yet',
                  subtitle: 'Add participants before recording expenses.',
                ),
              )
            else
              ...participants.map((p) {
                final balance = balanceByParticipant[p.id];
                if (balance == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PersonBalanceTile(participant: p, balance: balance),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: participants.isEmpty
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseFormScreen(groupId: groupId),
                ),
              ),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}
