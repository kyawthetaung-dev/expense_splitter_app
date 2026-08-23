/// Distributes [total] integer minor-units among [count] entries as evenly
/// as possible: everyone gets `total ~/ count`, and the first
/// `total % count` entries (by index in the caller's already-deterministic
/// order — e.g. participant ids sorted ascending) get one extra unit. The
/// result always sums to exactly [total], which is what lets equal-split
/// shares add up exactly even when the amount doesn't divide evenly.
List<int> distributeEqually({required int total, required int count}) {
  if (count <= 0) {
    throw ArgumentError.value(count, 'count', 'must be > 0');
  }
  final base = total ~/ count;
  final remainder = total % count;
  return List<int>.generate(count, (i) => base + (i < remainder ? 1 : 0));
}

/// Distributes [total] among entries weighted by [percentages] (each 0-100,
/// summing to 100 within [epsilon]). Each entry's exact share is floored;
/// the leftover minor units from flooring go one-by-one to the entries with
/// the largest fractional remainder (ties broken by index), so the result
/// sums to exactly [total].
List<int> distributeByPercentage({
  required int total,
  required List<double> percentages,
  double epsilon = 0.001,
}) {
  final sum = percentages.fold<double>(0, (a, b) => a + b);
  if ((sum - 100).abs() > epsilon) {
    throw ArgumentError('percentages must sum to 100, got $sum');
  }

  final exact = [for (final p in percentages) total * p / 100];
  final floors = [for (final e in exact) e.floor()];
  var leftover = total - floors.fold<int>(0, (a, b) => a + b);

  final fractional = [
    for (var i = 0; i < exact.length; i++) exact[i] - floors[i],
  ];
  final order = List<int>.generate(exact.length, (i) => i)..sort((a, b) {
    final cmp = fractional[b].compareTo(fractional[a]);
    return cmp != 0 ? cmp : a.compareTo(b);
  });

  final result = List<int>.from(floors);
  var k = 0;
  while (leftover > 0 && k < order.length) {
    result[order[k]] += 1;
    leftover--;
    k++;
  }
  // leftover < 0 only if `sum` was within epsilon but slightly over 100;
  // claw back from the smallest-fractional entries in the same deterministic
  // order, from the tail.
  while (leftover < 0 && k > 0) {
    k--;
    result[order[k]] -= 1;
    leftover++;
  }

  return result;
}
