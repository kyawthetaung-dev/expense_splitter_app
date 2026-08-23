import 'package:flutter/material.dart';

import '../currency/currencies.dart';
import '../currency/currency.dart';
import '../currency/currency_formatter.dart';

class CurrencyText extends StatelessWidget {
  final int amountMinorUnits;
  final Currency currency;
  final TextStyle? style;
  final Color? color;

  const CurrencyText(
    this.amountMinorUnits, {
    super.key,
    this.currency = mmk,
    this.style,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    return Text(
      formatCurrency(amountMinorUnits, currency),
      style: baseStyle?.copyWith(color: color ?? baseStyle.color),
    );
  }
}
