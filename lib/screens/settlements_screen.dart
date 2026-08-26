import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/calculation_providers.dart';
import '../providers/group_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/settlement_tile.dart';

class SettlementsScreen extends ConsumerWidget {
  final String groupId;
  const SettlementsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(settlementsProvider(groupId));
    final participants = ref.watch(participantsProvider(groupId));
    final nameById = {for (final p in participants) p.id: p.name};

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
                return SettlementTile(
                  settlement: s,
                  fromName: nameById[s.fromParticipantId] ?? 'Unknown',
                  toName: nameById[s.toParticipantId] ?? 'Unknown',
                );
              },
            ),
    );
  }
}
