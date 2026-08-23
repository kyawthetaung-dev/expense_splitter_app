import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/calculation_providers.dart';
import '../providers/group_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_text.dart';
import '../widgets/empty_state.dart';

class SettlementsScreen extends ConsumerWidget {
  final String groupId;
  const SettlementsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(settlementsProvider(groupId));
    final participants = ref.watch(participantsProvider(groupId));
    final nameById = {for (final p in participants) p.id: p.name};
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: settlements.isEmpty
          ? const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All settled',
              subtitle: 'Nobody owes anybody in this group.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: settlements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final s = settlements[index];
                final from = nameById[s.fromParticipantId] ?? 'Unknown';
                final to = nameById[s.toParticipantId] ?? 'Unknown';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  from,
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  to,
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CurrencyText(
                          s.amount,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: payColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
