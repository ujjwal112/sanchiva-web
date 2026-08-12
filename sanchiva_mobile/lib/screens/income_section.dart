import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/display_currency.dart';
import '../core/finance_refresh.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/expense.dart' show kMonthNames;
import '../models/income.dart';
import '../models/loan.dart';
import '../services/income_service.dart';
import '../services/loan_service.dart';
import '../services/table_export.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snack.dart';

/// Salary / Income — Entry · Charts · Data (web Monetary parity).
class IncomeSection extends StatefulWidget {
  const IncomeSection({super.key, this.initialTab = 0});

  /// 0 Entry · 1 Charts · 2 Data
  final int initialTab;

  @override
  State<IncomeSection> createState() => _IncomeSectionState();
}

class _IncomeSectionState extends State<IncomeSection> with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);

  /// Same palette as Card spends / Loans charts.
  static const _loanPalette = <Color>[
    Color(0xFF7C6CFF),
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
  ];

  late final TabController _tabs;
  final _svc = IncomeService.instance;
  final _loanSvc = LoanService.instance;

  final _sourceCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  List<IncomeSource> _list = [];
  IncomeSummary? _summary;

  /// Daily expense total for selected period (from income summary API).
  double _dailySpend = 0;
  /// Bank loan EMIs due in selected period.
  double _loanEmiSpend = 0;
  /// Card EMIs active in selected period.
  double _cardEmiSpend = 0;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int? _editingId;
  int _formMonth = DateTime.now().month;
  int _formYear = DateTime.now().year;

  // Charts / summary period
  int _periodMonth = DateTime.now().month;
  int _periodYear = DateTime.now().year;
  bool _sourceShowChart = true;
  bool _vsSpendShowChart = true;
  bool _spendBreakdownShowChart = true;

  // Data filters (null = All)
  int? _dataFilterMonth;
  int? _dataFilterYear;
  int _dataPage = 0;
  static const _pageSize = 5;
  String _exportFormat = 'csv';

  int _lastRefreshToken = -1;

  /// Combined spend for Income vs Spend chart.
  double get _totalSpend => _dailySpend + _loanEmiSpend + _cardEmiSpend;

  double get _totalIncome => _summary?.totalIncome ?? 0;

  double get _balance => _totalIncome - _totalSpend;

  @override
  void initState() {
    super.initState();
    final i = widget.initialTab.clamp(0, 2);
    _tabs = TabController(length: 3, vsync: this, initialIndex: i);
    _tabs.addListener(() {
      // Quiet refresh when opening Charts so spends stay current.
      if (!_tabs.indexIsChanging && _tabs.index == 1) {
        _loadPeriodSpends(showLoading: false);
      }
    });
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<FinanceRefresh>().token;
    if (token != _lastRefreshToken) {
      _lastRefreshToken = token;
      // Skip first attach noise only if we already have a token tracked as -1 and token is 0 after load
      if (!_loading) {
        _loadPeriodSpends(showLoading: false);
      }
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sourceCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.list();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
      await _loadPeriodSpends(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Income summary + daily / loan EMI / card EMI spends for [_periodMonth/_periodYear].
  Future<void> _loadPeriodSpends({bool showLoading = false}) async {
    try {
      final results = await Future.wait([
        _svc.summary(month: _periodMonth, year: _periodYear),
        _loanSvc.listLoans(),
        _loanSvc.listEmis(),
      ]);
      if (!mounted) return;
      final sum = results[0] as IncomeSummary;
      final loans = results[1] as List<Loan>;
      final emis = results[2] as List<CreditEmi>;

      final daily = sum.totalSpend;
      final loanEmi = loans
          .where((l) => l.isActiveIn(_periodMonth, _periodYear))
          .fold<double>(0, (s, l) => s + l.emiAmount);
      final cardEmi = emis
          .where((e) => e.isActiveIn(_periodMonth, _periodYear))
          .fold<double>(0, (s, e) => s + e.amount);

      setState(() {
        _summary = sum;
        _dailySpend = daily;
        _loanEmiSpend = loanEmi;
        _cardEmiSpend = cardEmi;
      });
    } catch (e) {
      debugPrint('Income period spends: $e');
    }
  }

  Future<void> _loadSummary() => _loadPeriodSpends(showLoading: false);

  void _resetForm() {
    _editingId = null;
    _sourceCtrl.clear();
    _amountCtrl.clear();
    _formMonth = DateTime.now().month;
    _formYear = DateTime.now().year;
  }

  void _startEdit(IncomeSource row) {
    setState(() {
      _editingId = row.id;
      _sourceCtrl.text = row.sourceName;
      _amountCtrl.text = row.amount == row.amount.roundToDouble()
          ? row.amount.toInt().toString()
          : row.amount.toString();
      _formMonth = row.month;
      _formYear = row.year;
      _tabs.index = 0;
    });
  }

  Future<void> _submit() async {
    final name = _sourceCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (name.isEmpty) {
      AppSnack.warning(context, 'Enter an income source');
      return;
    }
    if (amount == null || amount < 0) {
      AppSnack.warning(context, 'Enter a valid amount');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editingId != null) {
        await _svc.update(
          _editingId!,
          sourceName: name,
          amount: amount,
          month: _formMonth,
          year: _formYear,
        );
        if (mounted) AppSnack.success(context, 'Income updated');
      } else {
        await _svc.create(
          sourceName: name,
          amount: amount,
          month: _formMonth,
          year: _formYear,
        );
        if (mounted) AppSnack.success(context, 'Income added');
      }
      if (!mounted) return;
      setState(_resetForm);
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(IncomeSource row) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete income?',
      message: 'Remove "${row.sourceName}" (${formatMoney(row.amount)})? This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!ok) return;
    try {
      await _svc.delete(row.id);
      if (mounted) AppSnack.danger(context, 'Income deleted');
      if (_editingId == row.id) setState(_resetForm);
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    }
  }

  List<IncomeSource> get _dataFiltered {
    return _list.where((r) {
      if (_dataFilterMonth != null && r.month != _dataFilterMonth) return false;
      if (_dataFilterYear != null && r.year != _dataFilterYear) return false;
      return true;
    }).toList();
  }

  void _resetDataFilters() {
    setState(() {
      _dataFilterMonth = null;
      _dataFilterYear = null;
      _exportFormat = 'csv';
      _dataPage = 0;
    });
  }

  Future<void> _downloadFiltered() async {
    final rows = _dataFiltered;
    if (rows.isEmpty) {
      AppSnack.warning(context, 'No rows to download');
      return;
    }
    try {
      await exportTableReport(
        baseName: 'income',
        title: 'Income sources',
        headers: const ['Source', 'Amount', 'Month', 'Year'],
        rows: rows
            .map(
              (r) => [
                r.sourceName,
                r.amount.toStringAsFixed(r.amount == r.amount.roundToDouble() ? 0 : 2),
                kMonthNames[r.month - 1],
                '${r.year}',
              ],
            )
            .toList(),
        format: _exportFormat,
      );
      if (mounted) AppSnack.success(context, 'Download ready');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    }
  }

  // ─── UI helpers ──────────────────────────────────────────────────────────

  InputDecoration _fieldDeco(BuildContext context, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.softPurpleOf(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.borderOf(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.borderOf(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _brand, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    );
  }

  Widget _label(String text, Color muted) => Text(
        text,
        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: muted),
      );

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: child,
    );
  }

  Widget _empty(String msg, Color muted) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.inter(color: muted, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _pickerField({
    required String value,
    required Color ink,
    required Color muted,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.softPurpleOf(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: _brand.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5, color: ink),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Rounded option sheet with icon + heading (same as Daily expense).
  Future<T?> _showOptionSheet<T>({
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    required T selected,
    IconData icon = Icons.list_rounded,
  }) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.42;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Material(
            color: isDark ? AppColors.cardDark : Colors.white,
            elevation: 10,
            shadowColor: _brand.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 18, color: _brand),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: ink,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: muted, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final o = options[i];
                        final sel = o == selected;
                        return Material(
                          color: sel
                              ? _brand.withValues(alpha: isDark ? 0.22 : 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, o),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      labelOf(o),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                                        color: sel ? _brand : ink,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  if (sel)
                                    const Icon(Icons.check_circle_rounded, color: _brand, size: 18),
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
            ),
          ),
        );
      },
    );
  }

  static const _fallbackIcons = <IconData>[
    Icons.account_balance_wallet_rounded,
    Icons.payments_rounded,
    Icons.savings_rounded,
    Icons.currency_rupee_rounded,
    Icons.attach_money_rounded,
    Icons.account_balance_rounded,
  ];

  IconData _sourceIcon(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('salary') || n.contains('job') || n.contains('payroll')) {
      return Icons.work_rounded;
    }
    if (n.contains('freelance') || n.contains('contract') || n.contains('consult')) {
      return Icons.laptop_mac_rounded;
    }
    if (n.contains('rent') || n.contains('lease') || n.contains('tenant')) {
      return Icons.home_work_rounded;
    }
    if (n.contains('business') || n.contains('shop') || n.contains('store')) {
      return Icons.storefront_rounded;
    }
    if (n.contains('interest') || n.contains('fd') || n.contains('dividend')) {
      return Icons.trending_up_rounded;
    }
    if (n.contains('gift') || n.contains('bonus')) {
      return Icons.card_giftcard_rounded;
    }
    if (n.contains('pension') || n.contains('retire')) {
      return Icons.elderly_rounded;
    }
    return _fallbackIcons[n.hashCode.abs() % _fallbackIcons.length];
  }

  Color _sourceColor(String name) {
    return _loanPalette[name.trim().toLowerCase().hashCode.abs() % _loanPalette.length];
  }

  Widget _viewModeToggle({
    required bool showChart,
    required VoidCallback onChart,
    required VoidCallback onList,
    required Color muted,
    IconData chartIcon = Icons.pie_chart_rounded,
  }) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.softPurpleOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewModeIcon(chartIcon, showChart, onChart, muted, isDark),
          _viewModeIcon(Icons.view_list_rounded, !showChart, onList, muted, isDark),
        ],
      ),
    );
  }

  Widget _viewModeIcon(IconData icon, bool selected, VoidCallback onTap, Color muted, bool isDark) {
    return Material(
      color: selected ? _brand : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: selected ? Colors.white : muted),
        ),
      ),
    );
  }

  Widget _heroCard({required String title, required String value, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [_brand, _brandDeep]),
        boxShadow: [
          BoxShadow(color: _brand.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: color.withValues(alpha: isDark ? 0.22 : 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  ButtonStyle _downloadActionStyle() {
    final primary = Theme.of(context).colorScheme.primary;
    return OutlinedButton.styleFrom(
      foregroundColor: primary,
      disabledForegroundColor: primary.withValues(alpha: 0.35),
      side: BorderSide(color: primary.withValues(alpha: 0.45)),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _incomeTile(IncomeSource r, Color ink, Color muted) {
    final period = '${kMonthNames[r.month - 1]} ${r.year}';
    final color = _sourceColor(r.sourceName);
    final icon = _sourceIcon(r.sourceName);
    final isDark = AppColors.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink, fontSize: 14),
                ),
                Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(r.amount),
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionChip(
                    icon: Icons.edit_rounded,
                    color: _brand,
                    onTap: () => _startEdit(r),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _actionChip(
                    icon: Icons.delete_rounded,
                    color: AppColors.danger,
                    onTap: () => _delete(r),
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tabs ────────────────────────────────────────────────────────────────

  Widget _buildEntry(Color ink, Color muted) {
    final symbol = activeDisplayCurrencySymbol;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editingId != null ? 'Edit salary / income' : 'Add salary / income',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                ),
                const SizedBox(height: 14),
                _label('Income source', muted),
                const SizedBox(height: 6),
                TextField(
                  controller: _sourceCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDeco(context, hint: 'e.g. Salary, Freelance, Rent'),
                ),
                const SizedBox(height: 12),
                _label('Amount ($symbol)', muted),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _fieldDeco(context, hint: '0'),
                ),
                const SizedBox(height: 12),
                // Month + Year side by side (same row)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Month', muted),
                          const SizedBox(height: 6),
                          _pickerField(
                            value: kMonthNames[_formMonth - 1],
                            ink: ink,
                            muted: muted,
                            icon: Icons.calendar_view_month_rounded,
                            onTap: () async {
                              final v = await _showOptionSheet<int>(
                                title: 'Month',
                                options: List.generate(12, (i) => i + 1),
                                labelOf: (m) => kMonthNames[m - 1],
                                selected: _formMonth,
                                // Same list icon as Loans / Daily expense sheets
                                icon: Icons.list_rounded,
                              );
                              if (v != null) setState(() => _formMonth = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Year', muted),
                          const SizedBox(height: 6),
                          _pickerField(
                            value: '$_formYear',
                            ink: ink,
                            muted: muted,
                            icon: Icons.event_rounded,
                            onTap: () async {
                              final years = List.generate(8, (i) => DateTime.now().year - i + 1);
                              final v = await _showOptionSheet<int>(
                                title: 'Year',
                                options: years,
                                labelOf: (y) => '$y',
                                selected: _formYear,
                                icon: Icons.list_rounded,
                              );
                              if (v != null) setState(() => _formYear = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: _saving
                                ? [_brand.withValues(alpha: 0.45), const Color(0xFF7A40F8).withValues(alpha: 0.45)]
                                : const [_brand, Color(0xFF7A40F8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _brand.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: _saving ? null : _submit,
                            child: SizedBox(
                              height: 50,
                              child: Center(
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _editingId != null ? Icons.check_rounded : Icons.add_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _editingId != null ? 'Update income' : 'Add income',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_editingId != null) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => setState(_resetForm),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: BorderSide(color: AppColors.borderOf(context)),
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent entries',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                ),
              ),
              if (_list.isNotEmpty)
                Text(
                  'Latest 5',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_list.isEmpty)
            _empty('No income yet — add your first source above', muted)
          else
            ..._list.take(5).map((r) => _incomeTile(r, ink, muted)),
        ],
      ),
    );
  }

  Widget _periodFilters(Color ink, Color muted, {required VoidCallback onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Month', muted),
              const SizedBox(height: 6),
              _pickerField(
                value: kMonthNames[_periodMonth - 1],
                ink: ink,
                muted: muted,
                icon: Icons.calendar_view_month_rounded,
                onTap: () async {
                  final v = await _showOptionSheet<int>(
                    title: 'Month',
                    options: List.generate(12, (i) => i + 1),
                    labelOf: (m) => kMonthNames[m - 1],
                    selected: _periodMonth,
                    icon: Icons.list_rounded,
                  );
                  if (v != null) {
                    setState(() => _periodMonth = v);
                    onChanged();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Year', muted),
              const SizedBox(height: 6),
              _pickerField(
                value: '$_periodYear',
                ink: ink,
                muted: muted,
                icon: Icons.event_rounded,
                onTap: () async {
                  final years = List.generate(8, (i) => DateTime.now().year - i + 1);
                  final v = await _showOptionSheet<int>(
                    title: 'Year',
                    options: years,
                    labelOf: (y) => '$y',
                    selected: _periodYear,
                    icon: Icons.list_rounded,
                  );
                  if (v != null) {
                    setState(() => _periodYear = v);
                    onChanged();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCharts(Color ink, Color muted) {
    final s = _summary;
    final bySource = [...(s?.bySource ?? [])]..sort((a, b) => b.amount.compareTo(a.amount));
    final totalIncome = _totalIncome;
    final totalSpend = _totalSpend;
    final balance = _balance;
    final periodLabel = '${kMonthNames[_periodMonth - 1].substring(0, 3)} $_periodYear';
    final sourceCount = bySource.where((e) => e.amount > 0).length;
    final isDark = AppColors.isDark(context);

    // Bar series: Income · Spend (daily+loan EMI+card EMI) · Balance
    final barEntries = <MapEntry<String, double>>[
      MapEntry('Income', totalIncome),
      MapEntry('Spend', totalSpend),
      MapEntry('Balance', balance < 0 ? 0 : balance),
    ];
    final barColors = <Color>[
      _loanPalette[4], // green
      _loanPalette[2], // pink
      _loanPalette[0], // purple
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await _reload();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // Period filters (same as Card spends)
          _periodFilters(ink, muted, onChanged: _loadSummary),
          const SizedBox(height: 14),
          // Hero total
          _heroCard(
            title: 'Income · $periodLabel',
            value: formatMoney(totalIncome),
            subtitle:
                '$sourceCount source${sourceCount == 1 ? '' : 's'} · spend ${formatMoney(totalSpend)} · balance ${formatMoney(balance)}',
          ),
          const SizedBox(height: 12),

          // ── Pie: Income by source (chart / data toggle) ───────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'By income source',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                          ),
                          Text(
                            _sourceShowChart ? 'Source share chart' : 'Source breakdown list',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _viewModeToggle(
                      showChart: _sourceShowChart,
                      onChart: () => setState(() => _sourceShowChart = true),
                      onList: () => setState(() => _sourceShowChart = false),
                      muted: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (bySource.isEmpty || totalIncome <= 0)
                  Text(
                    'No income for $periodLabel',
                    style: GoogleFonts.inter(color: muted, fontSize: 13),
                  )
                else if (_sourceShowChart) ...[
                  SizedBox(
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 58,
                            startDegreeOffset: -90,
                            sections: [
                              for (var i = 0; i < bySource.length; i++)
                                if (bySource[i].amount > 0)
                                  PieChartSectionData(
                                    value: bySource[i].amount,
                                    color: _loanPalette[i % _loanPalette.length],
                                    radius: 52,
                                    title: '',
                                  ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total',
                              style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              formatMoney(totalIncome),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(bySource.length, (i) {
                      final e = bySource[i];
                      if (e.amount <= 0) return const SizedBox.shrink();
                      final color = _loanPalette[i % _loanPalette.length];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: color.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_sourceIcon(e.name), size: 13, color: color),
                            const SizedBox(width: 5),
                            Text(
                              e.name,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ] else
                  ...List.generate(bySource.length, (i) {
                    final e = bySource[i];
                    if (e.amount <= 0) return const SizedBox.shrink();
                    final pct = totalIncome > 0 ? e.amount / totalIncome : 0.0;
                    final color = _loanPalette[i % _loanPalette.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_sourceIcon(e.name), size: 17, color: color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.name,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
                                ),
                              ),
                              Text(
                                '${(pct * 100).round()}%',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatMoney(e.amount),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ink),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: color.withValues(alpha: 0.12),
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Bar: Income vs Spend (chart / data toggle — metrics live in data) ──
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Income vs Spend',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                          ),
                          Text(
                            _vsSpendShowChart ? 'Comparison bar chart' : 'Income · spend · balance list',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _viewModeToggle(
                      showChart: _vsSpendShowChart,
                      onChart: () => setState(() => _vsSpendShowChart = true),
                      onList: () => setState(() => _vsSpendShowChart = false),
                      muted: muted,
                      chartIcon: Icons.bar_chart_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_vsSpendShowChart) ...[
                  Text(
                    'Total spend  ${formatMoney(totalSpend)}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 240,
                    child: _incomeVsSpendBar(barEntries, barColors, ink, muted),
                  ),
                ] else
                  ..._metricDataRows(
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    rows: [
                      (
                        label: 'Income this month',
                        value: totalIncome,
                        icon: Icons.account_balance_wallet_rounded,
                        color: _loanPalette[4],
                        danger: false,
                      ),
                      (
                        label: 'Total spend',
                        value: totalSpend,
                        icon: Icons.shopping_bag_rounded,
                        color: _loanPalette[2],
                        danger: false,
                      ),
                      (
                        label: 'Remaining balance',
                        value: balance,
                        icon: Icons.savings_rounded,
                        color: _loanPalette[0],
                        danger: balance < 0,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── New bar: Daily expense · Loan EMI · Card EMI ─────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spend breakdown',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                          ),
                          Text(
                            _spendBreakdownShowChart
                                ? 'Daily · loan EMI · card EMI chart'
                                : 'Daily · loan EMI · card EMI list',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _viewModeToggle(
                      showChart: _spendBreakdownShowChart,
                      onChart: () => setState(() => _spendBreakdownShowChart = true),
                      onList: () => setState(() => _spendBreakdownShowChart = false),
                      muted: muted,
                      chartIcon: Icons.bar_chart_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_spendBreakdownShowChart) ...[
                  Text(
                    'Total  ${formatMoney(totalSpend)}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 240,
                    child: _incomeVsSpendBar(
                      [
                        MapEntry('Daily', _dailySpend),
                        MapEntry('Loan EMI', _loanEmiSpend),
                        MapEntry('Card EMI', _cardEmiSpend),
                      ],
                      [
                        _loanPalette[2], // pink — daily
                        _loanPalette[5], // blue — loan
                        _loanPalette[7], // orange — card
                      ],
                      ink,
                      muted,
                    ),
                  ),
                ] else
                  ..._metricDataRows(
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    rows: [
                      (
                        label: 'Daily expense',
                        value: _dailySpend,
                        icon: Icons.receipt_long_rounded,
                        color: _loanPalette[2],
                        danger: false,
                      ),
                      (
                        label: 'Loan EMI deductions',
                        value: _loanEmiSpend,
                        icon: Icons.account_balance_rounded,
                        color: _loanPalette[5],
                        danger: false,
                      ),
                      (
                        label: 'Card EMIs',
                        value: _cardEmiSpend,
                        icon: Icons.credit_card_rounded,
                        color: _loanPalette[7],
                        danger: false,
                      ),
                      (
                        label: 'Total spend',
                        value: totalSpend,
                        icon: Icons.payments_rounded,
                        color: _loanPalette[1],
                        danger: false,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shared progress-row list for chart data toggles.
  List<Widget> _metricDataRows({
    required Color ink,
    required Color muted,
    required bool isDark,
    required List<({String label, double value, IconData icon, Color color, bool danger})> rows,
  }) {
    final maxAbs = rows.map((r) => r.value.abs()).fold<double>(1, (a, b) => a > b ? a : b);

    return [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: r.color.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(r.icon, size: 17, color: r.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.label,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
                    ),
                  ),
                  Text(
                    formatMoney(r.value),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: r.danger ? AppColors.danger : ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (r.value.abs() / maxAbs).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: r.color.withValues(alpha: 0.12),
                  color: r.color,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _incomeVsSpendBar(
    List<MapEntry<String, double>> entries,
    List<Color> colors,
    Color ink,
    Color muted,
  ) {
    final maxY = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final top = (maxY <= 0 ? 1.0 : maxY) * 1.28;

    return BarChart(
      BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final e = entries[group.x.toInt()];
              return BarTooltipItem(
                '${e.key}\n${formatMoney(e.value)}',
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) {
                if (v >= meta.max - (meta.max * 0.001)) return const SizedBox.shrink();
                if (v == 0) {
                  return Text('0', style: GoogleFonts.inter(fontSize: 9, color: muted, fontWeight: FontWeight.w600));
                }
                final k = v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : v.toStringAsFixed(0);
                return Text(k, style: GoogleFonts.inter(fontSize: 9, color: muted, fontWeight: FontWeight.w600));
              },
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: muted.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                width: 28,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                color: colors[i % colors.length],
              ),
            ],
          );
        }),
      ),
    );
  }

  ({int page, int pageCount, int maxPage}) _pageMeta(int total) {
    final pageCount = total == 0 ? 0 : ((total + _pageSize - 1) ~/ _pageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _dataPage.clamp(0, maxPage);
    return (page: page, pageCount: pageCount, maxPage: maxPage);
  }

  List<T> _paged<T>(List<T> rows) {
    if (rows.isEmpty) return [];
    final meta = _pageMeta(rows.length);
    final start = meta.page * _pageSize;
    return rows.sublist(start, (start + _pageSize).clamp(0, rows.length));
  }

  /// Same list header + pagination as Card spends Data.
  Widget _dataListHeader({
    required String title,
    required int total,
    required Color ink,
    required Color muted,
    required ({int page, int pageCount, int maxPage}) pageMeta,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$title · $total',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
              ),
            ),
            Text(
              '$total total',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
            ),
          ],
        ),
        if (pageMeta.pageCount > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Page ${pageMeta.page + 1} of ${pageMeta.pageCount} · 5 per page',
                style: GoogleFonts.inter(fontSize: 12, color: muted),
              ),
              const Spacer(),
              _pageNav(
                label: '${pageMeta.page + 1}/${pageMeta.pageCount}',
                canPrev: pageMeta.page > 0,
                canNext: pageMeta.page < pageMeta.maxPage,
                onPrev: () => setState(() => _dataPage = pageMeta.page - 1),
                onNext: () => setState(() => _dataPage = pageMeta.page + 1),
                muted: muted,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pageNav({
    required String label,
    required bool canPrev,
    required bool canNext,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required Color muted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softPurpleOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _navIconBtn(
            icon: Icons.chevron_left_rounded,
            enabled: canPrev,
            onTap: onPrev,
            muted: muted,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
            ),
          ),
          _navIconBtn(
            icon: Icons.chevron_right_rounded,
            enabled: canNext,
            onTap: onNext,
            muted: muted,
          ),
        ],
      ),
    );
  }

  Widget _navIconBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required Color muted,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.inkOf(context) : muted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _buildData(Color ink, Color muted) {
    final rows = _dataFiltered;
    final pageMeta = _pageMeta(rows.length);
    final pageRows = _paged(rows);
    final isDefault =
        _dataFilterMonth == null && _dataFilterYear == null && _exportFormat == 'csv';
    final monthLabel = _dataFilterMonth == null ? 'All months' : kMonthNames[_dataFilterMonth! - 1];
    final yearLabel = _dataFilterYear == null ? 'All years' : '$_dataFilterYear';

    return RefreshIndicator(
      onRefresh: () async {
        await _reload();
        await _loadSummary();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                Text(
                  'Filter income, then export as CSV or PDF',
                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Month', muted),
                          const SizedBox(height: 6),
                          _pickerField(
                            value: monthLabel,
                            ink: ink,
                            muted: muted,
                            icon: Icons.calendar_view_month_rounded,
                            onTap: () async {
                              final options = <int>[0, ...List.generate(12, (i) => i + 1)];
                              final selected = _dataFilterMonth ?? 0;
                              final v = await _showOptionSheet<int>(
                                title: 'Month',
                                options: options,
                                labelOf: (m) => m == 0 ? 'All months' : kMonthNames[m - 1],
                                selected: selected,
                                icon: Icons.list_rounded,
                              );
                              if (v != null) {
                                setState(() {
                                  _dataFilterMonth = v == 0 ? null : v;
                                  _dataPage = 0;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Year', muted),
                          const SizedBox(height: 6),
                          _pickerField(
                            value: yearLabel,
                            ink: ink,
                            muted: muted,
                            icon: Icons.event_rounded,
                            onTap: () async {
                              final years = List.generate(7, (i) => DateTime.now().year - i);
                              final options = <int>[0, ...years];
                              final selected = _dataFilterYear ?? 0;
                              final v = await _showOptionSheet<int>(
                                title: 'Year',
                                options: options,
                                labelOf: (y) => y == 0 ? 'All years' : '$y',
                                selected: selected,
                                icon: Icons.list_rounded,
                              );
                              if (v != null) {
                                setState(() {
                                  _dataFilterYear = v == 0 ? null : v;
                                  _dataPage = 0;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('File type', muted),
                const SizedBox(height: 6),
                _pickerField(
                  value: _exportFormat == 'pdf' ? 'PDF' : 'CSV / Excel',
                  ink: ink,
                  muted: muted,
                  icon: Icons.description_outlined,
                  onTap: () async {
                    final v = await _showOptionSheet<String>(
                      title: 'File type',
                      options: const ['csv', 'pdf'],
                      labelOf: (f) => f == 'pdf' ? 'PDF' : 'CSV / Excel',
                      selected: _exportFormat,
                      icon: Icons.list_rounded,
                    );
                    if (v != null) setState(() => _exportFormat = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: rows.isEmpty ? null : _downloadFiltered,
                        style: _downloadActionStyle(),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          rows.isEmpty ? 'No data' : 'Download (${rows.length})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDefault ? null : _resetDataFilters,
                        style: _downloadActionStyle(),
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: Text(
                          'Reset',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _dataListHeader(
            title: 'Income',
            total: rows.length,
            ink: ink,
            muted: muted,
            pageMeta: pageMeta,
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _empty(
              _list.isEmpty ? 'No income yet.' : 'No income matches these filters.',
              muted,
            )
          else
            ...pageRows.map((r) => _incomeTile(r, ink, muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);

    if (_loading && _list.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _brand));
    }

    if (_error != null && _list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.danger)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: TabBar(
              controller: _tabs,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: _brand.withValues(alpha: AppColors.isDark(context) ? 0.28 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(14),
              labelColor: _brand,
              unselectedLabelColor: muted,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(height: 40, text: 'Entry'),
                Tab(height: 40, text: 'Charts'),
                Tab(height: 40, text: 'Data'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildEntry(ink, muted),
              _buildCharts(ink, muted),
              _buildData(ink, muted),
            ],
          ),
        ),
      ],
    );
  }
}
