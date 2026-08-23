import 'currency.dart';

const mmk = Currency(
  code: 'MMK',
  symbol: 'MMK',
  minorUnitDigits: 0,
  symbolBefore: false,
);

/// Registry of supported currencies, keyed by ISO code. Add new entries
/// here to support additional currencies in the future.
const supportedCurrencies = <String, Currency>{'MMK': mmk};
