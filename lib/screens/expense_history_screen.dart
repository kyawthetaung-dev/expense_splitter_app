import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../providers/expense_providers.dart';
import '../widgets/currency_text.dart';
import '../widgets/empty_state.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';

class ExpenseHistoryScreen extends ConsumerWidget {
  final String groupId;
  const ExpenseHistoryScreen({super.key, required this.groupId});

  Future<void> _clearAllExpenses(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all expenses?'),
        content: Text(
          'This will permanently delete all $count expense${count == 1 ? '' : 's'} in this group. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(expenseControllerProvider).clearAllExpenses(groupId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider(groupId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Expense History')),
      body: Column(
        children: [
          Expanded(
            child: expenses.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses yet',
                    subtitle: 'Expenses you add will show up here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ExpenseCard(expense: expenses[index]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: expenses.isEmpty
                    ? null
                    : () => _clearAllExpenses(context, ref, expenses.length),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear All Expenses'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
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

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  const _ExpenseCard({required this.expense});

  static const _splitIcons = {
    'equal': Icons.balance_outlined,
    'custom': Icons.tune,
    'percentage': Icons.percent,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpenseDetailScreen(expenseId: expense.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(
                  _splitIcons[expense.splitType.name] ?? Icons.receipt_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(expense.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              CurrencyText(
                expense.totalAmount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
