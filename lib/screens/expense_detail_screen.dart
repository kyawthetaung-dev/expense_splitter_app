import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../models/split_type.dart';
import '../providers/expense_providers.dart';
import '../providers/group_providers.dart';
import '../services/pdf/expense_pdf_builder.dart';
import '../widgets/currency_text.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expense = ref.watch(expenseProvider(expenseId));
    if (expense == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final payers = ref.watch(expensePayersProvider(expenseId));
    final shares = ref.watch(expenseSharesProvider(expenseId));
    final participants = ref.watch(participantsProvider(expense.groupId));
    final nameById = {for (final p in participants) p.id: p.name};
    final group = ref.watch(groupProvider(expense.groupId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: group == null
                ? null
                : () => Printing.layoutPdf(
                    onLayout: (format) async => buildExpensePdf(
                      group: group,
                      expense: expense,
                      payers: payers,
                      shares: shares,
                      participantNameById: nameById,
                    ).save(),
                    name: '${expense.title}.pdf',
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExpenseFormScreen(groupId: expense.groupId, expense: expense),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(expense.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          CurrencyText(
            expense.totalAmount,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Split: ${_splitTypeLabel(expense.splitType)} · Added ${_formatDateTime(expense.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('Paid by', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final payer in payers)
                  ListTile(
                    title: Text(nameById[payer.participantId] ?? 'Unknown'),
                    trailing: CurrencyText(payer.paidAmount),
                  ),
                if (payers.isEmpty)
                  const ListTile(title: Text('No payers recorded')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Participant shares', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final share in shares)
                  ListTile(
                    title: Text(nameById[share.participantId] ?? 'Unknown'),
                    trailing: CurrencyText(share.shareAmount),
                  ),
                if (shares.isEmpty)
                  const ListTile(title: Text('No participants recorded')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _splitTypeLabel(SplitType type) => switch (type) {
    SplitType.equal => 'Equal',
    SplitType.custom => 'Custom amounts',
    SplitType.percentage => 'Percentage',
  };

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(expenseControllerProvider).deleteExpense(expenseId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
