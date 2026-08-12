/// App-wide *display* currency (Profile preference).
///
/// Same idea as web `CurrencyContext`: amounts are stored as-is; only the
/// symbol/locale for UI formatting change.
///
/// Live currency converter & live metals use their own formatters and ignore this.

class DisplayCurrencyMeta {
  const DisplayCurrencyMeta({
    required this.code,
    required this.symbol,
    required this.label,
    required this.locale,
  });

  final String code;
  final String symbol;
  final String label;
  final String locale;
}

const kDisplayCurrencies = <DisplayCurrencyMeta>[
  DisplayCurrencyMeta(code: 'INR', symbol: '₹', label: 'Indian Rupee', locale: 'en_IN'),
  DisplayCurrencyMeta(code: 'USD', symbol: '\$', label: 'US Dollar', locale: 'en_US'),
  DisplayCurrencyMeta(code: 'EUR', symbol: '€', label: 'Euro', locale: 'en_IE'),
  DisplayCurrencyMeta(code: 'GBP', symbol: '£', label: 'British Pound', locale: 'en_GB'),
  DisplayCurrencyMeta(code: 'AED', symbol: 'د.إ', label: 'UAE Dirham', locale: 'en_AE'),
  DisplayCurrencyMeta(code: 'JPY', symbol: '¥', label: 'Japanese Yen', locale: 'ja_JP'),
  DisplayCurrencyMeta(code: 'AUD', symbol: 'A\$', label: 'Australian Dollar', locale: 'en_AU'),
  DisplayCurrencyMeta(code: 'CAD', symbol: 'C\$', label: 'Canadian Dollar', locale: 'en_CA'),
  DisplayCurrencyMeta(code: 'SGD', symbol: 'S\$', label: 'Singapore Dollar', locale: 'en_SG'),
  DisplayCurrencyMeta(code: 'CHF', symbol: 'CHF', label: 'Swiss Franc', locale: 'de_CH'),
  DisplayCurrencyMeta(code: 'CNY', symbol: '¥', label: 'Chinese Yuan', locale: 'zh_CN'),
  DisplayCurrencyMeta(code: 'HKD', symbol: 'HK\$', label: 'Hong Kong Dollar', locale: 'zh_HK'),
];

/// Module-level active code so [formatMoney] works without BuildContext.
String _activeDisplayCurrencyCode = 'INR';

DisplayCurrencyMeta getCurrencyMeta(String? code) {
  if (code == null || code.isEmpty) return kDisplayCurrencies.first;
  for (final c in kDisplayCurrencies) {
    if (c.code == code) return c;
  }
  return kDisplayCurrencies.first;
}

DisplayCurrencyMeta get activeDisplayCurrency => getCurrencyMeta(_activeDisplayCurrencyCode);

String get activeDisplayCurrencyCode => activeDisplayCurrency.code;

String get activeDisplayCurrencySymbol => activeDisplayCurrency.symbol;

/// Call when prefs load or user picks a new currency in Profile.
void setActiveDisplayCurrency(String code) {
  _activeDisplayCurrencyCode = getCurrencyMeta(code).code;
}
