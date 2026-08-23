import 'package:intl/intl.dart';

import 'currencies.dart';
import 'currency.dart';

/// Formats an integer amount (in minor units) for a currency, e.g.
/// `format(17025, mmk) == "17,025 MMK"`.
///
/// Uses [NumberFormat.decimalPattern] purely for thousands-grouping — the
/// symbol/placement/decimal digits come from [Currency], not from locale
/// currency data, since MMK isn't reliably represented by ICU currency
/// formatting across devices.
String formatCurrency(int amountMinorUnits, [Currency currency = mmk]) {
  final divisor = _pow10(currency.minorUnitDigits);
  final whole = amountMinorUnits ~/ divisor;
  final grouped = NumberFormat.decimalPattern().format(whole);

  final String amountText;
  if (currency.minorUnitDigits == 0) {
    amountText = grouped;
  } else {
    final fraction = (amountMinorUnits % divisor).abs().toString().padLeft(
      currency.minorUnitDigits,
      '0',
    );
    amountText = '$grouped.$fraction';
  }

  return currency.symbolBefore
      ? '${currency.symbol}$amountText'
      : '$amountText ${currency.symbol}';
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
