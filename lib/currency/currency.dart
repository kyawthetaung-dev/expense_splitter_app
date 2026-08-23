/// Describes how to format an integer amount (in minor units) for a
/// currency. All money in this app is stored as `int` — for MMK,
/// [minorUnitDigits] is 0, so the stored integer is the whole-unit amount.
class Currency {
  final String code;
  final String symbol;
  final int minorUnitDigits;
  final bool symbolBefore;

  const Currency({
    required this.code,
    required this.symbol,
    required this.minorUnitDigits,
    required this.symbolBefore,
  });
}
