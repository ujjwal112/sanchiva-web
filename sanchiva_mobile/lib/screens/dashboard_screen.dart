import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/ceremony_themes.dart';
import '../core/finance_refresh.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/dashboard.dart';
import '../models/event.dart';
import '../models/expense.dart' show kMonthNames;
import '../models/loan.dart';
import '../services/dashboard_service.dart';
import '../services/event_service.dart';
import '../services/loan_service.dart';
import 'events_screen.dart';

/// Home — live snapshot of spends, income, EMIs, assets & money lent.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Classic Home hero purple (medium strength, pre-restyle look).
  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);
  static const _palette = <Color>[
    Color(0xFF7C6CFF),
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
  ];

  DashboardData? _data;
  List<EventSummary> _events = const [];
  double _cardEmiMonth = 0;
  /// Active loan EMIs whose deduction day has already arrived this month
  /// (day-wise append: day 1 ₹10k + day 3 ₹30k → ₹40k till today).
  double _loanEmiTillToday = 0;
  bool _loading = true;
  String? _error;
  int _lastRefresh = -1;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<FinanceRefresh>().token;
    if (token != _lastRefresh) {
      _lastRefresh = token;
      if (!_loading) _reload(silent: true);
    }
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        DashboardService.instance.fetch(),
        LoanService.instance.listEmis(),
        LoanService.instance.listLoans().then<List<Loan>>(
          (v) => v,
          onError: (_) => <Loan>[],
        ),
        EventService.instance.list().then<List<EventSummary>>(
          (v) => v,
          onError: (_) => <EventSummary>[],
        ),
      ]);
      final dash = results[0] as DashboardData;
      final emis = results[1] as List<CreditEmi>;
      final loans = results[2] as List<Loan>;
      final events = results[3] as List<EventSummary>;
      final now = DateTime.now();
      var cardEmi = 0.0;
      for (final e in emis) {
        if (e.isActiveIn(now.month, now.year)) cardEmi += e.amount;
      }
      // Day-wise loan EMI: append each loan once its deduction day ≤ today.
      // Example: day 1 ₹10k + day 3 ₹30k → till today = ₹40k (day 2 unchanged).
      var loanTillToday = 0.0;
      for (final loan in loans) {
        if (!loan.isActiveIn(now.month, now.year)) continue;
        final dedDay = loan.emiDeductionDate;
        if (dedDay > 0 && dedDay <= now.day) {
          loanTillToday += loan.emiAmount;
        }
      }
      if (!mounted) return;
      setState(() {
        _data = dash;
        _events = events;
        _cardEmiMonth = cardEmi;
        _loanEmiTillToday = loanTillToday;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _categoryIcon(String category) {
    final n = category.toLowerCase();
    if (n.contains('food') || n.contains('dining') || n.contains('restaurant')) {
      return Icons.restaurant_rounded;
    }
    if (n.contains('groc')) return Icons.local_grocery_store_rounded;
    if (n.contains('travel') || n.contains('uber') || n.contains('fuel')) {
      return Icons.directions_car_rounded;
    }
    if (n.contains('shop') || n.contains('ecom')) return Icons.shopping_bag_rounded;
    if (n.contains('electro')) return Icons.devices_rounded;
    if (n.contains('misc')) return Icons.category_rounded;
    return Icons.payments_rounded;
  }

  void _openEvents() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
    );
  }

  DateTime? _parseEventDay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final d = DateTime.tryParse(raw.trim());
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  EventSummary? _nextUpcomingEvent() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final upcoming = <EventSummary>[];
    for (final e in _events) {
      final day = _parseEventDay(e.eventDate);
      if (day != null && !day.isBefore(today)) upcoming.add(e);
    }
    upcoming.sort((a, b) {
      final da = _parseEventDay(a.eventDate)!;
      final db = _parseEventDay(b.eventDate)!;
      return da.compareTo(db);
    });
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthState>().user?['name']?.toString() ?? 'there';
    final first = name.trim().split(RegExp(r'\s+')).first;
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final d = _data;
    final now = DateTime.now();
    final monthName = kMonthNames[now.month - 1];

    if (_loading && d == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final k = d?.kpis;
    final totalEmi = (k?.monthlyEmi ?? 0) + _cardEmiMonth;
    final income = k?.monthIncome ?? 0;
    final spent = k?.monthExpenseTotal ?? 0;
    final loanTillToday = _loanEmiTillToday;
    final cardEmi = _cardEmiMonth;
    // Net = income − spent − card EMI (month) − loan EMI (deduction days ≤ today)
    final balance = income - spent - cardEmi - loanTillToday;
    final cats = d?.categories ?? const <NamedAmount>[];
    final catTotal = cats.fold<double>(0, (s, e) => s + e.amount);
    final trend = d?.expenseTrend ?? const <TrendPoint>[];

    return RefreshIndicator(
      onRefresh: () => _reload(),
      color: _brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Greeting
          Text(
            '${_greeting()}, $first',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMM yyyy').format(now),
            style: GoogleFonts.inter(fontSize: 13, color: muted, fontWeight: FontWeight.w500),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Material(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                title: Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reload,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Hero — net balance focus + clean Income / Spent strip
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brand, _brandDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: isDark ? 0.35 : 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          monthName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (_loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Net balance',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatMoney(balance),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _heroCashStrip(
                              label: 'Income',
                              value: formatMoney(income),
                              icon: Icons.south_west_rounded,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          Expanded(
                            child: _heroCashStrip(
                              label: 'Spent',
                              value: formatMoney(spent),
                              icon: Icons.north_east_rounded,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _heroCashStrip(
                              label: 'Card EMI',
                              value: formatMoney(cardEmi),
                              icon: Icons.credit_card_rounded,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          Expanded(
                            child: _heroCashStrip(
                              label: 'Loan till today',
                              value: formatMoney(loanTillToday),
                              icon: Icons.account_balance_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Events — kept (replaces old Quick actions)
          _eventsHomeCard(ink: ink, muted: muted, isDark: isDark, kpiCount: k?.eventsCount ?? 0),
          const SizedBox(height: 12),

          // At a glance — compact like Events
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [_brand.withValues(alpha: 0.22), AppColors.cardOf(context)]
                    : [const Color(0xFFEEEDFE), Colors.white],
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: isDark ? 0.35 : 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: _brand, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'At a glance',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5, color: ink),
                          ),
                          Text(
                            'Your money snapshot',
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.today_rounded,
                        label: 'Today spend',
                        value: formatMoney(k?.todayExpenseTotal ?? 0),
                        color: const Color(0xFFF472B6),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.calendar_month_rounded,
                        label: 'Month spend',
                        value: formatMoney(k?.monthExpenseTotal ?? 0),
                        color: const Color(0xFF60A5FA),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.savings_rounded,
                        label: 'Assets',
                        value: formatMoney(k?.assetsTotal ?? 0),
                        color: const Color(0xFF34D399),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.handshake_rounded,
                        label: 'Money lent',
                        value: formatMoney(k?.moneyGivenTotal ?? 0),
                        color: AppColors.orange,
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Loans & EMI — compact like Events
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [_brand.withValues(alpha: 0.22), AppColors.cardOf(context)]
                    : [const Color(0xFFEEEDFE), Colors.white],
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: isDark ? 0.35 : 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: _brand, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Loans & EMI',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5, color: ink),
                          ),
                          Text(
                            'Total EMI this month',
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(totalEmi),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _brand),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.tag_rounded,
                        label: 'Active loans',
                        value: '${k?.activeLoans ?? 0}',
                        color: _brand,
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.today_rounded,
                        label: 'Today EMI',
                        value: formatMoney(k?.todayLoanEmi ?? 0),
                        color: AppColors.orange,
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.account_balance_rounded,
                        label: 'Loan EMI',
                        value: formatMoney(k?.monthlyEmi ?? 0),
                        color: const Color(0xFFF472B6),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.payments_rounded,
                        label: 'Card EMI',
                        value: formatMoney(_cardEmiMonth),
                        color: const Color(0xFF60A5FA),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Top spending — Loans & EMI shell, white chips with color outline
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [_brand.withValues(alpha: 0.22), AppColors.cardOf(context)]
                    : [const Color(0xFFEEEDFE), Colors.white],
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF472B6).withValues(alpha: isDark ? 0.28 : 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pie_chart_rounded, color: Color(0xFFDB2777), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top spending',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5, color: ink),
                          ),
                          Text(
                            'Daily expense · $monthName',
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (cats.isNotEmpty)
                      Text(
                        formatMoney(catTotal),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ink),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (cats.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No spends this month yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  ...List.generate(cats.length, (i) {
                    final c = cats[i];
                    final color = _palette[i % _palette.length];
                    final pct = catTotal > 0 ? c.amount / catTotal : 0.0;
                    return Container(
                      margin: EdgeInsets.only(bottom: i == cats.length - 1 ? 0 : 6),
                      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_categoryIcon(c.name), size: 14, color: color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5, color: ink),
                                ),
                              ),
                              Text(
                                '${(pct * 100).round()}%',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: muted),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatMoney(c.amount),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5, color: ink),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: color.withValues(alpha: isDark ? 0.15 : 0.12),
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

          // Spend trend — Loans & EMI shell, white chart panel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [_brand.withValues(alpha: 0.22), AppColors.cardOf(context)]
                    : [const Color(0xFFEEEDFE), Colors.white],
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22D3EE).withValues(alpha: isDark ? 0.28 : 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.show_chart_rounded, color: Color(0xFF0891B2), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spend trend',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5, color: ink),
                          ),
                          Text(
                            'Daily expenses · last 6 months',
                            style: GoogleFonts.inter(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (trend.isNotEmpty)
                      Text(
                        formatMoney(trend.fold<double>(0, (s, e) => s + e.total)),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ink),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (trend.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFF22D3EE).withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      'Not enough data yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFF22D3EE).withValues(alpha: 0.16),
                      ),
                    ),
                    child: SizedBox(height: 132, child: _trendBars(trend, muted, isDark)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  /// Flat Income / Spent strip cell (no nested box).
  Widget _heroCashStrip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventsHomeCard({
    required Color ink,
    required Color muted,
    required bool isDark,
    required int kpiCount,
  }) {
    final count = _events.isNotEmpty ? _events.length : kpiCount;
    final planning =
        _events.where((e) => e.lifecycleStatus == 'planning').length;
    final next = _nextUpcomingEvent();
    final nextType = next == null ? null : eventTypeStyle(next.eventType);
    final nextDate = next == null ? '' : formatDate(next.eventDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openEvents,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFFE879F9).withValues(alpha: 0.2), AppColors.cardOf(context)]
                  : [const Color(0xFFFDF2FF), Colors.white],
            ),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE879F9).withValues(alpha: isDark ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.celebration_rounded, color: Color(0xFFD946EF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Events',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5, color: ink),
                        ),
                        Text(
                          count == 0
                              ? 'Plan weddings, parties and celebrations'
                              : (count == 1 ? '1 event in your workspace' : '$count events in your workspace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              if (count == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No events yet. Tap to create your first one.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.event_available_rounded,
                        label: 'Total',
                        value: '$count',
                        color: const Color(0xFFE879F9),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _eventsMiniTile(
                        icon: Icons.edit_calendar_rounded,
                        label: 'Planning',
                        value: '$planning',
                        color: const Color(0xFFA78BFA),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFE879F9).withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: (nextType?.$2 ?? const Color(0xFFE879F9))
                                .withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            nextType?.$1 ?? Icons.event_rounded,
                            size: 15,
                            color: nextType?.$2 ?? const Color(0xFFE879F9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next up',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: muted,
                                ),
                              ),
                              Text(
                                next.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (nextDate.isNotEmpty)
                          Text(
                            nextDate,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: nextType?.$2 ?? const Color(0xFFE879F9),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventsMiniTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color ink,
    required Color muted,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendBars(List<TrendPoint> trend, Color muted, bool isDark) {
    final maxY = trend.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    final top = (maxY <= 0 ? 1.0 : maxY) * 1.22;
    return BarChart(
      BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, gi, rod, ri) {
              final e = trend[group.x.toInt()];
              String short = e.label;
              if (e.label.length >= 7) {
                final m = int.tryParse(e.label.substring(5, 7)) ?? 1;
                short = kMonthNames[m - 1];
              }
              return BarTooltipItem(
                '$short\n${formatMoney(e.total)}',
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                final label = trend[i].label;
                String short = label;
                if (label.length >= 7) {
                  final m = int.tryParse(label.substring(5, 7)) ?? 1;
                  short = kMonthNames[m - 1].substring(0, 3);
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short,
                    style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: muted.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(trend.length, (i) {
          final isLast = i == trend.length - 1;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: trend[i].total,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isLast
                      ? const [_brand, _brandDeep]
                      : [
                          _brand.withValues(alpha: isDark ? 0.45 : 0.35),
                          _brand.withValues(alpha: isDark ? 0.75 : 0.65),
                        ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
