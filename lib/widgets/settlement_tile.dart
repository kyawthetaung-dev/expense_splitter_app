import 'package:flutter/material.dart';

import '../models/settlement_transaction.dart';
import '../theme/app_theme.dart';
import 'currency_text.dart';

/// One "X pays Y an amount" settlement row — shared by [SettlementsScreen]
/// (single group) and the cross-group Expense Summary screen.
class SettlementTile extends StatelessWidget {
  final SettlementTransaction settlement;
  final String fromName;
  final String toName;

  const SettlementTile({
    super.key,
    required this.settlement,
    required this.fromName,
    required this.toName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      fromName,
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
                      toName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            CurrencyText(
              settlement.amount,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: payColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
