import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/display_currency.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/expense.dart' show kMonthNames;
import '../models/money_lent.dart';
import '../services/money_lent_service.dart';
import '../services/table_export.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snack.dart';

/// Money lent — Entry · Charts · Data (same layout as Other assets / Daily expense).
class MoneyLentSection extends StatefulWidget {
  const MoneyLentSection({super.key, this.initialTab = 0});

  /// 0 Entry · 1 Charts · 2 Data (from Home deep-link).
  final int initialTab;

  @override
  State<MoneyLentSection> createState() => _MoneyLentSectionState();
}

class _MoneyLentSectionState extends State<MoneyLentSection> with SingleTickerProviderStateMixin {
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

  late final TabController _tabs;
  final _svc = MoneyLentService.instance;

  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<MoneyLent> _list = [];
  MoneyLentSummary _summary = MoneyLentSummary.empty();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int? _editingId;
  DateTime _givenDate = DateTime.now();

  int _dataPage = 0;
  static const _pageSize = 5;

  /// Data download filters — null = All people / months / years.
  String? _dataFilterPerson;
  int? _dataFilterMonth;
  int? _dataFilterYear;
  String _exportFormat = 'csv';

  bool _byPersonShowChart = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initialTab.clamp(0, 2);
    _tabs = TabController(length: 3, vsync: this, initialIndex: i);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _svc.list(),
        _svc.summary(),
      ]);
      if (!mounted) return;
      setState(() {
        _list = results[0] as List<MoneyLent>;
        _summary = results[1] as MoneyLentSummary;
        _loading = false;
        final filtered = _dataFilteredRows;
        final maxPage = filtered.isEmpty ? 0 : ((filtered.length - 1) ~/ _pageSize);
        if (_dataPage > maxPage) _dataPage = maxPage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<MoneyLent> get _dataFilteredRows {
    return _list.where((e) {
      if (_dataFilterPerson != null &&
          _dataFilterPerson!.isNotEmpty &&
          e.personName != _dataFilterPerson) {
        return false;
      }
      if (_dataFilterYear != null && e.givenDate.year != _dataFilterYear) return false;
      if (_dataFilterMonth != null && e.givenDate.month != _dataFilterMonth) return false;
      return true;
    }).toList();
  }

  List<String> get _personFilterOptions {
    final names = _list.map((e) => e.personName.trim()).where((n) => n.isNotEmpty).toSet().toList()
      ..sort();
    return names;
  }

  Future<void> _downloadFiltered() async {
    try {
      final rows = _dataFilteredRows;
      if (rows.isEmpty) return;
      final personLabel = _dataFilterPerson ?? 'All people';
      final monthLabel =
          _dataFilterMonth == null ? 'All months' : kMonthNames[_dataFilterMonth! - 1];
      final yearLabel = _dataFilterYear == null ? 'All years' : '$_dataFilterYear';
      final personPart = (_dataFilterPerson ?? 'all_people')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final monthPart = _dataFilterMonth == null
          ? 'all_months'
          : _dataFilterMonth!.toString().padLeft(2, '0');
      final yearPart = _dataFilterYear == null ? 'all_years' : '$_dataFilterYear';
      final title = 'Money Lent · $personLabel · $monthLabel · $yearLabel';
      final name = 'money_lent_${personPart}_${yearPart}_$monthPart';
      final headers = ['Person', 'Date', 'Amount', 'Notes'];
      final tableRows = rows
          .map(
            (e) => [
              e.personName,
              formatDate(e.givenDate),
              e.amount.toStringAsFixed(2),
              e.notes,
            ],
          )
          .toList();
      await exportTableReport(
        baseName: name,
        title: title,
        headers: headers,
        rows: tableRows,
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
      _dataFilterPerson = null;
      _dataFilterMonth = null;
      _dataFilterYear = null;
      _exportFormat = 'csv';
      _dataPage = 0;
    });
  }

  void _resetForm() {
    _editingId = null;
    _personCtrl.clear();
    _amountCtrl.clear();
    _notesCtrl.clear();
    _givenDate = DateTime.now();
  }

  void _startEdit(MoneyLent e) {
    setState(() {
      _editingId = e.id;
      _personCtrl.text = e.personName;
      _amountCtrl.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2);
      _notesCtrl.text = e.notes;
      _givenDate = e.givenDate;
      _tabs.animateTo(0);
    });
  }

  Future<void> _submit() async {
    final person = _personCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    if (person.isEmpty) {
      AppSnack.warning(context, 'Enter person name');
      return;
    }
    if (amt == null || amt < 0) {
      AppSnack.warning(context, 'Enter a valid amount');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editingId != null) {
        await _svc.update(
          _editingId!,
          personName: person,
          givenDate: _givenDate,
          amount: amt,
          notes: _notesCtrl.text.trim(),
        );
        if (mounted) AppSnack.success(context, 'Entry updated', icon: Icons.edit_rounded);
      } else {
        await _svc.create(
          personName: person,
          givenDate: _givenDate,
          amount: amt,
          notes: _notesCtrl.text.trim(),
        );
        if (mounted) AppSnack.success(context, 'Entry added', icon: Icons.add_circle_rounded);
      }
      _resetForm();
      await _reload();
    } catch (e) {
      if (mounted) AppSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(MoneyLent e) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete entry?',
      message: 'Remove ${e.personName} · ${formatMoney(e.amount)}? This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!ok) return;
    try {
      await _svc.delete(e.id);
      if (mounted) AppSnack.success(context, 'Deleted', icon: Icons.delete_rounded);
      if (_editingId == e.id) _resetForm();
      await _reload();
    } catch (err) {
      if (mounted) AppSnack.error(context, '$err');
    }
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

  Widget _label(String t, Color muted) => Text(
        t,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
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

  /// Same in-app calendar bottom sheet as Daily expense / Card spends.
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

  Color _personColor(String name) {
    return _palette[name.trim().toLowerCase().hashCode.abs() % _palette.length];
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

  Widget _empty(String msg, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: muted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _entryTile(MoneyLent e, Color ink, Color muted) {
    final color = _personColor(e.personName);
    final isDark = AppColors.isDark(context);
    final sub = [
      formatDate(e.givenDate),
      if (e.notes.trim().isNotEmpty) e.notes.trim(),
    ].join(' · ');
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
            child: Icon(Icons.person_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.personName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink, fontSize: 14),
                ),
                Text(
                  sub,
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
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionChip(
                    icon: Icons.edit_rounded,
                    color: _brand,
                    onTap: () => _startEdit(e),
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

  // ─── Entry ───────────────────────────────────────────────────────────────

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
                  _editingId != null ? 'Edit entry' : 'Money given to people',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track how much you gave each person and when.',
                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 14),
                _label('Person name', muted),
                const SizedBox(height: 6),
                TextField(
                  controller: _personCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDeco(context, hint: 'e.g. Rahul, Mom'),
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
                          _label('Date given', muted),
                          const SizedBox(height: 6),
                          _pickerField(
                            value: DateFormat('dd MMM yyyy').format(_givenDate),
                            ink: ink,
                            muted: muted,
                            icon: Icons.calendar_today_rounded,
                            onTap: () async {
                              final d = await _showCompactDatePicker(_givenDate);
                              if (d != null) setState(() => _givenDate = d);
                            },
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
                  controller: _notesCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDeco(context, hint: 'e.g. Emergency help'),
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
                                ? [
                                    _brand.withValues(alpha: 0.45),
                                    _brandDeep.withValues(alpha: 0.45),
                                  ]
                                : const [_brand, _brandDeep],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _brand.withValues(alpha: 0.28),
                              blurRadius: 12,
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
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _editingId != null
                                                ? Icons.check_rounded
                                                : Icons.add_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _editingId != null ? 'Update entry' : 'Add entry',
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
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
            _empty('No entries yet — add money you lent above', muted)
          else
            ..._list.take(5).map((e) => _entryTile(e, ink, muted)),
        ],
      ),
    );
  }

  // ─── Charts ──────────────────────────────────────────────────────────────

  Widget _buildCharts(Color ink, Color muted) {
    final entries = _summary.byPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final isDark = AppColors.isDark(context);

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brand, _brandDeep],
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
                  'Total money lent',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(_summary.total),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_summary.count} ${_summary.count == 1 ? 'entry' : 'entries'} · by person',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                            'Amount per person',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: ink,
                            ),
                          ),
                          Text(
                            _byPersonShowChart
                                ? 'Lent by person chart'
                                : 'Lent by person list',
                            style: GoogleFonts.inter(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _viewModeToggle(
                      showChart: _byPersonShowChart,
                      onChart: () => setState(() => _byPersonShowChart = true),
                      onList: () => setState(() => _byPersonShowChart = false),
                      muted: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (entries.isEmpty)
                  _empty('No money lent data to chart yet', muted)
                else if (_byPersonShowChart) ...[
                  Text(
                    'Total  ${formatMoney(_summary.total)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 240,
                    child: _amountByPersonBar(entries, ink, muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(entries.length, (i) {
                      final e = entries[i];
                      final color = _palette[i % _palette.length];
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
                            Icon(Icons.person_rounded, size: 13, color: color),
                            const SizedBox(width: 5),
                            Text(
                              e.key,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ] else
                  ...List.generate(entries.length, (i) {
                    final e = entries[i];
                    final pct = _summary.total > 0 ? e.value / _summary.total : 0.0;
                    final color = _palette[i % _palette.length];
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
                                child: Icon(Icons.person_rounded, size: 17, color: color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
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
                                formatMoney(e.value),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: ink,
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

  Widget _viewModeToggle({
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
            icon: Icons.bar_chart_rounded,
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
      color: selected
          ? _brand.withValues(alpha: isDark ? 0.35 : 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: selected ? _brand : muted),
        ),
      ),
    );
  }

  Widget _amountByPersonBar(
    List<MapEntry<String, double>> entries,
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
                  return Text(
                    '0',
                    style: GoogleFonts.inter(fontSize: 9, color: muted, fontWeight: FontWeight.w600),
                  );
                }
                final k = v >= 1000
                    ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
                    : v.toStringAsFixed(0);
                return Text(
                  k,
                  style: GoogleFonts.inter(fontSize: 9, color: muted, fontWeight: FontWeight.w600),
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
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                width: entries.length > 6 ? 14 : 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                color: _palette[i % _palette.length],
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─── Data ────────────────────────────────────────────────────────────────

  ({int page, int pageCount, int maxPage}) _pageMeta(int total) {
    final pageCount = total == 0 ? 0 : ((total + _pageSize - 1) ~/ _pageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _dataPage.clamp(0, maxPage);
    return (page: page, pageCount: pageCount, maxPage: maxPage);
  }

  List<MoneyLent> _paged(List<MoneyLent> rows) {
    if (rows.isEmpty) return [];
    final meta = _pageMeta(rows.length);
    final start = meta.page * _pageSize;
    return rows.sublist(start, (start + _pageSize).clamp(0, rows.length));
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: canPrev ? onPrev : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: canPrev ? AppColors.inkOf(context) : muted.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: canNext ? onNext : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: canNext ? AppColors.inkOf(context) : muted.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildData(Color ink, Color muted) {
    final rows = _dataFilteredRows;
    final pageMeta = _pageMeta(rows.length);
    final pageRows = _paged(rows);
    final personLabel = _dataFilterPerson ?? 'All people';
    final monthLabel =
        _dataFilterMonth == null ? 'All months' : kMonthNames[_dataFilterMonth! - 1];
    final yearLabel = _dataFilterYear == null ? 'All years' : '$_dataFilterYear';
    final isDefault = _dataFilterPerson == null &&
        _dataFilterMonth == null &&
        _dataFilterYear == null &&
        _exportFormat == 'csv';
    final filteredTotal = rows.fold<double>(0, (s, e) => s + e.amount);

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
                  'Download',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                ),
                Text(
                  'Filter by person, month and year, then export as CSV or PDF',
                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 12),
                _label('Person', muted),
                const SizedBox(height: 6),
                _pickerField(
                  value: personLabel,
                  ink: ink,
                  muted: muted,
                  // Field shows person icon; sheet header uses list (3-bar) like File type.
                  icon: Icons.person_rounded,
                  onTap: () async {
                    final options = <String>['__all__', ..._personFilterOptions];
                    final selected = _dataFilterPerson ?? '__all__';
                    final v = await _showOptionSheet<String>(
                      title: 'Person',
                      options: options,
                      labelOf: (t) => t == '__all__' ? 'All people' : t,
                      selected: selected,
                      icon: Icons.list_rounded,
                    );
                    if (v != null) {
                      setState(() {
                        _dataFilterPerson = v == '__all__' ? null : v;
                        _dataPage = 0;
                      });
                    }
                  },
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Money lent · $personLabel · $monthLabel · $yearLabel',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                ),
              ),
              Text(
                formatMoney(filteredTotal),
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _brand),
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
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _empty(
              _list.isEmpty ? 'No entries yet' : 'No entries match these filters.',
              muted,
            )
          else
            ...pageRows.map((e) => _entryTile(e, ink, muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);

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
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                title: Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger),
                ),
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
}
