import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/display_currency.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/expense.dart' show kMonthNames;
import '../models/split.dart';
import '../services/split_export.dart';
import '../services/split_service.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snack.dart';
import '../widgets/section_header_card.dart';

/// Splits — inline entry forms (same pattern as Money lent / Daily expense).
/// No bottom-sheet popups for create/add/edit (avoids Flutter lifecycle crashes).
class SplitsScreen extends StatefulWidget {
  const SplitsScreen({super.key});

  @override
  State<SplitsScreen> createState() => _SplitsScreenState();
}

class _SplitsScreenState extends State<SplitsScreen> with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);

  /// Same multi-color rods as Assets chart section.
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

  final _svc = SplitService.instance;

  // ── List ────────────────────────────────────────────────────────────────
  List<SplitGroupSummary> _groups = [];
  bool _loading = true;
  String? _error;

  // Create group (inline)
  final _groupNameCtrl = TextEditingController();
  final _groupNotesCtrl = TextEditingController();
  final _memberDraftCtrl = TextEditingController();
  final List<String> _newMembers = [];
  bool _savingGroup = false;

  // ── Detail ──────────────────────────────────────────────────────────────
  int? _openGroupId;
  SplitGroupDetail? _detail;
  bool _detailLoading = false;
  String? _detailError;
  /// One controller for the whole screen lifetime (create once).
  /// Recreating it per open/close breaks tab swipe + second open (ticker crash).
  late final TabController _detailTabs;

  // Expense form (inline)
  final _expDescCtrl = TextEditingController();
  final _expAmountCtrl = TextEditingController();
  final _expNotesCtrl = TextEditingController();
  final _expHistoryNoteCtrl = TextEditingController();
  DateTime _expDate = DateTime.now();
  int? _expPaidById;
  final Set<int> _expSplitIds = {};
  int? _editingExpenseId;
  bool _savingExpense = false;

  // Settlement form (inline)
  final _settleAmountCtrl = TextEditingController();
  final _settleNotesCtrl = TextEditingController();
  DateTime _settleDate = DateTime.now();
  int? _settleFromId;
  int? _settleToId;
  bool _savingSettle = false;
  bool _exportingExcel = false;

  // Add member (inline)
  final _addMemberCtrl = TextEditingController();

  // Amount history (inline expand)
  int? _historyExpenseId;
  List<SplitAmountChange> _historyRows = [];
  bool _historyLoading = false;

  // Expense list pagination (same as Daily expense Data: 5 per page)
  int _expensePage = 0;
  static const _expensePageSize = 5;
  /// Expenses tab: Entry form vs Data list (chart-style toggle).
  bool _expenseShowEntry = true;
  final _expenseScroll = ScrollController();

  /// Balances tab: bar chart vs data list (Assets-style).
  bool _balanceShowChart = true;

  // Settled list pagination (same as Expenses: 5 per page)
  int _settlePage = 0;
  static const _settlePageSize = 5;
  /// Settled tab: Entry form vs Data list.
  bool _settleShowEntry = true;
  final _settleScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _detailTabs = TabController(length: 3, vsync: this);
    _syncSelfName();
    _reloadGroups();
  }

  /// Keep self member labels as the logged-in account name (not "You").
  void _syncSelfName() {
    final u = context.read<AuthState>().user;
    final name = u?['name']?.toString().trim() ?? '';
    if (name.isNotEmpty && name.toLowerCase() != 'you') {
      splitSelfDisplayName = name;
      return;
    }
    final email = u?['email']?.toString().split('@').first.trim() ?? '';
    splitSelfDisplayName = email.isNotEmpty ? email : 'Me';
  }

  @override
  void dispose() {
    _detailTabs.dispose();
    _expenseScroll.dispose();
    _settleScroll.dispose();
    _groupNameCtrl.dispose();
    _groupNotesCtrl.dispose();
    _memberDraftCtrl.dispose();
    _expDescCtrl.dispose();
    _expAmountCtrl.dispose();
    _expNotesCtrl.dispose();
    _expHistoryNoteCtrl.dispose();
    _settleAmountCtrl.dispose();
    _settleNotesCtrl.dispose();
    _addMemberCtrl.dispose();
    super.dispose();
  }

  /// Dismiss keyboard and scroll an entry form back to the top.
  void _collapseEntryScroll(ScrollController scroll) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _collapseExpenseEntryUi() => _collapseEntryScroll(_expenseScroll);

  void _collapseSettleEntryUi() => _collapseEntryScroll(_settleScroll);

  // ── Helpers ─────────────────────────────────────────────────────────────

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

  Widget _label(String t, Color muted) => Text(
        t,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
      );

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: child,
    );
  }

  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
    bool orange = false,
  }) {
    final c1 = orange ? AppColors.orange : _brand;
    final c2 = orange ? const Color(0xFFFF9A5C) : _brandDeep;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: onTap == null || loading
              ? [c1.withValues(alpha: 0.45), c2.withValues(alpha: 0.45)]
              : [c1, c2],
        ),
        boxShadow: [
          BoxShadow(color: c1.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 6)),
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
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          label,
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
    );
  }

  Widget _dateField(DateTime value, ValueChanged<DateTime> onPick, Color ink, Color muted) {
    return Material(
      color: AppColors.softPurpleOf(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final d = await _showCompactDatePicker(value);
          if (d != null) onPick(d);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 17, color: _brand.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('dd MMM yyyy').format(value),
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

  /// Compact themed calendar bottom sheet (same as Daily expense / Card spends).
  Future<DateTime?> _showCompactDatePicker(DateTime initial) {
    final first = DateTime(2020);
    final last = DateTime.now().add(const Duration(days: 1));
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.52;
    final years =
        List.generate(last.year - first.year + 1, (i) => first.year + i).reversed.toList();

    // Clamp initial into allowed range
    var safeInitial = initial;
    if (safeInitial.isBefore(first)) safeInitial = first;
    if (safeInitial.isAfter(last)) safeInitial = last;

    var viewMonth = DateTime(safeInitial.year, safeInitial.month);
    var selected = DateTime(safeInitial.year, safeInitial.month, safeInitial.day);
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

            final canPrev =
                DateTime(viewMonth.year, viewMonth.month).isAfter(DateTime(first.year, first.month));
            final canNext =
                DateTime(viewMonth.year, viewMonth.month).isBefore(DateTime(last.year, last.month));

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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                        child: Row(
                          children: [
                            if (mode == 'day')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: canPrev
                                    ? () => setLocal(() {
                                          viewMonth =
                                              DateTime(viewMonth.year, viewMonth.month - 1);
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
                                          viewMonth =
                                              DateTime(viewMonth.year, viewMonth.month + 1);
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
                                        final dim = DateUtils.getDaysInMonth(
                                          viewMonth.year,
                                          viewMonth.month,
                                        );
                                        final day = selected.day.clamp(1, dim);
                                        var out =
                                            DateTime(viewMonth.year, viewMonth.month, day);
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

  Widget _memberDropdown({
    required String label,
    required int? value,
    required List<SplitMember> members,
    required ValueChanged<int?> onChanged,
    required Color muted,
  }) {
    final ink = AppColors.inkOf(context);
    final selected = value != null && members.any((m) => m.id == value)
        ? members.firstWhere((m) => m.id == value)
        : null;
    final display = selected?.displayName ?? 'Select member';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, muted),
        const SizedBox(height: 6),
        Material(
          color: AppColors.softPurpleOf(context),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: members.isEmpty
                ? null
                : () async {
                    final currentId = selected?.id ?? members.first.id;
                    final picked = await _showMemberPickerSheet(
                      title: label,
                      members: members,
                      selectedId: currentId,
                    );
                    if (picked != null) onChanged(picked);
                  },
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 17,
                    color: _brand.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: selected == null ? muted : ink,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: muted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// App-themed member picker sheet (same style as Daily expense option sheets).
  Future<int?> _showMemberPickerSheet({
    required String title,
    required List<SplitMember> members,
    required int selectedId,
  }) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.42;

    return showModalBottomSheet<int>(
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
                          child: const Icon(Icons.person_rounded, size: 18, color: _brand),
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
                      itemCount: members.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final m = members[i];
                        final isSel = m.id == selectedId;
                        return Material(
                          color: isSel
                              ? _brand.withValues(alpha: isDark ? 0.22 : 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, m.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _brand.withValues(
                                        alpha: isDark ? 0.28 : 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        m.displayName.isNotEmpty
                                            ? m.displayName[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: _brand,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      m.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontWeight:
                                            isSel ? FontWeight.w800 : FontWeight.w600,
                                        color: isSel ? _brand : ink,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  if (isSel)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: _brand,
                                      size: 18,
                                    ),
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

  Color _balColor(double bal) {
    if (bal > 0.009) return AppColors.success;
    if (bal < -0.009) return AppColors.danger;
    return AppColors.muted;
  }

  String _balLabel(double bal) {
    if (bal > 0.009) return 'you are owed ${formatMoney(bal)}';
    if (bal < -0.009) return 'you owe ${formatMoney(-bal)}';
    return 'settled up';
  }

  String _err(Object e) {
    var s = e.toString();
    s = s.replaceFirst(RegExp(r'^ApiException:\s*'), '');
    s = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    return s.trim().isEmpty ? 'Something went wrong' : s.trim();
  }

  void _snackOk(String m, {IconData? icon}) {
    if (!mounted) return;
    AppSnack.success(context, m, icon: icon);
  }

  void _snackErr(Object e) {
    if (!mounted) return;
    AppSnack.error(context, _err(e));
  }

  void _snackWarn(String m) {
    if (!mounted) return;
    AppSnack.warning(context, m);
  }

  double? _parseAmt(String raw) {
    final c = raw.trim().replaceAll(',', '').replaceAll(' ', '');
    if (c.isEmpty) return null;
    return double.tryParse(c);
  }

  // ── Load ────────────────────────────────────────────────────────────────

  Future<void> _reloadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listGroups();
      if (!mounted) return;
      setState(() {
        _groups = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _err(e);
        _loading = false;
      });
    }
  }

  Future<void> _openGroup(int id) async {
    // Reset to Expenses tab without recreating the controller.
    if (_detailTabs.index != 0) {
      _detailTabs.index = 0;
    }
    setState(() {
      _openGroupId = id;
      _detail = null;
      _detailLoading = true;
      _detailError = null;
      _editingExpenseId = null;
      _historyExpenseId = null;
      _historyRows = [];
      _historyLoading = false;
      _expensePage = 0;
      _expenseShowEntry = true;
      _settlePage = 0;
      _settleShowEntry = true;
      _resetExpenseForm();
      _resetSettleForm();
    });
    await _reloadDetail();
  }

  Future<void> _reloadDetail() async {
    final id = _openGroupId;
    if (id == null) return;
    if (mounted) {
      setState(() {
        _detailLoading = true;
        _detailError = null;
      });
    }
    try {
      final d = await _svc.getGroup(id);
      if (!mounted || _openGroupId != id) return;
      setState(() {
        _detail = d;
        _detailLoading = false;
        if (_editingExpenseId == null) {
          _applyExpenseDefaults(d);
        }
        _applySettleDefaults(d);
      });
    } catch (e) {
      if (!mounted || _openGroupId != id) return;
      setState(() {
        _detailError = _err(e);
        _detailLoading = false;
      });
    }
  }

  void _closeGroup() {
    setState(() {
      _openGroupId = null;
      _detail = null;
      _detailError = null;
      _detailLoading = false;
      _editingExpenseId = null;
      _historyExpenseId = null;
      _historyRows = [];
      _expensePage = 0;
      _expenseShowEntry = true;
      _settlePage = 0;
      _settleShowEntry = true;
    });
    // Soft refresh list — don't block UI with full-screen spinner.
    _reloadGroupsSoft();
  }

  Future<void> _reloadGroupsSoft() async {
    try {
      final list = await _svc.listGroups();
      if (!mounted || _openGroupId != null) return;
      setState(() {
        _groups = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || _openGroupId != null) return;
      setState(() {
        _error = _err(e);
        _loading = false;
      });
    }
  }

  SplitMember? _youOf(SplitGroupDetail d) {
    for (final m in d.members) {
      if (m.isYou) return m;
    }
    return d.members.isNotEmpty ? d.members.first : null;
  }

  SplitMember? _otherOf(SplitGroupDetail d) {
    for (final m in d.members) {
      if (!m.isYou) return m;
    }
    return d.members.length > 1 ? d.members[1] : null;
  }

  void _applyExpenseDefaults(SplitGroupDetail d) {
    _expPaidById = _youOf(d)?.id;
    _expSplitIds
      ..clear()
      ..addAll(d.members.map((m) => m.id));
  }

  void _applySettleDefaults(SplitGroupDetail d) {
    _settleFromId = _youOf(d)?.id;
    _settleToId = _otherOf(d)?.id;
  }

  void _resetExpenseForm([SplitGroupDetail? d]) {
    _editingExpenseId = null;
    _expDescCtrl.clear();
    _expAmountCtrl.clear();
    _expNotesCtrl.clear();
    _expHistoryNoteCtrl.clear();
    _expDate = DateTime.now();
    final detail = d ?? _detail;
    if (detail != null) _applyExpenseDefaults(detail);
  }

  void _resetSettleForm([SplitGroupDetail? d]) {
    _settleAmountCtrl.clear();
    _settleNotesCtrl.clear();
    _settleDate = DateTime.now();
    final detail = d ?? _detail;
    if (detail != null) _applySettleDefaults(detail);
  }

  void _startEditExpense(SplitExpense e) {
    final d = _detail;
    if (d == null) return;
    setState(() {
      _editingExpenseId = e.id;
      _expDescCtrl.text = e.description;
      _expAmountCtrl.text = e.amount.toStringAsFixed(2);
      _expNotesCtrl.text = e.notes;
      _expHistoryNoteCtrl.clear();
      _expDate = e.expenseDate;
      _expPaidById = e.paidByMemberId;
      _expSplitIds
        ..clear()
        ..addAll(
          e.shares.isNotEmpty ? e.shares.map((s) => s.memberId) : d.members.map((m) => m.id),
        );
      _expenseShowEntry = true; // show form when editing from data list
      _detailTabs.animateTo(0);
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  String get _selfDisplayName {
    final u = context.read<AuthState>().user;
    final name = u?['name']?.toString().trim() ?? '';
    if (name.isNotEmpty && name.toLowerCase() != 'you') return name;
    final email = u?['email']?.toString().split('@').first.trim() ?? '';
    if (email.isNotEmpty) return email;
    return 'Me';
  }

  void _addNewMemberChip() {
    final n = _memberDraftCtrl.text.trim();
    if (n.isEmpty) {
      _snackWarn('Enter a member name');
      return;
    }
    if (n.toLowerCase() == 'you' || n.toLowerCase() == _selfDisplayName.toLowerCase()) {
      _snackWarn('$_selfDisplayName is already included');
      return;
    }
    if (_newMembers.any((m) => m.toLowerCase() == n.toLowerCase())) {
      _snackWarn('Already added');
      return;
    }
    setState(() {
      _newMembers.add(n);
      _memberDraftCtrl.clear();
    });
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) {
      _snackWarn('Enter a group name');
      return;
    }
    final draft = _memberDraftCtrl.text.trim();
    final members = [..._newMembers];
    if (draft.isNotEmpty &&
        draft.toLowerCase() != 'you' &&
        !members.any((m) => m.toLowerCase() == draft.toLowerCase())) {
      members.add(draft);
    }
    setState(() => _savingGroup = true);
    try {
      final g = await _svc.createGroup(
        name: name,
        notes: _groupNotesCtrl.text.trim(),
        members: members,
      );
      if (!mounted) return;
      setState(() {
        _groupNameCtrl.clear();
        _groupNotesCtrl.clear();
        _memberDraftCtrl.clear();
        _newMembers.clear();
        _savingGroup = false;
      });
      _snackOk('Group created', icon: Icons.group_rounded);
      await _reloadGroups();
      if (!mounted) return;
      await _openGroup(g.id);
    } catch (e) {
      if (mounted) setState(() => _savingGroup = false);
      _snackErr(e);
    }
  }

  Future<void> _saveExpense() async {
    final d = _detail;
    if (d == null) return;
    final desc = _expDescCtrl.text.trim();
    final amt = _parseAmt(_expAmountCtrl.text);
    if (desc.isEmpty) {
      _snackWarn('Enter a description');
      return;
    }
    if (amt == null || amt <= 0) {
      _snackWarn('Enter a valid amount');
      return;
    }
    if (_expPaidById == null || _expPaidById! <= 0) {
      _snackWarn('Select who paid');
      return;
    }
    if (_expSplitIds.isEmpty) {
      _snackWarn('Select at least one member');
      return;
    }
    // Close keypad as soon as user taps Add / Update
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _savingExpense = true);
    try {
      if (_editingExpenseId != null) {
        await _svc.updateExpense(
          groupId: d.id,
          expenseId: _editingExpenseId!,
          description: desc,
          amount: amt,
          paidByMemberId: _expPaidById!,
          expenseDate: _expDate,
          notes: _expNotesCtrl.text.trim(),
          splitMemberIds: _expSplitIds.toList(),
          historyNote: _expHistoryNoteCtrl.text.trim(),
        );
        _snackOk('Expense updated');
      } else {
        await _svc.addExpense(
          groupId: d.id,
          description: desc,
          amount: amt,
          paidByMemberId: _expPaidById!,
          expenseDate: _expDate,
          notes: _expNotesCtrl.text.trim(),
          splitMemberIds: _expSplitIds.toList(),
        );
        _snackOk('Expense added');
      }
      if (!mounted) return;
      final wasNew = _editingExpenseId == null;
      // Close keypad + scroll form up right after a successful add/update
      _collapseExpenseEntryUi();
      setState(() {
        _resetExpenseForm(d);
        _savingExpense = false;
        _historyExpenseId = null;
        // New expenses land at top (date DESC) — show first page
        if (wasNew) _expensePage = 0;
      });
      await _reloadDetail();
    } catch (e) {
      if (mounted) setState(() => _savingExpense = false);
      if (_err(e).toLowerCase().contains('not found')) {
        _snackWarn('Group no longer available. Refreshing…');
        _closeGroup();
      } else {
        _snackErr(e);
      }
    }
  }

  Future<void> _deleteExpense(SplitExpense e) async {
    final d = _detail;
    if (d == null) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete expense?',
      message: 'Remove “${e.description}” · ${formatMoney(e.amount)}?',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!ok) return;
    try {
      await _svc.deleteExpense(d.id, e.id);
      if (mounted) AppSnack.danger(context, 'Expense deleted');
      if (_editingExpenseId == e.id) {
        setState(() => _resetExpenseForm(d));
      }
      await _reloadDetail();
    } catch (err) {
      _snackErr(err);
    }
  }

  Future<void> _toggleHistory(SplitExpense e) async {
    if (_historyExpenseId == e.id) {
      setState(() {
        _historyExpenseId = null;
        _historyRows = [];
      });
      return;
    }
    setState(() {
      _historyExpenseId = e.id;
      _historyRows = List.of(e.amountHistory);
      _historyLoading = true;
    });
    try {
      final rows = await _svc.amountHistory(_detail!.id, e.id);
      if (!mounted || _historyExpenseId != e.id) return;
      setState(() {
        _historyRows = rows;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted || _historyExpenseId != e.id) return;
      setState(() => _historyLoading = false);
    }
  }

  Future<void> _saveSettlement() async {
    final d = _detail;
    if (d == null) return;
    final amt = _parseAmt(_settleAmountCtrl.text);
    if (_settleFromId == null || _settleToId == null) {
      _snackWarn('Select From and To');
      return;
    }
    if (_settleFromId == _settleToId) {
      _snackWarn('From and To must differ');
      return;
    }
    if (amt == null || amt <= 0) {
      _snackWarn('Enter a valid amount');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _savingSettle = true);
    try {
      await _svc.addSettlement(
        groupId: d.id,
        fromMemberId: _settleFromId!,
        toMemberId: _settleToId!,
        amount: amt,
        settledDate: _settleDate,
        notes: _settleNotesCtrl.text.trim(),
      );
      if (!mounted) return;
      _collapseSettleEntryUi();
      setState(() {
        _resetSettleForm(d);
        _savingSettle = false;
        _settlePage = 0; // newest first
      });
      _snackOk('Settlement recorded');
      await _reloadDetail();
    } catch (e) {
      if (mounted) setState(() => _savingSettle = false);
      _snackErr(e);
    }
  }

  Future<void> _deleteSettlement(SplitSettlement s) async {
    final d = _detail;
    if (d == null) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete settlement?',
      message: 'Remove ${s.fromDisplay} → ${s.toDisplay} · ${formatMoney(s.amount)}?',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!ok) return;
    try {
      await _svc.deleteSettlement(d.id, s.id);
      if (mounted) AppSnack.danger(context, 'Settlement deleted');
      await _reloadDetail();
    } catch (e) {
      _snackErr(e);
    }
  }

  /// Bottom sheet to add a member to the open group (header + icon).
  Future<void> _showAddMemberSheet() async {
    final detail = _detail;
    if (detail == null) return;

    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);

    // Fresh field each open
    _addMemberCtrl.clear();
    var saving = false;

    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 14,
          ),
          child: Material(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                Future<void> submit() async {
                  if (saving) return;
                  final d = _detail;
                  if (d == null) return;
                  final name = _addMemberCtrl.text.trim();
                  if (name.isEmpty) {
                    _snackWarn('Enter a name');
                    return;
                  }
                  final exists = d.members.any(
                    (m) =>
                        m.name.toLowerCase() == name.toLowerCase() ||
                        m.displayName.toLowerCase() == name.toLowerCase(),
                  );
                  if (exists) {
                    _snackWarn('Already in this group');
                    return;
                  }
                  if (name.toLowerCase() == 'you' ||
                      name.toLowerCase() == _selfDisplayName.toLowerCase()) {
                    _snackWarn('$_selfDisplayName is already included');
                    return;
                  }
                  setLocal(() => saving = true);
                  try {
                    await _svc.addMember(d.id, name);
                    if (!ctx.mounted) return;
                    _addMemberCtrl.clear();
                    Navigator.pop(ctx, true);
                    if (mounted) {
                      _snackOk('Member added');
                      await _reloadDetail();
                    }
                  } catch (e) {
                    if (ctx.mounted) setLocal(() => saving = false);
                    _snackErr(e);
                  }
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: muted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              size: 18,
                              color: _brand,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add member',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: ink,
                                  ),
                                ),
                                Text(
                                  detail.name,
                                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: saving ? null : () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded, color: muted, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: detail.members.map((m) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softPurpleOf(context),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AppColors.borderOf(context)),
                            ),
                            child: Text(
                              m.displayName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: ink,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'New member name',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _addMemberCtrl,
                        autofocus: true,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        decoration: _fieldDeco(hint: 'e.g. Rahul'),
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 14),
                      _primaryBtn(
                        label: 'Add member',
                        icon: Icons.person_add_rounded,
                        loading: saving,
                        onTap: saving ? null : submit,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteGroup() async {
    final d = _detail;
    if (d == null) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete group?',
      message: 'Remove “${d.name}” and all expenses & settlements?',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!ok) return;
    try {
      await _svc.deleteGroup(d.id);
      if (mounted) AppSnack.danger(context, 'Group deleted');
      _closeGroup();
    } catch (e) {
      _snackErr(e);
    }
  }

  void _prefillSettle(SplitTransfer t) {
    setState(() {
      _settleFromId = t.fromMemberId;
      _settleToId = t.toMemberId;
      _settleAmountCtrl.text = t.amount.toStringAsFixed(2);
      _settleShowEntry = true; // open entry form with suggestion filled
      _detailTabs.animateTo(2);
    });
  }

  /// Excel download — only when group has at least one expense or settlement.
  bool _groupHasEntries(SplitGroupDetail d) =>
      d.expenses.isNotEmpty || d.settlements.isNotEmpty;

  Future<void> _downloadGroupExcel() async {
    final d = _detail;
    if (d == null || !_groupHasEntries(d) || _exportingExcel) return;
    setState(() => _exportingExcel = true);
    try {
      await exportSplitGroupExcel(d);
      if (mounted) {
        _snackOk('Excel ready', icon: Icons.download_rounded);
      }
    } catch (e) {
      _snackErr(e);
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  /// Bottom sheet of settle suggestions (same pop-from-bottom style as Groups menu).
  Future<void> _showSettleSuggestionsSheet(SplitGroupDetail detail) async {
    if (detail.transfers.isEmpty) return;

    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);

    final choice = await showModalBottomSheet<SplitTransfer>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.62;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Material(
            color: isDark ? AppColors.cardDark : Colors.white,
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.handshake_rounded, size: 18, color: _brand),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settle suggestions',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: ink,
                                ),
                              ),
                              Text(
                                'Tap a row to record that settlement',
                                style: GoogleFonts.inter(fontSize: 12, color: muted),
                              ),
                            ],
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
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      children: [
                        ...detail.transfers.map((t) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: AppColors.softPurpleOf(ctx),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pop(ctx, t),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: _brand.withValues(
                                            alpha: isDark ? 0.28 : 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.swap_horiz_rounded,
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
                                              '${t.fromName} → ${t.toName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w800,
                                                color: ink,
                                              ),
                                            ),
                                            Text(
                                              'Pay ${formatMoney(t.amount)}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formatMoney(t.amount),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: _brand,
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: muted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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

    if (!mounted || choice == null) return;
    _prefillSettle(choice);
  }

  // ── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Refresh self name if profile loaded after mount
    _syncSelfName();
    if (_openGroupId != null) return _buildDetail();
    return _buildList();
  }

  // ── List + create group entry (Loans-style header menu, no group list) ──

  /// Like Loans header menu: New group + each existing group.
  Future<void> _showGroupMenu() async {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);

    // Refresh so menu is up to date
    try {
      final list = await _svc.listGroups();
      if (mounted) setState(() => _groups = list);
    } catch (_) {}

    if (!mounted) return;

    final choice = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.62;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Material(
            color: isDark ? AppColors.cardDark : Colors.white,
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.call_split_rounded, size: 18, color: _brand),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Splits',
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
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      children: [
                        _menuTile(
                          icon: Icons.group_add_rounded,
                          title: 'New group',
                          subtitle: 'Create a split group',
                          ink: ink,
                          muted: muted,
                          selected: true,
                          onTap: () => Navigator.pop(ctx, 'new'),
                        ),
                        if (_groups.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                            child: Text(
                              'Your groups',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ),
                          ..._groups.map((g) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _menuTile(
                                icon: Icons.groups_rounded,
                                title: g.name,
                                subtitle:
                                    '${g.memberCount} members · ${_balLabel(g.yourBalance)}',
                                ink: ink,
                                muted: muted,
                                selected: false,
                                onTap: () => Navigator.pop(ctx, g.id),
                              ),
                            );
                          }),
                        ],
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

    if (!mounted || choice == null) return;
    if (choice == 'new') {
      // Already on create form — just stay
      setState(() {});
      return;
    }
    if (choice is int) {
      await _openGroup(choice);
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
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
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

  Widget _kpiMini({
    required Widget icon,
    required String caption,
    required String value,
    required Color valueColor,
    required Color ink,
    required Color muted,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          // Fixed value area so both cards share the same height
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: valueColor,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: body,
      ),
    );
  }

  Widget _buildList() {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);

    double netYou = 0;
    for (final g in _groups) {
      netYou += g.yourBalance;
    }
    final balTone = netYou.abs() < 0.01
        ? 'neutral'
        : netYou > 0
            ? 'pos'
            : 'neg';
    final balText = netYou.abs() < 0.01
        ? 'Settled up'
        : netYou > 0
            ? 'Owed ${formatMoney(netYou)}'
            : 'You owe ${formatMoney(-netYou)}';
    final balColor = balTone == 'pos'
        ? AppColors.success
        : balTone == 'neg'
            ? AppColors.danger
            : ink;
    final groupsValue =
        '${_groups.length} ${_groups.length == 1 ? 'group' : 'groups'}';

    return RefreshIndicator(
      onRefresh: _reloadGroups,
      color: _brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Static header like Daily expense (open groups via Groups card)
          const SectionHeaderCard(
            icon: Icons.call_split_rounded,
            title: 'Splits',
            subtitle: 'Share expenses with friends & groups',
          ),
          const SizedBox(height: 12),

          // Equal-height KPI cards
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _kpiMini(
                    ink: ink,
                    muted: muted,
                    caption: 'Overall balance',
                    value: balText,
                    valueColor: balColor,
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: balTone == 'pos'
                              ? const [Color(0xFF22C55E), Color(0xFF4ADE80)]
                              : balTone == 'neg'
                                  ? const [Color(0xFFEF4444), Color(0xFFF87171)]
                                  : const [_brand, _brandDeep],
                        ),
                      ),
                      child: Icon(
                        balTone == 'pos'
                            ? Icons.trending_up_rounded
                            : balTone == 'neg'
                                ? Icons.trending_down_rounded
                                : Icons.balance_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiMini(
                    ink: ink,
                    muted: muted,
                    caption: 'Groups',
                    value: groupsValue,
                    valueColor: ink,
                    onTap: _showGroupMenu,
                    trailing: Icon(Icons.chevron_right_rounded, size: 18, color: muted),
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
                      ),
                      child: const Icon(Icons.groups_rounded, color: _brand, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  title: Text(
                    _error!,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _reloadGroups,
                  ),
                ),
              ),
            ),

          // Create form entry
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create group',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_selfDisplayName is always included. Add friends with +.',
                  style: GoogleFonts.inter(fontSize: 12, color: muted, height: 1.35),
                ),
                const SizedBox(height: 14),
                _label('Group name', muted),
                const SizedBox(height: 6),
                TextField(
                  controller: _groupNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDeco(hint: 'e.g. Goa trip, Flatmates'),
                ),
                const SizedBox(height: 12),
                _label('Notes (optional)', muted),
                const SizedBox(height: 6),
                TextField(
                  controller: _groupNotesCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDeco(hint: 'Optional'),
                ),
                const SizedBox(height: 12),
                _label('Members', muted),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.softPurpleOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: _brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selfDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ink,
                          ),
                        ),
                      ),
                      Text(
                        'Always in',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brand,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._newMembers.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.softPurpleOf(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded,
                              size: 18, color: _brand.withValues(alpha: 0.85)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.value,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: ink,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _newMembers.removeAt(e.key)),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.danger.withValues(alpha: 0.8),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _memberDraftCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDeco(hint: 'Friend name'),
                        onSubmitted: (_) => _addNewMemberChip(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: _brand,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _addNewMemberChip,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _primaryBtn(
                  label: 'Create group',
                  icon: Icons.check_rounded,
                  loading: _savingGroup,
                  onTap: _savingGroup ? null : _createGroup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail ──────────────────────────────────────────────────────────────

  Widget _buildDetail() {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final detail = _detail;
    final symbol = activeDisplayCurrencySymbol;

    // Always keep TabBar + TabBarView mounted so Balances/Settled never go blank.
    final title = detail?.name ?? 'Group';
    final subtitle = detail == null
        ? (_detailLoading ? 'Loading…' : (_detailError ?? 'Tap retry if this stuck'))
        : '${detail.members.length} members · ${formatMoney(detail.totalSpent)} total';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _closeGroup,
                icon: Icon(Icons.arrow_back_rounded, color: ink),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                    ),
                  ],
                ),
              ),
              if (detail != null) ...[
                // Download Excel (enabled only when group has expenses / settlements)
                IconButton(
                  onPressed: _groupHasEntries(detail) && !_exportingExcel
                      ? _downloadGroupExcel
                      : null,
                  icon: _exportingExcel
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _brand,
                          ),
                        )
                      : Icon(
                          Icons.download_rounded,
                          color: _groupHasEntries(detail)
                              ? _brand.withValues(alpha: 0.95)
                              : muted.withValues(alpha: 0.35),
                        ),
                  tooltip: _groupHasEntries(detail)
                      ? 'Download Excel'
                      : 'Add an expense or settlement to download',
                ),
                IconButton(
                  onPressed: _showAddMemberSheet,
                  icon: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: _brand.withValues(alpha: 0.95),
                  ),
                  tooltip: 'Add member',
                ),
                IconButton(
                  onPressed: _deleteGroup,
                  icon: Icon(
                    Icons.delete_rounded,
                    color: AppColors.danger.withValues(alpha: 0.9),
                  ),
                  tooltip: 'Delete group',
                ),
              ],
            ],
          ),
        ),
        if (detail != null) ...[
          // Side-by-side: Your balance | Settle (sheet on tap, like Groups menu)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _kpiMini(
                      ink: ink,
                      muted: muted,
                      caption: 'Your balance',
                      value: detail.yourBalance.abs() < 0.01
                          ? 'Settled up'
                          : detail.yourBalance > 0
                              ? 'Owed ${formatMoney(detail.yourBalance)}'
                              : 'You owe ${formatMoney(-detail.yourBalance)}',
                      valueColor: _balColor(detail.yourBalance),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: detail.yourBalance.abs() < 0.01
                                ? const [_brand, _brandDeep]
                                : detail.yourBalance > 0
                                    ? const [Color(0xFF22C55E), Color(0xFF4ADE80)]
                                    : const [Color(0xFFEF4444), Color(0xFFF87171)],
                          ),
                        ),
                        child: Icon(
                          detail.yourBalance.abs() < 0.01
                              ? Icons.balance_rounded
                              : detail.yourBalance > 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _kpiMini(
                      ink: ink,
                      muted: muted,
                      caption: 'Settle',
                      value: detail.transfers.isEmpty
                          ? 'All settled'
                          : detail.transfers.length == 1
                              ? '1 suggestion'
                              : '${detail.transfers.length} suggestions',
                      valueColor: detail.transfers.isEmpty ? ink : _brand,
                      onTap: detail.transfers.isEmpty
                          ? null
                          : () => _showSettleSuggestionsSheet(detail),
                      trailing: detail.transfers.isEmpty
                          ? null
                          : Icon(Icons.chevron_right_rounded, size: 18, color: muted),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
                        ),
                        child: Icon(
                          detail.transfers.isEmpty
                              ? Icons.check_circle_outline_rounded
                              : Icons.handshake_rounded,
                          color: _brand,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (_detailError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _card(
              child: Column(
                children: [
                  Text(_detailError!, textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: muted, fontSize: 13)),
                  TextButton(
                    onPressed: _reloadDetail,
                    child: Text('Retry',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _brand)),
                  ),
                ],
              ),
            ),
          ),
        // Same pill slider as Daily expense Entry / Charts / Data
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
              controller: _detailTabs,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
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
                Tab(height: 40, text: 'Expenses'),
                Tab(height: 40, text: 'Balances'),
                Tab(height: 40, text: 'Settled'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _detailLoading && detail == null
              ? const Center(child: CircularProgressIndicator(color: _brand))
              : detail == null
                  ? Center(
                      child: TextButton(
                        onPressed: _reloadDetail,
                        child: Text('Load group',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _brand)),
                      ),
                    )
                  : TabBarView(
                      controller: _detailTabs,
                      children: [
                        _expensesTab(detail, ink, muted, isDark, symbol),
                        _balancesTab(detail, ink, muted, isDark),
                        _settledTab(detail, ink, muted, isDark, symbol),
                      ],
                    ),
        ),
      ],
    );
  }

  // ── Expenses tab (Entry form / Data list toggle like Charts) ────────────

  Widget _expensesTab(
    SplitGroupDetail detail,
    Color ink,
    Color muted,
    bool isDark,
    String symbol,
  ) {
    return RefreshIndicator(
      onRefresh: _reloadDetail,
      color: _brand,
      child: ListView(
        controller: _expenseScroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Header + Entry / Data toggle (same control as Charts chart/list)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: ink,
                      ),
                    ),
                    Text(
                      _expenseShowEntry
                          ? (_editingExpenseId != null
                              ? 'Edit expense form'
                              : 'Add a new split expense')
                          : 'All expenses · paginated list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showEntry: _expenseShowEntry,
                onEntry: () => setState(() => _expenseShowEntry = true),
                onList: () => setState(() {
                  _expenseShowEntry = false;
                  _historyExpenseId = null;
                }),
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_expenseShowEntry)
            _buildExpenseEntryForm(detail, ink, muted, symbol)
          else
            ..._buildExpenseListSection(detail, ink, muted, isDark),
        ],
      ),
    );
  }

  Widget _viewModeToggle({
    required bool showEntry,
    required VoidCallback onEntry,
    required VoidCallback onList,
    required Color muted,
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
            icon: Icons.edit_note_rounded,
            selected: showEntry,
            onTap: onEntry,
            muted: muted,
            isDark: isDark,
          ),
          _viewModeIcon(
            icon: Icons.view_list_rounded,
            selected: !showEntry,
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

  Widget _buildExpenseEntryForm(
    SplitGroupDetail detail,
    Color ink,
    Color muted,
    String symbol,
  ) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingExpenseId != null ? 'Edit expense' : 'Add expense',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
          ),
          const SizedBox(height: 4),
          Text(
            _editingExpenseId != null
                ? 'Changing amount is saved in history.'
                : 'Split equally among selected members.',
            style: GoogleFonts.inter(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          _label('Description', muted),
          const SizedBox(height: 6),
          TextField(
            controller: _expDescCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDeco(hint: 'e.g. Dinner, Taxi'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Amount ($symbol)', muted),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _expAmountCtrl,
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
                    _dateField(_expDate, (d) => setState(() => _expDate = d), ink, muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _memberDropdown(
            label: 'Paid by',
            value: _expPaidById,
            members: detail.members,
            onChanged: (v) => setState(() => _expPaidById = v),
            muted: muted,
          ),
          const SizedBox(height: 12),
          _label('Split equally among', muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: detail.members.map((m) {
              final sel = _expSplitIds.contains(m.id);
              return FilterChip(
                selected: sel,
                label: Text(
                  m.displayName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: sel ? Colors.white : ink,
                  ),
                ),
                selectedColor: _brand,
                backgroundColor: AppColors.softPurpleOf(context),
                checkmarkColor: Colors.white,
                side: BorderSide(color: sel ? _brand : AppColors.borderOf(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _expSplitIds.add(m.id);
                    } else if (_expSplitIds.length > 1) {
                      _expSplitIds.remove(m.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _label('Notes (optional)', muted),
          const SizedBox(height: 6),
          TextField(
            controller: _expNotesCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDeco(hint: 'Optional'),
          ),
          if (_editingExpenseId != null) ...[
            const SizedBox(height: 12),
            _label('Amount-change note (optional)', muted),
            const SizedBox(height: 6),
            TextField(
              controller: _expHistoryNoteCtrl,
              decoration: _fieldDeco(hint: 'e.g. Added tip'),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _primaryBtn(
                  label: _editingExpenseId != null ? 'Update expense' : 'Add expense',
                  icon: _editingExpenseId != null
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  loading: _savingExpense,
                  onTap: _savingExpense ? null : _saveExpense,
                ),
              ),
              if (_editingExpenseId != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => setState(() => _resetExpenseForm(detail)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    foregroundColor: muted,
                    side: BorderSide(color: AppColors.borderOf(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpenseListSection(
    SplitGroupDetail detail,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    final rows = detail.expenses;
    final pageCount = rows.isEmpty ? 0 : ((rows.length + _expensePageSize - 1) ~/ _expensePageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _expensePage.clamp(0, maxPage);
    if (page != _expensePage) {
      // Keep page in range after delete/reload without scheduling mid-build issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _expensePage != page) setState(() => _expensePage = page);
      });
    }
    final start = page * _expensePageSize;
    final pageRows = rows.isEmpty
        ? <SplitExpense>[]
        : rows.sublist(start, (start + _expensePageSize).clamp(0, rows.length));

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Recent entries',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
            ),
          ),
          if (rows.isNotEmpty)
            Text(
              rows.length <= _expensePageSize
                  ? 'Latest ${rows.length}'
                  : '${rows.length} total',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
            ),
        ],
      ),
      if (pageCount > 1) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Page ${page + 1} of $pageCount · $_expensePageSize per page',
              style: GoogleFonts.inter(fontSize: 12, color: muted),
            ),
            const Spacer(),
            _pageNav(
              label: '${page + 1}/$pageCount',
              canPrev: page > 0,
              canNext: page < maxPage,
              onPrev: () => setState(() {
                _expensePage = page - 1;
                _historyExpenseId = null;
              }),
              onNext: () => setState(() {
                _expensePage = page + 1;
                _historyExpenseId = null;
              }),
              muted: muted,
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Text(
            'No expenses yet — add your first spend above',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: muted, fontSize: 13),
          ),
        )
      else
        ...pageRows.map((e) => _expenseTile(detail, e, ink, muted, isDark)),
    ];
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

  /// Daily-expense-style tile (icon · title · meta · amount · action chips).
  Widget _expenseTile(
    SplitGroupDetail _,
    SplitExpense e,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    final last = e.lastAmountChange;
    final showHist = _historyExpenseId == e.id;
    final dateLabel = DateFormat('dd MMM yyyy').format(e.expenseDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_rounded, color: _brand, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: ink,
                        fontSize: 14,
                      ),
                    ),
                    if (e.amountEditCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: _brand.withValues(alpha: isDark ? 0.4 : 0.22),
                          ),
                        ),
                        child: Text(
                          e.amountEditCount == 1
                              ? 'Edited'
                              : 'Edited ${e.amountEditCount}×',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _brand,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '${e.paidByDisplay} paid · $dateLabel',
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
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: ink,
                      fontSize: 13.5,
                    ),
                  ),
                  if (last != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'was ${formatMoney(last.oldAmount)}',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionChip(
                        icon: Icons.edit_rounded,
                        color: _brand,
                        onTap: () => _startEditExpense(e),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _actionChip(
                        icon: showHist ? Icons.expand_less_rounded : Icons.history_rounded,
                        color: e.amountEditCount > 0 || showHist ? _brand : muted,
                        onTap: () => _toggleHistory(e),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _actionChip(
                        icon: Icons.delete_rounded,
                        color: AppColors.danger,
                        onTap: () => _deleteExpense(e),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (showHist) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.borderOf(context)),
            const SizedBox(height: 10),
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: _brand),
                  ),
                ),
              )
            else if (_historyRows.isEmpty)
              Text(
                'No amount changes yet.',
                style: GoogleFonts.inter(fontSize: 12.5, color: muted),
              )
            else
              ..._historyRows.map((h) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softPurpleOf(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              formatMoney(h.oldAmount),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: muted,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: muted),
                            ),
                            Text(
                              formatMoney(h.newAmount),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _brand,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (h.createdAt != null)
                              DateFormat('dd MMM yyyy · HH:mm')
                                  .format(h.createdAt!.toLocal()),
                            if (h.changedByName.isNotEmpty) h.changedByName,
                          ].join(' · '),
                          style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                        ),
                        if (h.note.isNotEmpty)
                          Text(
                            h.note,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  // ── Balances tab (Assets-style bar chart + list toggle) ─────────────────

  Widget _balancesTab(
    SplitGroupDetail detail,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    // Sort by |balance| so the largest outstanding shows first (like Assets by amount).
    final balances = detail.balances.toList()
      ..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    final maxAbs = balances.fold<double>(
      0,
      (m, b) => b.balance.abs() > m ? b.balance.abs() : m,
    );

    return RefreshIndicator(
      onRefresh: _reloadDetail,
      color: _brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
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
                            'Member balances',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: ink,
                            ),
                          ),
                          Text(
                            _balanceShowChart
                                ? 'Balance share by member'
                                : 'Balance by member list',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _chartListToggle(
                      showChart: _balanceShowChart,
                      onChart: () => setState(() => _balanceShowChart = true),
                      onList: () => setState(() => _balanceShowChart = false),
                      muted: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Positive = owed · Negative = owes',
                  style: GoogleFonts.inter(fontSize: 11.5, color: muted),
                ),
                const SizedBox(height: 14),
                if (balances.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No balance data yet',
                        style: GoogleFonts.inter(color: muted, fontSize: 13),
                      ),
                    ),
                  )
                else if (_balanceShowChart) ...[
                  Text(
                    'Share of open balances  ·  largest ${formatMoney(maxAbs)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _memberBalancePie(balances, ink, muted, isDark),
                ] else
                  ...List.generate(balances.length, (i) {
                    final b = balances[i];
                    final abs = b.balance.abs();
                    final pct = maxAbs > 0 ? abs / maxAbs : 0.0;
                    final color = _palette[i % _palette.length];
                    final label = abs < 0.01
                        ? 'settled'
                        : b.balance > 0
                            ? '+${formatMoney(b.balance)}'
                            : formatMoney(b.balance);
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
                                child: Icon(
                                  b.isYou ? Icons.star_rounded : Icons.person_rounded,
                                  size: 17,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  b.displayName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: ink,
                                  ),
                                ),
                              ),
                              if (abs >= 0.01) ...[
                                Text(
                                  '${(pct * 100).round()}%',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: abs < 0.01
                                      ? AppColors.success
                                      : _balColor(b.balance),
                                ),
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
        ],
      ),
    );
  }

  /// Chart / list toggle (same control as Assets charts).
  Widget _chartListToggle({
    required bool showChart,
    required VoidCallback onChart,
    required VoidCallback onList,
    required Color muted,
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
            icon: Icons.pie_chart_rounded,
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

  /// Ring pie of |balance| share per member + color legend tags (side by side).
  Widget _memberBalancePie(
    List<SplitBalance> balances,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    // Pie uses absolute open balances so slices stay positive.
    final slices = balances
        .where((b) => b.balance.abs() >= 0.01)
        .toList()
      ..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));

    if (slices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'Everyone is settled',
            style: GoogleFonts.inter(color: muted, fontSize: 13),
          ),
        ),
      );
    }

    final total = slices.fold<double>(0, (s, b) => s + b.balance.abs());
    int colorIndex(SplitBalance b) {
      final i = balances.indexWhere((x) => x.id == b.id);
      return i >= 0 ? i : 0;
    }

    // Rounded % so pie titles and legend always match (e.g. Ankit 8%).
    int pctOf(SplitBalance b) {
      if (total <= 0) return 0;
      return ((b.balance.abs() / total) * 100).round();
    }

    Widget legendTag(SplitBalance b) {
      final color = _palette[colorIndex(b) % _palette.length];
      final pct = pctOf(b);
      final status = b.balance > 0
          ? 'owed ${formatMoney(b.balance)}'
          : 'owes ${formatMoney(-b.balance)}';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    b.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _balColor(b.balance),
              ),
            ),
          ],
        ),
      );
    }

    // Pair legends side by side (2 per row)
    final legendRows = <Widget>[];
    for (var i = 0; i < slices.length; i += 2) {
      legendRows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < slices.length ? 8 : 0),
          child: Row(
            children: [
              Expanded(child: legendTag(slices[i])),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < slices.length
                    ? legendTag(slices[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 64,
                  startDegreeOffset: -90,
                  sections: List.generate(slices.length, (i) {
                    final b = slices[i];
                    final color = _palette[colorIndex(b) % _palette.length];
                    final pct = pctOf(b);
                    // Always show % on every slice (small font if tiny)
                    return PieChartSectionData(
                      value: b.balance.abs(),
                      color: color,
                      title: '$pct%',
                      titleStyle: GoogleFonts.inter(
                        fontSize: pct < 10 ? 11 : 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 3),
                        ],
                      ),
                      titlePositionPercentageOffset: pct < 10 ? 0.62 : 0.55,
                      radius: pct < 10 ? 58 : 62,
                    );
                  }),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  Text(
                    formatMoney(total),
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...legendRows,
      ],
    );
  }

  // ── Settled tab (Entry / Data like Expenses) ────────────────────────────

  Widget _settledTab(
    SplitGroupDetail detail,
    Color ink,
    Color muted,
    bool isDark,
    String symbol,
  ) {
    return RefreshIndicator(
      onRefresh: _reloadDetail,
      color: _brand,
      child: ListView(
        controller: _settleScroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settled',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: ink,
                      ),
                    ),
                    Text(
                      _settleShowEntry
                          ? 'Record a new settlement'
                          : 'All settlements · paginated list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _viewModeToggle(
                showEntry: _settleShowEntry,
                onEntry: () => setState(() => _settleShowEntry = true),
                onList: () => setState(() => _settleShowEntry = false),
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_settleShowEntry)
            _buildSettleEntryForm(detail, ink, muted, symbol)
          else
            ..._buildSettleListSection(detail, ink, muted, isDark),
        ],
      ),
    );
  }

  Widget _buildSettleEntryForm(
    SplitGroupDetail detail,
    Color ink,
    Color muted,
    String symbol,
  ) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record settlement',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Mark that one person paid another.',
            style: GoogleFonts.inter(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          _memberDropdown(
            label: 'From (who paid)',
            value: _settleFromId,
            members: detail.members,
            onChanged: (v) => setState(() => _settleFromId = v),
            muted: muted,
          ),
          const SizedBox(height: 12),
          _memberDropdown(
            label: 'To (who received)',
            value: _settleToId,
            members: detail.members,
            onChanged: (v) => setState(() => _settleToId = v),
            muted: muted,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Amount ($symbol)', muted),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _settleAmountCtrl,
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
                    _dateField(
                      _settleDate,
                      (d) => setState(() => _settleDate = d),
                      ink,
                      muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('Notes (optional)', muted),
          const SizedBox(height: 6),
          TextField(
            controller: _settleNotesCtrl,
            decoration: _fieldDeco(hint: 'e.g. UPI'),
          ),
          const SizedBox(height: 16),
          _primaryBtn(
            label: 'Record settlement',
            icon: Icons.handshake_rounded,
            loading: _savingSettle,
            orange: true,
            onTap: _savingSettle ? null : _saveSettlement,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSettleListSection(
    SplitGroupDetail detail,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    final rows = detail.settlements;
    final pageCount =
        rows.isEmpty ? 0 : ((rows.length + _settlePageSize - 1) ~/ _settlePageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _settlePage.clamp(0, maxPage);
    if (page != _settlePage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _settlePage != page) setState(() => _settlePage = page);
      });
    }
    final start = page * _settlePageSize;
    final pageRows = rows.isEmpty
        ? <SplitSettlement>[]
        : rows.sublist(start, (start + _settlePageSize).clamp(0, rows.length));

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Recent entries',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
            ),
          ),
          if (rows.isNotEmpty)
            Text(
              rows.length <= _settlePageSize
                  ? 'Latest ${rows.length}'
                  : '${rows.length} total',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
        ],
      ),
      if (pageCount > 1) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Page ${page + 1} of $pageCount · $_settlePageSize per page',
              style: GoogleFonts.inter(fontSize: 12, color: muted),
            ),
            const Spacer(),
            _pageNav(
              label: '${page + 1}/$pageCount',
              canPrev: page > 0,
              canNext: page < maxPage,
              onPrev: () => setState(() => _settlePage = page - 1),
              onNext: () => setState(() => _settlePage = page + 1),
              muted: muted,
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Text(
            'No settlements yet — record one from Entry',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: muted, fontSize: 13),
          ),
        )
      else
        ...pageRows.map((s) => _settlementTile(s, ink, muted, isDark)),
    ];
  }

  /// Expense-style tile for a settlement row.
  Widget _settlementTile(
    SplitSettlement s,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(s.settledDate);

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
              color: AppColors.success.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.handshake_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.fromDisplay} → ${s.toDisplay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: ink,
                    fontSize: 14,
                  ),
                ),
                Text(
                  s.notes.isNotEmpty ? '$dateLabel · ${s.notes}' : dateLabel,
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
                formatMoney(s.amount),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: ink,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 4),
              _actionChip(
                icon: Icons.delete_rounded,
                color: AppColors.danger,
                onTap: () => _deleteSettlement(s),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
