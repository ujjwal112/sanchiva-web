import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/finance_refresh.dart';
import '../core/format.dart';
import '../core/shell_nav.dart';
import '../core/theme.dart';
import '../models/dashboard.dart';
import '../models/expense.dart' show kMonthNames;
import '../models/loan.dart';
import '../services/dashboard_service.dart';
import '../services/loan_service.dart';

/// Home — live snapshot of spends, income, EMIs, assets & money lent.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
  double _cardEmiMonth = 0;
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
      ]);
      final dash = results[0] as DashboardData;
      final emis = results[1] as List<CreditEmi>;
      final now = DateTime.now();
      var cardEmi = 0.0;
      for (final e in emis) {
        if (e.isActiveIn(now.month, now.year)) cardEmi += e.amount;
      }
      if (!mounted) return;
      setState(() {
        _data = dash;
        _cardEmiMonth = cardEmi;
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

  // KPI cards → Data tab of the matching section
  void _openDailySpend() => context.read<ShellNav>().open(tab: 0, subTab: 2);

  void _openCardEmi() =>
      context.read<ShellNav>().open(tab: 1, loansArea: 'emis', subTab: 2);

  void _openAssets() =>
      context.read<ShellNav>().open(tab: 3, monetaryArea: 'assets', subTab: 2);

  void _openMoneyLent() =>
      context.read<ShellNav>().open(tab: 3, monetaryArea: 'lent', subTab: 2);

  // Quick actions → Entry / first section of that area
  void _qaAddSpend() => context.read<ShellNav>().open(tab: 0, subTab: 0);

  void _qaLoans() =>
      context.read<ShellNav>().open(tab: 1, loansArea: 'loans', subTab: 0);

  void _qaMonetary() =>
      context.read<ShellNav>().open(tab: 3, monetaryArea: 'currency', subTab: 0);

  void _qaSplits() => context.read<ShellNav>().open(tab: 4, subTab: 0);

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
    final spend = (k?.monthExpenseTotal ?? 0) + (k?.ccSpendMonth ?? 0) + totalEmi;
    final income = k?.monthIncome ?? 0;
    // Cash-flow style balance: income − daily − EMI (card spend optional; include daily+EMI primary)
    final balance = income - (k?.monthExpenseTotal ?? 0) - totalEmi;
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

          // Hero — this month cash flow
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brand, _brandDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: isDark ? 0.4 : 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$monthName ${now.year}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Net balance',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(balance),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _heroStat(
                        'Income',
                        formatMoney(income),
                        Icons.trending_up_rounded,
                      ),
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    Expanded(
                      child: _heroStat(
                        'Spent',
                        formatMoney(k?.monthExpenseTotal ?? 0),
                        Icons.trending_down_rounded,
                      ),
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    Expanded(
                      child: _heroStat(
                        'EMI',
                        formatMoney(totalEmi),
                        Icons.account_balance_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick actions — above KPI cards; open Entry / first section
          Text(
            'Quick actions',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.receipt_long_rounded,
                  label: 'Add spend',
                  color: const Color(0xFFF472B6),
                  onTap: _qaAddSpend,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.account_balance_rounded,
                  label: 'Loans',
                  color: _brand,
                  onTap: _qaLoans,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.currency_exchange_rounded,
                  label: 'Monetary',
                  color: const Color(0xFF34D399),
                  onTap: _qaMonetary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.call_split_rounded,
                  label: 'Splits',
                  color: const Color(0xFF0EA5E9),
                  onTap: _qaSplits,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // KPI tiles → Data of matching section
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Daily spend',
                  value: formatMoney(k?.monthExpenseTotal ?? 0),
                  color: const Color(0xFFF472B6),
                  icon: Icons.receipt_long_rounded,
                  onTap: _openDailySpend,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  label: 'Card EMI',
                  value: formatMoney(_cardEmiMonth),
                  color: const Color(0xFF60A5FA),
                  icon: Icons.payments_rounded,
                  onTap: _openCardEmi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Assets',
                  value: formatMoney(k?.assetsTotal ?? 0),
                  color: const Color(0xFF34D399),
                  icon: Icons.savings_rounded,
                  onTap: _openAssets,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  label: 'Money lent',
                  value: formatMoney(k?.moneyGivenTotal ?? 0),
                  color: AppColors.orange,
                  icon: Icons.handshake_rounded,
                  onTap: _openMoneyLent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Loans & EMI — display only (not tappable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderOf(context)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        _brand.withValues(alpha: 0.22),
                        AppColors.cardOf(context),
                      ]
                    : [
                        const Color(0xFFEEEDFE),
                        Colors.white,
                      ],
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: isDark ? 0.35 : 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: _brand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Loans & EMI',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: ink,
                            ),
                          ),
                          Text(
                            'Total EMI this month',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(totalEmi),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _loanTile(
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
                      child: _loanTile(
                        icon: Icons.account_balance_rounded,
                        label: 'Loan EMI',
                        value: formatMoney(k?.monthlyEmi ?? 0),
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
                      child: _loanTile(
                        icon: Icons.payments_rounded,
                        label: 'Card EMI',
                        value: formatMoney(_cardEmiMonth),
                        color: const Color(0xFF60A5FA),
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _loanTile(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'Remaining',
                        value: formatMoney(d?.loanMonth.remainingToDeduct ?? 0),
                        color: const Color(0xFFF472B6),
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

          // Top spending — display only
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF472B6).withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        color: Color(0xFFDB2777),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top spending',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: ink,
                            ),
                          ),
                          Text(
                            'Daily expense · $monthName',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    if (cats.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatMoney(catTotal),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (cats.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: AppColors.softPurpleOf(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 28,
                          color: muted.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No spends this month yet',
                          style: GoogleFonts.inter(
                            color: muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...List.generate(cats.length, (i) {
                    final c = cats[i];
                    final color = _palette[i % _palette.length];
                    final pct = catTotal > 0 ? c.amount / catTotal : 0.0;
                    return Container(
                      margin: EdgeInsets.only(bottom: i == cats.length - 1 ? 0 : 8),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : AppColors.softPurpleOf(context).withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : color.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.24 : 0.14),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(_categoryIcon(c.name), size: 18, color: color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: ink,
                                  ),
                                ),
                              ),
                              Text(
                                '${(pct * 100).round()}%',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatMoney(c.amount),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 7,
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

          // Spend trend
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22D3EE).withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.show_chart_rounded,
                        color: Color(0xFF0891B2),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spend trend',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: ink,
                            ),
                          ),
                          Text(
                            'Daily expenses · last 6 months',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    if (trend.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Period total',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatMoney(trend.fold<double>(0, (s, e) => s + e.total)),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (trend.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: AppColors.softPurpleOf(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.bar_chart_rounded, size: 28, color: muted.withValues(alpha: 0.7)),
                        const SizedBox(height: 8),
                        Text(
                          'Not enough data yet',
                          style: GoogleFonts.inter(color: muted, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 180,
                    child: _trendBars(trend, muted, isDark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loanTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color ink,
    required Color muted,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: ink),
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
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: child,
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final isDark = AppColors.isDark(context);
    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
