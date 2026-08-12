import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import '../core/finance_refresh.dart';
import '../core/shell_nav.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../services/expense_export.dart';
import '../services/expense_service.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snack.dart';
import '../widgets/section_header_card.dart';

/// Daily expense — 3 sections like web: Entry · Charts · Data (+ download).
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF5038F0);

  late final TabController _tabs;
  final _svc = ExpenseService.instance;
  int _deepLinkToken = -1;

  List<Expense> _list = [];
  List<WeekSummary> _weeks = [];
  List<MonthSummary> _months = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Form
  final _itemCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController();
  final _paidViaDetailCtrl = TextEditingController();
  String _category = kExpenseCategories.first;
  String _paidVia = kPaidViaOptions.first; // UPI default
  DateTime _date = DateTime.now();
  int? _editingId;

  // Filters (charts)
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  int _weekSlide = 0;
  int _dataPage = 0; // pagination for data list (5 per page)
  static const _pageSize = 5;
  String _exportFormat = 'csv'; // csv | pdf
  /// Data download filters (null = All months / All years) — same as Card spends.
  int? _dataFilterMonth;
  int? _dataFilterYear;
  /// Charts tab: toggle chart vs data list per section.
  bool _categoryShowChart = true;
  bool _weekShowChart = true;
  bool _paidViaShowChart = true;
  bool _paidViaDetailShowChart = true;

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

  /// Distinct icon per known category; hash fallback so customs stay unique.
  static IconData _categoryIcon(String category) {
    switch (category.trim().toLowerCase()) {
      case 'ecommerce':
      case 'e-commerce':
      case 'e commerce':
      case 'online shopping':
      case 'online':
        // Globe / bag — clearly different from grocery cart
        return Icons.language_rounded;
      case 'grocery':
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'food':
      case 'dining':
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'travel':
      case 'transport':
      case 'transportation':
        return Icons.directions_car_rounded;
      case 'electronics':
      case 'gadgets':
        return Icons.devices_rounded;
      case 'miscellaneous':
      case 'misc':
        return Icons.widgets_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'bills':
      case 'bill':
        return Icons.receipt_long_rounded;
      case 'health':
      case 'medical':
        return Icons.local_hospital_rounded;
      case 'entertainment':
      case 'movies':
        return Icons.movie_rounded;
      case 'education':
      case 'school':
        return Icons.school_rounded;
      case 'rent':
      case 'housing':
        return Icons.home_rounded;
      case 'utilities':
      case 'electricity':
      case 'power':
        return Icons.bolt_rounded;
      case 'fuel':
      case 'petrol':
        return Icons.local_gas_station_rounded;
      case 'subscriptions':
      case 'subscription':
        return Icons.autorenew_rounded;
      case 'gifts':
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'personal care':
      case 'beauty':
        return Icons.spa_rounded;
      case 'fitness':
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'insurance':
        return Icons.shield_rounded;
      case 'investment':
      case 'investments':
        return Icons.trending_up_rounded;
      default:
        return _fallbackIcons[category.trim().toLowerCase().hashCode.abs() % _fallbackIcons.length];
    }
  }

  static const _fallbackIcons = <IconData>[
    Icons.category_rounded,
    Icons.label_rounded,
    Icons.sell_rounded,
    Icons.inventory_2_rounded,
    Icons.storefront_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.payments_rounded,
    Icons.credit_card_rounded,
    Icons.local_mall_rounded,
    Icons.handyman_rounded,
    Icons.pets_rounded,
    Icons.flight_rounded,
  ];

  /// Distinct color per known category; stable hash for any other name.
  static Color _categoryColor(String category) {
    switch (category.trim().toLowerCase()) {
      case 'ecommerce':
      case 'e-commerce':
      case 'e commerce':
      case 'online shopping':
      case 'online':
        return const Color(0xFF6366F1); // indigo
      case 'grocery':
      case 'groceries':
        return const Color(0xFF22C55E); // green
      case 'food':
      case 'dining':
      case 'restaurant':
        return const Color(0xFFF97316); // orange
      case 'travel':
      case 'transport':
      case 'transportation':
        return const Color(0xFF3B82F6); // blue
      case 'electronics':
      case 'gadgets':
        return const Color(0xFF06B6D4); // cyan
      case 'miscellaneous':
      case 'misc':
        return const Color(0xFFA855F7); // purple
      case 'other':
        return const Color(0xFF64748B); // slate
      case 'shopping':
        return const Color(0xFFEC4899); // pink
      case 'bills':
      case 'bill':
        return const Color(0xFF8B5CF6); // violet
      case 'health':
      case 'medical':
        return const Color(0xFFEF4444); // red
      case 'entertainment':
      case 'movies':
        return const Color(0xFFD946EF); // fuchsia
      case 'education':
      case 'school':
        return const Color(0xFF0EA5E9); // sky
      case 'rent':
      case 'housing':
        return const Color(0xFF14B8A6); // teal
      case 'utilities':
      case 'electricity':
      case 'power':
        return const Color(0xFFFBBF24); // amber
      case 'fuel':
      case 'petrol':
        return const Color(0xFFF59E0B); // amber-dark
      case 'subscriptions':
      case 'subscription':
        return const Color(0xFF7C3AED);
      case 'gifts':
      case 'gift':
        return const Color(0xFFF43F5E);
      case 'personal care':
      case 'beauty':
        return const Color(0xFFDB2777);
      case 'fitness':
      case 'gym':
        return const Color(0xFF10B981);
      case 'insurance':
        return const Color(0xFF2563EB);
      case 'investment':
      case 'investments':
        return const Color(0xFF059669);
      default:
        return _fallbackColors[
            category.trim().toLowerCase().hashCode.abs() % _fallbackColors.length];
    }
  }

  static const _fallbackColors = <Color>[
    Color(0xFF7C6CFF),
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
    Color(0xFF2DD4BF),
    Color(0xFFE879F9),
    Color(0xFF4ADE80),
    Color(0xFFF87171),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        if (_tabs.index >= 1) _loadSummaries();
      }
    });
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.watch<ShellNav>();
    if (nav.index != 0) return;
    if (!nav.pendingApplySubTab) return;
    if (nav.pendingMonetaryArea != null || nav.pendingLoansArea != null) return;
    if (nav.deepLinkToken == _deepLinkToken) return;
    _deepLinkToken = nav.deepLinkToken;
    final t = nav.pendingSubTab.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tabs.index != t) {
        _tabs.animateTo(t);
        if (t >= 1) _loadSummaries();
      }
      nav.clearSubTabDeepLink();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _itemCtrl.dispose();
    _amountCtrl.dispose();
    _customCatCtrl.dispose();
    _paidViaDetailCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listAll();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
      if (_tabs.index >= 1) await _loadSummaries();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSummaries() async {
    try {
      final weeks = await _svc.weeks(year: _year, month: _month);
      final months = await _svc.months(year: _year);
      if (!mounted) return;
      setState(() {
        _weeks = weeks;
        _months = months;
        _weekSlide = 0;
        _dataPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, '$e');
    }
  }

  MonthSummary get _currentMonth {
    for (final m in _months) {
      if (m.month == _month && m.year == _year) return m;
    }
    return MonthSummary(
      month: _month,
      year: _year,
      total: 0,
      byCategory: const {},
      expenses: const [],
    );
  }

  List<WeekSummary> get _monthWeeks {
    if (_weeks.isEmpty) return [];
    return _weeks.where((w) {
      if (w.expenses.any((e) => e.expenseDate.year == _year && e.expenseDate.month == _month)) {
        return true;
      }
      try {
        final start = DateTime.parse(w.weekStart);
        final end = DateTime.parse(w.weekEnd);
        final ms = DateTime(_year, _month, 1);
        final me = DateTime(_year, _month + 1, 0, 23, 59, 59);
        return !start.isAfter(me) && !end.isBefore(ms);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List<Expense> get _monthRows {
    if (_currentMonth.expenses.isNotEmpty) return _currentMonth.expenses;
    return _list
        .where((r) => r.expenseDate.year == _year && r.expenseDate.month == _month)
        .toList();
  }

  List<Expense> get _yearRows =>
      _list.where((r) => r.expenseDate.year == _year).toList();

  void _resetForm() {
    _editingId = null;
    _itemCtrl.clear();
    _amountCtrl.clear();
    _customCatCtrl.clear();
    _paidViaDetailCtrl.clear();
    _category = kExpenseCategories.first;
    _paidVia = kPaidViaOptions.first;
    _date = DateTime.now();
  }

  void _edit(Expense e) {
    setState(() {
      _editingId = e.id;
      _itemCtrl.text = e.itemName;
      _amountCtrl.text = e.amount.toString();
      _category = kExpenseCategories.contains(e.category) ? e.category : 'Other';
      if (!kExpenseCategories.contains(e.category) || e.category == 'Other') {
        if (e.category != 'Other') {
          _category = 'Other';
          _customCatCtrl.text = e.category;
        }
      }
      _paidVia = kPaidViaOptions.contains(e.paidVia) ? e.paidVia : 'Other';
      _paidViaDetailCtrl.text = e.paidViaDetail;
      _date = e.expenseDate;
      _tabs.index = 0;
    });
  }

  Future<void> _submit() async {
    final item = _itemCtrl.text.trim();
    // Accept amounts with commas (e.g. 1,200.50)
    final amtRaw = _amountCtrl.text.trim().replaceAll(',', '');
    final amt = double.tryParse(amtRaw);
    if (item.isEmpty || amt == null || amt < 0) {
      AppSnack.warning(context, 'Enter item name and a valid amount');
      return;
    }
    // "Other" is optional custom name: blank → save as "Other"; filled → use that name.
    final customName = _customCatCtrl.text.trim();
    final categoryToSend = (_category == 'Other' && customName.isNotEmpty)
        ? customName
        : _category;
    final viaDetail = _paidVia == 'Cash' ? '' : _paidViaDetailCtrl.text.trim();

    setState(() => _saving = true);
    try {
      final dateIso =
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      final wasEdit = _editingId != null;
      // Send resolved category name directly (avoids backend custom_category path failures).
      if (wasEdit) {
        await _svc.update(
          _editingId!,
          category: categoryToSend,
          amount: amt,
          expenseDate: dateIso,
          itemName: item,
          customCategory: null,
          paidVia: _paidVia,
          paidViaDetail: viaDetail,
        );
      } else {
        await _svc.create(
          category: categoryToSend,
          amount: amt,
          expenseDate: dateIso,
          itemName: item,
          customCategory: null,
          paidVia: _paidVia,
          paidViaDetail: viaDetail,
        );
      }
      if (!mounted) return;
      _resetForm();
      await _reload();
      if (!mounted) return;
      // Notify Salary / Income charts to pick up new spends immediately.
      context.read<FinanceRefresh>().bump();
      AppSnack.success(
        context,
        wasEdit ? 'Expense updated' : 'Expense added',
        icon: wasEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Expense e) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete expense?',
      message: 'Remove ${e.itemName} · ${formatMoney(e.amount)}? This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!ok) return;
    try {
      await _svc.delete(e.id);
      await _reload();
      if (!mounted) return;
      context.read<FinanceRefresh>().bump();
      AppSnack.danger(context, 'Expense deleted');
    } catch (err) {
      if (!mounted) return;
      AppSnack.error(context, '$err');
    }
  }

  /// Expenses for Data list + download (All months / All years by default).
  List<Expense> get _dataFilteredRows {
    final rows = _list.where((e) {
      if (_dataFilterYear != null && e.expenseDate.year != _dataFilterYear) return false;
      if (_dataFilterMonth != null && e.expenseDate.month != _dataFilterMonth) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return rows;
  }

  Future<void> _downloadFiltered() async {
    try {
      final rows = _dataFilteredRows;
      if (rows.isEmpty) return;
      final monthPart = _dataFilterMonth == null
          ? 'all_months'
          : _dataFilterMonth!.toString().padLeft(2, '0');
      final yearPart = _dataFilterYear == null ? 'all_years' : '$_dataFilterYear';
      final labelMonth = _dataFilterMonth == null
          ? 'All months'
          : kMonthNames[_dataFilterMonth! - 1];
      final labelYear = _dataFilterYear == null ? 'All years' : '$_dataFilterYear';
      final label = 'Daily Expenses · $labelMonth · $labelYear';
      final name = 'daily_expenses_${yearPart}_$monthPart';
      await exportExpensesReport(
        baseName: name,
        title: label,
        rows: rows,
        format: _exportFormat,
      );
      if (!mounted) return;
      AppSnack.info(
        context,
        _exportFormat == 'pdf' ? 'PDF ready' : 'CSV ready (opens in Excel)',
        icon: Icons.download_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, '$e');
    }
  }

  void _resetDataFilters() {
    setState(() {
      // Defaults match Card spends Data: All months + All years
      _dataFilterMonth = null;
      _dataFilterYear = null;
      _exportFormat = 'csv';
      _dataPage = 0;
    });
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

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SectionHeaderCard(
            icon: Icons.receipt_long_rounded,
            title: 'Daily expense',
            subtitle: 'Track everyday spends by category and week',
          ),
        ),
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
              // Pill highlight like bottom nav — no underline bar.
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
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                title: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger)),
                trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
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

  // ─── Tab 1: Entry ─────────────────────────────────────────────────────────

  Widget _buildEntry(Color ink, Color muted) {
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
                  _editingId != null ? 'Edit expense' : 'Add daily expense',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                ),
                const SizedBox(height: 14),
                _label('Category', muted),
                const SizedBox(height: 6),
                _pickerField(
                  value: _category,
                  ink: ink,
                  muted: muted,
                  icon: _categoryIcon(_category),
                  onTap: () async {
                    final v = await _showOptionSheet<String>(
                      title: 'Category',
                      options: kExpenseCategories,
                      labelOf: (c) => c,
                      selected: _category,
                    );
                    if (v != null) setState(() => _category = v);
                  },
                ),
                if (_category == 'Other') ...[
                  const SizedBox(height: 12),
                  _label('Custom category', muted),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _customCatCtrl,
                    decoration: _fieldDeco(context, hint: 'e.g. Gifts'),
                  ),
                ],
                const SizedBox(height: 12),
                _label('Item name', muted),
                const SizedBox(height: 6),
                TextField(
                  controller: _itemCtrl,
                  decoration: _fieldDeco(context, hint: 'e.g. Milk, Uber, Amazon order'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Amount (₹)', muted),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _fieldDeco(context, hint: '0'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Date', muted),
                          const SizedBox(height: 6),
                          _pickerField(
                            value: DateFormat('dd MMM yyyy').format(_date),
                            ink: ink,
                            muted: muted,
                            icon: Icons.calendar_today_rounded,
                            onTap: () async {
                              final d = await _showCompactDatePicker(_date);
                              if (d != null) setState(() => _date = d);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Paid via', muted),
                const SizedBox(height: 6),
                _pickerField(
                  value: _paidVia,
                  ink: ink,
                  muted: muted,
                  icon: _paidViaIcon(_paidVia),
                  onTap: () async {
                    final v = await _showOptionSheet<String>(
                      title: 'Paid via',
                      options: kPaidViaOptions,
                      labelOf: (c) => c,
                      selected: _paidVia,
                    );
                    if (v != null) {
                      setState(() {
                        _paidVia = v;
                        if (v == 'Cash') _paidViaDetailCtrl.clear();
                      });
                    }
                  },
                ),
                if (_paidVia != 'Cash') ...[
                  const SizedBox(height: 12),
                  _label(paidViaDetailLabel(_paidVia), muted),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _paidViaDetailCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDeco(context, hint: paidViaDetailHint(_paidVia)),
                  ),
                ],
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
                                            _editingId != null ? 'Update expense' : 'Add expense',
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
            _empty('No expenses yet — add your first spend above', muted)
          else
            ..._list.take(5).map((e) => _expenseTile(e, ink, muted)),
        ],
      ),
    );
  }

  // ─── Tab 2: Charts ────────────────────────────────────────────────────────

  Widget _buildCharts(Color ink, Color muted) {
    final monthCard = _currentMonth;
    final weeks = _monthWeeks;
    final maxSlide = weeks.length <= 1 ? 0 : weeks.length - 1;
    final visible = weeks.isEmpty
        ? <WeekSummary>[]
        : [weeks[_weekSlide.clamp(0, weeks.length - 1)]];
    final cats = monthCard.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = monthCard.total;

    return RefreshIndicator(
      onRefresh: () async {
        await _reload();
        await _loadSummaries();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _periodPicker(ink, muted),
          const SizedBox(height: 14),
          // Summary hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brand, Color(0xFF7A40F8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${kMonthNames[_month - 1]} $_year',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total spend',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
                Text(
                  formatMoney(total),
                  style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cats.length} categor${cats.length == 1 ? 'y' : 'ies'} · ${_monthRows.length} entries',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 1) Weekly breakdown first
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly breakdown',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _weekShowChart ? 'Weekly share chart' : 'Weekly items list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _weekShowChart,
                onChart: () => setState(() => _weekShowChart = true),
                onList: () => setState(() => _weekShowChart = false),
                muted: muted,
              ),
              const SizedBox(width: 8),
              _pageNav(
                label: weeks.isEmpty ? '0/0' : '${_weekSlide + 1}/${weeks.length}',
                canPrev: _weekSlide > 0,
                canNext: _weekSlide < maxSlide,
                onPrev: () => setState(() => _weekSlide--),
                onNext: () => setState(() => _weekSlide++),
                muted: muted,
              ),
            ],
          ),
          Text('Sunday–Saturday', style: GoogleFonts.inter(fontSize: 12, color: muted)),
          const SizedBox(height: 8),
          if (weeks.isEmpty)
            _empty('No weekly data for this month', muted)
          else
            ...visible.map((w) => _weekCard(w, ink, muted)),
          const SizedBox(height: 16),
          // 2) By category
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
                            'By category',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                          ),
                          Text(
                            _categoryShowChart ? 'Category share chart' : 'Category breakdown list',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _viewModeToggle(
                      showChart: _categoryShowChart,
                      onChart: () => setState(() => _categoryShowChart = true),
                      onList: () => setState(() => _categoryShowChart = false),
                      muted: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (cats.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text('No chart data yet', style: TextStyle(color: muted)),
                    ),
                  )
                else if (_categoryShowChart) ...[
                  SizedBox(
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _pie(Map.fromEntries(cats), ring: true, compact: false),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total',
                              style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              formatMoney(total),
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Category tags under pie (same style as Paid via)
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cats.map((e) {
                      final color = _categoryColor(e.key);
                      final isDark = AppColors.isDark(context);
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
                            Icon(_categoryIcon(e.key), size: 13, color: color),
                            const SizedBox(width: 5),
                            Text(
                              e.key,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ] else
                  ...cats.map((e) {
                    final pct = total > 0 ? e.value / total : 0.0;
                    final color = _categoryColor(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: AppColors.isDark(context) ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_categoryIcon(e.key), size: 15, color: color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
                                ),
                              ),
                              Text(
                                '${(pct * 100).round()}%',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatMoney(e.value),
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
          // 3) Paid via — pie (method) + bar (bank/card detail)
          _paidViaMethodCard(ink, muted, monthCard.expenses.isNotEmpty ? monthCard.expenses : _monthRows),
          const SizedBox(height: 12),
          _paidViaDetailCard(ink, muted, monthCard.expenses.isNotEmpty ? monthCard.expenses : _monthRows),
        ],
      ),
    );
  }

  Map<String, double> _aggregatePaidVia(List<Expense> rows) {
    final map = <String, double>{};
    for (final e in rows) {
      final k = e.paidVia.trim().isEmpty ? 'Cash' : e.paidVia.trim();
      map[k] = (map[k] ?? 0) + e.amount;
    }
    return map;
  }

  /// Second-level: which bank/card within paid-via methods.
  Map<String, double> _aggregatePaidViaDetail(List<Expense> rows) {
    final map = <String, double>{};
    for (final e in rows) {
      final via = e.paidVia.trim().isEmpty ? 'Cash' : e.paidVia.trim();
      final detail = e.paidViaDetail.trim();
      final key = detail.isEmpty ? via : '$detail ($via)';
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }

  IconData _paidViaIcon(String via) {
    switch (via) {
      case 'UPI':
        return Icons.qr_code_2_rounded;
      case 'Card':
        return Icons.credit_card_rounded;
      case 'Cash':
        return Icons.payments_rounded;
      case 'Bank transfer':
        return Icons.account_balance_rounded;
      case 'Other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _paidViaColor(String via, int index) {
    switch (via) {
      case 'UPI':
        return const Color(0xFF7C6CFF);
      case 'Card':
        return const Color(0xFF22D3EE);
      case 'Cash':
        return const Color(0xFF34D399);
      case 'Bank transfer':
        return const Color(0xFF60A5FA);
      case 'Other':
        return const Color(0xFFFB923C);
      default:
        return _loanPalette[index % _loanPalette.length];
    }
  }

  Widget _paidViaMethodCard(Color ink, Color muted, List<Expense> rows) {
    final data = _aggregatePaidVia(rows);
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final isDark = AppColors.isDark(context);

    return _card(
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
                      'Paid via',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _paidViaShowChart ? 'Payment method share' : 'Payment method list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _paidViaShowChart,
                onChart: () => setState(() => _paidViaShowChart = true),
                onList: () => setState(() => _paidViaShowChart = false),
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('No spends this month', style: TextStyle(color: muted))
          else if (_paidViaShowChart)
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 54,
                      startDegreeOffset: -90,
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          PieChartSectionData(
                            value: entries[i].value,
                            color: _paidViaColor(entries[i].key, i),
                            radius: 48,
                            title: '',
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total', style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                      Text(
                        formatMoney(total),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: ink),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              final pct = total > 0 ? e.value / total : 0.0;
              final color = _paidViaColor(e.key, i);
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
                          child: Icon(_paidViaIcon(e.key), size: 17, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.key,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
                          ),
                        ),
                        Text(
                          '${(pct * 100).round()}%',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatMoney(e.value),
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
          if (entries.isNotEmpty && _paidViaShowChart) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(entries.length, (i) {
                final e = entries[i];
                final color = _paidViaColor(e.key, i);
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
                      Icon(_paidViaIcon(e.key), size: 13, color: color),
                      const SizedBox(width: 5),
                      Text(e.key, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paidViaDetailCard(Color ink, Color muted, List<Expense> rows) {
    final data = _aggregatePaidViaDetail(rows);
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final isDark = AppColors.isDark(context);

    return _card(
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
                      'Paid via detail',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _paidViaDetailShowChart
                          ? 'Bank / card spend chart'
                          : 'Bank / card breakdown list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _paidViaDetailShowChart,
                onChart: () => setState(() => _paidViaDetailShowChart = true),
                onList: () => setState(() => _paidViaDetailShowChart = false),
                muted: muted,
                chartIcon: Icons.bar_chart_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('No paid-via details this month', style: TextStyle(color: muted))
          else if (_paidViaDetailShowChart) ...[
            Text(
              'Total  ${formatMoney(total)}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: _simpleBarChart(entries, ink, muted),
            ),
          ] else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              final pct = total > 0 ? e.value / total : 0.0;
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
                          child: Icon(Icons.account_balance_wallet_rounded, size: 17, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.key,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
                          ),
                        ),
                        Text(
                          '${(pct * 100).round()}%',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatMoney(e.value),
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
    );
  }

  Widget _simpleBarChart(List<MapEntry<String, double>> entries, Color ink, Color muted) {
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
          getDrawingHorizontalLine: (v) => FlLine(color: muted.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                width: entries.length > 6 ? 14 : 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                color: _loanPalette[i % _loanPalette.length],
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Compact chart / list icon pair for section headers.
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
          _viewModeIcon(
            icon: chartIcon,
            selected: showChart,
            onTap: onChart,
            muted: muted,
            isDark: isDark,
          ),
          _viewModeIcon(
            icon: Icons.view_list_rounded,
            selected: !showChart,
            onTap: onList,
            muted: muted,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _viewModeIcon({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color muted,
    required bool isDark,
  }) {
    return Material(
      color: selected ? _brand : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : muted,
          ),
        ),
      ),
    );
  }

  // ─── Tab 3: Data + download ───────────────────────────────────────────────

  Widget _buildData(Color ink, Color muted) {
    final rows = _dataFilteredRows;
    final pageCount = rows.isEmpty ? 0 : ((rows.length + _pageSize - 1) ~/ _pageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _dataPage.clamp(0, maxPage);
    final start = page * _pageSize;
    final pageRows = rows.isEmpty
        ? <Expense>[]
        : rows.sublist(start, (start + _pageSize).clamp(0, rows.length));
    final isDefaultFilter =
        _dataFilterMonth == null && _dataFilterYear == null && _exportFormat == 'csv';
    final monthLabel =
        _dataFilterMonth == null ? 'All months' : kMonthNames[_dataFilterMonth! - 1];
    final yearLabel = _dataFilterYear == null ? 'All years' : '$_dataFilterYear';
    final periodTitle = '$monthLabel · $yearLabel';

    return RefreshIndicator(
      onRefresh: () async {
        await _reload();
        await _loadSummaries();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                ),
                Text(
                  'Filter expenses, then export as CSV or PDF',
                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 12),
                // Month + Year — defaults All months / All years (like Card spends)
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
                              // 0 = All months
                              final options = <int>[0, ...List.generate(12, (i) => i + 1)];
                              final selected = _dataFilterMonth ?? 0;
                              final v = await _showOptionSheet<int>(
                                title: 'Month',
                                options: options,
                                labelOf: (m) => m == 0 ? 'All months' : kMonthNames[m - 1],
                                selected: selected,
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
                              // 0 = All years
                              final years = List.generate(7, (i) => DateTime.now().year - i);
                              final options = <int>[0, ...years];
                              final selected = _dataFilterYear ?? 0;
                              final v = await _showOptionSheet<int>(
                                title: 'Year',
                                options: options,
                                labelOf: (y) => y == 0 ? 'All years' : '$y',
                                selected: selected,
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
                    );
                    if (v != null) setState(() => _exportFormat = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: rows.isEmpty ? null : () => _downloadFiltered(),
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
                        onPressed: isDefaultFilter ? null : _resetDataFilters,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Expenses · $periodTitle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                ),
              ),
              Text(
                '${rows.length} total',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
              ),
            ],
          ),
          if (pageCount > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Page ${page + 1} of $pageCount · 5 per page',
                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                ),
                const Spacer(),
                _pageNav(
                  label: '${page + 1}/$pageCount',
                  canPrev: page > 0,
                  canNext: page < maxPage,
                  onPrev: () => setState(() => _dataPage = page - 1),
                  onNext: () => setState(() => _dataPage = page + 1),
                  muted: muted,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _empty(
              _list.isEmpty
                  ? 'No expenses yet.'
                  : 'No expenses match these filters.',
              muted,
            )
          else
            ...pageRows.map((e) => _expenseTile(e, ink, muted)),
        ],
      ),
    );
  }

  /// e.g. "2025-07-19" → "19 July"
  String _weekDayMonth(String iso) {
    try {
      final d = DateTime.parse(iso.length >= 10 ? iso.substring(0, 10) : iso);
      return DateFormat('d MMMM').format(d);
    } catch (_) {
      return iso;
    }
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

  // ─── shared widgets ───────────────────────────────────────────────────────

  Widget _periodPicker(Color ink, Color muted) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Month', muted),
              const SizedBox(height: 6),
              _pickerField(
                value: kMonthNames[_month - 1],
                ink: ink,
                muted: muted,
                icon: Icons.calendar_view_month_rounded,
                onTap: () async {
                  final months = List.generate(12, (i) => i + 1);
                  final v = await _showOptionSheet<int>(
                    title: 'Month',
                    options: months,
                    labelOf: (m) => kMonthNames[m - 1],
                    selected: _month,
                  );
                  if (v != null) {
                    setState(() {
                      _month = v;
                      _dataPage = 0;
                    });
                    await _loadSummaries();
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
                value: '$_year',
                ink: ink,
                muted: muted,
                icon: Icons.event_rounded,
                onTap: () async {
                  final years = List.generate(7, (i) => DateTime.now().year - i);
                  final v = await _showOptionSheet<int>(
                    title: 'Year',
                    options: years,
                    labelOf: (y) => '$y',
                    selected: _year,
                  );
                  if (v != null) {
                    setState(() {
                      _year = v;
                      _dataPage = 0;
                    });
                    await _loadSummaries();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact themed field that opens a bottom sheet (avoids huge Material menus).
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: ink,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Rounded app-themed option sheet — never clips left/right, height hugs content.
  Future<T?> _showOptionSheet<T>({
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    required T selected,
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
          // Keep clear of screen edges so nothing clips left/right.
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
                          child: const Icon(Icons.list_rounded, size: 18, color: _brand),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final opt = options[i];
                        final isSel = opt == selected;
                        return Material(
                          color: isSel
                              ? _brand.withValues(alpha: isDark ? 0.22 : 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, opt),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      labelOf(opt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                        color: isSel ? _brand : ink,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  if (isSel)
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

  /// Compact rounded calendar sheet with quick year / month jump.
  Future<DateTime?> _showCompactDatePicker(DateTime initial) {
    final first = DateTime(2020);
    final last = DateTime.now().add(const Duration(days: 1));
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.52;
    final years = List.generate(last.year - first.year + 1, (i) => first.year + i).reversed.toList();

    var viewMonth = DateTime(initial.year, initial.month);
    var selected = DateTime(initial.year, initial.month, initial.day);
    // day | month | year
    var mode = 'day';

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final daysInMonth = DateUtils.getDaysInMonth(viewMonth.year, viewMonth.month);
            final firstWeekday = DateTime(viewMonth.year, viewMonth.month, 1).weekday; // Mon=1
            final leading = firstWeekday - 1;
            final totalCells = leading + daysInMonth;
            final rows = ((totalCells + 6) ~/ 7);

            final canPrev = DateTime(viewMonth.year, viewMonth.month)
                .isAfter(DateTime(first.year, first.month));
            final canNext = DateTime(viewMonth.year, viewMonth.month)
                .isBefore(DateTime(last.year, last.month));

            Widget chip({
              required String label,
              required bool active,
              required VoidCallback onTap,
            }) {
              return Material(
                color: active
                    ? _brand.withValues(alpha: isDark ? 0.28 : 0.12)
                    : AppColors.softPurpleOf(context),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: active ? _brand : ink,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: active ? _brand : muted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget body;
            if (mode == 'year') {
              body = ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: years.length,
                  itemBuilder: (_, i) {
                    final y = years[i];
                    final isSel = y == viewMonth.year;
                    return Material(
                      color: isSel
                          ? _brand
                          : AppColors.softPurpleOf(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setLocal(() {
                          viewMonth = DateTime(y, viewMonth.month);
                          mode = 'month';
                        }),
                        child: Center(
                          child: Text(
                            '$y',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isSel ? Colors.white : ink,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            } else if (mode == 'month') {
              body = Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: 12,
                  itemBuilder: (_, i) {
                    final m = i + 1;
                    final candidate = DateTime(viewMonth.year, m);
                    final tooEarly = candidate.isBefore(DateTime(first.year, first.month));
                    final tooLate = candidate.isAfter(DateTime(last.year, last.month));
                    final disabled = tooEarly || tooLate;
                    final isSel = m == viewMonth.month;
                    return Material(
                      color: isSel
                          ? _brand
                          : disabled
                              ? muted.withValues(alpha: 0.08)
                              : AppColors.softPurpleOf(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: disabled
                            ? null
                            : () => setLocal(() {
                                  viewMonth = DateTime(viewMonth.year, m);
                                  mode = 'day';
                                }),
                        child: Center(
                          child: Text(
                            kMonthNames[i].substring(0, 3),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isSel
                                  ? Colors.white
                                  : disabled
                                      ? muted.withValues(alpha: 0.4)
                                      : ink,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            } else {
              body = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                    child: Row(
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                          .map(
                            (d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: List.generate(rows, (r) {
                        return Row(
                          children: List.generate(7, (c) {
                            final idx = r * 7 + c;
                            final dayNum = idx - leading + 1;
                            if (dayNum < 1 || dayNum > daysInMonth) {
                              return const Expanded(child: SizedBox(height: 36));
                            }
                            final date = DateTime(viewMonth.year, viewMonth.month, dayNum);
                            final enabled = !date.isBefore(first) && !date.isAfter(last);
                            final isSel = date.year == selected.year &&
                                date.month == selected.month &&
                                date.day == selected.day;
                            final isToday = date.year == DateTime.now().year &&
                                date.month == DateTime.now().month &&
                                date.day == DateTime.now().day;

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Material(
                                  color: isSel
                                      ? _brand
                                      : isToday
                                          ? _brand.withValues(alpha: isDark ? 0.2 : 0.08)
                                          : Colors.transparent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: enabled
                                        ? () => setLocal(() => selected = date)
                                        : null,
                                    child: SizedBox(
                                      height: 34,
                                      child: Center(
                                        child: Text(
                                          '$dayNum',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: isSel || isToday
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: !enabled
                                                ? muted.withValues(alpha: 0.35)
                                                : isSel
                                                    ? Colors.white
                                                    : ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ],
              );
            }

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
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.calendar_today_rounded, size: 16, color: _brand),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                mode == 'year'
                                    ? 'Select year'
                                    : mode == 'month'
                                        ? 'Select month'
                                        : 'Select date',
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
                      // Month + year jump chips + prev/next
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                        child: Row(
                          children: [
                            if (mode == 'day')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: canPrev
                                    ? () => setLocal(() {
                                          viewMonth = DateTime(viewMonth.year, viewMonth.month - 1);
                                        })
                                    : null,
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: canPrev ? ink : muted.withValues(alpha: 0.35),
                                ),
                              )
                            else
                              const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  chip(
                                    label: kMonthNames[viewMonth.month - 1].substring(0, 3),
                                    active: mode == 'month',
                                    onTap: () => setLocal(() => mode = mode == 'month' ? 'day' : 'month'),
                                  ),
                                  chip(
                                    label: '${viewMonth.year}',
                                    active: mode == 'year',
                                    onTap: () => setLocal(() => mode = mode == 'year' ? 'day' : 'year'),
                                  ),
                                ],
                              ),
                            ),
                            if (mode == 'day')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: canNext
                                    ? () => setLocal(() {
                                          viewMonth = DateTime(viewMonth.year, viewMonth.month + 1);
                                        })
                                    : null,
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  color: canNext ? ink : muted.withValues(alpha: 0.35),
                                ),
                              )
                            else
                              const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      body,
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  if (mode != 'day') {
                                    setLocal(() => mode = 'day');
                                  } else {
                                    Navigator.pop(ctx);
                                  }
                                },
                                child: Text(
                                  mode != 'day' ? 'Back' : 'Cancel',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: mode != 'day'
                                    ? () => setLocal(() => mode = 'day')
                                    : () {
                                        // Clamp selected day if month/year jumped past old day
                                        final dim = DateUtils.getDaysInMonth(
                                          viewMonth.year,
                                          viewMonth.month,
                                        );
                                        final day = selected.day.clamp(1, dim);
                                        var out = DateTime(viewMonth.year, viewMonth.month, day);
                                        if (out.isBefore(first)) out = first;
                                        if (out.isAfter(last)) out = last;
                                        Navigator.pop(ctx, out);
                                      },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _brand,
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  mode != 'day' ? 'Show calendar' : 'Done',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _weekCard(WeekSummary w, Color ink, Color muted) {
    final cats = w.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
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
                        '${_weekDayMonth(w.weekStart)} – ${_weekDayMonth(w.weekEnd)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: 13),
                      ),
                      Text(
                        '${w.expenses.length} items this week',
                        style: GoogleFonts.inter(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: AppColors.isDark(context) ? 0.22 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatMoney(w.total),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _brand, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_weekShowChart) ...[
              if (cats.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No chart data', style: TextStyle(color: muted))),
                )
              else ...[
                SizedBox(
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _pie(Map.fromEntries(cats), ring: true, compact: false),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Week',
                            style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            formatMoney(w.total),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: ink),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cats.map((e) {
                    final color = _categoryColor(e.key);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_categoryIcon(e.key), size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            e.key,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ] else ...[
              if (w.expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No items this week', style: TextStyle(color: muted))),
                )
              else
                // Show every item in this week (no 5-item cap).
                ...w.expenses.map((e) => _expenseTile(e, ink, muted, dense: true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expenseTile(Expense e, Color ink, Color muted, {bool dense = false}) {
    final color = _categoryColor(e.category);
    final icon = _categoryIcon(e.category);
    final isDark = AppColors.isDark(context);
    return Container(
      margin: EdgeInsets.only(bottom: dense ? 6 : 10),
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: dense ? null : AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: dense ? 36 : 42,
            height: dense ? 36 : 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: dense ? 18 : 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink, fontSize: dense ? 13 : 14),
                ),
                Text(
                  '${e.category} · ${e.paidViaLabel} · ${DateFormat('dd MMM yyyy').format(e.expenseDate)}',
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
                formatMoney(e.amount),
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: dense ? 12.5 : 13.5),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionChip(
                    icon: Icons.edit_rounded,
                    color: _brand,
                    onTap: () => _edit(e),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _actionChip(
                    icon: Icons.delete_rounded,
                    color: AppColors.danger,
                    onTap: () => _delete(e),
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

  Widget _actionChip({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: color.withValues(alpha: isDark ? 0.22 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Widget _pie(Map<String, double> byCategory, {bool ring = false, bool compact = false}) {
    final entries = byCategory.entries.toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();
    return PieChart(
      PieChartData(
        sectionsSpace: ring ? 3 : 2,
        centerSpaceRadius: ring ? (compact ? 34 : 58) : 36,
        startDegreeOffset: -90,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value,
              color: _categoryColor(entries[i].key),
              title: ring
                  ? ''
                  : (total > 0 ? '${(entries[i].value / total * 100).round()}%' : ''),
              titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              radius: ring ? (compact ? 28 : 52) : 48,
              badgeWidget: null,
            ),
        ],
      ),
    );
  }

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
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.inter(color: muted)),
    );
  }

  Widget _label(String t, Color muted) =>
      Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted));

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
}
