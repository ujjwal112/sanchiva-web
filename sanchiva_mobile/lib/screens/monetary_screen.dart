import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/finance_refresh.dart';
import '../core/shell_nav.dart';
import '../core/theme.dart';
import '../widgets/section_header_card.dart';
import 'assets_section.dart';
import 'income_section.dart';
import 'money_lent_section.dart';

/// Monetary areas (same set as web): live rates + personal money tracking.
enum _MonetaryArea {
  currency,
  metals,
  income,
  assets,
  lent,
}

/// Monetary — section header card (icon + title + subtitle) to switch areas.
class MonetaryScreen extends StatefulWidget {
  const MonetaryScreen({super.key});

  @override
  State<MonetaryScreen> createState() => _MonetaryScreenState();
}

class _MonetaryScreenState extends State<MonetaryScreen> {
  static const _brand = Color(0xFF5038F0);

  _MonetaryArea _area = _MonetaryArea.currency;
  int _subTab = 0;
  int _deepLinkToken = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.watch<ShellNav>();
    if (nav.deepLinkToken == _deepLinkToken) return;
    final areaKey = nav.pendingMonetaryArea;
    if (areaKey == null) return;
    final mapped = switch (areaKey) {
      'currency' => _MonetaryArea.currency,
      'metals' => _MonetaryArea.metals,
      'income' => _MonetaryArea.income,
      'assets' => _MonetaryArea.assets,
      'lent' => _MonetaryArea.lent,
      _ => null,
    };
    if (mapped == null) return;
    _deepLinkToken = nav.deepLinkToken;
    final sub = nav.pendingSubTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _area = mapped;
        _subTab = sub;
      });
      nav.clearMonetaryDeepLink();
      if (mapped == _MonetaryArea.income) {
        context.read<FinanceRefresh>().bump();
      }
    });
  }

  String get _areaTitle {
    switch (_area) {
      case _MonetaryArea.currency:
        return 'Live currency';
      case _MonetaryArea.metals:
        return 'Live metal';
      case _MonetaryArea.income:
        return 'Salary / Income';
      case _MonetaryArea.assets:
        return 'Other assets';
      case _MonetaryArea.lent:
        return 'Money lent';
    }
  }

  String get _areaSubtitle {
    switch (_area) {
      case _MonetaryArea.currency:
        return 'Exchange rates & converter';
      case _MonetaryArea.metals:
        return 'Gold, silver, platinum rates';
      case _MonetaryArea.income:
        return 'Track monthly income sources';
      case _MonetaryArea.assets:
        return 'Savings, holdings, valuables';
      case _MonetaryArea.lent:
        return 'Money given to people';
    }
  }

  IconData get _areaIcon {
    switch (_area) {
      case _MonetaryArea.currency:
        return Icons.currency_exchange_rounded;
      case _MonetaryArea.metals:
        return Icons.diamond_rounded;
      case _MonetaryArea.income:
        return Icons.account_balance_wallet_rounded;
      case _MonetaryArea.assets:
        return Icons.savings_rounded;
      case _MonetaryArea.lent:
        return Icons.handshake_rounded;
    }
  }

  Future<void> _showAreaMenu() async {
    final choice = await showModalBottomSheet<_MonetaryArea>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        final ink = AppColors.inkOf(ctx);
        final muted = AppColors.mutedOf(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Material(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Monetary',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a section',
                    style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  _menuTile(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Live currency',
                    subtitle: 'Exchange rates & converter',
                    ink: ink,
                    muted: muted,
                    selected: _area == _MonetaryArea.currency,
                    onTap: () => Navigator.pop(ctx, _MonetaryArea.currency),
                  ),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.diamond_rounded,
                    title: 'Live metal',
                    subtitle: 'Gold, silver, platinum rates',
                    ink: ink,
                    muted: muted,
                    selected: _area == _MonetaryArea.metals,
                    onTap: () => Navigator.pop(ctx, _MonetaryArea.metals),
                  ),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Salary / Income',
                    subtitle: 'Track monthly income sources',
                    ink: ink,
                    muted: muted,
                    selected: _area == _MonetaryArea.income,
                    onTap: () => Navigator.pop(ctx, _MonetaryArea.income),
                  ),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.savings_rounded,
                    title: 'Other assets',
                    subtitle: 'Savings, holdings, valuables',
                    ink: ink,
                    muted: muted,
                    selected: _area == _MonetaryArea.assets,
                    onTap: () => Navigator.pop(ctx, _MonetaryArea.assets),
                  ),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.handshake_rounded,
                    title: 'Money lent',
                    subtitle: 'Money given to people',
                    ink: ink,
                    muted: muted,
                    selected: _area == _MonetaryArea.lent,
                    onTap: () => Navigator.pop(ctx, _MonetaryArea.lent),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (choice != null && mounted) {
      setState(() {
        _area = choice;
        _subTab = 0;
      });
      // Opening Salary — pull latest daily spends + EMIs into charts.
      if (choice == _MonetaryArea.income) {
        context.read<FinanceRefresh>().bump();
      }
    }
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final isDark = AppColors.isDark(context);
    return Material(
      color: selected
          ? _brand.withValues(alpha: isDark ? 0.22 : 0.12)
          : AppColors.softPurpleOf(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: muted)),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: _brand, size: 22)
              else
                Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Section card (icon + title + subtitle) — tap to switch Monetary areas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SectionHeaderCard(
              icon: _areaIcon,
              title: _areaTitle,
              subtitle: _areaSubtitle,
              onTap: _showAreaMenu,
            ),
          ),
          Expanded(child: _buildBody(ink, muted)),
        ],
      ),
    );
  }

  Widget _buildBody(Color ink, Color muted) {
    switch (_area) {
      case _MonetaryArea.currency:
        return const _LiveCurrencyPanel();
      case _MonetaryArea.metals:
        return const _LiveMetalsPanel();
      case _MonetaryArea.income:
        return IncomeSection(
          key: ValueKey('income_$_deepLinkToken'),
          initialTab: _area == _MonetaryArea.income ? _subTab : 0,
        );
      case _MonetaryArea.assets:
        return AssetsSection(
          key: ValueKey('assets_$_deepLinkToken'),
          initialTab: _area == _MonetaryArea.assets ? _subTab : 0,
        );
      case _MonetaryArea.lent:
        return MoneyLentSection(
          key: ValueKey('lent_$_deepLinkToken'),
          initialTab: _area == _MonetaryArea.lent ? _subTab : 0,
        );
    }
  }

  Widget _placeholderBody({
    required Color ink,
    required Color muted,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: AppColors.isDark(context) ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: _brand, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap the header above to switch sections',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _brand),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

// ─── Shared live panel toolbar (currency + metals) ───────────────────────────

/// Convert/Rates control + refresh meta (section title lives in SectionHeaderCard).
class _LivePanelHeader extends StatelessWidget {
  const _LivePanelHeader({
    required this.hint,
    required this.convertSelected,
    required this.onConvert,
    required this.onRates,
    required this.loading,
    required this.onRefresh,
    this.updatedTime,
    this.dateLabel,
  });

  final String hint;
  final bool convertSelected;
  final VoidCallback onConvert;
  final VoidCallback onRates;
  final bool loading;
  final VoidCallback onRefresh;
  final String? updatedTime;
  final String? dateLabel;

  static const _brand = Color(0xFF5038F0);

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.cardOf(context),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: GoogleFonts.inter(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // Segmented Convert | Rates
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.25) : AppColors.softPurpleOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segBtn(
                    label: 'Convert',
                    icon: Icons.swap_horiz_rounded,
                    selected: convertSelected,
                    onTap: onConvert,
                    muted: muted,
                  ),
                ),
                Expanded(
                  child: _segBtn(
                    label: 'Rates',
                    icon: Icons.list_alt_rounded,
                    selected: !convertSelected,
                    onTap: onRates,
                    muted: muted,
                  ),
                ),
              ],
            ),
          ),
          if (updatedTime != null || dateLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (updatedTime != null)
                        Text(
                          updatedTime!,
                          style: GoogleFonts.inter(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
                        ),
                      if (dateLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateLabel!,
                          style: GoogleFonts.inter(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                Material(
                  color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: loading ? null : onRefresh,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (loading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
                            )
                          else
                            const Icon(Icons.refresh_rounded, size: 16, color: _brand),
                          const SizedBox(width: 6),
                          Text(
                            loading ? 'Updating…' : 'Refresh',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _segBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color muted,
  }) {
    return Material(
      color: selected ? _brand : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? Colors.white : muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected ? Colors.white : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Live currency (web parity: rates board + converter) ─────────────────────

enum _FxMode { rates, convert }

const _kBoardCodes = <String>[
  'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'SGD', 'CHF',
  'CNY', 'HKD', 'NZD', 'THB', 'MYR', 'KRW', 'IDR', 'AED',
];

const _kPopular = <String>['INR', ..._kBoardCodes];

const _kSymbols = <String, String>{
  'INR': '₹',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'AUD': 'A\$',
  'CAD': 'C\$',
  'SGD': 'S\$',
  'CHF': 'CHF',
  'CNY': '¥',
  'HKD': 'HK\$',
  'NZD': 'NZ\$',
  'THB': '฿',
  'MYR': 'RM',
  'KRW': '₩',
  'IDR': 'Rp',
  'AED': 'د.إ',
};

const _kNames = <String, String>{
  'USD': 'US Dollar',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'JPY': 'Japanese Yen',
  'AUD': 'Australian Dollar',
  'CAD': 'Canadian Dollar',
  'SGD': 'Singapore Dollar',
  'CHF': 'Swiss Franc',
  'CNY': 'Chinese Yuan',
  'HKD': 'Hong Kong Dollar',
  'NZD': 'New Zealand Dollar',
  'THB': 'Thai Baht',
  'MYR': 'Malaysian Ringgit',
  'KRW': 'South Korean Won',
  'IDR': 'Indonesian Rupiah',
  'AED': 'UAE Dirham',
  'INR': 'Indian Rupee',
};

String _formatRate(double n) {
  if (n >= 100) return n.toStringAsFixed(2);
  if (n >= 1) return n.toStringAsFixed(4);
  return n.toStringAsFixed(6);
}

String _formatMoney(double? n, String code) {
  if (n == null) return '—';
  final sym = _kSymbols[code] ?? code;
  final digits = n >= 100 ? 2 : (n >= 1 ? 2 : 4);
  return '$sym ${NumberFormat('#,##0.${'0' * digits}').format(n)}';
}

/// Always English 3-letter months (Aug, Jul, Jun…) — never locale “Au” or digits.
const _kMonthAbbr = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _labelFromDateTime(DateTime d) {
  return '${d.year}-${_kMonthAbbr[d.month - 1]}-${d.day.toString().padLeft(2, '0')}';
}

/// Reformats API date → `2026-Aug-07`. Falls back to today if API date is bad
/// (e.g. truncated HTTP string `"Sat, 08 Au"` from server bug).
String _formatFxDate(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isNotEmpty) {
    // yyyy-mm-dd or yyyy/mm/dd
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (m != null) {
      final year = int.tryParse(m.group(1)!) ?? 0;
      final month = int.tryParse(m.group(2)!) ?? 0;
      final day = int.tryParse(m.group(3)!) ?? 0;
      if (year >= 2000 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return '$year-${_kMonthAbbr[month - 1]}-${day.toString().padLeft(2, '0')}';
      }
    }

    // Full HTTP date e.g. "Sat, 08 Aug 2026 00:00:00 +0000"
    final http = RegExp(
      r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(s);
    if (http != null) {
      final day = int.tryParse(http.group(1)!) ?? 0;
      final monName = http.group(2)!;
      final year = int.tryParse(http.group(3)!) ?? 0;
      final monthIdx = _kMonthAbbr.indexWhere(
        (x) => monName.toLowerCase().startsWith(x.toLowerCase()),
      );
      if (year >= 2000 && day >= 1 && day <= 31 && monthIdx >= 0) {
        return '$year-${_kMonthAbbr[monthIdx]}-${day.toString().padLeft(2, '0')}';
      }
    }

    try {
      return _labelFromDateTime(DateTime.parse(s));
    } catch (_) {
      // Truncated junk like "Sat, 08 Au" — ignore
    }
  }
  // Always show a readable date when rates are loaded
  return _labelFromDateTime(DateTime.now());
}

class _LiveCurrencyPanel extends StatefulWidget {
  const _LiveCurrencyPanel();

  @override
  State<_LiveCurrencyPanel> createState() => _LiveCurrencyPanelState();
}

class _LiveCurrencyPanelState extends State<_LiveCurrencyPanel> {
  static const _brand = Color(0xFF5038F0);

  _FxMode _mode = _FxMode.convert;
  Map<String, double>? _inrRates; // CODE per 1 INR
  /// Pre-formatted display date, e.g. `2026-Aug-07` (never raw API `2026-08-07`).
  String? _dateLabel;
  DateTime? _updatedAt;
  bool _loading = true;
  String? _error;

  final _amountCtrl = TextEditingController(text: '1000');
  String _from = 'INR';
  String _to = 'USD';

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.instance.get('/fx/latest?from=INR');
      final raw = data['rates'];
      final map = <String, double>{'INR': 1};
      if (raw is Map) {
        raw.forEach((k, v) {
          final n = double.tryParse('$v');
          if (n != null && n > 0) map[k.toString().toUpperCase()] = n;
        });
      }
      if (!mounted) return;
      // Reform any API date (or bad truncated strings) → always 2026-Aug-07 style
      final formatted = _formatFxDate(data['date']?.toString());
      setState(() {
        _inrRates = map;
        _dateLabel = formatted;
        _updatedAt = DateTime.now();
        _loading = false;
        if (_from != 'INR' && map[_from] == null) _from = 'INR';
        if (_to != 'INR' && map[_to] == null) {
          _to = map['USD'] != null ? 'USD' : map.keys.firstWhere((k) => k != 'INR', orElse: () => 'USD');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  /// rates[CODE] = units of CODE per 1 INR → cross rate FROM → TO
  double? _crossRate(String from, String to) {
    final rates = _inrRates;
    if (rates == null) return null;
    if (from == to) return 1;
    final fromPerInr = from == 'INR' ? 1.0 : rates[from];
    final toPerInr = to == 'INR' ? 1.0 : rates[to];
    if (fromPerInr == null || toPerInr == null || fromPerInr == 0) return null;
    return toPerInr / fromPerInr;
  }

  List<String> get _currencyCodes {
    final rates = _inrRates;
    if (rates == null) return List.from(_kPopular);
    final preferred = _kPopular.where(rates.containsKey).toList();
    final rest = rates.keys.where((c) => !preferred.contains(c)).toList()..sort();
    return [...preferred, ...rest];
  }

  List<({String code, String name, String symbol, double inrPerUnit})> get _boardRows {
    final rates = _inrRates;
    if (rates == null) return [];
    return _kBoardCodes
        .where((c) => rates[c] != null && rates[c]! > 0)
        .map((code) {
          final perInr = rates[code]!;
          return (
            code: code,
            name: _kNames[code] ?? code,
            symbol: _kSymbols[code] ?? code,
            inrPerUnit: 1 / perInr,
          );
        })
        .toList();
  }

  Future<void> _pickCurrency({required bool isFrom}) async {
    final codes = _currencyCodes;
    final selected = isFrom ? _from : _to;
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        final ink = AppColors.inkOf(ctx);
        final muted = AppColors.mutedOf(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      isFrom ? 'From currency' : 'To currency',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: codes.length,
                      itemBuilder: (_, i) {
                        final code = codes[i];
                        final sel = code == selected;
                        return ListTile(
                          leading: Text(
                            _kSymbols[code] ?? code,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _brand, fontSize: 16),
                          ),
                          title: Text(
                            code,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                          ),
                          subtitle: Text(
                            _kNames[code] ?? code,
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                          trailing: sel ? const Icon(Icons.check_circle_rounded, color: _brand) : null,
                          onTap: () => Navigator.pop(ctx, code),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (v != null && mounted) {
      setState(() {
        if (isFrom) {
          _from = v;
        } else {
          _to = v;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);

    final amountNum = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final unitRate = _crossRate(_from, _to);
    final converted = unitRate != null ? amountNum * unitRate : null;

    return RefreshIndicator(
      onRefresh: _fetchRates,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _LivePanelHeader(
            hint: _mode == _FxMode.rates
                ? '1 foreign unit in Indian Rupees'
                : 'Convert between currencies',
            convertSelected: _mode == _FxMode.convert,
            onConvert: () => setState(() => _mode = _FxMode.convert),
            onRates: () => setState(() => _mode = _FxMode.rates),
            loading: _loading,
            onRefresh: _fetchRates,
            updatedTime: _updatedAt == null ? null : 'Updated ${DateFormat('HH:mm').format(_updatedAt!)}',
            dateLabel: _dateLabel == null ? null : 'As of $_dateLabel',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_mode == _FxMode.rates)
            _ratesBoard(ink, muted, isDark)
          else
            _converterCard(ink, muted, isDark, unitRate, converted),
        ],
      ),
    );
  }

  Widget _ratesBoard(Color ink, Color muted, bool isDark) {
    final rows = _boardRows;
    if (_loading && rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('No rates available', style: GoogleFonts.inter(color: muted)),
        ),
      );
    }
    return Column(
      children: rows.map((row) {
        final active = row.code == _from || row.code == _to;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: active
                ? _brand.withValues(alpha: isDark ? 0.2 : 0.1)
                : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _from = 'INR';
                  _to = row.code;
                  _mode = _FxMode.convert;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? _brand.withValues(alpha: 0.35) : AppColors.borderOf(context),
                  ),
                  boxShadow: active ? null : AppColors.cardShadow(context),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        row.symbol,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _brand, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.code,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
                          ),
                          Text(
                            row.name,
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹ ${_formatRate(row.inrPerUnit)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
                        ),
                        Text(
                          'per 1 ${row.code}',
                          style: GoogleFonts.inter(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _converterCard(
    Color ink,
    Color muted,
    bool isDark,
    double? unitRate,
    double? converted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Converter',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
          ),
          const SizedBox(height: 12),
          Text('Amount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '0.00',
              filled: true,
              fillColor: AppColors.softPurpleOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _brand, width: 1.4),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: ink),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _currencyPickerField(label: 'From', code: _from, ink: ink, muted: muted, onTap: () => _pickCurrency(isFrom: true))),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 18, 6, 0),
                child: Material(
                  color: _brand.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      final t = _from;
                      _from = _to;
                      _to = t;
                    }),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.swap_horiz_rounded, color: _brand),
                    ),
                  ),
                ),
              ),
              Expanded(child: _currencyPickerField(label: 'To', code: _to, ink: ink, muted: muted, onTap: () => _pickCurrency(isFrom: false))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_brand, Color(0xFF7A40F8)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Converted amount',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loading && _inrRates == null
                      ? 'Loading rates…'
                      : _formatMoney(converted, _to),
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                if (unitRate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '1 $_from = ${_formatRate(unitRate)} $_to',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_dateLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'As of $_dateLabel',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Quick picks',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              ('INR', 'USD'),
              ('USD', 'INR'),
              ('EUR', 'INR'),
              ('GBP', 'INR'),
              ('USD', 'EUR'),
            ].map((pair) {
              final a = pair.$1;
              final b = pair.$2;
              final active = _from == a && _to == b;
              return Material(
                color: active ? _brand : AppColors.softPurpleOf(context),
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => setState(() {
                    _from = a;
                    _to = b;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      '$a → $b',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : ink,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _currencyPickerField({
    required String label,
    required String code,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
        const SizedBox(height: 6),
        Material(
          color: AppColors.softPurpleOf(context),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  Text(
                    _kSymbols[code] ?? code,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _brand, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      code,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 18, color: muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Live metals (web parity: converter + rates, converter first) ────────────

enum _MetalMode { convert, rates }

const _kMetalKeys = <String>['gold', 'silver', 'platinum', 'palladium', 'copper'];
const _kMetalLabels = <String, String>{
  'gold': 'Gold',
  'silver': 'Silver',
  'platinum': 'Platinum',
  'palladium': 'Palladium',
  'copper': 'Copper',
};
const _kMetalSymbols = <String, String>{
  'gold': 'Au',
  'silver': 'Ag',
  'platinum': 'Pt',
  'palladium': 'Pd',
  'copper': 'Cu',
};
const _kMetalColors = <String, Color>{
  'gold': Color(0xFFF59E0B),
  'silver': Color(0xFF94A3B8),
  'platinum': Color(0xFF64748B),
  'palladium': Color(0xFF78716C),
  'copper': Color(0xFFEA580C),
};

const _kTolaGrams = 11.6638038;
const _kTroyOzGrams = 31.1034768;

String _formatInr(double? n) {
  if (n == null) return '—';
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(n);
}

String _formatUsd(double? n) {
  if (n == null) return '—';
  return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2).format(n);
}

String _formatLocal(double? n, String currency) {
  if (n == null) return '—';
  if (currency == 'INR') return _formatInr(n);
  try {
    return NumberFormat.simpleCurrency(
      name: currency,
      decimalDigits: currency == 'JPY' ? 0 : 2,
    ).format(n);
  } catch (_) {
    return '${NumberFormat('#,##0.00').format(n)} $currency';
  }
}

IconData _purityIcon(String p) {
  return switch (p) {
    'k24' => Icons.stars_rounded,
    'k22' => Icons.star_rounded,
    'k18' => Icons.star_half_rounded,
    'k14' => Icons.star_outline_rounded,
    _ => Icons.diamond_outlined,
  };
}

/// Periodic symbol badge (Au, Ag, Pt…) — always keeps the metal’s own color
/// (never flips to white/purple when selected).
Widget _metalSymbolBadge(
  String key, {
  required bool isDark,
  double size = 40,
  double fontSize = 13,
  bool emphasize = false,
}) {
  final color = _kMetalColors[key] ?? const Color(0xFF5038F0);
  final sym = _kMetalSymbols[key] ?? '?';
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: isDark ? (emphasize ? 0.35 : 0.28) : (emphasize ? 0.22 : 0.15)),
      borderRadius: BorderRadius.circular(size >= 40 ? 12 : 10),
      border: Border.all(
        color: color.withValues(alpha: emphasize ? 0.65 : 0.35),
        width: emphasize ? 1.5 : 1,
      ),
    ),
    child: Text(
      sym,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        color: color,
        letterSpacing: 0.2,
      ),
    ),
  );
}

double _goldPurityFactor(String purity) {
  return switch (purity) {
    'k24' => 1.0,
    'k22' => 22 / 24,
    'k18' => 18 / 24,
    'k14' => 14 / 24,
    _ => 22 / 24,
  };
}

/// ISO country code → flag emoji (IN → 🇮🇳). EU uses the EU flag.
String _countryFlagEmoji(String? code) {
  if (code == null || code.isEmpty) return '🏳️';
  final c = code.trim().toUpperCase();
  if (c == 'EU') return '🇪🇺';
  if (c.length != 2) return '🏳️';
  final a = c.codeUnitAt(0);
  final b = c.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return '🏳️';
  // Regional Indicator Symbol Letter A = U+1F1E6
  return String.fromCharCodes([0x1F1E6 + (a - 0x41), 0x1F1E6 + (b - 0x41)]);
}

Widget _flagBadge(String? countryCode, {double size = 42, bool isDark = false}) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F0FF),
      borderRadius: BorderRadius.circular(size >= 40 ? 12 : 10),
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
      ),
    ),
    child: Text(
      _countryFlagEmoji(countryCode),
      style: TextStyle(fontSize: size * 0.48, height: 1.1),
    ),
  );
}

class _LiveMetalsPanel extends StatefulWidget {
  const _LiveMetalsPanel();

  @override
  State<_LiveMetalsPanel> createState() => _LiveMetalsPanelState();
}

class _LiveMetalsPanelState extends State<_LiveMetalsPanel> {
  static const _brand = Color(0xFF5038F0);

  _MetalMode _mode = _MetalMode.convert;
  Map<String, dynamic>? _payload;
  String? _dateLabel;
  DateTime? _updatedAt;
  bool _loading = true;
  String? _error;

  String _metal = 'gold';
  String _purity = 'k22'; // gold only
  final _amountCtrl = TextEditingController(text: '10');
  String _unit = 'gram'; // gram | 10g | oz | tola
  /// Location type for convert + rates (same as web).
  String _locationType = 'india'; // india | countries
  String _city = 'Mumbai';
  String _countryCode = 'IN';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.instance.get('/metals/latest');
      if (!mounted) return;
      final metals = data['metals'];
      if (metals is! Map || metals.isEmpty) {
        throw Exception('Metal prices response was empty');
      }
      String? rawDate;
      if (metals['gold'] is Map) {
        rawDate = metals['gold']['updatedAt']?.toString();
      }
      rawDate ??= data['fetchedAt']?.toString();
      setState(() {
        _payload = data;
        _dateLabel = _formatFxDate(rawDate);
        _updatedAt = DateTime.now();
        _loading = false;
        if (data['warning'] != null) {
          _error = data['warning'].toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Map<String, dynamic>? get _metalData {
    final metals = _payload?['metals'];
    if (metals is! Map) return null;
    final m = metals[_metal];
    if (m is Map) return Map<String, dynamic>.from(m);
    return null;
  }

  List<Map<String, dynamic>> get _cities {
    final list = _metalData?['cities'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> get _countries {
    final list = _metalData?['countries'];
    if (list is! List) return const [];
    final rows = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    // India always first in country picker / rates list
    rows.sort((a, b) {
      final ac = a['code']?.toString() ?? '';
      final bc = b['code']?.toString() ?? '';
      if (ac == 'IN' && bc != 'IN') return -1;
      if (bc == 'IN' && ac != 'IN') return 1;
      return (a['country']?.toString() ?? '').compareTo(b['country']?.toString() ?? '');
    });
    return rows;
  }

  Map<String, dynamic>? get _selectedCity {
    final list = _cities;
    if (list.isEmpty) return null;
    for (final c in list) {
      if (c['city']?.toString() == _city) return c;
    }
    return list.first;
  }

  Map<String, dynamic>? get _selectedCountry {
    final list = _countries;
    if (list.isEmpty) return null;
    for (final c in list) {
      if (c['code']?.toString() == _countryCode) return c;
    }
    for (final c in list) {
      if (c['code']?.toString() == 'IN') return c;
    }
    return list.first;
  }

  bool get _isCountryMode => _locationType == 'countries';

  String get _displayCurrency {
    if (!_isCountryMode) return 'INR';
    return _selectedCountry?['currency']?.toString() ?? 'INR';
  }

  String get _locationLabel {
    if (_isCountryMode) {
      final c = _selectedCountry;
      return c == null ? 'Country' : '${c['country']} (${c['currency']})';
    }
    final city = _selectedCity;
    return city == null ? 'India' : '${city['city']}, ${city['state']}';
  }

  /// Price per gram in display currency at selected purity + location.
  double? get _pricePerGramDisplay {
    final m = _metalData;
    if (m == null) return null;
    final pf = _metal == 'gold' ? _goldPurityFactor(_purity) : 1.0;

    if (_isCountryMode) {
      final country = _selectedCountry;
      if (country == null) return null;
      // Board rows are 22K for gold / fine for others
      final local22 = double.tryParse('${country['perGramLocal']}') ?? 0;
      if (local22 <= 0) return null;
      if (_metal == 'gold') {
        return local22 / (22 / 24) * pf;
      }
      return local22;
    }

    // India city mode — INR
    final city = _selectedCity;
    if (_metal == 'gold') {
      final city22 = double.tryParse('${city?['perGramInr']}') ?? 0;
      if (city22 > 0) return city22 / (22 / 24) * pf;
      final pure = double.tryParse('${m['purePerGramInr']}') ?? 0;
      return pure > 0 ? pure * pf : null;
    }
    final cityPg = double.tryParse('${city?['perGramInr']}');
    if (cityPg != null && cityPg > 0) return cityPg;
    return double.tryParse('${m['purePerGramInr']}');
  }

  /// Always INR for secondary line when converting foreign.
  double? get _pricePerGramInr {
    final m = _metalData;
    if (m == null) return null;
    final pf = _metal == 'gold' ? _goldPurityFactor(_purity) : 1.0;

    if (_isCountryMode) {
      final country = _selectedCountry;
      final inr22 = double.tryParse('${country?['perGramInr']}') ?? 0;
      if (inr22 <= 0) return null;
      if (_metal == 'gold') return inr22 / (22 / 24) * pf;
      return inr22;
    }

    final city = _selectedCity;
    if (_metal == 'gold') {
      final city22 = double.tryParse('${city?['perGramInr']}') ?? 0;
      if (city22 > 0) return city22 / (22 / 24) * pf;
      final pure = double.tryParse('${m['purePerGramInr']}') ?? 0;
      return pure > 0 ? pure * pf : null;
    }
    final cityPg = double.tryParse('${city?['perGramInr']}');
    if (cityPg != null && cityPg > 0) return cityPg;
    return double.tryParse('${m['purePerGramInr']}');
  }

  double? get _grams {
    final n = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (n == null || n < 0) return null;
    return switch (_unit) {
      'oz' => n * _kTroyOzGrams,
      '10g' => n * 10,
      'tola' => n * _kTolaGrams,
      _ => n,
    };
  }

  double? get _convertedDisplay {
    final g = _grams;
    final p = _pricePerGramDisplay;
    if (g == null || p == null) return null;
    return g * p;
  }

  double? get _convertedInr {
    final g = _grams;
    final p = _pricePerGramInr;
    if (g == null || p == null) return null;
    return g * p;
  }

  Widget _locationTypeToggle(Color ink, Color muted) {
    return Row(
      children: [
        Expanded(
          child: _locChip(
            label: 'Country',
            icon: Icons.public_rounded,
            selected: _locationType == 'countries',
            onTap: () => setState(() => _locationType = 'countries'),
            ink: ink,
            muted: muted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _locChip(
            label: 'India states',
            icon: Icons.location_city_rounded,
            selected: _locationType == 'india',
            onTap: () => setState(() => _locationType = 'india'),
            ink: ink,
            muted: muted,
          ),
        ),
      ],
    );
  }

  Widget _locChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color ink,
    required Color muted,
  }) {
    final isDark = AppColors.isDark(context);
    return Material(
      color: selected ? _brand : AppColors.softPurpleOf(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : _brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRich({
    required String title,
    required List<
        ({
          String value,
          String label,
          String? subtitle,
          IconData? icon,
          String? metalKey, // if set → show Au/Ag symbol instead of icon
          String? countryCode, // if set → show country flag emoji
          Color? color,
        })> options,
    required String selected,
    required ValueChanged<String> onPick,
  }) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        final ink = AppColors.inkOf(ctx);
        final muted = AppColors.mutedOf(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final o = options[i];
                        final sel = o.value == selected;
                        final c = o.color ?? _brand;
                        final Widget leading;
                        if (o.metalKey != null) {
                          // Always keep Au/Ag/… metal color — do not recolor on select
                          leading = _metalSymbolBadge(
                            o.metalKey!,
                            isDark: isDark,
                            size: 42,
                            fontSize: 14,
                            emphasize: sel,
                          );
                        } else if (o.countryCode != null) {
                          leading = _flagBadge(o.countryCode, size: 42, isDark: isDark);
                        } else {
                          leading = Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: isDark ? 0.28 : 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(o.icon ?? Icons.circle, color: c, size: 22),
                          );
                        }
                        // Selected row: soft tint of metal/item color (not purple override for metals)
                        final rowBg = sel
                            ? c.withValues(alpha: isDark ? 0.22 : 0.12)
                            : AppColors.softPurpleOf(ctx);
                        return Material(
                          color: rowBg,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, o.value),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: sel
                                    ? Border.all(color: c.withValues(alpha: 0.45), width: 1.2)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  leading,
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          o.label,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink),
                                        ),
                                        if (o.subtitle != null)
                                          Text(
                                            o.subtitle!,
                                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (sel)
                                    Icon(Icons.check_circle_rounded, color: c, size: 22)
                                  else
                                    Icon(Icons.chevron_right_rounded, color: muted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (v != null && mounted) onPick(v);
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final m = _metalData;
    final quoteLabel = m?['quoteUnitLabel']?.toString() ?? 'oz';
    final usdSpot = double.tryParse('${m?['usdSpot'] ?? m?['usdPerOz'] ?? m?['usdPerLb']}');
    final perG = _pricePerGramDisplay;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _LivePanelHeader(
            hint: _mode == _MetalMode.rates
                ? (_locationType == 'india'
                    ? 'India state rates · ${_kMetalLabels[_metal] ?? _metal}'
                    : 'Country rates · ${_kMetalLabels[_metal] ?? _metal}')
                : 'Convert metal weight to value',
            convertSelected: _mode == _MetalMode.convert,
            onConvert: () => setState(() => _mode = _MetalMode.convert),
            onRates: () => setState(() => _mode = _MetalMode.rates),
            loading: _loading,
            onRefresh: _fetch,
            updatedTime: _updatedAt == null ? null : 'Updated ${DateFormat('HH:mm').format(_updatedAt!)}',
            dateLabel: _dateLabel == null ? null : 'As of $_dateLabel',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_mode == _MetalMode.rates)
            _ratesBoard(ink, muted, isDark)
          else
            _converter(ink, muted, isDark, quoteLabel, usdSpot, perG),
        ],
      ),
    );
  }

  Widget _metalChipBar(Color ink, Color muted) {
    final isDark = AppColors.isDark(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kMetalKeys.map((key) {
          final sel = key == _metal;
          final color = _kMetalColors[key] ?? _brand;
          final sym = _kMetalSymbols[key] ?? '';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              // Soft metal tint when selected — symbol color stays the metal color
              color: sel
                  ? color.withValues(alpha: isDark ? 0.28 : 0.16)
                  : AppColors.softPurpleOf(context),
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => setState(() {
                  _metal = key;
                  if (key != 'gold' && _unit == 'tola') _unit = 'gram';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: sel ? color.withValues(alpha: 0.55) : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Au / Ag / … always in metal color
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.3 : 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          sym,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _kMetalLabels[key] ?? key,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? color : ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _ratesBoard(Color ink, Color muted, bool isDark) {
    if (_loading && _payload == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final carat = _metal == 'gold' ? '22K' : 'Fine';
    final rows = _isCountryMode ? _countries : _cities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters card — metal chips + location type
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.list_alt_rounded, color: _brand, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live rates',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                        ),
                        Text(
                          '${_kMetalLabels[_metal] ?? _metal} · $carat',
                          style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Metal',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
              ),
              const SizedBox(height: 8),
              _metalChipBar(ink, muted),
              const SizedBox(height: 14),
              Text(
                'Location type',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
              ),
              const SizedBox(height: 8),
              _locationTypeToggle(ink, muted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No rates available', style: GoogleFonts.inter(color: muted))),
          )
        else
          ...rows.map((row) {
            if (_isCountryMode) {
              final code = row['code']?.toString() ?? '';
              final active = code == _countryCode;
              final currency = row['currency']?.toString() ?? '';
              final local = double.tryParse('${row['perGramLocal']}');
              final inr = double.tryParse('${row['perGramInr']}');
              return _rateRow(
                ink: ink,
                muted: muted,
                isDark: isDark,
                active: active,
                badge: code,
                flagEmoji: _countryFlagEmoji(code),
                title: row['country']?.toString() ?? code,
                subtitle: currency,
                primary: currency == 'INR' ? _formatInr(inr) : _formatLocal(local, currency),
                secondary: currency != 'INR' ? '${_formatInr(inr)} · $carat' : '/ g · $carat',
                onTap: () => setState(() {
                  _countryCode = code;
                  _locationType = 'countries';
                  _mode = _MetalMode.convert;
                }),
              );
            }
            final city = row['city']?.toString() ?? '';
            final state = row['state']?.toString() ?? '';
            final active = city == _city;
            final inr = double.tryParse('${row['perGramInr']}');
            final initials = city.length >= 2 ? city.substring(0, 2).toUpperCase() : city;
            return _rateRow(
              ink: ink,
              muted: muted,
              isDark: isDark,
              active: active,
              badge: initials,
              title: city,
              subtitle: state,
              primary: _formatInr(inr),
              secondary: '/ g · $carat',
              onTap: () => setState(() {
                _city = city;
                _locationType = 'india';
                _mode = _MetalMode.convert;
              }),
            );
          }),
        const SizedBox(height: 8),
        Text(
          'Tap a location to convert. Rates are indicative (spot + typical premium).',
          style: GoogleFonts.inter(fontSize: 11.5, color: muted),
        ),
      ],
    );
  }

  Widget _rateRow({
    required Color ink,
    required Color muted,
    required bool isDark,
    required bool active,
    required String badge,
    String? flagEmoji,
    required String title,
    required String subtitle,
    required String primary,
    required String secondary,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? _brand.withValues(alpha: isDark ? 0.2 : 0.1) : AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? _brand.withValues(alpha: 0.35) : AppColors.borderOf(context),
              ),
              boxShadow: active ? null : AppColors.cardShadow(context),
            ),
            child: Row(
              children: [
                if (flagEmoji != null)
                  _flagBadge(badge, size: 40, isDark: isDark)
                else
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.length > 3 ? badge.substring(0, 3) : badge,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _brand, fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink)),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(primary, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ink)),
                    Text(secondary, style: GoogleFonts.inter(fontSize: 11, color: muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _converter(
    Color ink,
    Color muted,
    bool isDark,
    String quoteLabel,
    double? usdSpot,
    double? perG,
  ) {
    final purityLabel = switch (_purity) {
      'k24' => '24K (pure)',
      'k22' => '22K',
      'k18' => '18K',
      'k14' => '14K',
      _ => _purity,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Converter',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
          ),
          const SizedBox(height: 12),
          // Metal picker — periodic symbol (Au, Ag…) not Material icons
          _metalSelectField(
            label: 'Metal',
            metalKey: _metal,
            value: '${_kMetalLabels[_metal] ?? _metal} (${_kMetalSymbols[_metal] ?? ''})',
            subtitle: 'Live international spot',
            ink: ink,
            muted: muted,
            onTap: () => _pickRich(
              title: 'Choose metal',
              selected: _metal,
              options: _kMetalKeys
                  .map(
                    (k) => (
                      value: k,
                      label: '${_kMetalLabels[k]} (${_kMetalSymbols[k]})',
                      subtitle: k == 'gold' ? 'With purity options' : 'Fine metal',
                      icon: null,
                      metalKey: k,
                      countryCode: null,
                      color: _kMetalColors[k],
                    ),
                  )
                  .toList(),
              onPick: (v) => setState(() {
                _metal = v;
                if (v != 'gold' && _unit == 'tola') _unit = 'gram';
              }),
            ),
          ),
          if (_metal == 'gold') ...[
            const SizedBox(height: 12),
            _iconSelectField(
              label: 'Purity',
              value: purityLabel,
              subtitle: 'Jewellery carat',
              icon: _purityIcon(_purity),
              iconColor: const Color(0xFFF59E0B),
              ink: ink,
              muted: muted,
              onTap: () => _pickRich(
                title: 'Gold purity',
                selected: _purity,
                options: [
                  (value: 'k24', label: '24K (pure)', subtitle: '99.9% fine gold', icon: _purityIcon('k24'), metalKey: null, countryCode: null, color: const Color(0xFFF59E0B)),
                  (value: 'k22', label: '22K', subtitle: 'Common jewellery grade', icon: _purityIcon('k22'), metalKey: null, countryCode: null, color: const Color(0xFFFBBF24)),
                  (value: 'k18', label: '18K', subtitle: '75% gold alloy', icon: _purityIcon('k18'), metalKey: null, countryCode: null, color: const Color(0xFFFCD34D)),
                  (value: 'k14', label: '14K', subtitle: '58.3% gold alloy', icon: _purityIcon('k14'), metalKey: null, countryCode: null, color: const Color(0xFFFDE68A)),
                ],
                onPick: (v) => setState(() => _purity = v),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Amount + Unit — same height, equal width (compact unit, no large icon)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '0',
                          filled: true,
                          fillColor: AppColors.softPurpleOf(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.borderOf(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.borderOf(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _brand, width: 1.4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                    const SizedBox(height: 6),
                    Material(
                      color: AppColors.softPurpleOf(context),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _pickRich(
                          title: 'Unit',
                          selected: _unit,
                          options: [
                            (value: 'gram', label: 'Gram (g)', subtitle: 'Per gram', icon: Icons.scale_rounded, metalKey: null, countryCode: null, color: _brand),
                            (value: '10g', label: '10 grams', subtitle: '× 10', icon: Icons.layers_rounded, metalKey: null, countryCode: null, color: _brand),
                            (value: 'oz', label: 'Troy ounce', subtitle: '≈ 31.1 g', icon: Icons.change_history_rounded, metalKey: null, countryCode: null, color: _brand),
                            if (_metal == 'gold')
                              (value: 'tola', label: 'Tola', subtitle: '≈ 11.66 g', icon: Icons.auto_awesome_rounded, metalKey: null, countryCode: null, color: _brand),
                          ],
                          onPick: (v) => setState(() => _unit = v),
                        ),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  switch (_unit) {
                                    'gram' => 'Gram (g)',
                                    '10g' => '10 grams',
                                    'oz' => 'Troy oz',
                                    'tola' => 'Tola',
                                    _ => _unit,
                                  },
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: ink),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.expand_more_rounded, size: 20, color: muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Location type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
          const SizedBox(height: 6),
          _locationTypeToggle(ink, muted),
          const SizedBox(height: 12),
          if (_isCountryMode)
            _countrySelectField(
              label: 'Country',
              countryCode: _selectedCountry?['code']?.toString() ?? _countryCode,
              value: _selectedCountry == null
                  ? 'Select country'
                  : '${_selectedCountry!['country']} (${_selectedCountry!['currency']})',
              subtitle: 'Local currency rate',
              ink: ink,
              muted: muted,
              onTap: () {
                final opts = _countries
                    .map(
                      (c) => (
                        value: c['code']!.toString(),
                        label: '${c['country']} (${c['currency']})',
                        subtitle: c['carat']?.toString(),
                        icon: null,
                        metalKey: null,
                        countryCode: c['code']?.toString(),
                        color: _brand,
                      ),
                    )
                    .toList();
                if (opts.isEmpty) return;
                _pickRich(
                  title: 'Country',
                  selected: _countryCode,
                  options: opts,
                  onPick: (v) => setState(() => _countryCode = v),
                );
              },
            )
          else
            _iconSelectField(
              label: 'City / state',
              value: _locationLabel,
              subtitle: 'India retail premium',
              icon: Icons.location_city_rounded,
              iconColor: _brand,
              ink: ink,
              muted: muted,
              onTap: () {
                final opts = _cities
                    .map(
                      (c) => (
                        value: c['city']!.toString(),
                        label: '${c['city']}, ${c['state']}',
                        subtitle: c['carat']?.toString(),
                        icon: Icons.place_rounded,
                        metalKey: null,
                        countryCode: null,
                        color: _brand,
                      ),
                    )
                    .toList();
                if (opts.isEmpty) return;
                _pickRich(
                  title: 'City / state',
                  selected: _city,
                  options: opts,
                  onPick: (v) => setState(() => _city = v),
                );
              },
            ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_brand, Color(0xFF7A40F8)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated value · $_locationLabel',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loading && _payload == null
                      ? 'Loading prices…'
                      : _formatLocal(_convertedDisplay, _displayCurrency),
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                if (_isCountryMode && _displayCurrency != 'INR' && _convertedInr != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '≈ ${_formatInr(_convertedInr)} INR',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (perG != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Spot: ${_formatUsd(usdSpot)} / $quoteLabel · ${_formatLocal(perG, _displayCurrency)} / g',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (_dateLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'As of $_dateLabel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (perG != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _spotChip(muted, ink, '${_displayCurrency == 'INR' ? '₹' : _displayCurrency} / g', _formatLocal(perG, _displayCurrency)),
                ),
                const SizedBox(width: 8),
                Expanded(child: _spotChip(muted, ink, 'USD / $quoteLabel', _formatUsd(usdSpot))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _spotChip(
                    muted,
                    ink,
                    _metal == 'gold' ? '1 tola' : 'Per kg',
                    _metal == 'gold'
                        ? _formatLocal(perG * _kTolaGrams, _displayCurrency)
                        : _formatLocal(perG * 1000, _displayCurrency),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _spotChip(
                    muted,
                    ink,
                    'USD/INR',
                    (_payload?['usdInr'] != null)
                        ? NumberFormat('#,##0.00').format(double.tryParse('${_payload!['usdInr']}') ?? 0)
                        : '—',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _spotChip(Color muted, Color ink, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softPurpleOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
        ],
      ),
    );
  }

  /// Country field — leading real flag emoji for that country.
  Widget _countrySelectField({
    required String label,
    required String countryCode,
    required String value,
    required String? subtitle,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
        const SizedBox(height: 6),
        Material(
          color: AppColors.softPurpleOf(context),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  _flagBadge(countryCode, size: 40, isDark: isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 22, color: muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Metal field — leading periodic symbol (Au, Ag…) with metal color.
  Widget _metalSelectField({
    required String label,
    required String metalKey,
    required String value,
    required String? subtitle,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
        const SizedBox(height: 6),
        Material(
          color: AppColors.softPurpleOf(context),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  _metalSymbolBadge(metalKey, isDark: isDark, size: 40, fontSize: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 22, color: muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Rich select field with leading icon badge (purity / unit / location).
  Widget _iconSelectField({
    required String label,
    required String value,
    required String? subtitle,
    required IconData icon,
    required Color iconColor,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
        const SizedBox(height: 6),
        Material(
          color: AppColors.softPurpleOf(context),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: isDark ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 22, color: muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
