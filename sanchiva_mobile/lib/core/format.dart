import 'package:intl/intl.dart';

import 'display_currency.dart';
import 'local_date.dart';

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
  if (value is DateTime) {
    return DateFormat('dd MMM yyyy').format(localCalendarDate(value));
  }
  final raw = value.toString().trim();
  // Prefer calendar YYYY-MM-DD so UTC parsing never flips the day in IST.
  if (raw.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
    return DateFormat('dd MMM yyyy').format(parseLocalYmd(raw));
  }
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return DateFormat('dd MMM yyyy').format(localCalendarDate(d.toLocal()));
}
