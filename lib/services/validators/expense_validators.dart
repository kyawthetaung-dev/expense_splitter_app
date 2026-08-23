/// Pure validation helpers for expense input, run before persisting so the
/// balance/settlement invariant (payers sum == shares sum == total) holds in
/// normal use. Throw [ArgumentError] on violation; the form layer catches
/// these and surfaces them as field errors.
void validateExpenseAmount(int totalAmount) {
  if (totalAmount < 0) {
    throw ArgumentError.value(
      totalAmount,
      'totalAmount',
      'must not be negative',
    );
  }
}

void validatePayersSumToTotal(Map<String, int> paidAmounts, int totalAmount) {
  if (paidAmounts.values.any((amount) => amount < 0)) {
    throw ArgumentError('paidAmount values must not be negative');
  }
  final sum = paidAmounts.values.fold<int>(0, (a, b) => a + b);
  if (sum != totalAmount) {
    throw ArgumentError(
      'sum of payer amounts ($sum) must equal totalAmount ($totalAmount)',
    );
  }
}

void validateSharesSumToTotal(List<int> shareAmounts, int totalAmount) {
  final sum = shareAmounts.fold<int>(0, (a, b) => a + b);
  if (sum != totalAmount) {
    throw ArgumentError(
      'sum of shares ($sum) must equal totalAmount ($totalAmount)',
    );
  }
}
