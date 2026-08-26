import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../providers/group_providers.dart';
import '../providers/summary_providers.dart';
import '../services/pdf/summary_pdf_builder.dart';
import '../widgets/currency_text.dart';
import '../widgets/empty_state.dart';
import '../widgets/person_balance_tile.dart';
import '../widgets/settlement_tile.dart';
import '../widgets/summary_card.dart';

/// Cross-group expense summary: every participant's overall paid/share/
/// balance across ALL groups they belong to, and the automatically
/// calculated settlement (who pays whom) that resolves it.
class ExpenseSummaryScreen extends ConsumerWidget {
  const ExpenseSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(overallSummaryProvider);
    final balances = ref.watch(overallPersonBalancesProvider);
    final settlements = ref.watch(overallSettlementsProvider);
    final participants = ref.watch(allParticipantsProvider);
    final participantById = {for (final p in participants) p.id: p};
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: balances.isEmpty
                ? null
                : () => Printing.layoutPdf(
                    onLayout: (format) async => buildSummaryPdf(
                      generatedAt: DateTime.now(),
                      summary: summary,
                      participants: participants,
                      balances: balances,
                      settlements: settlements,
                    ).save(),
                    name: 'expense-summary.pdf',
                  ),
          ),
        ],
      ),
      body: balances.isEmpty
          ? const EmptyState(
              icon: Icons.summarize_outlined,
              title: 'Nothing to summarize yet',
              subtitle: 'Add participants and groups to see the overall summary.',
            )
          : ListView(
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
                      label: 'Expense Groups',
                      icon: Icons.groups_outlined,
                      value: Text('${summary.groupCount}'),
                    ),
                    SummaryCard(
                      label: 'Grand Total',
                      icon: Icons.receipt_long_outlined,
                      value: CurrencyText(summary.totalExpenseAmount),
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
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Participant Summary', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                for (final b in balances)
                  if (participantById[b.participantId] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PersonBalanceTile(
                        participant: participantById[b.participantId]!,
                        balance: b,
                      ),
                    ),
                const SizedBox(height: 24),
                Text('Settlement Details', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                if (settlements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'All settled',
                      subtitle: 'Nobody owes anybody across any group.',
                    ),
                  )
                else
                  for (final s in settlements)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SettlementTile(
                        settlement: s,
                        fromName: participantById[s.fromParticipantId]?.name ?? 'Unknown',
                        toName: participantById[s.toParticipantId]?.name ?? 'Unknown',
                      ),
                    ),
              ],
            ),
    );
  }
}
