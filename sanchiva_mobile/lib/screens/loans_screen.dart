import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import '../core/finance_refresh.dart';
import '../core/format.dart';
import '../core/settings_state.dart';
import '../core/shell_nav.dart';
import '../core/theme.dart';
import '../models/loan.dart';
import '../services/loan_service.dart';
import '../services/notification_service.dart';
import '../services/table_export.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snack.dart';
import '../widgets/section_header_card.dart';

/// Loans & Credit — Loans (default) or Credit Card (Spends / EMIs).
/// Each area has Entry · Charts · Data (list only on Data).
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

enum _Area { loans, ccSpends, ccEmis }

class _LoansScreenState extends State<LoansScreen> with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);

  final _svc = LoanService.instance;
  late final TabController _tabs;

  _Area _area = _Area.loans;
  int _deepLinkToken = -1;

  // Data
  List<Loan> _loans = [];
  LoanSummary? _loanSummary;
  List<CreditSpend> _spends = [];
  List<CreditEmi> _emis = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Loan form
  final _loanBankCtrl = TextEditingController();
  final _loanEmiBankCtrl = TextEditingController();
  final _loanEmiAmtCtrl = TextEditingController();
  final _loanRoiCtrl = TextEditingController();
  int _loanDeductionDay = 5;
  int _loanCloseMonth = 12;
  int _loanCloseYear = DateTime.now().year + 2;
  int _loanStartMonth = DateTime.now().month;
  int _loanStartYear = DateTime.now().year;
  String _loanStatus = 'ongoing';
  int? _loanEditId;

  // CC spend form
  final _spendCardCtrl = TextEditingController();
  final _spendAmtCtrl = TextEditingController();
  final _spendCustomCtrl = TextEditingController();
  String _spendType = kSpendTypes.first;
  DateTime _spendDate = DateTime.now();
  int? _spendEditId;

  // CC EMI form
  final _emiNameCtrl = TextEditingController();
  final _emiCardCtrl = TextEditingController();
  final _emiAmtCtrl = TextEditingController();
  final _emiRoiCtrl = TextEditingController();
  int _emiStartMonth = DateTime.now().month;
  int _emiStartYear = DateTime.now().year;
  int _emiEndMonth = 12;
  int _emiEndYear = DateTime.now().year + 1;
  int? _emiEditId;

  int _dataPage = 0;
  static const _pageSize = 5; // spends / EMIs
  static const _loanPageSize = 4; // 2x2 square grid
  /// Charts: pie vs breakdown list (like Daily expense).
  bool _monthlyShowChart = true;
  bool _overallShowChart = true;
  bool _closureShowChart = true;
  bool _bankEmiShowChart = true;
  /// Card spends charts: period + per-section chart/list toggles.
  int _spendChartMonth = DateTime.now().month;
  int _spendChartYear = DateTime.now().year;
  bool _spendTypeShowChart = true;
  bool _spendCardShowChart = true;
  /// Card EMI charts: total pie + current-month bar.
  bool _emiTotalShowChart = true;
  bool _emiMonthlyShowChart = true;
  String _exportFormat = 'csv'; // csv | pdf
  /// Loans Data filters
  int? _loanFilterYear; // null = all years
  String _loanFilterStatus = 'all'; // all | ongoing | closed
  /// Card spends Data filters (null = all)
  int? _spendDataMonth;
  int? _spendDataYear;
  /// Card EMI Data filters (like Loans)
  int? _emiFilterYear; // end year; null = all
  String _emiFilterStatus = 'all'; // all | ongoing | completed

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.watch<ShellNav>();
    if (nav.index != 1) return;
    if (nav.deepLinkToken == _deepLinkToken) return;
    final areaKey = nav.pendingLoansArea;
    if (areaKey == null) return;
    final mapped = switch (areaKey) {
      'loans' => _Area.loans,
      // Card spends disabled — fall through to EMIs if requested.
      'spends' => _Area.ccEmis,
      'emis' => _Area.ccEmis,
      _ => null,
    };
    if (mapped == null) return;
    _deepLinkToken = nav.deepLinkToken;
    final sub = nav.pendingSubTab.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _area = mapped;
        _dataPage = 0;
        if (_tabs.index != sub) _tabs.index = sub;
      });
      nav.clearLoansDeepLink();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loanBankCtrl.dispose();
    _loanEmiBankCtrl.dispose();
    _loanEmiAmtCtrl.dispose();
    _loanRoiCtrl.dispose();
    _spendCardCtrl.dispose();
    _spendAmtCtrl.dispose();
    _spendCustomCtrl.dispose();
    _emiNameCtrl.dispose();
    _emiCardCtrl.dispose();
    _emiAmtCtrl.dispose();
    _emiRoiCtrl.dispose();
    super.dispose();
  }

  String get _areaTitle {
    switch (_area) {
      case _Area.loans:
        return 'Loans';
      case _Area.ccSpends:
        return 'Card spends';
      case _Area.ccEmis:
        return 'Card EMIs';
    }
  }

  String get _areaSubtitle {
    switch (_area) {
      case _Area.loans:
        return 'Bank loans, EMI progress, and schedules';
      case _Area.ccSpends:
        return 'Purchases and spends on your cards';
      case _Area.ccEmis:
        return 'Installment plans on credit cards';
    }
  }

  IconData get _areaIcon {
    switch (_area) {
      case _Area.loans:
        return Icons.account_balance_rounded;
      case _Area.ccSpends:
        return Icons.shopping_bag_rounded;
      case _Area.ccEmis:
        return Icons.payments_rounded;
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loans = await _svc.listLoans();
      LoanSummary? lsum;
      try {
        lsum = await _svc.loanSummary();
      } catch (_) {}
      final spends = await _svc.listSpends();
      final emis = await _svc.listEmis();
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _loanSummary = lsum;
        _spends = spends;
        _emis = emis;
        _loading = false;
        _dataPage = 0;
      });
      // Salary charts include loan / card EMI as spend — refresh them.
      if (mounted) context.read<FinanceRefresh>().bump();
      // Inbox history always; system deduction-day schedules only if push enabled.
      await NotificationService.instance.ensureInboxEntries();
      if (mounted && context.read<SettingsState>().notificationsEnabled) {
        await NotificationService.instance.scheduleLoanEmiReminders(loans);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _resetLoanForm() {
    _loanEditId = null;
    _loanBankCtrl.clear();
    _loanEmiBankCtrl.clear();
    _loanEmiAmtCtrl.clear();
    _loanRoiCtrl.clear();
    _loanDeductionDay = 5;
    _loanCloseMonth = 12;
    _loanCloseYear = DateTime.now().year + 2;
    _loanStartMonth = DateTime.now().month;
    _loanStartYear = DateTime.now().year;
    _loanStatus = 'ongoing';
  }

  void _resetSpendForm() {
    _spendEditId = null;
    _spendCardCtrl.clear();
    _spendAmtCtrl.clear();
    _spendCustomCtrl.clear();
    _spendType = kSpendTypes.first;
    _spendDate = DateTime.now();
  }

  void _resetEmiForm() {
    _emiEditId = null;
    _emiNameCtrl.clear();
    _emiCardCtrl.clear();
    _emiAmtCtrl.clear();
    _emiRoiCtrl.clear();
    _emiStartMonth = DateTime.now().month;
    _emiStartYear = DateTime.now().year;
    _emiEndMonth = 12;
    _emiEndYear = DateTime.now().year + 1;
  }

  Future<void> _submitLoan() async {
    final bank = _loanBankCtrl.text.trim();
    final emiBank = _loanEmiBankCtrl.text.trim();
    final amt = double.tryParse(_loanEmiAmtCtrl.text.trim().replaceAll(',', ''));
    final roiRaw = _loanRoiCtrl.text.trim().replaceAll(',', '');
    final roi = roiRaw.isEmpty ? 0.0 : double.tryParse(roiRaw);
    if (bank.isEmpty || emiBank.isEmpty || amt == null || amt < 0) {
      AppSnack.warning(context, 'Fill bank names and a valid EMI amount');
      return;
    }
    // ROI optional — blank means 0%; only reject garbage input.
    if (roi == null || roi < 0) {
      AppSnack.warning(context, 'ROI must be a number ≥ 0 (or leave blank for 0%)');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'bank_name': bank,
        'emi_deduction_bank': emiBank,
        'emi_deduction_date': _loanDeductionDay,
        'emi_close_month': _loanCloseMonth,
        'emi_close_year': _loanCloseYear,
        'emi_amount': amt,
        'roi': roi,
        'status': _loanStatus,
        'start_month': _loanStartMonth,
        'start_year': _loanStartYear,
      };
      if (_loanEditId != null) {
        await _svc.updateLoan(_loanEditId!, body);
        AppSnack.success(context, 'Loan updated', icon: Icons.edit_rounded);
      } else {
        await _svc.createLoan(body);
        AppSnack.success(context, 'Loan added', icon: Icons.add_circle_rounded);
      }
      _resetLoanForm();
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitSpend() async {
    final card = _spendCardCtrl.text.trim();
    final amt = double.tryParse(_spendAmtCtrl.text.trim().replaceAll(',', ''));
    final type = _spendType == 'Other' && _spendCustomCtrl.text.trim().isNotEmpty
        ? _spendCustomCtrl.text.trim()
        : _spendType;
    if (card.isEmpty || amt == null || amt < 0 || type.isEmpty) {
      AppSnack.warning(context, 'Fill card, type and a valid amount');
      return;
    }
    setState(() => _saving = true);
    try {
      final dateIso =
          '${_spendDate.year.toString().padLeft(4, '0')}-${_spendDate.month.toString().padLeft(2, '0')}-${_spendDate.day.toString().padLeft(2, '0')}';
      final body = {
        'spend_date': dateIso,
        'spend_type': type,
        'credit_card_name': card,
        'amount': amt,
      };
      if (_spendEditId != null) {
        await _svc.updateSpend(_spendEditId!, body);
        AppSnack.success(context, 'Spend updated', icon: Icons.edit_rounded);
      } else {
        await _svc.createSpend(body);
        AppSnack.success(context, 'Spend added', icon: Icons.add_circle_rounded);
      }
      _resetSpendForm();
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitEmi() async {
    final name = _emiNameCtrl.text.trim();
    final card = _emiCardCtrl.text.trim();
    final amt = double.tryParse(_emiAmtCtrl.text.trim().replaceAll(',', ''));
    final roiRaw = _emiRoiCtrl.text.trim().replaceAll(',', '');
    final roi = roiRaw.isEmpty ? 0.0 : double.tryParse(roiRaw);
    if (name.isEmpty || card.isEmpty || amt == null || amt < 0) {
      AppSnack.warning(context, 'Fill EMI name, card and amount');
      return;
    }
    // ROI optional — blank means 0%; only reject garbage input.
    if (roi == null || roi < 0) {
      AppSnack.warning(context, 'ROI must be a number ≥ 0 (or leave blank for 0%)');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'emi_name': name,
        'credit_card_name': card,
        'start_month': _emiStartMonth,
        'start_year': _emiStartYear,
        'end_month': _emiEndMonth,
        'end_year': _emiEndYear,
        'amount': amt,
        'roi': roi,
      };
      if (_emiEditId != null) {
        await _svc.updateEmi(_emiEditId!, body);
        AppSnack.success(context, 'Card EMI updated', icon: Icons.edit_rounded);
      } else {
        await _svc.createEmi(body);
        AppSnack.success(context, 'Card EMI added', icon: Icons.add_circle_rounded);
      }
      _resetEmiForm();
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteLoan(Loan l) async {
    final ok = await _confirmDelete('Delete loan?', '${l.bankName} · ${formatMoney(l.emiAmount)} EMI');
    if (ok != true) return;
    try {
      await _svc.deleteLoan(l.id);
      AppSnack.danger(context, 'Loan deleted');
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    }
  }

  Future<void> _deleteSpend(CreditSpend s) async {
    final ok = await _confirmDelete('Delete spend?', '${s.creditCardName} · ${formatMoney(s.amount)}');
    if (ok != true) return;
    try {
      await _svc.deleteSpend(s.id);
      AppSnack.danger(context, 'Spend deleted');
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    }
  }

  Future<void> _deleteEmi(CreditEmi e) async {
    final ok = await _confirmDelete('Delete card EMI?', '${e.emiName} · ${formatMoney(e.amount)}');
    if (ok != true) return;
    try {
      await _svc.deleteEmi(e.id);
      AppSnack.danger(context, 'Card EMI deleted');
      await _reload();
    } catch (err) {
      if (mounted) AppSnack.error(context, '$err');
    }
  }

  Future<bool> _confirmDelete(String title, String body) {
    return showAppConfirmDialog(
      context,
      title: title,
      message: '$body This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.danger,
    );
  }

  void _editLoan(Loan l) {
    setState(() {
      _area = _Area.loans;
      _loanEditId = l.id;
      _loanBankCtrl.text = l.bankName;
      _loanEmiBankCtrl.text = l.emiDeductionBank;
      _loanEmiAmtCtrl.text = l.emiAmount.toString();
      _loanRoiCtrl.text = l.roi == 0
          ? ''
          : (l.roi == l.roi.roundToDouble() ? l.roi.toInt().toString() : l.roi.toString());
      _loanDeductionDay = l.emiDeductionDate;
      _loanCloseMonth = l.emiCloseMonth;
      _loanCloseYear = l.emiCloseYear;
      _loanStartMonth = l.startMonth;
      _loanStartYear = l.startYear;
      _loanStatus = l.status;
      _tabs.index = 0;
    });
  }

  void _editSpend(CreditSpend s) {
    setState(() {
      _area = _Area.ccSpends;
      _spendEditId = s.id;
      _spendCardCtrl.text = s.creditCardName;
      _spendAmtCtrl.text = s.amount.toString();
      _spendDate = s.spendDate;
      if (kSpendTypes.contains(s.spendType)) {
        _spendType = s.spendType;
        _spendCustomCtrl.clear();
      } else {
        _spendType = 'Other';
        _spendCustomCtrl.text = s.spendType;
      }
      _tabs.index = 0;
    });
  }

  void _editEmi(CreditEmi e) {
    setState(() {
      _area = _Area.ccEmis;
      _emiEditId = e.id;
      _emiNameCtrl.text = e.emiName;
      _emiCardCtrl.text = e.creditCardName;
      _emiAmtCtrl.text = e.amount.toString();
      _emiRoiCtrl.text = e.roi == 0
          ? ''
          : (e.roi == e.roi.roundToDouble() ? e.roi.toInt().toString() : e.roi.toString());
      _emiStartMonth = e.startMonth;
      _emiStartYear = e.startYear;
      _emiEndMonth = e.endMonth;
      _emiEndYear = e.endYear;
      _tabs.index = 0;
    });
  }

  /// Top dropdown to switch Loans / Card spends / Card EMIs (no + FAB).
  Future<void> _showAreaMenu() async {
    final choice = await showModalBottomSheet<_Area>(
      context: context,
      backgroundColor: Colors.transparent,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_rounded, size: 18, color: _brand),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Loans & Credit',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
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
                  const SizedBox(height: 6),
                  _menuTile(
                    icon: Icons.account_balance_rounded,
                    title: 'Loans',
                    subtitle: 'Bank loans and EMIs',
                    ink: ink,
                    muted: muted,
                    selected: _area == _Area.loans,
                    onTap: () => Navigator.pop(ctx, _Area.loans),
                  ),
                  // Card spends — temporarily off
                  // const SizedBox(height: 8),
                  // _menuTile(
                  //   icon: Icons.shopping_bag_rounded,
                  //   title: 'Card spends',
                  //   subtitle: 'Purchases on credit cards',
                  //   ink: ink,
                  //   muted: muted,
                  //   selected: _area == _Area.ccSpends,
                  //   onTap: () => Navigator.pop(ctx, _Area.ccSpends),
                  // ),
                  const SizedBox(height: 8),
                  _menuTile(
                    icon: Icons.payments_rounded,
                    title: 'Card EMIs',
                    subtitle: 'Installment plans on cards',
                    ink: ink,
                    muted: muted,
                    selected: _area == _Area.ccEmis,
                    onTap: () => Navigator.pop(ctx, _Area.ccEmis),
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
        // Card spends disabled — never stay on that area.
        _area = choice == _Area.ccSpends ? _Area.loans : choice;
        _tabs.index = 0;
        _dataPage = 0;
      });
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

    // Card spends temporarily disabled — snap back to Loans if needed.
    if (_area == _Area.ccSpends) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _area == _Area.ccSpends) {
          setState(() {
            _area = _Area.loans;
            _tabs.index = 0;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Section card (icon + title + subtitle) — tap to switch Loans / EMIs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SectionHeaderCard(
              icon: _areaIcon,
              title: _areaTitle,
              subtitle: _areaSubtitle,
              onTap: _showAreaMenu,
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
                dividerColor: Colors.transparent,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: _brand.withValues(alpha: AppColors.isDark(context) ? 0.28 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
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
      ),
    );
  }

  // ─── Entry (form only, no list) ──────────────────────────────────────────

  Widget _buildEntry(Color ink, Color muted) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          if (_area == _Area.loans) _loanEntryCard(ink, muted),
          // if (_area == _Area.ccSpends) _spendEntryCard(ink, muted), // Card spends off
          if (_area == _Area.ccEmis) _emiEntryCard(ink, muted),
        ],
      ),
    );
  }

  Widget _loanEntryCard(Color ink, Color muted) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loanEditId != null ? 'Edit loan' : 'Add loan',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
          ),
          const SizedBox(height: 14),
          _label('Bank name (loan from)', muted),
          const SizedBox(height: 6),
          TextField(controller: _loanBankCtrl, decoration: _fieldDeco(hint: 'e.g. HDFC')),
          const SizedBox(height: 12),
          _label('EMI deduction bank', muted),
          const SizedBox(height: 6),
          TextField(controller: _loanEmiBankCtrl, decoration: _fieldDeco(hint: 'e.g. SBI')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('EMI amount (₹)', muted),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _loanEmiAmtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDeco(hint: '0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('ROI / Interest (%)', muted),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _loanRoiCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDeco(hint: 'e.g. 10.5'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('Deduction day', muted),
          const SizedBox(height: 6),
          _pickerField(
            value: 'Day $_loanDeductionDay',
            ink: ink,
            muted: muted,
            icon: Icons.event_rounded,
            onTap: () async {
              final days = List.generate(31, (i) => i + 1);
              final v = await _showOptionSheet<int>(
                title: 'Deduction day',
                options: days,
                labelOf: (d) => 'Day $d',
                selected: _loanDeductionDay.clamp(1, 31),
              );
              if (v != null) setState(() => _loanDeductionDay = v);
            },
          ),
          const SizedBox(height: 12),
          // Start / End — same combined month+year pickers as Card EMI
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Start', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: '${kMonthNamesShort[_loanStartMonth - 1]} $_loanStartYear',
                      ink: ink,
                      muted: muted,
                      icon: Icons.play_arrow_rounded,
                      onTap: () async {
                        final m = await _showOptionSheet<int>(
                          title: 'Start month',
                          options: List.generate(12, (i) => i + 1),
                          labelOf: (x) => kMonthNamesShort[x - 1],
                          selected: _loanStartMonth,
                        );
                        // Only open year after a month is chosen (not on cancel/close).
                        if (m == null || !mounted) return;
                        setState(() => _loanStartMonth = m);
                        final y = DateTime.now().year;
                        final yr = await _showOptionSheet<int>(
                          title: 'Start year',
                          options: List.generate(12, (i) => y - 5 + i),
                          labelOf: (x) => '$x',
                          selected: _loanStartYear,
                        );
                        if (yr != null && mounted) setState(() => _loanStartYear = yr);
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
                    _label('End', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: '${kMonthNamesShort[_loanCloseMonth - 1]} $_loanCloseYear',
                      ink: ink,
                      muted: muted,
                      icon: Icons.stop_rounded,
                      onTap: () async {
                        final m = await _showOptionSheet<int>(
                          title: 'End month',
                          options: List.generate(12, (i) => i + 1),
                          labelOf: (x) => kMonthNamesShort[x - 1],
                          selected: _loanCloseMonth,
                        );
                        if (m == null || !mounted) return;
                        setState(() => _loanCloseMonth = m);
                        final y = DateTime.now().year;
                        final yr = await _showOptionSheet<int>(
                          title: 'End year',
                          options: List.generate(20, (i) => y + i),
                          labelOf: (x) => '$x',
                          selected: _loanCloseYear,
                        );
                        if (yr != null && mounted) setState(() => _loanCloseYear = yr);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('Status', muted),
          const SizedBox(height: 6),
          _pickerField(
            value: _loanStatus == 'closed' ? 'Closed' : 'Ongoing',
            ink: ink,
            muted: muted,
            icon: Icons.flag_rounded,
            onTap: () async {
              final v = await _showOptionSheet<String>(
                title: 'Status',
                options: const ['ongoing', 'closed'],
                labelOf: (s) => s == 'closed' ? 'Closed' : 'Ongoing',
                selected: _loanStatus,
              );
              if (v != null) setState(() => _loanStatus = v);
            },
          ),
          const SizedBox(height: 16),
          _primaryBtn(
            label: _loanEditId != null ? 'Update loan' : 'Add loan',
            icon: _loanEditId != null ? Icons.check_rounded : Icons.add_rounded,
            loading: _saving,
            onTap: _submitLoan,
          ),
          if (_loanEditId != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(_resetLoanForm),
                child: Text('Cancel edit', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: muted)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _spendEntryCard(Color ink, Color muted) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _spendEditId != null ? 'Edit card spend' : 'Add card spend',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
          ),
          const SizedBox(height: 14),
          _label('Credit card name', muted),
          const SizedBox(height: 6),
          TextField(controller: _spendCardCtrl, decoration: _fieldDeco(hint: 'e.g. HDFC Millennia')),
          const SizedBox(height: 12),
          _label('Spend type', muted),
          const SizedBox(height: 6),
          _pickerField(
            value: _spendType,
            ink: ink,
            muted: muted,
            icon: Icons.category_rounded,
            onTap: () async {
              final v = await _showOptionSheet<String>(
                title: 'Spend type',
                options: kSpendTypes,
                labelOf: (t) => t,
                selected: _spendType,
              );
              if (v != null) setState(() => _spendType = v);
            },
          ),
          if (_spendType == 'Other') ...[
            const SizedBox(height: 12),
            _label('Custom type', muted),
            const SizedBox(height: 6),
            TextField(controller: _spendCustomCtrl, decoration: _fieldDeco(hint: 'e.g. Gifts')),
          ],
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
                      controller: _spendAmtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDeco(hint: '0'),
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
                      value: DateFormat('dd MMM yyyy').format(_spendDate),
                      ink: ink,
                      muted: muted,
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        final d = await _showCompactDatePicker(_spendDate);
                        if (d != null) setState(() => _spendDate = d);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _primaryBtn(
            label: _spendEditId != null ? 'Update spend' : 'Add spend',
            icon: _spendEditId != null ? Icons.check_rounded : Icons.add_rounded,
            loading: _saving,
            onTap: _submitSpend,
          ),
          if (_spendEditId != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(_resetSpendForm),
                child: Text('Cancel edit', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: muted)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emiEntryCard(Color ink, Color muted) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _emiEditId != null ? 'Edit card EMI' : 'Add card EMI',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
          ),
          const SizedBox(height: 14),
          _label('EMI name', muted),
          const SizedBox(height: 6),
          TextField(controller: _emiNameCtrl, decoration: _fieldDeco(hint: 'e.g. Phone EMI')),
          const SizedBox(height: 12),
          _label('Credit card name', muted),
          const SizedBox(height: 6),
          TextField(controller: _emiCardCtrl, decoration: _fieldDeco(hint: 'e.g. Axis Ace')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('EMI amount (₹)', muted),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emiAmtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDeco(hint: '0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('ROI / Interest (%)', muted),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emiRoiCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDeco(hint: 'e.g. 14.5'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Start', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: '${kMonthNamesShort[_emiStartMonth - 1]} $_emiStartYear',
                      ink: ink,
                      muted: muted,
                      icon: Icons.play_arrow_rounded,
                      onTap: () async {
                        final m = await _showOptionSheet<int>(
                          title: 'Start month',
                          options: List.generate(12, (i) => i + 1),
                          labelOf: (x) => kMonthNamesShort[x - 1],
                          selected: _emiStartMonth,
                        );
                        // Only open year after a month is chosen (not on cancel/close).
                        if (m == null || !mounted) return;
                        setState(() => _emiStartMonth = m);
                        final y = DateTime.now().year;
                        // Start years from 2020 through a few years ahead.
                        final years = List.generate(y - 2020 + 3, (i) => 2020 + i);
                        final yr = await _showOptionSheet<int>(
                          title: 'Start year',
                          options: years,
                          labelOf: (x) => '$x',
                          selected: _emiStartYear < 2020 ? 2020 : _emiStartYear,
                        );
                        if (yr != null && mounted) setState(() => _emiStartYear = yr);
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
                    _label('End', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: '${kMonthNamesShort[_emiEndMonth - 1]} $_emiEndYear',
                      ink: ink,
                      muted: muted,
                      icon: Icons.stop_rounded,
                      onTap: () async {
                        final m = await _showOptionSheet<int>(
                          title: 'End month',
                          options: List.generate(12, (i) => i + 1),
                          labelOf: (x) => kMonthNamesShort[x - 1],
                          selected: _emiEndMonth,
                        );
                        if (m == null || !mounted) return;
                        setState(() => _emiEndMonth = m);
                        final y = DateTime.now().year;
                        final yr = await _showOptionSheet<int>(
                          title: 'End year',
                          options: List.generate(12, (i) => y + i),
                          labelOf: (x) => '$x',
                          selected: _emiEndYear,
                        );
                        if (yr != null && mounted) setState(() => _emiEndYear = yr);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _primaryBtn(
            label: _emiEditId != null ? 'Update EMI' : 'Add EMI',
            icon: _emiEditId != null ? Icons.check_rounded : Icons.add_rounded,
            loading: _saving,
            onTap: _submitEmi,
          ),
          if (_emiEditId != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(_resetEmiForm),
                child: Text('Cancel edit', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: muted)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Charts ──────────────────────────────────────────────────────────────

  Widget _buildCharts(Color ink, Color muted) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          if (_area == _Area.loans) ..._loanCharts(ink, muted),
          // if (_area == _Area.ccSpends) ..._spendCharts(ink, muted), // Card spends off
          if (_area == _Area.ccEmis) ..._emiCharts(ink, muted),
        ],
      ),
    );
  }

  List<Widget> _loanCharts(Color ink, Color muted) {
    final s = _loanSummary;
    final now = DateTime.now();
    final monthLabel = '${kMonthNamesShort[(s?.month ?? now.month) - 1]} ${s?.year ?? now.year}';

    // Monthly pie: of this month's total EMI, how much is already deducted
    // by today (emi_deduction_date <= today's day) vs still pending this month.
    final monthly = _monthlyEmiSplit(now);
    final monthlyPie = <String, double>{
      'Already deducted': monthly.alreadyDeducted,
      'Still to deduct': monthly.stillPending,
    };

    // Overall pie: lifetime deducted vs remaining across all loans.
    double overallDeducted = 0;
    double overallRemaining = 0;
    for (final l in _loans) {
      overallDeducted += l.progress.deducted;
      overallRemaining += l.progress.remaining;
    }
    // Fallback from summary totals if list empty of progress
    if (_loans.isEmpty && s != null) {
      overallRemaining = s.remainingToDeduct;
      overallDeducted = (s.totalLoanAmount - s.remainingToDeduct).clamp(0, double.infinity);
    }
    final overallPie = <String, double>{
      'Paid / deducted': overallDeducted,
      'Still remaining': overallRemaining,
    };

    final closure = s?.closureYears ?? const <LoanClosureYear>[];

    // EMI deduction amount by bank account (active loans).
    final byBank = Map<String, double>.from(s?.byBank ?? {});
    if (byBank.isEmpty) {
      for (final l in _loans) {
        if (l.isClosed) continue;
        final bank = l.emiDeductionBank.isNotEmpty ? l.emiDeductionBank : l.bankName;
        byBank[bank] = (byBank[bank] ?? 0) + l.emiAmount;
      }
    }

    return [
      _heroCard(
        title: 'Monthly EMI',
        value: formatMoney(s?.totalMonthlyEmi ?? 0),
        subtitle: '${s?.activeCount ?? 0} active · ${s?.closedCount ?? 0} closed · $monthLabel',
      ),
      const SizedBox(height: 12),
      // 1) Monthly pie — total EMI this month split by what hit already vs pending
      _expenseStylePieCard(
        title: 'This month · $monthLabel',
        subtitle: _monthlyShowChart
            ? 'EMI progress for the current month'
            : 'Deducted and pending EMI amounts',
        ink: ink,
        muted: muted,
        data: monthlyPie,
        showChart: _monthlyShowChart,
        onChart: () => setState(() => _monthlyShowChart = true),
        onList: () => setState(() => _monthlyShowChart = false),
        colors: const {
          'Already deducted': Color(0xFF34D399),
          'Still to deduct': Color(0xFF7C6CFF),
        },
        centerLabel: 'This month',
      ),
      const SizedBox(height: 12),
      // 2) Overall pie
      _expenseStylePieCard(
        title: 'Overall loans',
        subtitle: _overallShowChart
            ? 'Total paid and remaining across loans'
            : 'Paid and remaining loan amounts',
        ink: ink,
        muted: muted,
        data: overallPie,
        showChart: _overallShowChart,
        onChart: () => setState(() => _overallShowChart = true),
        onList: () => setState(() => _overallShowChart = false),
        colors: const {
          'Paid / deducted': Color(0xFF22D3EE),
          'Still remaining': Color(0xFFF472B6),
        },
      ),
      const SizedBox(height: 12),
      // 3) EMI deduction by bank account
      _bankEmiBarCard(ink: ink, muted: muted, byBank: byBank),
      const SizedBox(height: 12),
      // 4) Closure year bar chart
      _closureYearCard(ink: ink, muted: muted, years: closure),
    ];
  }

  /// Bar chart: which deduction bank takes how much EMI each month.
  Widget _bankEmiBarCard({
    required Color ink,
    required Color muted,
    required Map<String, double> byBank,
  }) {
    final entries = byBank.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    const barColor = Color(0xFF7C6CFF);

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
                      'EMI by deduction bank',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _bankEmiShowChart
                          ? 'Where your monthly EMI is deducted'
                          : 'EMI amount for each bank',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _bankEmiShowChart,
                onChart: () => setState(() => _bankEmiShowChart = true),
                onList: () => setState(() => _bankEmiShowChart = false),
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No bank EMI data yet', style: TextStyle(color: muted))),
            )
          else if (_bankEmiShowChart) ...[
            Text(
              'Total monthly EMI  ${formatMoney(total)}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: _bankEmiBarChart(entries, barColor, ink, muted),
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
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: AppColors.isDark(context) ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.account_balance_rounded, size: 15, color: color),
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

  Widget _bankEmiBarChart(
    List<MapEntry<String, double>> entries,
    Color barColor,
    Color ink,
    Color muted,
  ) {
    final maxY = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    // Extra headroom so top Y labels / bars don't clip into each other.
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
                // Skip top-edge tick so it doesn't overlap chart title / plot edge.
                if (v >= meta.max - (meta.max * 0.001)) return const SizedBox.shrink();
                if (v == 0) {
                  return Text('0', style: GoogleFonts.inter(fontSize: 9, color: muted, fontWeight: FontWeight.w600));
                }
                final k = v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : v.toStringAsFixed(0);
                return Text(k, style: GoogleFonts.inter(fontSize: 9, color: muted, fontWeight: FontWeight.w600));
              },
            ),
          ),
          // Names only in tooltip on hover/tap — avoid long labels overlapping.
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
                color: _loanPalette[i % _loanPalette.length],
                width: entries.length > 5 ? 16 : 26,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Active loans in [month]/[year]: total EMI, already deducted by today, still pending.
  /// Uses each loan's [emiDeductionDate] vs today's day.
  ({double totalThisMonth, double alreadyDeducted, double stillPending}) _monthlyEmiSplit(DateTime now) {
    final curKey = now.year * 12 + now.month;
    final day = now.day;
    double total = 0;
    double done = 0;
    double pending = 0;

    for (final l in _loans) {
      if (l.isClosed) continue;
      final startKey = l.startYear * 12 + l.startMonth;
      final closeKey = l.emiCloseYear * 12 + l.emiCloseMonth;
      // Only count EMIs active in the current month.
      if (curKey < startKey || curKey > closeKey) continue;

      total += l.emiAmount;
      if (l.emiDeductionDate <= day) {
        // Deduction day already passed (or is today) → treated as deducted.
        done += l.emiAmount;
      } else {
        pending += l.emiAmount;
      }
    }

    // If no loan rows but summary exists, fall back to full monthly EMI as pending.
    if (total <= 0 && _loanSummary != null) {
      total = _loanSummary!.totalMonthlyEmi;
      pending = total;
      done = 0;
    }

    return (totalThisMonth: total, alreadyDeducted: done, stillPending: pending);
  }

  /// Pie + list toggle matching Daily expense format (ring pie, colored rows).
  Widget _expenseStylePieCard({
    required String title,
    required String subtitle,
    required Color ink,
    required Color muted,
    required Map<String, double> data,
    required bool showChart,
    required VoidCallback onChart,
    required VoidCallback onList,
    Map<String, Color>? colors,
    String centerLabel = 'Total',
  }) {
    final entries = data.entries.where((e) => e.value >= 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final isDark = AppColors.isDark(context);

    Color colorOf(String key, int i) {
      if (colors != null && colors.containsKey(key)) return colors[key]!;
      return _loanPalette[i % _loanPalette.length];
    }

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
                    Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: muted)),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: showChart,
                onChart: onChart,
                onList: onList,
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (total <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No chart data yet', style: TextStyle(color: muted))),
            )
          else if (showChart)
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _pie(
                    Map.fromEntries(entries),
                    ring: true,
                    colorOf: (key, i) => colorOf(key, i),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerLabel,
                        style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        formatMoney(total),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
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
              final color = colorOf(e.key, i);
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
                            color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.circle, size: 12, color: color),
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

  /// Grouped bar: per close-year, will close (active) vs already closed.
  Widget _closureYearCard({
    required Color ink,
    required Color muted,
    required List<LoanClosureYear> years,
  }) {
    final list = List<LoanClosureYear>.from(years)..sort((a, b) => a.year.compareTo(b.year));
    const willCloseColor = Color(0xFF7C6CFF);
    const closedColor = Color(0xFF34D399);

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
                      'Loan closure year',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _closureShowChart
                          ? 'Closing schedule year by year'
                          : 'Active and closed loans by year',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _closureShowChart,
                onChart: () => setState(() => _closureShowChart = true),
                onList: () => setState(() => _closureShowChart = false),
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No closure year data yet', style: TextStyle(color: muted))),
            )
          else if (_closureShowChart) ...[
            // Legend
            Row(
              children: [
                _legendDot(willCloseColor, 'Will close', ink),
                const SizedBox(width: 14),
                _legendDot(closedColor, 'Already closed', ink),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: _closureBarChart(list, willCloseColor, closedColor, ink, muted),
            ),
          ] else
            ...list.map((y) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softPurpleOf(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${y.year}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _miniStat(
                            'Will close',
                            '${y.activeCount}',
                            willCloseColor,
                            ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniStat(
                            'Already closed',
                            '${y.closedCount}',
                            closedColor,
                            ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniStat(
                            'Total',
                            '${y.closingCount}',
                            muted,
                            ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, Color ink) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color accent, Color ink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
      ],
    );
  }

  Widget _closureBarChart(
    List<LoanClosureYear> years,
    Color willCloseColor,
    Color closedColor,
    Color ink,
    Color muted,
  ) {
    final maxY = years.fold<int>(0, (m, y) {
      final local = y.activeCount > y.closedCount ? y.activeCount : y.closedCount;
      return local > m ? local : m;
    }).toDouble();
    final top = (maxY < 1 ? 1.0 : maxY) * 1.35;

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
              final y = years[group.x.toInt()];
              final label = rodIndex == 0 ? 'Will close' : 'Closed';
              final val = rodIndex == 0 ? y.activeCount : y.closedCount;
              return BarTooltipItem(
                '${y.year}\n$label: $val',
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
              reservedSize: 32,
              getTitlesWidget: (v, meta) {
                if (v >= meta.max - (meta.max * 0.001)) return const SizedBox.shrink();
                if (v != v.roundToDouble()) return const SizedBox.shrink();
                return Text(
                  '${v.toInt()}',
                  style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w600),
                );
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
        barGroups: List.generate(years.length, (i) {
          final y = years[i];
          return BarChartGroupData(
            x: i,
            barsSpace: 5,
            barRods: [
              BarChartRodData(
                toY: y.activeCount.toDouble(),
                color: willCloseColor,
                width: years.length > 5 ? 12 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
              BarChartRodData(
                toY: y.closedCount.toDouble(),
                color: closedColor,
                width: years.length > 5 ? 12 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

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

  /// Spends for the selected chart month/year (client-side filter).
  List<CreditSpend> get _spendChartRows {
    return _spends
        .where(
          (s) =>
              s.spendDate.year == _spendChartYear &&
              s.spendDate.month == _spendChartMonth,
        )
        .toList();
  }

  Map<String, double> _aggregateSpends(List<CreditSpend> rows, String Function(CreditSpend) keyOf) {
    final map = <String, double>{};
    for (final s in rows) {
      final k = keyOf(s).trim().isEmpty ? 'Other' : keyOf(s).trim();
      map[k] = (map[k] ?? 0) + s.amount;
    }
    return map;
  }

  /// Icons matched to spend types (same spirit as Daily expense categories).
  static IconData _spendTypeIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'ecommerce':
      case 'e-commerce':
      case 'e commerce':
      case 'online shopping':
      case 'online':
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
        return Icons.flight_takeoff_rounded;
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
      case 'fuel':
      case 'petrol':
        return Icons.local_gas_station_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      default:
        return Icons.credit_card_rounded;
    }
  }

  static Color _spendTypeColor(String type, int index) {
    switch (type.trim().toLowerCase()) {
      case 'ecommerce':
      case 'e-commerce':
      case 'online':
        return const Color(0xFF7C6CFF);
      case 'grocery':
      case 'groceries':
        return const Color(0xFF34D399);
      case 'food':
      case 'dining':
        return const Color(0xFFFBBF24);
      case 'travel':
      case 'transport':
        return const Color(0xFF60A5FA);
      case 'electronics':
      case 'gadgets':
        return const Color(0xFF22D3EE);
      case 'miscellaneous':
      case 'misc':
        return const Color(0xFFA78BFA);
      case 'other':
        return const Color(0xFFFB923C);
      default:
        return _loanPalette[index % _loanPalette.length];
    }
  }

  Widget _spendPeriodPicker(Color ink, Color muted) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Month', muted),
              const SizedBox(height: 6),
              _pickerField(
                value: kMonthNamesShort[_spendChartMonth - 1],
                ink: ink,
                muted: muted,
                icon: Icons.calendar_view_month_rounded,
                onTap: () async {
                  final months = List.generate(12, (i) => i + 1);
                  final v = await _showOptionSheet<int>(
                    title: 'Month',
                    options: months,
                    labelOf: (m) => kMonthNamesShort[m - 1],
                    selected: _spendChartMonth,
                  );
                  if (v != null) setState(() => _spendChartMonth = v);
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
                value: '$_spendChartYear',
                ink: ink,
                muted: muted,
                icon: Icons.event_rounded,
                onTap: () async {
                  final years = List.generate(7, (i) => DateTime.now().year - i);
                  final v = await _showOptionSheet<int>(
                    title: 'Year',
                    options: years,
                    labelOf: (y) => '$y',
                    selected: _spendChartYear,
                  );
                  if (v != null) setState(() => _spendChartYear = v);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _spendCharts(Color ink, Color muted) {
    final rows = _spendChartRows;
    final byType = _aggregateSpends(rows, (s) => s.spendType);
    final byCard = _aggregateSpends(rows, (s) => s.creditCardName);
    final total = rows.fold<double>(0, (a, s) => a + s.amount);
    final periodLabel = '${kMonthNamesShort[_spendChartMonth - 1]} $_spendChartYear';

    return [
      _spendPeriodPicker(ink, muted),
      const SizedBox(height: 14),
      _heroCard(
        title: 'Card spends · $periodLabel',
        value: formatMoney(total),
        subtitle:
            '${byType.length} type${byType.length == 1 ? '' : 's'} · ${rows.length} entr${rows.length == 1 ? 'y' : 'ies'}',
      ),
      const SizedBox(height: 12),
      _spendByTypeCard(ink: ink, muted: muted, data: byType, total: total),
      const SizedBox(height: 12),
      _spendByCardCard(ink: ink, muted: muted, data: byCard, total: total),
    ];
  }

  /// By spend type — pie chart / list with type icons.
  Widget _spendByTypeCard({
    required Color ink,
    required Color muted,
    required Map<String, double> data,
    required double total,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
                      'By spend type',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _spendTypeShowChart ? 'Type share chart' : 'Type breakdown list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _spendTypeShowChart,
                onChart: () => setState(() => _spendTypeShowChart = true),
                onList: () => setState(() => _spendTypeShowChart = false),
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('No spends in this month', style: TextStyle(color: muted))
          else if (_spendTypeShowChart)
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _pie(
                    Map.fromEntries(entries),
                    ring: true,
                    colorOf: (key, i) => _spendTypeColor(key, i),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        formatMoney(total),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
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
              final color = _spendTypeColor(e.key, i);
              final icon = _spendTypeIcon(e.key);
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
                          child: Icon(icon, size: 17, color: color),
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
          // Legend under pie so each type still shows its icon
          if (entries.isNotEmpty && _spendTypeShowChart) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(entries.length, (i) {
                final e = entries[i];
                final color = _spendTypeColor(e.key, i);
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
                      Icon(_spendTypeIcon(e.key), size: 13, color: color),
                      const SizedBox(width: 5),
                      Text(
                        e.key,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
                      ),
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

  /// By credit card — bar chart (not pie) / list.
  Widget _spendByCardCard({
    required Color ink,
    required Color muted,
    required Map<String, double> data,
    required double total,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
                      'By credit card',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _spendCardShowChart ? 'Card share chart' : 'Card breakdown list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _spendCardShowChart,
                onChart: () => setState(() => _spendCardShowChart = true),
                onList: () => setState(() => _spendCardShowChart = false),
                muted: muted,
                chartIcon: Icons.bar_chart_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('No spends in this month', style: TextStyle(color: muted))
          else if (_spendCardShowChart) ...[
            Text(
              'Total  ${formatMoney(total)}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: _bankEmiBarChart(entries, _brand, ink, muted),
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
                          child: Icon(Icons.credit_card_rounded, size: 17, color: color),
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

  /// Total purchase amount per card (monthly EMI × tenure months).
  Map<String, double> get _emiTotalByCard {
    final map = <String, double>{};
    for (final e in _emis) {
      final name = e.creditCardName.trim().isEmpty ? 'Card' : e.creditCardName.trim();
      map[name] = (map[name] ?? 0) + e.totalAmount;
    }
    return map;
  }

  /// Monthly installment amount per card for the **current calendar month** only.
  Map<String, double> get _emiMonthlyByCard {
    final now = DateTime.now();
    final map = <String, double>{};
    for (final e in _emis) {
      if (!e.isActiveIn(now.month, now.year)) continue;
      final name = e.creditCardName.trim().isEmpty ? 'Card' : e.creditCardName.trim();
      map[name] = (map[name] ?? 0) + e.amount;
    }
    return map;
  }

  List<Widget> _emiCharts(Color ink, Color muted) {
    final now = DateTime.now();
    final totalByCard = _emiTotalByCard;
    final monthlyByCard = _emiMonthlyByCard;
    final totalSpend = totalByCard.values.fold<double>(0, (a, b) => a + b);
    final monthlyTotal = monthlyByCard.values.fold<double>(0, (a, b) => a + b);
    final monthLabel = '${kMonthNamesShort[now.month - 1]} ${now.year}';
    final activeCount = _emis.where((e) => e.isActiveIn(now.month, now.year)).length;
    final cardCount = totalByCard.length;

    return [
      // Info hero — clean hierarchy (title → label → amount → meta)
      _emiHeroCard(
        monthLabel: monthLabel,
        monthlyTotal: monthlyTotal,
        totalSpend: totalSpend,
        activeCount: activeCount,
        emiCount: _emis.length,
        cardCount: cardCount,
      ),
      const SizedBox(height: 12),
      // 1) Pie — total purchase / spend amount per credit card
      _emiTotalByCardCard(
        ink: ink,
        muted: muted,
        data: totalByCard,
        total: totalSpend,
      ),
      const SizedBox(height: 12),
      // 2) Bar — monthly EMI for current month only (no filter)
      _emiMonthlyByCardCard(
        ink: ink,
        muted: muted,
        data: monthlyByCard,
        total: monthlyTotal,
        monthLabel: monthLabel,
        activeCount: activeCount,
      ),
    ];
  }

  /// Summary card for Card EMI charts (proper title + subtitle layout).
  Widget _emiHeroCard({
    required String monthLabel,
    required double monthlyTotal,
    required double totalSpend,
    required int activeCount,
    required int emiCount,
    required int cardCount,
  }) {
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
          Text(
            'Card EMIs',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Due this month',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            formatMoney(monthlyTotal),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '$monthLabel · $activeCount active · $emiCount EMI${emiCount == 1 ? '' : 's'} on $cardCount card${cardCount == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (totalSpend > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Total commitment  ${formatMoney(totalSpend)}',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Pie: full EMI commitment per card (e.g. ₹10k × 4 months = ₹40k).
  Widget _emiTotalByCardCard({
    required Color ink,
    required Color muted,
    required Map<String, double> data,
    required double total,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
                      'Total by card',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _emiTotalShowChart
                          ? 'Total spend share chart'
                          : 'Total spend breakdown list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _emiTotalShowChart,
                onChart: () => setState(() => _emiTotalShowChart = true),
                onList: () => setState(() => _emiTotalShowChart = false),
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('No card EMIs yet', style: TextStyle(color: muted))
          else if (_emiTotalShowChart)
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _pie(Map.fromEntries(entries), ring: true),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        formatMoney(total),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
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
                          child: Icon(Icons.credit_card_rounded, size: 17, color: color),
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
          if (entries.isNotEmpty && _emiTotalShowChart) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(entries.length, (i) {
                final e = entries[i];
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
                      Icon(Icons.credit_card_rounded, size: 13, color: color),
                      const SizedBox(width: 5),
                      Text(
                        e.key,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
                      ),
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

  /// Bar: monthly EMI due per card for the **current month only** (no filter).
  Widget _emiMonthlyByCardCard({
    required Color ink,
    required Color muted,
    required Map<String, double> data,
    required double total,
    required String monthLabel,
    required int activeCount,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
                      'This month by card',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                    ),
                    Text(
                      _emiMonthlyShowChart
                          ? 'Monthly EMI share chart'
                          : 'Monthly EMI breakdown list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showChart: _emiMonthlyShowChart,
                onChart: () => setState(() => _emiMonthlyShowChart = true),
                onList: () => setState(() => _emiMonthlyShowChart = false),
                muted: muted,
                chartIcon: Icons.bar_chart_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('No EMIs due in $monthLabel', style: TextStyle(color: muted))
          else if (_emiMonthlyShowChart) ...[
            Text(
              '$monthLabel · ${formatMoney(total)} · $activeCount active',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: _bankEmiBarChart(entries, _brand, ink, muted),
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
                          child: Icon(Icons.payments_rounded, size: 17, color: color),
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

  // ─── Data lists only ─────────────────────────────────────────────────────

  Widget _buildData(Color ink, Color muted) {
    if (_area == _Area.loans) return _loanData(ink, muted);
    // if (_area == _Area.ccSpends) return _spendData(ink, muted); // Card spends off
    return _emiData(ink, muted);
  }

  List<Loan> get _filteredLoans {
    return _loans.where((l) {
      if (_loanFilterYear != null && l.emiCloseYear != _loanFilterYear) return false;
      if (_loanFilterStatus == 'ongoing' && l.isClosed) return false;
      if (_loanFilterStatus == 'closed' && !l.isClosed) return false;
      return true;
    }).toList();
  }

  List<int> get _loanFilterYears {
    final years = _loans.map((l) => l.emiCloseYear).toSet().toList()..sort();
    return years;
  }

  Widget _loanData(Color ink, Color muted) {
    final rows = _filteredLoans;
    final pageMeta = _pageMeta(rows.length, pageSize: _loanPageSize);
    final page = _paged(rows, pageSize: _loanPageSize);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          _loanDownloadCard(
            ink: ink,
            muted: muted,
            filteredCount: rows.length,
          ),
          const SizedBox(height: 14),
          _dataListHeader(
            title: 'Loans',
            total: rows.length,
            ink: ink,
            muted: muted,
            pageMeta: pageMeta,
            perPageLabel: '4 per page',
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _empty(
              _loans.isEmpty
                  ? 'No loans yet. Open Entry to add one.'
                  : 'No loans match these filters.',
              muted,
            )
          else
            _loanSquareGrid(page, ink, muted),
        ],
      ),
    );
  }

  Widget _loanDownloadCard({
    required Color ink,
    required Color muted,
    required int filteredCount,
  }) {
    final yearLabel = _loanFilterYear == null ? 'All years' : '$_loanFilterYear';
    final statusLabel = _loanFilterStatus == 'all'
        ? 'All status'
        : _loanFilterStatus == 'closed'
            ? 'Closed'
            : 'Ongoing';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Download', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
          Text(
            'Filter loans, then export as CSV or PDF',
            style: GoogleFonts.inter(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Close year', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: yearLabel,
                      ink: ink,
                      muted: muted,
                      icon: Icons.event_rounded,
                      onTap: () async {
                        // 0 = All years; positive = that close year
                        final options = <int>[0, ..._loanFilterYears];
                        final selected = _loanFilterYear ?? 0;
                        final v = await _showOptionSheet<int>(
                          title: 'Close year',
                          options: options,
                          labelOf: (y) => y == 0 ? 'All years' : '$y',
                          selected: selected,
                        );
                        if (v != null) {
                          setState(() {
                            _loanFilterYear = v == 0 ? null : v;
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
                    _label('Status', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: statusLabel,
                      ink: ink,
                      muted: muted,
                      icon: Icons.flag_rounded,
                      onTap: () async {
                        final v = await _showOptionSheet<String>(
                          title: 'Loan status',
                          options: const ['all', 'ongoing', 'closed'],
                          labelOf: (s) => s == 'all'
                              ? 'All status'
                              : s == 'closed'
                                  ? 'Closed'
                                  : 'Ongoing',
                          selected: _loanFilterStatus,
                        );
                        if (v != null) {
                          setState(() {
                            _loanFilterStatus = v;
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
                  onPressed: filteredCount == 0 ? null : () => _downloadCurrent(),
                  style: _downloadActionStyle(),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    filteredCount == 0 ? 'No data' : 'Download ($filteredCount)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_loanFilterYear == null && _loanFilterStatus == 'all')
                      ? null
                      : () {
                          setState(() {
                            _loanFilterYear = null;
                            _loanFilterStatus = 'all';
                            _exportFormat = 'csv';
                            _dataPage = 0;
                          });
                        },
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
    );
  }

  /// Shared outlined style for Download + Reset (equal size, theme purple).
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

  /// 2 columns × up to 2 rows = 4 cards per page (height fits all details).
  Widget _loanSquareGrid(List<Loan> page, Color ink, Color muted) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final cardW = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: page.map((l) {
            return SizedBox(
              width: cardW,
              child: _loanSquareCard(l, ink, muted),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatRoi(double r) => '${r.toStringAsFixed(1)}%';

  Widget _statusRoiRow({
    required String statusLabel,
    required Color statusColor,
    required double roi,
    required bool isDark,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            statusLabel,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            _formatRoi(roi),
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
          ),
        ),
      ],
    );
  }

  Widget _loanSquareCard(Loan l, Color ink, Color muted) {
    final isDark = AppColors.isDark(context);
    final statusColor = l.isClosed ? AppColors.success : _brand;
    final startSm = (l.startMonth >= 1 && l.startMonth <= 12) ? l.startMonth : 1;
    final endSm = (l.emiCloseMonth >= 1 && l.emiCloseMonth <= 12) ? l.emiCloseMonth : 12;
    final startMonthName = kMonthNamesShort[startSm - 1];
    final endMonthName = kMonthNamesShort[endSm - 1];
    final paid = l.paidMonths();
    final total = l.tenureMonths;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_rounded, color: _brand, size: 15),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.bankName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _statusRoiRow(
            statusLabel: l.isClosed ? 'Closed' : 'Ongoing',
            statusColor: statusColor,
            roi: l.roi,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _loanDetailLine('Total', formatMoney(l.progress.totalAmount), ink, muted),
          _loanDetailLine('Remaining', formatMoney(l.progress.remaining), ink, muted),
          _loanDetailLine('EMI / month', formatMoney(l.emiAmount), ink, muted),
          _loanDetailLine('Tenure', '$paid / $total mo', ink, muted),
          const SizedBox(height: 8),
          // Start / End — two columns so month + year never clip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _brand.withValues(alpha: isDark ? 0.35 : 0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _loanDateCell(
                    title: 'Start',
                    month: startMonthName,
                    year: '${l.startYear}',
                    ink: ink,
                    muted: muted,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: _brand.withValues(alpha: isDark ? 0.35 : 0.2),
                ),
                Expanded(
                  child: _loanDateCell(
                    title: 'End',
                    month: endMonthName,
                    year: '${l.emiCloseYear}',
                    ink: ink,
                    muted: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: l.progress.fraction.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _brand.withValues(alpha: 0.12),
              color: _brand,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionChip(Icons.edit_rounded, _brand, () => _editLoan(l), isDark),
              const SizedBox(width: 6),
              _actionChip(Icons.delete_rounded, AppColors.danger, () => _deleteLoan(l), isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact Start/End cell: title, month, year each on its own line.
  Widget _loanDateCell({
    required String title,
    required String month,
    required String year,
    required Color ink,
    required Color muted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          month,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 13, color: ink, fontWeight: FontWeight.w800),
        ),
        Text(
          year,
          maxLines: 1,
          style: GoogleFonts.inter(fontSize: 12, color: _brand, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _loanDetailLine(String label, String value, Color ink, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 10.5, color: ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  List<CreditSpend> get _filteredSpends {
    return _spends.where((s) {
      if (_spendDataYear != null && s.spendDate.year != _spendDataYear) return false;
      if (_spendDataMonth != null && s.spendDate.month != _spendDataMonth) return false;
      return true;
    }).toList();
  }

  Widget _spendData(Color ink, Color muted) {
    final rows = _filteredSpends;
    final pageMeta = _pageMeta(rows.length);
    final page = _paged(rows);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          _spendDownloadCard(
            ink: ink,
            muted: muted,
            filteredCount: rows.length,
          ),
          const SizedBox(height: 14),
          _dataListHeader(
            title: 'Card spends',
            total: rows.length,
            ink: ink,
            muted: muted,
            pageMeta: pageMeta,
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _empty(
              _spends.isEmpty
                  ? 'No card spends yet.'
                  : 'No spends match these filters.',
              muted,
            )
          else
            ...page.map((s) => _spendTile(s, ink, muted)),
        ],
      ),
    );
  }

  Widget _spendDownloadCard({
    required Color ink,
    required Color muted,
    required int filteredCount,
  }) {
    final monthLabel =
        _spendDataMonth == null ? 'All months' : kMonthNamesShort[_spendDataMonth! - 1];
    final yearLabel = _spendDataYear == null ? 'All years' : '$_spendDataYear';
    final isDefault = _spendDataMonth == null && _spendDataYear == null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Download', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
          Text(
            'Filter spends, then export as CSV or PDF',
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
                        // 0 = All months
                        final options = <int>[0, ...List.generate(12, (i) => i + 1)];
                        final selected = _spendDataMonth ?? 0;
                        final v = await _showOptionSheet<int>(
                          title: 'Month',
                          options: options,
                          labelOf: (m) => m == 0 ? 'All months' : kMonthNamesShort[m - 1],
                          selected: selected,
                        );
                        if (v != null) {
                          setState(() {
                            _spendDataMonth = v == 0 ? null : v;
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
                        final selected = _spendDataYear ?? 0;
                        final v = await _showOptionSheet<int>(
                          title: 'Year',
                          options: options,
                          labelOf: (y) => y == 0 ? 'All years' : '$y',
                          selected: selected,
                        );
                        if (v != null) {
                          setState(() {
                            _spendDataYear = v == 0 ? null : v;
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
                  onPressed: filteredCount == 0 ? null : () => _downloadCurrent(),
                  style: _downloadActionStyle(),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    filteredCount == 0 ? 'No data' : 'Download ($filteredCount)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDefault
                      ? null
                      : () {
                          setState(() {
                            _spendDataMonth = null;
                            _spendDataYear = null;
                            _exportFormat = 'csv';
                            _dataPage = 0;
                          });
                        },
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
    );
  }

  List<CreditEmi> get _filteredEmis {
    return _emis.where((e) {
      if (_emiFilterYear != null && e.endYear != _emiFilterYear) return false;
      if (_emiFilterStatus == 'ongoing' && !e.isOngoing) return false;
      if (_emiFilterStatus == 'completed' && !e.isCompleted) return false;
      return true;
    }).toList();
  }

  List<int> get _emiFilterYears {
    final years = _emis.map((e) => e.endYear).toSet().toList()..sort();
    return years;
  }

  Widget _emiData(Color ink, Color muted) {
    final rows = _filteredEmis;
    final pageMeta = _pageMeta(rows.length, pageSize: _loanPageSize);
    final page = _paged(rows, pageSize: _loanPageSize);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          _emiDownloadCard(
            ink: ink,
            muted: muted,
            filteredCount: rows.length,
          ),
          const SizedBox(height: 14),
          _dataListHeader(
            title: 'Card EMIs',
            total: rows.length,
            ink: ink,
            muted: muted,
            pageMeta: pageMeta,
            perPageLabel: '4 per page',
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _empty(
              _emis.isEmpty
                  ? 'No card EMIs yet. Open Entry to add one.'
                  : 'No EMIs match these filters.',
              muted,
            )
          else
            _emiSquareGrid(page, ink, muted),
        ],
      ),
    );
  }

  Widget _emiDownloadCard({
    required Color ink,
    required Color muted,
    required int filteredCount,
  }) {
    final yearLabel = _emiFilterYear == null ? 'All years' : '$_emiFilterYear';
    final statusLabel = _emiFilterStatus == 'all'
        ? 'All status'
        : _emiFilterStatus == 'completed'
            ? 'Completed'
            : 'Ongoing';
    final isDefault = _emiFilterYear == null && _emiFilterStatus == 'all';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Download', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
          Text(
            'Filter EMIs, then export as CSV or PDF',
            style: GoogleFonts.inter(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('End year', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: yearLabel,
                      ink: ink,
                      muted: muted,
                      icon: Icons.event_rounded,
                      onTap: () async {
                        final options = <int>[0, ..._emiFilterYears];
                        final selected = _emiFilterYear ?? 0;
                        final v = await _showOptionSheet<int>(
                          title: 'End year',
                          options: options,
                          labelOf: (y) => y == 0 ? 'All years' : '$y',
                          selected: selected,
                        );
                        if (v != null) {
                          setState(() {
                            _emiFilterYear = v == 0 ? null : v;
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
                    _label('Status', muted),
                    const SizedBox(height: 6),
                    _pickerField(
                      value: statusLabel,
                      ink: ink,
                      muted: muted,
                      icon: Icons.flag_rounded,
                      onTap: () async {
                        final v = await _showOptionSheet<String>(
                          title: 'EMI status',
                          options: const ['all', 'ongoing', 'completed'],
                          labelOf: (s) => s == 'all'
                              ? 'All status'
                              : s == 'completed'
                                  ? 'Completed'
                                  : 'Ongoing',
                          selected: _emiFilterStatus,
                        );
                        if (v != null) {
                          setState(() {
                            _emiFilterStatus = v;
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
                  onPressed: filteredCount == 0 ? null : () => _downloadCurrent(),
                  style: _downloadActionStyle(),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    filteredCount == 0 ? 'No data' : 'Download ($filteredCount)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDefault
                      ? null
                      : () {
                          setState(() {
                            _emiFilterYear = null;
                            _emiFilterStatus = 'all';
                            _exportFormat = 'csv';
                            _dataPage = 0;
                          });
                        },
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
    );
  }

  /// 2 columns × up to 2 rows = 4 cards per page (same as Loans Data).
  Widget _emiSquareGrid(List<CreditEmi> page, Color ink, Color muted) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final cardW = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: page.map((e) {
            return SizedBox(
              width: cardW,
              child: _emiSquareCard(e, ink, muted),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emiSquareCard(CreditEmi e, Color ink, Color muted) {
    final isDark = AppColors.isDark(context);
    final statusColor = e.isCompleted
        ? AppColors.success
        : e.isUpcoming
            ? AppColors.muted
            : _brand;
    final statusLabel = e.isCompleted
        ? 'Completed'
        : e.isUpcoming
            ? 'Upcoming'
            : 'Ongoing';
    final startSm = (e.startMonth >= 1 && e.startMonth <= 12) ? e.startMonth : 1;
    final endSm = (e.endMonth >= 1 && e.endMonth <= 12) ? e.endMonth : 12;
    final paid = e.paidMonths();
    final total = e.tenureMonths;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payments_rounded, color: _brand, size: 15),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  e.emiName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _statusRoiRow(
            statusLabel: statusLabel,
            statusColor: statusColor,
            roi: e.roi,
            isDark: isDark,
          ),
          const SizedBox(height: 4),
          Text(
            e.creditCardName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
          ),
          const SizedBox(height: 8),
          _loanDetailLine('Total', formatMoney(e.totalAmount), ink, muted),
          _loanDetailLine('Remaining', formatMoney(e.remainingAmount), ink, muted),
          _loanDetailLine('EMI / month', formatMoney(e.amount), ink, muted),
          _loanDetailLine('Tenure', '$paid / $total mo', ink, muted),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _brand.withValues(alpha: isDark ? 0.35 : 0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _loanDateCell(
                    title: 'Start',
                    month: kMonthNamesShort[startSm - 1],
                    year: '${e.startYear}',
                    ink: ink,
                    muted: muted,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: _brand.withValues(alpha: isDark ? 0.35 : 0.2),
                ),
                Expanded(
                  child: _loanDateCell(
                    title: 'End',
                    month: kMonthNamesShort[endSm - 1],
                    year: '${e.endYear}',
                    ink: ink,
                    muted: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: e.progressFraction.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _brand.withValues(alpha: 0.12),
              color: _brand,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionChip(Icons.edit_rounded, _brand, () => _editEmi(e), isDark),
              const SizedBox(width: 6),
              _actionChip(Icons.delete_rounded, AppColors.danger, () => _deleteEmi(e), isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// Title left, total + page nav right (same layout as Daily expense Data).
  Widget _dataListHeader({
    required String title,
    required int total,
    required Color ink,
    required Color muted,
    required ({int page, int pageCount, int maxPage}) pageMeta,
    String perPageLabel = '5 per page',
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
                'Page ${pageMeta.page + 1} of ${pageMeta.pageCount} · $perPageLabel',
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

  Widget _downloadCard({
    required Color ink,
    required Color muted,
    required int count,
    required VoidCallback onDownload,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Download', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
          Text(
            'Export current list as CSV (Excel) or PDF',
            style: GoogleFonts.inter(fontSize: 12, color: muted),
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: count == 0 ? null : onDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(
                'Download ($count rows)',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCurrent() async {
    try {
      late final String title;
      late final String baseName;
      late final List<String> headers;
      late final List<List<String>> rows;

      switch (_area) {
        case _Area.loans:
          final filtered = _filteredLoans;
          title = 'Loans report';
          baseName = 'loans_${DateTime.now().millisecondsSinceEpoch}';
          headers = const [
            'Bank',
            'EMI bank',
            'Status',
            'Total amount',
            'Remaining',
            'EMI monthly',
            'Start',
            'End',
            'Deduction day',
          ];
          rows = filtered
              .map(
                (l) => [
                  l.bankName,
                  l.emiDeductionBank,
                  l.isClosed ? 'Closed' : 'Ongoing',
                  l.progress.totalAmount.toStringAsFixed(2),
                  l.progress.remaining.toStringAsFixed(2),
                  l.emiAmount.toStringAsFixed(2),
                  '${kMonthNamesShort[l.startMonth - 1]} ${l.startYear}',
                  '${kMonthNamesShort[l.emiCloseMonth - 1]} ${l.emiCloseYear}',
                  '${l.emiDeductionDate}',
                ],
              )
              .toList();
        case _Area.ccSpends:
          final filtered = _filteredSpends;
          title = 'Credit card spends';
          baseName = 'cc_spends_${DateTime.now().millisecondsSinceEpoch}';
          headers = const ['Date', 'Type', 'Card', 'Amount'];
          rows = filtered
              .map(
                (s) => [
                  DateFormat('yyyy-MM-dd').format(s.spendDate),
                  s.spendType,
                  s.creditCardName,
                  s.amount.toStringAsFixed(2),
                ],
              )
              .toList();
        case _Area.ccEmis:
          final filtered = _filteredEmis;
          title = 'Credit card EMIs';
          baseName = 'cc_emis_${DateTime.now().millisecondsSinceEpoch}';
          headers = const [
            'EMI name',
            'Card',
            'Status',
            'Total',
            'Remaining',
            'EMI monthly',
            'Start',
            'End',
            'Tenure months',
          ];
          rows = filtered
              .map(
                (e) => [
                  e.emiName,
                  e.creditCardName,
                  e.isCompleted
                      ? 'Completed'
                      : e.isUpcoming
                          ? 'Upcoming'
                          : 'Ongoing',
                  e.totalAmount.toStringAsFixed(2),
                  e.remainingAmount.toStringAsFixed(2),
                  e.amount.toStringAsFixed(2),
                  '${kMonthNamesShort[e.startMonth - 1]} ${e.startYear}',
                  '${kMonthNamesShort[e.endMonth - 1]} ${e.endYear}',
                  '${e.tenureMonths}',
                ],
              )
              .toList();
      }

      await exportTableReport(
        baseName: baseName,
        title: title,
        headers: headers,
        rows: rows,
        format: _exportFormat,
      );
      if (!mounted) return;
      AppSnack.success(
        context,
        _exportFormat == 'pdf' ? 'PDF ready' : 'CSV ready (opens in Excel)',
        icon: Icons.download_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, '$e');
    }
  }

  ({int page, int pageCount, int maxPage}) _pageMeta(int total, {int pageSize = _pageSize}) {
    final pageCount = total == 0 ? 0 : ((total + pageSize - 1) ~/ pageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _dataPage.clamp(0, maxPage);
    return (page: page, pageCount: pageCount, maxPage: maxPage);
  }

  List<T> _paged<T>(List<T> rows, {int pageSize = _pageSize}) {
    if (rows.isEmpty) return [];
    final meta = _pageMeta(rows.length, pageSize: pageSize);
    final start = meta.page * pageSize;
    return rows.sublist(start, (start + pageSize).clamp(0, rows.length));
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

  Widget _spendTile(CreditSpend s, Color ink, Color muted) {
    return _listTile(
      icon: Icons.credit_card_rounded,
      title: s.creditCardName,
      subtitle: '${s.spendType} · ${DateFormat('dd MMM yyyy').format(s.spendDate)}',
      amount: formatMoney(s.amount),
      ink: ink,
      muted: muted,
      onEdit: () => _editSpend(s),
      onDelete: () => _deleteSpend(s),
    );
  }

  Widget _emiTile(CreditEmi e, Color ink, Color muted) {
    return _listTile(
      icon: Icons.payments_rounded,
      title: e.emiName,
      subtitle:
          '${e.creditCardName} · ${kMonthNamesShort[e.startMonth - 1]} ${e.startYear} to ${kMonthNamesShort[e.endMonth - 1]} ${e.endYear}',
      amount: formatMoney(e.amount),
      ink: ink,
      muted: muted,
      onEdit: () => _editEmi(e),
      onDelete: () => _deleteEmi(e),
    );
  }

  Widget _listTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color ink,
    required Color muted,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    double? progress,
  }) {
    final isDark = AppColors.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _brand, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionChip(Icons.edit_rounded, _brand, onEdit, isDark),
                      const SizedBox(width: 6),
                      _actionChip(Icons.delete_rounded, AppColors.danger, onDelete, isDark),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: _brand.withValues(alpha: 0.12),
                color: _brand,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return Material(
      color: color.withValues(alpha: isDark ? 0.22 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(width: 30, height: 30, child: Icon(icon, size: 15, color: color)),
      ),
    );
  }

  // ─── shared UI ───────────────────────────────────────────────────────────

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

  Widget _statRow(String label, String value, Color ink, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w600))),
          Text(value, style: GoogleFonts.inter(color: ink, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _pie(
    Map<String, double> data, {
    bool ring = false,
    Color Function(String key, int index)? colorOf,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();
    // Match Daily expense chart sizing (ring: center 58, ring width 52).
    return PieChart(
      PieChartData(
        sectionsSpace: ring ? 3 : 2,
        centerSpaceRadius: ring ? 58 : 36,
        startDegreeOffset: -90,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value,
              color: colorOf?.call(entries[i].key, i) ?? _loanPalette[i % _loanPalette.length],
              title: ring ? '' : '${(entries[i].value / total * 100).round()}%',
              titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              radius: ring ? 52 : 48,
            ),
        ],
      ),
    );
  }

  Widget _primaryBtn({
    required String label,
    required bool loading,
    required VoidCallback onTap,
    IconData icon = Icons.add_rounded,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: loading
              ? [_brand.withValues(alpha: 0.45), _brandDeep.withValues(alpha: 0.45)]
              : const [_brand, _brandDeep],
        ),
        boxShadow: [
          BoxShadow(color: _brand.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: loading ? null : onTap,
          child: SizedBox(
            height: 50,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
            ),
          ),
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

  /// Themed compact calendar (same style as Daily expense).
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
    var mode = 'day'; // day | month | year

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
            final firstWeekday = DateTime(viewMonth.year, viewMonth.month, 1).weekday;
            final leading = firstWeekday - 1;
            final totalCells = leading + daysInMonth;
            final rows = ((totalCells + 6) ~/ 7);
            final canPrev = DateTime(viewMonth.year, viewMonth.month)
                .isAfter(DateTime(first.year, first.month));
            final canNext = DateTime(viewMonth.year, viewMonth.month)
                .isBefore(DateTime(last.year, last.month));

            Widget chip({required String label, required bool active, required VoidCallback onTap}) {
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
                        Icon(Icons.expand_more_rounded, size: 18, color: active ? _brand : muted),
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
                      color: isSel ? _brand : AppColors.softPurpleOf(context),
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
                    final disabled = candidate.isBefore(DateTime(first.year, first.month)) ||
                        candidate.isAfter(DateTime(last.year, last.month));
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
                            kMonthNamesShort[i],
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
                                    onTap: enabled ? () => setLocal(() => selected = date) : null,
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
                                    label: kMonthNamesShort[viewMonth.month - 1],
                                    active: mode == 'month',
                                    onTap: () => setLocal(
                                      () => mode = mode == 'month' ? 'day' : 'month',
                                    ),
                                  ),
                                  chip(
                                    label: '${viewMonth.year}',
                                    active: mode == 'year',
                                    onTap: () => setLocal(
                                      () => mode = mode == 'year' ? 'day' : 'year',
                                    ),
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
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: muted),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: mode != 'day'
                                    ? () => setLocal(() => mode = 'day')
                                    : () {
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

  /// Rounded option sheet with icon + heading (same style as Daily expense).
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

  Widget _empty(String msg, Color muted) => Padding(
        padding: const EdgeInsets.all(28),
        child: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.inter(color: muted)),
      );

  Widget _label(String t, Color muted) =>
      Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted));

  InputDecoration _fieldDeco({String? hint}) {
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
