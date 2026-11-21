import '../models/split_type.dart';
import 'remainder_distributor.dart';

class ExpenseShareResult {
  final String participantId;
  final int shareAmount;

  const ExpenseShareResult({
    required this.participantId,
    required this.shareAmount,
  });
}

/// Computes each participant's share of [totalAmount] for one expense.
///
/// [participantIds] is canonicalized (sorted ascending) before any
/// remainder distribution, so the result is deterministic regardless of UI
/// selection order — re-saving an unchanged expense always yields identical
/// shares.
List<ExpenseShareResult> calculateExpenseShares({
  required int totalAmount,
  required SplitType splitType,
  required List<String> participantIds,
  Map<String, int>? customAmounts,
  Map<String, double>? percentages,
}) {
  if (totalAmount < 0) {
    throw ArgumentError.value(totalAmount, 'totalAmount', 'must be >= 0');
  }
  if (participantIds.isEmpty) {
    throw ArgumentError.value(
      participantIds,
      'participantIds',
      'must not be empty',
    );
  }
  final uniqueIds = participantIds.toSet();
  if (uniqueIds.length != participantIds.length) {
    throw ArgumentError.value(
      participantIds,
      'participantIds',
      'must not contain duplicates',
    );
  }

  final sortedIds = participantIds.toList()..sort();

  switch (splitType) {
    case SplitType.equal:
      final amounts = distributeEqually(
        total: totalAmount,
        count: sortedIds.length,
      );
      return [
        for (var i = 0; i < sortedIds.length; i++)
          ExpenseShareResult(
            participantId: sortedIds[i],
            shareAmount: amounts[i],
          ),
      ];

    case SplitType.custom:
      if (customAmounts == null) {
        throw ArgumentError('customAmounts is required for SplitType.custom');
      }
      _requireExactKeys(customAmounts.keys.toSet(), uniqueIds, 'customAmounts');
      if (customAmounts.values.any((amount) => amount < 0)) {
        throw ArgumentError('customAmounts must not be negative');
      }
      final sum = customAmounts.values.fold<int>(0, (a, b) => a + b);
      if (sum != totalAmount) {
        throw ArgumentError(
          'customAmounts must sum to totalAmount ($sum != $totalAmount)',
        );
      }
      return [
        for (final id in sortedIds)
          ExpenseShareResult(participantId: id, shareAmount: customAmounts[id]!),
      ];

    case SplitType.percentage:
      if (percentages == null) {
        throw ArgumentError('percentages is required for SplitType.percentage');
      }
      _requireExactKeys(percentages.keys.toSet(), uniqueIds, 'percentages');
      final amounts = distributeByPercentage(
        total: totalAmount,
        percentages: [for (final id in sortedIds) percentages[id]!],
      );
      return [
        for (var i = 0; i < sortedIds.length; i++)
          ExpenseShareResult(
            participantId: sortedIds[i],
            shareAmount: amounts[i],
          ),
      ];
  }
}

/// Best-effort percentages for an expense that has only integer [shares]
/// (saved before [Expense.percentages] existed): each share rounded to two
/// decimals, with the rounding drift placed on the largest share (ties go to
/// the lowest id) so the result sums to exactly 100 and can be re-saved.
/// Returns an empty map when the shares sum to zero.
Map<String, double> derivePercentagesFromShares(Map<String, int> shares) {
  final total = shares.values.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return {};

  final sortedIds = shares.keys.toList()..sort();
  final hundredths = {
    for (final id in sortedIds) id: (shares[id]! * 10000 / total).round(),
  };
  var largestId = sortedIds.first;
  for (final id in sortedIds) {
    if (shares[id]! > shares[largestId]!) largestId = id;
  }
  final drift = 10000 - hundredths.values.fold<int>(0, (a, b) => a + b);
  hundredths[largestId] = hundredths[largestId]! + drift;

  return {for (final id in sortedIds) id: hundredths[id]! / 100};
}

void _requireExactKeys(Set<String> keys, Set<String> expected, String name) {
  if (keys.difference(expected).isNotEmpty ||
      expected.difference(keys).isNotEmpty) {
    throw ArgumentError('$name keys must exactly match participantIds');
  }
}
