import 'package:intl/intl.dart';

import 'display_currency.dart';

/// Formats money with the **system display currency** (Profile preference).
///
/// Pass [currency] only to force a specific code. Live currency / live metals
/// must **not** use this for their converter boards — they format with explicit
/// FX/metal codes instead.
String formatMoney(dynamic value, {String? currency}) {
  final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  final meta = currency != null ? getCurrencyMeta(currency) : activeDisplayCurrency;
  final digits = n == n.roundToDouble() ? 0 : 2;
  try {
    return NumberFormat.currency(
      locale: meta.locale,
      symbol: meta.symbol,
      decimalDigits: digits,
    ).format(n);
  } catch (_) {
    return '${meta.symbol}${n.toStringAsFixed(digits)}';
  }
}

String formatDate(dynamic value) {
  if (value == null) return '-';
  final d = value is DateTime ? value : DateTime.tryParse(value.toString());
  if (d == null) return value.toString();
  return DateFormat('dd MMM yyyy').format(d);
}
