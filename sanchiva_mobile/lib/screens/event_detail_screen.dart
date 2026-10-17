import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/ceremony_themes.dart';
import '../core/format.dart';
import '../core/local_date.dart';
import '../core/safe_insets.dart';
import '../core/theme.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../services/table_export.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_option_sheet.dart';
import '../widgets/app_snack.dart';

/// Event detail — Overview · Charts · Todos · Guests (pill tabs like Daily expense).
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  final _svc = EventService.instance;
  late final TabController _tabs;

  EventDetail? _detail;
  bool _loading = true;
  String? _error;
  /// Guests tab filters: empty = all. Ceremony and side combine with AND.
  String _guestCeremony = '';
  String _guestSide = '';
  int _guestPage = 0;
  static const _guestPageSize = 6;

  /// Charts tab: chart vs data list per section.
  bool _categoryShowChart = true;
  bool _budgetShowChart = true;
  bool _guestShowChart = true;
  bool _ceremonyGuestShowChart = true;

  /// Todos tab: open | completed. Add todo is an action from the top card.
  String _todoMode = 'open';
  int _todoPage = 0;
  static const _todoPageSize = 6;

  /// In-page todo editor (replaces bottom-sheet form).
  bool _todoEditorOpen = false;
  EventItem? _todoEditing;

  static const _chartPalette = <Color>[
    Color(0xFFF472B6),
    Color(0xFF60A5FA),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFFA78BFA),
    Color(0xFFFB7185),
    Color(0xFF22D3EE),
    Color(0xFFFB923C),
    Color(0xFF818CF8),
    Color(0xFF4ADE80),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Color get _accent {
    final type = _detail?.summary.eventType ?? 'other';
    return eventTypeStyle(type).$2;
  }

  IconData get _typeIcon {
    final type = _detail?.summary.eventType ?? 'other';
    return eventTypeStyle(type).$1;
  }

  Color get _deep => Color.lerp(_accent, Colors.black, 0.18) ?? _accent;

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _svc.getById(widget.eventId);
      if (!mounted) return;
      final cers = d.ceremonies;
      final sides = _guestSideNames(d);
      setState(() {
        _detail = d;
        _loading = false;
        var resetPage = false;
        if (_guestCeremony.isNotEmpty && !cers.contains(_guestCeremony)) {
          _guestCeremony = '';
          resetPage = true;
        }
        if (_guestSide.isNotEmpty && !sides.contains(_guestSide)) {
          _guestSide = '';
          resetPage = true;
        }
        if (resetPage) _guestPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final d = _detail;
    final accent = _accent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: ink, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            d?.name ?? 'Event',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
          ),
        ),
        body: _loading && d == null
            ? Center(child: CircularProgressIndicator(color: accent))
            : d == null
                ? Center(
                    child: Text(_error ?? 'Not found', style: GoogleFonts.inter(color: AppColors.danger)),
                  )
                : Column(
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
                              color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            indicatorColor: Colors.transparent,
                            splashBorderRadius: BorderRadius.circular(14),
                            labelColor: _deep,
                            unselectedLabelColor: muted,
                            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
                            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                            labelPadding: EdgeInsets.zero,
                            tabs: const [
                              Tab(height: 40, text: 'Overview'),
                              Tab(height: 40, text: 'Charts'),
                              Tab(height: 40, text: 'Todos'),
                              Tab(height: 40, text: 'Guests'),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(_error!, style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12)),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          physics: _todoEditorOpen
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          children: [
                            _scrollable(_overview(d, ink, muted, isDark, accent)),
                            _scrollable(_charts(d, ink, muted, isDark, accent)),
                            // Editor fills the tab (not inside ListView) so Back stays tappable.
                            _todoEditorOpen
                                ? Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      8 + MediaQuery.viewPaddingOf(context).bottom,
                                    ),
                                    child: _TodoEditorSection(
                                      key: ValueKey(
                                        'todo-editor-${_todoEditing?.id ?? 'new'}',
                                      ),
                                      existing: _todoEditing,
                                      eventId: widget.eventId,
                                      accent: accent,
                                      svc: _svc,
                                      onBack: _closeTodoEditor,
                                      onSaved: _onTodoEditorSaved,
                                    ),
                                  )
                                : _scrollable(_todos(d, ink, muted, isDark, accent)),
                            _scrollable(_guests(d, ink, muted, isDark, accent)),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _scrollable(List<Widget> children) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: _accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: children,
      ),
    );
  }

  String _defaultNoteForType(String eventType) {
    switch (eventType.toLowerCase().trim()) {
      case 'wedding':
        return 'Keep vendors, guest lists, and ceremony dates in sync as plans settle.';
      case 'birthday':
        return 'Track the party budget, cake, gifts, and RSVPs in one place.';
      case 'anniversary':
        return 'Plan a memorable day with a clear budget and shared checklist.';
      case 'housewarming':
        return 'Organize invites, home setup tasks, and gifts for the big move in.';
      case 'corporate':
        return 'Coordinate agenda, attendees, and spend against your event budget.';
      default:
        return 'Track budget, tasks, and guests here so nothing slips through.';
    }
  }

  List<Widget> _overview(EventDetail d, Color ink, Color muted, bool isDark, Color accent) {
    final s = d.summary;
    final m = d.money;
    final softFill = Color.lerp(accent, isDark ? AppColors.cardDark : Colors.white, isDark ? 0.82 : 0.9) ??
        AppColors.softPurpleOf(context);
    final ceremonies = d.ceremonyDetails
        .where((c) => c.name.trim().isNotEmpty && c.name.toLowerCase() != 'other' && c.name.toLowerCase() != 'general')
        .toList()
      ..sort((a, b) {
        final ad = (a.date ?? '').trim();
        final bd = (b.date ?? '').trim();
        if (ad.isEmpty && bd.isEmpty) return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (ad.isEmpty) return 1; // undated last
        if (bd.isEmpty) return -1;
        final byDate = ad.compareTo(bd); // yyyy-MM-dd sorts chronologically
        if (byDate != 0) return byDate;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final userNotes = (s.notes ?? '').trim();
    final notesText = userNotes.isNotEmpty ? userNotes : _defaultNoteForType(s.eventType);
    final isDefaultNote = userNotes.isEmpty;
    final budget = s.budget;
    final paidPct = budget > 0 ? (m.paid / budget).clamp(0.0, 1.0) : 0.0;
    final plannedPct = budget > 0 ? (m.planned / budget).clamp(0.0, 1.5) : 0.0;
    final todoPct = m.itemsTotal > 0 ? (m.itemsDone / m.itemsTotal).clamp(0.0, 1.0) : 0.0;
    // Signed: positive = still available, negative = overspent vs budget.
    final budgetBalance = budget - m.paid;

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, _deep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_typeIcon, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.styleLabel,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        s.name,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (s.location != null && s.location!.trim().isNotEmpty) ...[
              _heroPill(Icons.place_rounded, s.location!.trim()),
              const SizedBox(height: 6),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (s.eventDate != null) _heroPill(Icons.calendar_today_rounded, formatDate(s.eventDate)),
                _heroPill(Icons.flag_rounded, _detail?.statusLabel ?? s.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Notes',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            if (isDefaultNote) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  'Tip',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notesText,
                          // Default tips stay short; real notes grow with the card (no "...").
                          maxLines: isDefaultNote ? 2 : null,
                          overflow: isDefaultNote ? TextOverflow.ellipsis : TextOverflow.visible,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.35,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            fontStyle: isDefaultNote ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: softFill,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.insights_rounded, color: accent, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'At a glance',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: ink),
                      ),
                      Text(
                        'Budget, tasks, and guests',
                        style: GoogleFonts.inter(fontSize: 10.5, color: muted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _editBudget,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(accent, softFill, isDark ? 0.35 : 0.18) ?? accent,
                        Color.lerp(_deep, softFill, isDark ? 0.45 : 0.28) ?? _deep,
                      ],
                    ),
                    border: Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.28)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total budget',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.88),
                                    ),
                                  ),
                                  Text(
                                    budget > 0 ? 'Tap to edit' : 'Tap to set your budget',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.22),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    budget > 0 ? 'Edit' : 'Set',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          budget > 0 ? formatMoney(budget) : 'No budget set',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: budget > 0 ? 21 : 16,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: budget > 0 ? paidPct : 0,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.22),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                budget > 0
                                    ? '${(paidPct * 100).round()}% paid · ${formatMoney(m.paid)}'
                                    : 'Paid ${formatMoney(m.paid)}',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                            Text(
                              budget > 0
                                  ? 'Balance ${formatMoney(budgetBalance)}'
                                  : 'Set a total to track',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    label: 'Planned',
                    value: formatMoney(m.planned),
                    hint: budget > 0
                        ? '${(plannedPct * 100).clamp(0, 999).round()}% of budget'
                        : 'From todos',
                    icon: Icons.savings_rounded,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                    softFill: softFill,
                    progress: budget > 0 ? plannedPct.clamp(0.0, 1.0) : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _metricTile(
                    label: 'Paid',
                    value: formatMoney(m.paid),
                    hint: budget > 0 ? '${(paidPct * 100).round()}% of budget' : 'Tokens paid',
                    icon: Icons.payments_rounded,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                    softFill: softFill,
                    progress: budget > 0 ? paidPct : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    label: 'Todos',
                    value: '${m.itemsDone}/${m.itemsTotal}',
                    hint: m.itemsTotal == 0 ? 'No tasks yet' : '${(todoPct * 100).round()}% done',
                    icon: Icons.checklist_rounded,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                    softFill: softFill,
                    progress: m.itemsTotal > 0 ? todoPct : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _metricTile(
                    label: 'Guests',
                    value: '${m.guestCount}',
                    hint: m.guestCount == 0 ? 'None added yet' : 'On the guest list',
                    icon: Icons.groups_rounded,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                    softFill: softFill,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: softFill,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.auto_awesome_rounded, color: accent, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ceremonies',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: ink),
                      ),
                      Text(
                        ceremonies.isEmpty
                            ? 'Add Haldi, Mehendi, Reception, or custom'
                            : ceremonies.length == 1
                                ? '1 ceremony on your timeline'
                                : '${ceremonies.length} ceremonies on your timeline',
                        style: GoogleFonts.inter(fontSize: 10.5, color: muted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: accent,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: _addCeremony,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Add ceremony',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (ceremonies.isEmpty) ...[
              const SizedBox(height: 8),
              Material(
                color: softFill,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _addCeremony,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: accent.withValues(alpha: 0.28)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.add_rounded, color: accent, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add ceremony',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: ink,
                                ),
                              ),
                              Text(
                                'Name and date for your timeline',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: accent, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ceremonies.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  // Wider rectangle; tall enough for bottom edit/delete actions.
                  childAspectRatio: 1.38,
                ),
                itemBuilder: (context, i) {
                  final c = ceremonies[i];
                  return _CeremonyCard(
                    ceremony: c,
                    isDark: isDark,
                    onEdit: () => _editCeremony(c),
                    onDelete: () => _deleteCeremony(c),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ];
  }


  Widget _metricTile({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required Color ink,
    required Color muted,
    required Color accent,
    required Color softFill,
    double? progress,
    bool editable = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: softFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 11, color: accent),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (editable)
                    Icon(Icons.edit_rounded, size: 12, color: accent.withValues(alpha: 0.85)),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ink),
              ),
              const SizedBox(height: 1),
              Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 9.5, color: muted, fontWeight: FontWeight.w500),
              ),
              // Always reserve bar space so tiles in a row stay the same height
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (progress ?? 0).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 80,
            ),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  List<({String name, double planned, double paid, double remaining})> _categoryStats(EventDetail d) {
    final plannedMap = <String, double>{};
    final paidMap = <String, double>{};
    for (final item in d.items) {
      final cat = (item.category ?? '').trim();
      final key = cat.isEmpty ? 'Uncategorized' : cat;
      plannedMap[key] = (plannedMap[key] ?? 0) + item.plannedAmount;
      paidMap[key] = (paidMap[key] ?? 0) + item.tokenPaid;
    }
    final keys = {...plannedMap.keys, ...paidMap.keys};
    final list = <({String name, double planned, double paid, double remaining})>[
      for (final key in keys)
        (
          name: key,
          planned: plannedMap[key] ?? 0,
          paid: paidMap[key] ?? 0,
          remaining: (plannedMap[key] ?? 0) - (paidMap[key] ?? 0),
        ),
    ].where((e) => e.planned > 0 || e.paid > 0).toList()
      ..sort((a, b) => b.planned.compareTo(a.planned));
    return list;
  }

  Color _paletteColor(int i) => _chartPalette[i % _chartPalette.length];

  IconData _todoCategoryIcon(String category) {
    switch (category.trim().toLowerCase()) {
      case 'venue':
      case 'hall':
      case 'location':
        return Icons.location_city_rounded;
      case 'catering':
      case 'food':
      case 'dining':
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'decor':
      case 'decoration':
      case 'decorations':
        return Icons.auto_awesome_rounded;
      case 'photography':
      case 'photo':
      case 'videography':
      case 'video':
        return Icons.camera_alt_rounded;
      case 'makeup':
      case 'beauty':
      case 'personal care':
        return Icons.spa_rounded;
      case 'attire':
      case 'dress':
      case 'outfit':
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'music':
      case 'dj':
      case 'entertainment':
        return Icons.music_note_rounded;
      case 'invites':
      case 'invitation':
      case 'invitations':
      case 'cards':
        return Icons.mail_rounded;
      case 'gifts':
      case 'gift':
      case 'return gifts':
        return Icons.card_giftcard_rounded;
      case 'transport':
      case 'travel':
      case 'transportation':
        return Icons.directions_car_rounded;
      case 'accommodation':
      case 'hotel':
      case 'stay':
        return Icons.hotel_rounded;
      case 'florist':
      case 'flowers':
        return Icons.local_florist_rounded;
      case 'jewelry':
      case 'jewellery':
        return Icons.diamond_rounded;
      case 'mehendi':
      case 'mehndi':
      case 'haldi':
        return Icons.brush_rounded;
      case 'priest':
      case 'ritual':
      case 'puja':
        return Icons.temple_hindu_rounded;
      case 'guest':
      case 'guests':
      case 'hospitality':
        return Icons.groups_rounded;
      case 'cake':
      case 'bakery':
        return Icons.cake_rounded;
      case 'rent':
      case 'housing':
        return Icons.home_rounded;
      case 'bills':
      case 'bill':
        return Icons.receipt_long_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'electronics':
      case 'gadgets':
        return Icons.devices_rounded;
      case 'uncategorized':
      case 'miscellaneous':
      case 'misc':
      case 'other':
        return Icons.category_rounded;
      default:
        return Icons.label_rounded;
    }
  }

  List<Widget> _charts(EventDetail d, Color ink, Color muted, bool isDark, Color accent) {
    final softFill = Color.lerp(accent, isDark ? AppColors.cardDark : Colors.white, isDark ? 0.82 : 0.9) ??
        AppColors.softPurpleOf(context);
    final deep = _deep;
    final cats = _categoryStats(d);
    final catTotal = cats.fold<double>(0, (s, e) => s + e.planned);
    final budget = d.summary.budget;
    final paid = d.money.paid;
    final remaining = budget - paid;
    final budgetRows = <({String label, double value, Color color, IconData icon})>[
      (label: 'Budget', value: budget, color: accent, icon: Icons.account_balance_wallet_rounded),
      (label: 'Paid', value: paid, color: const Color(0xFF34D399), icon: Icons.payments_rounded),
      (
        label: 'Balance',
        value: remaining,
        color: remaining < 0 ? AppColors.danger : const Color(0xFFFBBF24),
        icon: Icons.account_balance_rounded,
      ),
    ];
    final barMax = [budget, paid, remaining.abs()].fold<double>(0, (a, b) => a > b ? a : b);

    // Guest counts by side / ceremony (uses guest.count so a family of 3 counts as 3)
    final sideMap = <String, int>{};
    final ceremonyGuestMap = <String, int>{};
    // side → ceremony → count (for Guests by side data drill-down)
    final sideCeremonyMap = <String, Map<String, int>>{};
    for (final g in d.guests) {
      final n = g.count <= 0 ? 1 : g.count;
      final side = (g.side ?? '').trim();
      final sideKey = side.isEmpty ? 'Not set' : side;
      sideMap[sideKey] = (sideMap[sideKey] ?? 0) + n;
      final cer = g.ceremony.trim();
      final cerKey = cer.isEmpty ? 'Not set' : cer;
      ceremonyGuestMap[cerKey] = (ceremonyGuestMap[cerKey] ?? 0) + n;
      final byCer = sideCeremonyMap.putIfAbsent(sideKey, () => <String, int>{});
      byCer[cerKey] = (byCer[cerKey] ?? 0) + n;
    }
    final sideRows = sideMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ceremonyGuestRows = ceremonyGuestMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final guestTotal = sideRows.fold<int>(0, (s, e) => s + e.value);
    final ceremonyGuestBarMax =
        ceremonyGuestRows.fold<double>(0, (a, e) => e.value > a ? e.value.toDouble() : a);

    Widget chartShell({
      required IconData icon,
      required String title,
      required String subtitle,
      required Widget trailing,
      required List<Widget> body,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: AppColors.cardShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.32 : 0.18),
                    accent.withValues(alpha: isDark ? 0.14 : 0.06),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ],
        ),
      );
    }

    Widget emptyState({required IconData icon, required String text}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: softFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: muted, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ],
        ),
      );
    }

    return [
      chartShell(
        icon: Icons.pie_chart_rounded,
        title: 'By category',
        subtitle: _categoryShowChart ? 'Planned share chart' : 'Category breakdown list',
        trailing: _chartViewToggle(
          showChart: _categoryShowChart,
          onChart: () => setState(() => _categoryShowChart = true),
          onList: () => setState(() => _categoryShowChart = false),
          accent: accent,
          muted: muted,
          chartIcon: Icons.pie_chart_rounded,
        ),
        body: [
          if (cats.isEmpty)
            emptyState(
              icon: Icons.donut_large_rounded,
              text: 'No category amounts yet. Add planned amounts on todos.',
            )
          else if (_categoryShowChart)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
              decoration: BoxDecoration(
                color: softFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: SizedBox(
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 48,
                        startDegreeOffset: -90,
                        sections: [
                          for (var i = 0; i < cats.length; i++)
                            PieChartSectionData(
                              value: cats[i].planned <= 0 ? 0.01 : cats[i].planned,
                              color: _paletteColor(i),
                              radius: 46,
                              title: '',
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Planned',
                          style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          formatMoney(catTotal),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: ink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(cats.length, (i) {
              final e = cats[i];
              final pct = catTotal > 0 ? e.planned / catTotal : 0.0;
              final paidPct = e.planned > 0 ? (e.paid / e.planned).clamp(0.0, 1.0) : 0.0;
              final color = _paletteColor(i);
              final icon = _todoCategoryIcon(e.name);
              return Padding(
                padding: EdgeInsets.only(bottom: i == cats.length - 1 ? 0 : 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: isDark ? 0.3 : 0.16),
                              color.withValues(alpha: isDark ? 0.12 : 0.05),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.cardOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: color.withValues(alpha: 0.35)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.name,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: ink),
                              ),
                            ),
                            Text(
                              '${(pct * 100).round()}%',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: deep),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          children: [
                            _catAmountChip(
                              label: 'Planned',
                              value: e.planned,
                              color: color,
                              ink: ink,
                              muted: muted,
                              softFill: softFill,
                            ),
                            const SizedBox(height: 6),
                            _catAmountChip(
                              label: 'Paid',
                              value: e.paid,
                              color: const Color(0xFF34D399),
                              ink: ink,
                              muted: muted,
                              softFill: softFill,
                            ),
                            const SizedBox(height: 6),
                            _catAmountChip(
                              label: 'Balance',
                              value: e.remaining,
                              color: e.remaining < 0 ? AppColors.danger : const Color(0xFFFBBF24),
                              ink: ink,
                              muted: muted,
                              softFill: softFill,
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: paidPct,
                                minHeight: 5,
                                backgroundColor: color.withValues(alpha: 0.12),
                                color: const Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e.planned > 0
                                    ? '${(paidPct * 100).round()}% of planned paid'
                                    : 'No planned amount',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      const SizedBox(height: 12),
      chartShell(
        icon: Icons.bar_chart_rounded,
        title: 'Budget overview',
        subtitle: _budgetShowChart ? 'Budget vs paid chart' : 'Budget breakdown list',
        trailing: _chartViewToggle(
          showChart: _budgetShowChart,
          onChart: () => setState(() => _budgetShowChart = true),
          onList: () => setState(() => _budgetShowChart = false),
          accent: accent,
          muted: muted,
          chartIcon: Icons.bar_chart_rounded,
        ),
        body: [
          if (barMax <= 0)
            emptyState(
              icon: Icons.account_balance_wallet_outlined,
              text: 'No budget amounts yet. Set a budget or add paid amounts on todos.',
            )
          else if (_budgetShowChart)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
              decoration: BoxDecoration(
                color: softFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: SizedBox(
                height: 210,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: barMax * 1.15,
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= budgetRows.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                budgetRows[i].label,
                                style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w700),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: accent.withValues(alpha: 0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < budgetRows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: budgetRows[i].value <= 0 ? 0.01 : budgetRows[i].value,
                              color: budgetRows[i].color,
                              width: 36,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...List.generate(budgetRows.length, (i) {
              final row = budgetRows[i];
              final pct = budget > 0 ? (row.value / budget).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: EdgeInsets.only(bottom: i == budgetRows.length - 1 ? 0 : 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: row.color.withValues(alpha: 0.22)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              row.color.withValues(alpha: isDark ? 0.3 : 0.16),
                              row.color.withValues(alpha: isDark ? 0.12 : 0.05),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.cardOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: row.color.withValues(alpha: 0.35)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(row.icon, size: 16, color: row.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                row.label,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: ink),
                              ),
                            ),
                            Text(
                              formatMoney(row.value),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
                            ),
                          ],
                        ),
                      ),
                      if (row.label != 'Budget')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: row.color.withValues(alpha: 0.12),
                                  color: row.color,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  budget > 0 ? '${(pct * 100).round()}% of budget' : 'No budget set',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      const SizedBox(height: 12),
      chartShell(
        icon: Icons.auto_awesome_rounded,
        title: 'Guests by ceremony',
        subtitle: _ceremonyGuestShowChart ? 'Ceremony wise guest chart' : 'Ceremony wise guest list',
        trailing: _chartViewToggle(
          showChart: _ceremonyGuestShowChart,
          onChart: () => setState(() => _ceremonyGuestShowChart = true),
          onList: () => setState(() => _ceremonyGuestShowChart = false),
          accent: accent,
          muted: muted,
          chartIcon: Icons.bar_chart_rounded,
        ),
        body: [
          if (ceremonyGuestRows.isEmpty)
            emptyState(
              icon: Icons.event_busy_rounded,
              text: 'No guests yet. Add guests to see ceremony counts.',
            )
          else if (_ceremonyGuestShowChart)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
              decoration: BoxDecoration(
                color: softFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: SizedBox(
                height: 210,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (ceremonyGuestBarMax <= 0 ? 1 : ceremonyGuestBarMax) * 1.25,
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= ceremonyGuestRows.length) return const SizedBox.shrink();
                            final label = ceremonyGuestRows[i].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: SizedBox(
                                width: 56,
                                child: Text(
                                  label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: accent.withValues(alpha: 0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < ceremonyGuestRows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: ceremonyGuestRows[i].value.toDouble(),
                              color: ceremonyGuestRows[i].key == 'Not set'
                                  ? accent
                                  : ceremonyThemeFor(ceremonyGuestRows[i].key).accent,
                              width: ceremonyGuestRows.length <= 3 ? 36 : 28,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                          ],
                        ),
                    ],
                    barTouchData: _intBarTouchData(
                      labels: ceremonyGuestRows.map((e) => e.key).toList(),
                      values: ceremonyGuestRows.map((e) => e.value).toList(),
                      ink: ink,
                      softFill: softFill,
                    ),
                  ),
                ),
              ),
            )
          else ...[
            ...List.generate(ceremonyGuestRows.length, (i) {
              final row = ceremonyGuestRows[i];
              final color = row.key == 'Not set' ? accent : ceremonyThemeFor(row.key).accent;
              final pct = guestTotal > 0 ? (row.value / guestTotal).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: EdgeInsets.only(bottom: i == ceremonyGuestRows.length - 1 ? 0 : 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: isDark ? 0.3 : 0.16),
                              color.withValues(alpha: isDark ? 0.12 : 0.05),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.cardOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: color.withValues(alpha: 0.35)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                row.key == 'Not set'
                                    ? Icons.help_outline_rounded
                                    : ceremonyThemeFor(row.key).icon,
                                size: 16,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                row.key,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: ink),
                              ),
                            ),
                            Text(
                              '${row.value}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: color.withValues(alpha: 0.12),
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                guestTotal > 0
                                    ? '${(pct * 100).round()}% of total guests'
                                    : 'No guests',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                              ),
                            ),
                          ],
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
      const SizedBox(height: 12),
      chartShell(
        icon: Icons.groups_rounded,
        title: 'Guests by side',
        subtitle: _guestShowChart ? 'Side wise guest chart' : 'Side and ceremony guest list',
        trailing: _chartViewToggle(
          showChart: _guestShowChart,
          onChart: () => setState(() => _guestShowChart = true),
          onList: () => setState(() => _guestShowChart = false),
          accent: accent,
          muted: muted,
          chartIcon: Icons.pie_chart_rounded,
        ),
        body: [
          if (sideRows.isEmpty)
            emptyState(
              icon: Icons.person_off_rounded,
              text: 'No guests yet. Add guests to see side counts.',
            )
          else if (_guestShowChart)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
              decoration: BoxDecoration(
                color: softFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: SizedBox(
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 48,
                        startDegreeOffset: -90,
                        sections: [
                          for (var i = 0; i < sideRows.length; i++)
                            PieChartSectionData(
                              value: sideRows[i].value <= 0 ? 0.01 : sideRows[i].value.toDouble(),
                              color: _paletteColor(i),
                              radius: 46,
                              title: '',
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Guests',
                          style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$guestTotal',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ...List.generate(sideRows.length, (i) {
              final row = sideRows[i];
              final color = _paletteColor(i);
              final cerMap = sideCeremonyMap[row.key] ?? const <String, int>{};
              final cerRows = cerMap.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              return Padding(
                padding: EdgeInsets.only(bottom: i == sideRows.length - 1 ? 0 : 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: isDark ? 0.3 : 0.16),
                              color.withValues(alpha: isDark ? 0.12 : 0.05),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.cardOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: color.withValues(alpha: 0.35)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.diversity_3_rounded, size: 16, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                row.key,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cerRows.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'By ceremony',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(cerRows.length, (ci) {
                                final cer = cerRows[ci];
                                final cerColor = cer.key == 'Not set'
                                    ? accent
                                    : ceremonyThemeFor(cer.key).accent;
                                final cerIcon = cer.key == 'Not set'
                                    ? Icons.help_outline_rounded
                                    : ceremonyThemeFor(cer.key).icon;
                                final sideCerTotal =
                                    cerRows.fold<int>(0, (s, e) => s + e.value);
                                final cerPct = sideCerTotal > 0
                                    ? (cer.value / sideCerTotal).clamp(0.0, 1.0)
                                    : 0.0;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: ci == cerRows.length - 1 ? 0 : 8),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                    decoration: BoxDecoration(
                                      color: softFill,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cerColor.withValues(alpha: 0.22)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: AppColors.cardOf(context),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: cerColor.withValues(alpha: 0.35),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(cerIcon, size: 14, color: cerColor),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cer.key,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.5,
                                                  color: ink,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${cer.value}',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: LinearProgressIndicator(
                                            value: cerPct,
                                            minHeight: 4,
                                            backgroundColor: cerColor.withValues(alpha: 0.12),
                                            color: cerColor,
                                          ),
                                        ),
                                      ],
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
              );
            }),
          ],
        ],
      ),
    ];
  }

  BarTouchData _intBarTouchData({
    required List<String> labels,
    required List<int> values,
    required Color ink,
    required Color softFill,
  }) {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        // Same default tooltip bg as Budget overview; number color matches the bar
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final i = group.x.toInt();
          if (i < 0 || i >= values.length) return null;
          final barColor = rod.gradient?.colors.first ?? rod.color ?? Colors.white;
          // Whole number only (7, not 7.0), colored like the bar
          return BarTooltipItem(
            '${values[i]}',
            GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: barColor),
          );
        },
      ),
    );
  }

  Widget _catAmountChip({
    required String label,
    required double value,
    required Color color,
    required Color ink,
    required Color muted,
    required Color softFill,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: softFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatMoney(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartViewToggle({
    required bool showChart,
    required VoidCallback onChart,
    required VoidCallback onList,
    required Color accent,
    required Color muted,
    IconData chartIcon = Icons.pie_chart_rounded,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chartViewIcon(
            icon: chartIcon,
            selected: showChart,
            onTap: onChart,
            accent: accent,
            muted: muted,
          ),
          _chartViewIcon(
            icon: Icons.view_list_rounded,
            selected: !showChart,
            onTap: onList,
            accent: accent,
            muted: muted,
          ),
        ],
      ),
    );
  }

  Widget _chartViewIcon({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color accent,
    required Color muted,
  }) {
    return Material(
      color: selected ? accent : Colors.transparent,
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

  String get _todoModeLabel {
    switch (_todoMode) {
      case 'completed':
        return 'Completed';
      default:
        return 'Open tasks';
    }
  }

  Future<void> _pickTodoMode(Color accent) async {
    final openCount = _detail?.items.where((i) => !i.isDone).length ?? 0;
    final doneCount = _detail?.items.where((i) => i.isDone).length ?? 0;
    final v = await showAppOptionSheet<String>(
      context: context,
      title: 'Todos',
      options: const ['open', 'completed'],
      labelOf: (s) => s == 'completed' ? 'Completed' : 'Open tasks',
      subtitleOf: (s) {
        if (s == 'completed') {
          return doneCount == 1 ? '1 finished task' : '$doneCount finished tasks';
        }
        return openCount == 1 ? '1 task still open' : '$openCount tasks still open';
      },
      iconOf: (s) => s == 'completed' ? Icons.task_alt_rounded : Icons.pending_actions_rounded,
      colorOf: (s) => s == 'completed' ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
      selected: _todoMode,
      icon: Icons.checklist_rounded,
      accent: accent,
    );
    if (v == null || !mounted) return;
    setState(() {
      _todoMode = v;
      _todoPage = 0;
    });
  }

  Future<void> _downloadTodos(EventDetail d, Color accent) async {
    final format = await showAppOptionSheet<String>(
      context: context,
      title: 'Download todos',
      options: const ['pdf', 'csv'],
      labelOf: (f) => f == 'pdf' ? 'PDF' : 'Excel (CSV)',
      subtitleOf: (f) => f == 'pdf' ? 'Printable document' : 'Opens in Excel or Sheets',
      iconOf: (f) => f == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
      colorOf: (f) => f == 'pdf' ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      selected: 'pdf',
      icon: Icons.download_rounded,
      accent: accent,
    );
    if (format == null || !mounted) return;

    final items = d.items.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final rows = items
        .map(
          (item) => [
            item.title,
            (item.category ?? '').trim().isEmpty ? 'Uncategorized' : item.category!.trim(),
            item.isDone ? 'Completed' : 'Open',
            item.plannedAmount.toStringAsFixed(2),
            item.tokenPaid.toStringAsFixed(2),
            (item.plannedAmount - item.tokenPaid).toStringAsFixed(2),
            (item.vendorName ?? '').trim(),
            item.dueDate == null || item.dueDate!.isEmpty ? '' : formatDate(item.dueDate),
          ],
        )
        .toList();

    if (rows.isEmpty) {
      AppSnack.warning(context, 'No todos to download');
      return;
    }

    try {
      final safe = d.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      await exportTableReport(
        baseName: '${safe.isEmpty ? 'event' : safe}_todos',
        title: '${d.name} todos',
        headers: const [
          'Title',
          'Category',
          'Status',
          'Planned',
          'Paid',
          'Balance',
          'Vendor',
          'Due date',
        ],
        rows: rows,
        format: format,
      );
      if (mounted) {
        AppSnack.success(
          context,
          format == 'pdf' ? 'PDF ready' : 'Excel file ready',
          icon: Icons.download_rounded,
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  Future<void> _toggleTodoDone(EventItem item, bool done) async {
    try {
      await _svc.updateItem(item.id, isDone: done);
      await _reload();
      if (!mounted) return;
      if (done) {
        AppSnack.success(
          context,
          'Task completed',
          icon: Icons.task_alt_rounded,
        );
      } else {
        AppSnack.success(
          context,
          'Task moved back to open',
          icon: Icons.pending_actions_rounded,
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    }
  }

  Future<void> _deleteTodo(EventItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete todo?',
      message: item.title,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await _svc.deleteItem(item.id);
      if (_todoEditing?.id == item.id) {
        _closeTodoEditor();
      }
      await _reload();
      if (mounted) AppSnack.danger(context, 'Todo deleted');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    }
  }

  List<Widget> _todos(EventDetail d, Color ink, Color muted, bool isDark, Color accent) {
    final softFill = Color.lerp(accent, isDark ? AppColors.cardDark : Colors.white, isDark ? 0.82 : 0.9) ??
        AppColors.softPurpleOf(context);
    final open = d.items.where((i) => !i.isDone).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final done = d.items.where((i) => i.isDone).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final list = _todoMode == 'completed' ? done : open;
    final total = list.length;
    final pageCount = total == 0 ? 0 : ((total + _todoPageSize - 1) ~/ _todoPageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _todoPage.clamp(0, maxPage);
    if (page != _todoPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _todoPage = page);
      });
    }
    final start = page * _todoPageSize;
    final pageRows = total == 0 ? const <EventItem>[] : list.sublist(start, (start + _todoPageSize).clamp(0, total));

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
          boxShadow: AppColors.cardShadow(context),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [softFill, AppColors.cardOf(context)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _todoMode == 'completed' ? Icons.task_alt_rounded : Icons.pending_actions_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Todos',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                      ),
                      Text(
                        _todoMode == 'completed'
                            ? '${done.length} completed'
                            : '${open.length} open, ${done.length} completed',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                      ),
                    ],
                  ),
                ),
                if (pageCount > 1)
                  _TodoPageNav(
                    label: '${page + 1}/$pageCount',
                    canPrev: page > 0,
                    canNext: page < maxPage,
                    onPrev: () => setState(() => _todoPage = page - 1),
                    onNext: () => setState(() => _todoPage = page + 1),
                    muted: muted,
                    accent: accent,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _pickTodoMode(accent),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _todoMode == 'completed' ? Icons.task_alt_rounded : Icons.pending_actions_rounded,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'View',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                            ),
                            Text(
                              _todoModeLabel,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, color: accent),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _openTodoEditor(null),
                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Add todo',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _downloadTodos(d, accent),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withValues(alpha: 0.22)),
                      ),
                      child: Icon(Icons.download_rounded, color: accent, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (pageRows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              _todoMode == 'completed'
                  ? 'No completed todos yet'
                  : 'No open tasks. Tap Add todo to create one.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: muted, fontSize: 13),
            ),
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pageRows.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 218,
          ),
          itemBuilder: (context, i) {
            final item = pageRows[i];
            return _TodoGridCard(
              item: item,
              ink: ink,
              muted: muted,
              isDark: isDark,
              accent: accent,
              categoryIcon: _todoCategoryIcon((item.category ?? '').trim().isEmpty ? 'Uncategorized' : item.category!),
              onToggleDone: (v) => _toggleTodoDone(item, v),
              onEdit: () => _openTodoEditor(item),
              onDelete: () => _deleteTodo(item),
            );
          },
        ),
    ];
  }

  List<String> _guestSideNames(EventDetail d) {
    final set = <String>{};
    for (final g in d.guests) {
      final s = (g.side ?? '').trim();
      if (s.isNotEmpty) set.add(s);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<EventGuest> _filteredGuests(EventDetail d) {
    Iterable<EventGuest> list = d.guests;
    if (_guestCeremony.isNotEmpty) {
      list = d.guestsByCeremony[_guestCeremony] ??
          d.guests.where((g) => g.ceremony == _guestCeremony);
    }
    if (_guestSide.isNotEmpty) {
      list = list.where((g) => (g.side ?? '').trim() == _guestSide);
    }
    final out = list.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  String get _guestListSubtitle {
    if (_guestCeremony.isEmpty && _guestSide.isEmpty) {
      return 'Add, edit, or filter your guest list';
    }
    if (_guestCeremony.isNotEmpty && _guestSide.isNotEmpty) {
      return '$_guestCeremony · $_guestSide side';
    }
    if (_guestCeremony.isNotEmpty) return 'Guest list for $_guestCeremony';
    return 'Guests on $_guestSide side';
  }

  Future<void> _pickGuestCeremonyFilter(EventDetail d, Color accent) async {
    final options = <String>['__all__', ...d.ceremonies];
    final selected = _guestCeremony.isEmpty ? '__all__' : _guestCeremony;
    final v = await showAppOptionSheet<String>(
      context: context,
      title: 'Ceremony',
      options: options,
      labelOf: (s) => s == '__all__' ? 'All ceremonies' : s,
      subtitleOf: (s) {
        final rows = s == '__all__'
            ? d.guests
            : (d.guestsByCeremony[s] ?? d.guests.where((g) => g.ceremony == s).toList());
        // Respect active side filter in the count preview.
        final scoped = _guestSide.isEmpty
            ? rows
            : rows.where((g) => (g.side ?? '').trim() == _guestSide).toList();
        final n = _guestPeopleCount(scoped);
        return n == 1 ? '1 guest' : '$n guests';
      },
      iconOf: (s) => s == '__all__' ? Icons.auto_awesome_rounded : ceremonyThemeFor(s).icon,
      colorOf: (s) => s == '__all__' ? accent : ceremonyThemeFor(s).accent,
      selected: selected,
      icon: Icons.auto_awesome_rounded,
      accent: accent,
    );
    if (v == null || !mounted) return;
    setState(() {
      _guestCeremony = v == '__all__' ? '' : v;
      _guestPage = 0;
    });
  }

  Future<void> _pickGuestSideFilter(EventDetail d, Color accent) async {
    final sides = _guestSideNames(d);
    final options = <String>['__all__', ...sides];
    final selected = _guestSide.isEmpty ? '__all__' : _guestSide;
    final v = await showAppOptionSheet<String>(
      context: context,
      title: 'Side',
      options: options,
      labelOf: (s) => s == '__all__' ? 'All sides' : s,
      subtitleOf: (s) {
        final rows = s == '__all__'
            ? d.guests
            : d.guests.where((g) => (g.side ?? '').trim() == s).toList();
        final scoped = _guestCeremony.isEmpty
            ? rows
            : rows.where((g) => g.ceremony == _guestCeremony).toList();
        final n = _guestPeopleCount(scoped);
        return n == 1 ? '1 guest' : '$n guests';
      },
      iconOf: (s) => s == '__all__' ? Icons.diversity_3_rounded : Icons.groups_rounded,
      colorOf: (s) => accent,
      selected: selected,
      icon: Icons.diversity_3_rounded,
      accent: accent,
    );
    if (v == null || !mounted) return;
    setState(() {
      _guestSide = v == '__all__' ? '' : v;
      _guestPage = 0;
    });
  }

  Future<void> _downloadGuests(EventDetail d, Color accent) async {
    final format = await showAppOptionSheet<String>(
      context: context,
      title: 'Download guests',
      options: const ['pdf', 'csv'],
      labelOf: (f) => f == 'pdf' ? 'PDF' : 'Excel (CSV)',
      subtitleOf: (f) => f == 'pdf' ? 'Printable document' : 'Opens in Excel or Sheets',
      iconOf: (f) => f == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
      colorOf: (f) => f == 'pdf' ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      selected: 'pdf',
      icon: Icons.download_rounded,
      accent: accent,
    );
    if (format == null || !mounted) return;

    final guests = _filteredGuests(d); // already A to Z by name
    final people = _guestPeopleCount(guests);
    final rows = guests
        .map(
          (g) => [
            g.name,
            (g.side ?? '').trim(),
            g.ceremony,
            g.rsvp,
            '${g.count <= 0 ? 1 : g.count}',
            (g.phone ?? '').trim(),
          ],
        )
        .toList();
    if (rows.isEmpty) {
      AppSnack.warning(context, 'No guests to download');
      return;
    }

    final filterBits = <String>[
      if (_guestCeremony.isNotEmpty) _guestCeremony,
      if (_guestSide.isNotEmpty) '$_guestSide side',
    ];
    final titleSuffix = filterBits.isEmpty ? 'guests' : 'guests (${filterBits.join(' · ')})';

    try {
      final safe = d.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      await exportTableReport(
        baseName: '${safe.isEmpty ? 'event' : safe}_guests',
        title: '${d.name} $titleSuffix',
        headers: const ['Name', 'Side', 'Ceremony', 'RSVP', 'Count', 'Phone'],
        rows: rows,
        format: format,
        summaryText: people == 1 ? '1 guest' : '$people guests',
        // Total row only in Excel; PDF keeps the guest count in the summary line.
        trailingRows: format == 'csv'
            ? [
                ['Total guests', '', '', '', '$people', ''],
              ]
            : null,
      );
      if (mounted) {
        AppSnack.success(
          context,
          format == 'pdf' ? 'PDF ready' : 'Excel file ready',
          icon: Icons.download_rounded,
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  Future<void> _deleteGuest(EventGuest g) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Remove guest?',
      message: g.name,
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await _svc.deleteGuest(g.id);
      await _reload();
      if (mounted) AppSnack.danger(context, 'Guest removed');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    }
  }

  /// Sum of guest.count so a family of 3 counts as 3 (matches Charts).
  int _guestPeopleCount(Iterable<EventGuest> guests) =>
      guests.fold<int>(0, (s, g) => s + (g.count <= 0 ? 1 : g.count));

  Widget _guestIconAction({
    required IconData icon,
    required Color accent,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    // Disabled = dimmed accent (not grey), so it still matches the event color.
    final iconColor = enabled ? accent : accent.withValues(alpha: 0.42);
    final borderColor = accent.withValues(alpha: enabled ? 0.22 : 0.14);
    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }

  Widget _guestFilterTile({
    required String label,
    required String value,
    required IconData icon,
    required Color ink,
    required Color muted,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: muted),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ink),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _guests(EventDetail d, Color ink, Color muted, bool isDark, Color accent) {
    final softFill = Color.lerp(accent, isDark ? AppColors.cardDark : Colors.white, isDark ? 0.82 : 0.9) ??
        AppColors.softPurpleOf(context);
    final list = _filteredGuests(d);
    final total = list.length;
    final pageCount = total == 0 ? 0 : ((total + _guestPageSize - 1) ~/ _guestPageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _guestPage.clamp(0, maxPage);
    if (page != _guestPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _guestPage = page);
      });
    }
    final start = page * _guestPageSize;
    final pageRows =
        total == 0 ? const <EventGuest>[] : list.sublist(start, (start + _guestPageSize).clamp(0, total));
    final ceremonyLabel = _guestCeremony.isEmpty ? 'All ceremonies' : _guestCeremony;
    final sideLabel = _guestSide.isEmpty ? 'All sides' : _guestSide;
    final canDownload = list.isNotEmpty;
    final canResetFilters = _guestCeremony.isNotEmpty || _guestSide.isNotEmpty;
    final emptyMessage = () {
      if (d.guests.isEmpty) return 'No guests yet. Tap Add guest to create one.';
      if (_guestCeremony.isNotEmpty && _guestSide.isNotEmpty) {
        return 'No guests for $_guestCeremony on $_guestSide side.';
      }
      if (_guestCeremony.isNotEmpty) return 'No guests for $_guestCeremony yet.';
      if (_guestSide.isNotEmpty) return 'No guests on $_guestSide side yet.';
      return 'No guests yet. Tap Add guest to create one.';
    }();

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
          boxShadow: AppColors.cardShadow(context),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [softFill, AppColors.cardOf(context)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.groups_rounded, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guests',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                      ),
                      Text(
                        _guestListSubtitle,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                      ),
                    ],
                  ),
                ),
                if (pageCount > 1)
                  _TodoPageNav(
                    label: '${page + 1}/$pageCount',
                    canPrev: page > 0,
                    canNext: page < maxPage,
                    onPrev: () => setState(() => _guestPage = page - 1),
                    onNext: () => setState(() => _guestPage = page + 1),
                    muted: muted,
                    accent: accent,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _guestFilterTile(
                    label: 'Ceremony',
                    value: ceremonyLabel,
                    icon: _guestCeremony.isEmpty
                        ? Icons.auto_awesome_rounded
                        : ceremonyThemeFor(_guestCeremony).icon,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                    onTap: () => _pickGuestCeremonyFilter(d, accent),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _guestFilterTile(
                    label: 'Side',
                    value: sideLabel,
                    icon: Icons.diversity_3_rounded,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                    onTap: () => _pickGuestSideFilter(d, accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _editGuest(null),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Add guest',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _guestIconAction(
                  icon: Icons.restart_alt_rounded,
                  accent: accent,
                  enabled: canResetFilters,
                  onTap: canResetFilters
                      ? () => setState(() {
                            _guestCeremony = '';
                            _guestSide = '';
                            _guestPage = 0;
                          })
                      : null,
                ),
                const SizedBox(width: 8),
                _guestIconAction(
                  icon: Icons.download_rounded,
                  accent: accent,
                  enabled: canDownload,
                  onTap: canDownload ? () => _downloadGuests(d, accent) : null,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (pageRows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: muted, fontSize: 13),
            ),
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pageRows.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 188,
          ),
          itemBuilder: (context, i) {
            final g = pageRows[i];
            return _GuestGridCard(
              guest: g,
              ink: ink,
              muted: muted,
              isDark: isDark,
              accent: accent,
              onEdit: () => _editGuest(g),
              onDelete: () => _deleteGuest(g),
            );
          },
        ),
    ];
  }

  Future<void> _editBudget() async {
    final current = _detail?.summary.budget ?? 0;
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _EditBudgetSheet(currentBudget: current, accent: _accent),
    );
    if (result == null || !mounted) return;
    try {
      await _svc.updateEvent(widget.eventId, budget: result);
      await _reload();
      if (mounted) AppSnack.success(context, 'Budget updated');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  Future<void> _deleteCeremony(CeremonyDetail c) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete ceremony?',
      message:
          '${c.name}\n\nGuests on this ceremony stay on the event, but their ceremony will be cleared.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await _svc.deleteCeremony(widget.eventId, name: c.name);
      if (!mounted) return;
      if (_guestCeremony == c.name) {
        _guestCeremony = '';
      }
      await _reload();
      if (mounted) AppSnack.danger(context, 'Ceremony deleted');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  Future<void> _addCeremony() async {
    final result = await showModalBottomSheet<({String name, String? date})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _EditCeremonySheet(existing: null, accent: _accent),
    );

    if (result == null || !mounted) return;
    final newName = result.name.trim();
    if (newName.isEmpty) return;

    final lower = newName.toLowerCase();
    if (lower == 'other' || lower == 'general') {
      if (mounted) AppSnack.error(context, 'Please enter a real ceremony name');
      return;
    }
    final exists = (_detail?.ceremonyDetails ?? const <CeremonyDetail>[])
        .any((c) => c.name.toLowerCase() == lower);
    if (exists) {
      if (mounted) AppSnack.error(context, 'That ceremony is already on this event');
      return;
    }

    try {
      await _svc.addCeremony(
        widget.eventId,
        name: newName,
        date: result.date,
      );
      if (!mounted) return;
      _guestCeremony = newName;
      await _reload();
      if (mounted) AppSnack.success(context, 'Ceremony added');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  Future<void> _editCeremony(CeremonyDetail existing) async {
    final originalName = existing.name;

    final result = await showModalBottomSheet<({String name, String? date})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _EditCeremonySheet(existing: existing),
    );

    if (result == null || !mounted) return;
    final newName = result.name.trim();
    if (newName.isEmpty) return;

    try {
      await _svc.updateCeremony(
        widget.eventId,
        originalName: originalName,
        name: newName,
        date: result.date,
      );
      if (!mounted) return;
      if (_guestCeremony == originalName && newName != originalName) {
        _guestCeremony = newName;
      }
      await _reload();
      if (mounted) AppSnack.success(context, 'Ceremony updated');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  void _openTodoEditor(EventItem? existing) {
    setState(() {
      _todoEditorOpen = true;
      _todoEditing = existing;
    });
  }

  void _closeTodoEditor() {
    setState(() {
      _todoEditorOpen = false;
      _todoEditing = null;
    });
  }

  Future<void> _onTodoEditorSaved(EventItem item) async {
    await _reload();
    if (!mounted) return;
    // Stay on the editor with refreshed item so more payments can be saved.
    final refreshed = _detail?.items.where((i) => i.id == item.id).toList();
    setState(() {
      _todoEditorOpen = true;
      _todoEditing = (refreshed != null && refreshed.isNotEmpty) ? refreshed.first : item;
    });
  }

  Future<void> _editGuest(EventGuest? existing) async {
    final d = _detail;
    final result = await showModalBottomSheet<
        ({String name, String side, String ceremony, String rsvp, int count})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _EditGuestSheet(
        existing: existing,
        accent: _accent,
        ceremonies: d?.ceremonies ?? const [],
        preferredCeremony: _guestCeremony,
      ),
    );
    if (result == null || !mounted) return;
    try {
      if (existing == null) {
        await _svc.addGuest(
          widget.eventId,
          name: result.name,
          side: result.side,
          ceremony: result.ceremony,
          rsvp: result.rsvp,
          count: result.count,
        );
      } else {
        await _svc.updateGuest(
          existing.id,
          name: result.name,
          side: result.side,
          ceremony: result.ceremony,
          rsvp: result.rsvp,
          count: result.count,
        );
      }
      await _reload();
      if (mounted) AppSnack.success(context, 'Guest saved');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    }
  }
}

Color _rsvpColor(String rsvp) {
  switch (rsvp.toLowerCase().trim()) {
    case 'yes':
      return const Color(0xFF34D399);
    case 'no':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFFFBBF24);
  }
}

class _GuestGridCard extends StatelessWidget {
  const _GuestGridCard({
    required this.guest,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  final EventGuest guest;
  final Color ink;
  final Color muted;
  final bool isDark;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(accent, Colors.black, 0.18) ?? accent;
    final rsvp = guest.rsvp.trim().isEmpty ? 'maybe' : guest.rsvp.trim();
    final rsvpTint = _rsvpColor(rsvp);
    final side = (guest.side ?? '').trim();
    final ceremony = guest.ceremony.trim();
    final ceremonyTint = ceremony.isEmpty ? accent : ceremonyThemeFor(ceremony).accent;

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Two-shade header: side only + actions
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.32 : 0.18),
                      accent.withValues(alpha: isDark ? 0.14 : 0.06),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        side.isEmpty ? 'Side not set' : side,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: deep),
                      ),
                    ),
                    Material(
                      color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onEdit,
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(Icons.edit_rounded, size: 13, color: deep),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Material(
                      color: AppColors.danger.withValues(alpha: isDark ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onDelete,
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(Icons.delete_rounded, size: 13, color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        guest.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          height: 1.2,
                          color: ink,
                        ),
                      ),
                      const Spacer(),
                      _infoRow('RSVP', rsvp[0].toUpperCase() + rsvp.substring(1), rsvpTint, ink, muted, isDark),
                      const SizedBox(height: 4),
                      _infoRow('Count', '${guest.count}', accent, ink, muted, isDark),
                      const SizedBox(height: 4),
                      // Ceremony gets more room / larger type so the full name fits
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          color: ceremonyTint.withValues(alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ceremonyTint.withValues(alpha: isDark ? 0.32 : 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ceremony',
                              style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ceremony.isEmpty ? 'Not set' : ceremony,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: ink,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value,
    Color tint,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: isDark ? 0.32 : 0.2)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 11, color: ink, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditGuestSheet extends StatefulWidget {
  const _EditGuestSheet({
    required this.existing,
    required this.accent,
    required this.ceremonies,
    required this.preferredCeremony,
  });

  final EventGuest? existing;
  final Color accent;
  final List<String> ceremonies;
  final String preferredCeremony;

  @override
  State<_EditGuestSheet> createState() => _EditGuestSheetState();
}

class _EditGuestSheetState extends State<_EditGuestSheet> {
  late final TextEditingController _name;
  late final TextEditingController _side;
  late final TextEditingController _count;
  late String _rsvp;
  late String _ceremony;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _side = TextEditingController(text: e?.side ?? '');
    _count = TextEditingController(text: '${e?.count ?? 1}');
    _rsvp = e?.rsvp ?? 'maybe';
    _ceremony = e?.ceremony.isNotEmpty == true
        ? e!.ceremony
        : (widget.preferredCeremony.isNotEmpty
            ? widget.preferredCeremony
            : (widget.ceremonies.isNotEmpty ? widget.ceremonies.first : ''));
  }

  @override
  void dispose() {
    _name.dispose();
    _side.dispose();
    _count.dispose();
    super.dispose();
  }

  void _submit() {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a name');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    final payload = (
      name: name,
      side: _side.text.trim(),
      ceremony: _ceremony,
      rsvp: _rsvp,
      count: int.tryParse(_count.text.trim()) ?? 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(payload);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final card = isDark ? AppColors.cardDark : Colors.white;
    final accent = widget.accent;
    final softFill = Color.lerp(accent, card, isDark ? 0.82 : 0.9) ?? AppColors.softPurpleOf(context);
    final isAdd = widget.existing == null;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = (MediaQuery.sizeOf(context).height - keyboard) * 0.78;

    return Padding(
      padding: SafeInsets.floatingSheet(context),
      child: Material(
        color: card,
        elevation: 12,
        shadowColor: accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH.clamp(320, 640)),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: softFill,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isAdd ? Icons.person_add_alt_1_rounded : Icons.manage_accounts_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdd ? 'Add guest' : 'Edit guest',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                          ),
                          Text(
                            isAdd ? 'New guest entry' : (widget.existing?.name ?? 'Update details'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: muted, size: 22),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.borderOf(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(
                        label: 'Name',
                        icon: Icons.badge_rounded,
                        controller: _name,
                        hint: 'Guest name',
                        ink: ink,
                        muted: muted,
                        accent: accent,
                        softFill: softFill,
                        enabled: !_saving,
                        errorText: _nameError,
                        onChanged: (_) {
                          if (_nameError != null) setState(() => _nameError = null);
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Side',
                        icon: Icons.diversity_3_rounded,
                        controller: _side,
                        hint: 'Bride / Groom / Family',
                        ink: ink,
                        muted: muted,
                        accent: accent,
                        softFill: softFill,
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Count',
                        icon: Icons.tag_rounded,
                        controller: _count,
                        hint: '1',
                        ink: ink,
                        muted: muted,
                        accent: accent,
                        softFill: softFill,
                        enabled: !_saving,
                        number: true,
                      ),
                      const SizedBox(height: 12),
                      Text('RSVP', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted)),
                      const SizedBox(height: 6),
                      _pickerTile(
                        icon: Icons.mark_email_read_rounded,
                        label: _rsvp,
                        tint: _rsvpColor(_rsvp),
                        ink: ink,
                        muted: muted,
                        softFill: softFill,
                        enabled: !_saving,
                        onTap: () async {
                          final v = await showAppOptionSheet<String>(
                            context: context,
                            title: 'RSVP',
                            options: const ['yes', 'no', 'maybe'],
                            labelOf: (s) => s[0].toUpperCase() + s.substring(1),
                            subtitleOf: (s) {
                              switch (s) {
                                case 'yes':
                                  return 'Confirmed attending';
                                case 'no':
                                  return 'Not attending';
                                default:
                                  return 'Not decided yet';
                              }
                            },
                            iconOf: (s) {
                              switch (s) {
                                case 'yes':
                                  return Icons.check_circle_rounded;
                                case 'no':
                                  return Icons.cancel_rounded;
                                default:
                                  return Icons.help_rounded;
                              }
                            },
                            colorOf: _rsvpColor,
                            selected: _rsvp,
                            accent: accent,
                          );
                          if (v != null && mounted) setState(() => _rsvp = v);
                        },
                      ),
                      if (widget.ceremonies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Ceremony', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted)),
                        const SizedBox(height: 6),
                        _pickerTile(
                          icon: ceremonyThemeFor(_ceremony).icon,
                          label: _ceremony.isEmpty ? 'Pick ceremony' : _ceremony,
                          tint: _ceremony.isEmpty ? accent : ceremonyThemeFor(_ceremony).accent,
                          ink: ink,
                          muted: muted,
                          softFill: softFill,
                          enabled: !_saving,
                          onTap: () async {
                            final v = await showAppOptionSheet<String>(
                              context: context,
                              title: 'Ceremony',
                              options: widget.ceremonies,
                              labelOf: (s) => s,
                              iconOf: (s) => ceremonyThemeFor(s).icon,
                              colorOf: (s) => ceremonyThemeFor(s).accent,
                              selected: _ceremony.isEmpty ? null : _ceremony,
                              accent: accent,
                            );
                            if (v != null && mounted) setState(() => _ceremony = v);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: Icon(isAdd ? Icons.person_add_alt_1_rounded : Icons.check_rounded, color: Colors.white),
                    label: Text(
                      isAdd ? 'Add guest' : 'Save changes',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: accent.withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    required Color ink,
    required Color muted,
    required Color accent,
    required Color softFill,
    required bool enabled,
    String? errorText,
    bool number = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ink),
          cursorColor: accent,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w500),
            errorText: errorText,
            prefixIcon: Icon(icon, color: accent, size: 20),
            filled: true,
            fillColor: softFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent, width: 1.4),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent.withValues(alpha: 0.2)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent.withValues(alpha: 0.12)),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required Color tint,
    required Color ink,
    required Color muted,
    required Color softFill,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: softFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: tint, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: tint),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoPageNav extends StatelessWidget {
  const _TodoPageNav({
    required this.label,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.muted,
    required this.accent,
  });

  final String label;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softPurpleOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.chevron_left_rounded, canPrev, onPrev),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
            ),
          ),
          _btn(Icons.chevron_right_rounded, canNext, onNext),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: enabled ? accent : muted.withValues(alpha: 0.35)),
        ),
      ),
    );
  }
}

class _TodoGridCard extends StatelessWidget {
  const _TodoGridCard({
    required this.item,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.accent,
    required this.categoryIcon,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  final EventItem item;
  final Color ink;
  final Color muted;
  final bool isDark;
  final Color accent;
  final IconData categoryIcon;
  final ValueChanged<bool> onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cat = (item.category ?? '').trim();
    // Signed balance: plan − paid (negative when overpaid).
    final balance = item.plannedAmount - item.tokenPaid;
    final paidPct = item.plannedAmount > 0
        ? (item.tokenPaid / item.plannedAmount).clamp(0.0, 1.0)
        : 0.0;
    final deep = Color.lerp(accent, Colors.black, 0.18) ?? accent;
    final vendor = (item.vendorName ?? '').trim();
    final balanceColor = balance < 0 ? AppColors.danger : const Color(0xFFFBBF24);

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: item.isDone ? 0.14 : 0.24)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Two-shade header like My events cards
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: isDark ? 0.32 : 0.18),
                  accent.withValues(alpha: isDark ? 0.14 : 0.06),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(categoryIcon, size: 15, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.isEmpty ? 'Uncategorized' : cat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: deep),
                  ),
                ),
                Material(
                  color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onEdit,
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: Icon(Icons.edit_rounded, size: 13, color: deep),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Material(
                  color: AppColors.danger.withValues(alpha: isDark ? 0.22 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onDelete,
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: Icon(Icons.delete_rounded, size: 13, color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: item.isDone,
                          activeColor: accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: accent.withValues(alpha: 0.45)),
                          onChanged: (v) => onToggleDone(v ?? false),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.2,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (vendor.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      vendor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10.5, color: muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                  const Spacer(),
                  _amountRow('Plan', formatMoney(item.plannedAmount), accent, ink, muted, isDark),
                  const SizedBox(height: 4),
                  _amountRow('Paid', formatMoney(item.tokenPaid), const Color(0xFF34D399), ink, muted, isDark),
                  const SizedBox(height: 4),
                  _amountRow('Balance', formatMoney(balance), balanceColor, ink, muted, isDark),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: paidPct,
                      minHeight: 3.5,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      color: const Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountRow(
    String title,
    String value,
    Color tint,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: isDark ? 0.32 : 0.2)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, color: muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 11, color: ink, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoEditorSection extends StatefulWidget {
  const _TodoEditorSection({
    super.key,
    required this.existing,
    required this.eventId,
    required this.accent,
    required this.svc,
    required this.onBack,
    required this.onSaved,
  });

  final EventItem? existing;
  final String eventId;
  final Color accent;
  final EventService svc;
  final VoidCallback onBack;
  final Future<void> Function(EventItem item) onSaved;

  @override
  State<_TodoEditorSection> createState() => _TodoEditorSectionState();
}

class _TodoEditorSectionState extends State<_TodoEditorSection> {
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _planned;
  late final TextEditingController _vendor;
  late final TextEditingController _payAmount;
  late final TextEditingController _payDetail;

  String? _titleError;
  String? _payError;
  bool _saving = false;
  /// entry | payments
  String _section = 'entry';
  late DateTime _payDate;
  String _payVia = kEventPaidViaOptions.first;
  List<EventItemPayment> _payments = const [];
  double _paidTotal = 0;
  EventItem? _item;
  EventItemPayment? _editingPayment;

  bool get _isAdd => _item == null;

  @override
  void initState() {
    super.initState();
    _item = widget.existing;
    final e = _item;
    _title = TextEditingController(text: e?.title ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _planned = TextEditingController(
      text: e == null || e.plannedAmount == 0 ? '' : _fmtAmt(e.plannedAmount),
    );
    _vendor = TextEditingController(text: e?.vendorName ?? '');
    _payAmount = TextEditingController();
    _payDetail = TextEditingController();
    _payDate = localCalendarDate();
    _payments = List<EventItemPayment>.from(e?.payments ?? const []);
    _paidTotal = e?.tokenPaid ?? 0;
  }

  static String _fmtAmt(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _planned.dispose();
    _vendor.dispose();
    _payAmount.dispose();
    _payDetail.dispose();
    super.dispose();
  }

  void _clearPaymentFields() {
    _payAmount.clear();
    _payDetail.clear();
    _payDate = localCalendarDate();
    _payVia = kEventPaidViaOptions.first;
    _editingPayment = null;
    _payError = null;
  }

  void _startEditPayment(EventItemPayment p) {
    setState(() {
      _section = 'payments';
      _editingPayment = p;
      _payAmount.text = _fmtAmt(p.amount);
      _payDate = p.paymentDate.isNotEmpty ? parseLocalYmd(p.paymentDate) : localCalendarDate();
      _payVia = kEventPaidViaOptions.contains(p.paidVia) ? p.paidVia : 'UPI';
      _payDetail.text = (p.paidViaDetail ?? '').trim();
      _payError = null;
    });
  }

  Future<void> _pickPayDate() async {
    final picked = await showAppDateSheet(
      context,
      initial: _payDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      accent: widget.accent,
    );
    if (picked != null && mounted) {
      setState(() => _payDate = localCalendarDate(picked));
    }
  }

  Future<void> _pickPayVia() async {
    final v = await showAppOptionSheet<String>(
      context: context,
      title: 'Mode of payment',
      options: kEventPaidViaOptions,
      selected: _payVia,
      icon: Icons.payments_rounded,
      accent: widget.accent,
      labelOf: (k) => k,
      iconOf: (k) => switch (k) {
        'UPI' => Icons.qr_code_2_rounded,
        'Cash' => Icons.payments_rounded,
        'Card' => Icons.credit_card_rounded,
        'Bank transfer' => Icons.account_balance_rounded,
        'Wallet' => Icons.account_balance_wallet_rounded,
        _ => Icons.payments_rounded,
      },
    );
    if (v != null && mounted) {
      setState(() {
        _payVia = v;
        if (v == 'Cash') _payDetail.clear();
      });
    }
  }

  Future<void> _deletePayment(EventItemPayment p) async {
    if (_item == null) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete payment?',
      message: 'Remove ${formatMoney(p.amount)} (${p.modeLabel})?',
      confirmLabel: 'Delete',
      tone: AppConfirmTone.danger,
    );
    if (!ok || !mounted) return;
    try {
      final res = await widget.svc.deleteItemPayment(p.id);
      if (!mounted) return;
      setState(() {
        _payments = res.payments;
        _paidTotal = res.item?.tokenPaid ?? _payments.fold<double>(0, (s, e) => s + e.amount);
        if (res.item != null) _item = res.item!.copyWith(payments: res.payments);
        if (_editingPayment?.id == p.id) _clearPaymentFields();
      });
      AppSnack.success(context, 'Payment removed');
      await widget.onSaved(_item!);
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    }
  }

  Future<void> _saveEntry() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() {
        _section = 'entry';
        _titleError = 'Enter a title';
      });
      return;
    }

    final payRaw = _payAmount.text.trim().replaceAll(',', '');
    double? payAmt;
    if (payRaw.isNotEmpty) {
      payAmt = double.tryParse(payRaw);
      if (payAmt == null || payAmt <= 0) {
        setState(() {
          _section = 'entry';
          _payError = 'Enter a valid payment amount';
        });
        return;
      }
    }

    setState(() {
      _titleError = null;
      _payError = null;
      _saving = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();

    final planned = double.tryParse(_planned.text.trim().replaceAll(',', '')) ?? 0;
    final category = _category.text.trim();
    final vendor = _vendor.text.trim();

    try {
      EventItem saved;
      if (_item == null) {
        saved = await widget.svc.addItem(
          widget.eventId,
          title: title,
          category: category,
          plannedAmount: planned,
          tokenPaid: 0,
          vendorName: vendor,
        );
      } else {
        saved = await widget.svc.updateItem(
          _item!.id,
          title: title,
          category: category,
          plannedAmount: planned,
          vendorName: vendor,
        );
      }

      if (payAmt != null && payAmt > 0) {
        final res = await widget.svc.addItemPayment(
          saved.id,
          amount: payAmt,
          paymentDate: localDateYmd(_payDate),
          paidVia: _payVia,
          paidViaDetail: _payVia == 'Cash' ? '' : _payDetail.text.trim(),
        );
        saved = res.item;
        if (mounted) {
          setState(() {
            _item = saved;
            _payments = res.payments;
            _paidTotal = saved.tokenPaid;
            _clearPaymentFields();
            _saving = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _item = saved.copyWith(payments: _payments, tokenPaid: _paidTotal);
          _saving = false;
        });
      }

      if (mounted) AppSnack.success(context, 'Saved');
      await widget.onSaved(_item ?? saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, e.toString());
    }
  }

  Future<void> _saveEditedPayment() async {
    final editing = _editingPayment;
    final item = _item;
    if (editing == null || item == null || _saving) return;

    final payAmt = double.tryParse(_payAmount.text.trim().replaceAll(',', ''));
    if (payAmt == null || payAmt <= 0) {
      setState(() => _payError = 'Enter a valid payment amount');
      return;
    }

    setState(() {
      _payError = null;
      _saving = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final res = await widget.svc.updateItemPayment(
        editing.id,
        amount: payAmt,
        paymentDate: localDateYmd(_payDate),
        paidVia: _payVia,
        paidViaDetail: _payVia == 'Cash' ? '' : _payDetail.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _item = res.item;
        _payments = res.payments;
        _paidTotal = res.item.tokenPaid;
        _clearPaymentFields();
        _saving = false;
      });
      AppSnack.success(context, 'Payment updated');
      await widget.onSaved(_item!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final card = AppColors.cardOf(context);
    final accent = widget.accent;
    final softFill =
        Color.lerp(accent, card, isDark ? 0.82 : 0.9) ?? AppColors.softPurpleOf(context);
    final planned = double.tryParse(_planned.text.trim().replaceAll(',', '')) ?? 0;
    final balance = planned - _paidTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixed header — outside scroll so Back always works
        Material(
          color: card,
          elevation: 0,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to todos',
                  onPressed: _saving
                      ? null
                      : () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          widget.onBack();
                        },
                  icon: Icon(Icons.arrow_back_rounded, color: accent),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAdd ? 'Add todo' : 'Edit todo',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: ink,
                        ),
                      ),
                      Text(
                        _isAdd
                            ? 'Entry & payments'
                            : (_item?.title ?? 'Update todo'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Entry | Payments section switcher
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: softFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _sectionTab(
                  label: 'Entry',
                  selected: _section == 'entry',
                  accent: accent,
                  ink: ink,
                  muted: muted,
                  onTap: _saving
                      ? null
                      : () => setState(() {
                            _section = 'entry';
                            if (_editingPayment != null) _clearPaymentFields();
                          }),
                ),
              ),
              Expanded(
                child: _sectionTab(
                  label: 'Payments',
                  selected: _section == 'payments',
                  accent: accent,
                  ink: ink,
                  muted: muted,
                  onTap: _saving ? null : () => setState(() => _section = 'payments'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: 8 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              if (_section == 'entry')
                ..._entryBody(
                  ink: ink,
                  muted: muted,
                  isDark: isDark,
                  accent: accent,
                  softFill: softFill,
                  balance: balance,
                )
              else
                ..._paymentsBody(
                  ink: ink,
                  muted: muted,
                  isDark: isDark,
                  accent: accent,
                  softFill: softFill,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTab({
    required String label,
    required bool selected,
    required Color accent,
    required Color ink,
    required Color muted,
    VoidCallback? onTap,
  }) {
    return Material(
      color: selected ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? Colors.white : muted,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _entryBody({
    required Color ink,
    required Color muted,
    required bool isDark,
    required Color accent,
    required Color softFill,
    required double balance,
  }) {
    return [
      _card(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleRow('Todo details', Icons.checklist_rounded, ink, accent),
            const SizedBox(height: 12),
            _field(
              label: 'Title',
              controller: _title,
              hint: 'What needs to be done?',
              ink: ink,
              muted: muted,
              accent: accent,
              softFill: softFill,
              enabled: !_saving,
              errorText: _titleError,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 10),
            _field(
              label: 'Category',
              controller: _category,
              hint: 'Venue, catering, decor…',
              ink: ink,
              muted: muted,
              accent: accent,
              softFill: softFill,
              enabled: !_saving,
            ),
            const SizedBox(height: 10),
            _field(
              label: 'Planned amount',
              controller: _planned,
              hint: '0',
              ink: ink,
              muted: muted,
              accent: accent,
              softFill: softFill,
              enabled: !_saving,
              number: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _field(
              label: 'Vendor',
              controller: _vendor,
              hint: 'Optional',
              ink: ink,
              muted: muted,
              accent: accent,
              softFill: softFill,
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statChip(
                    'Paid',
                    formatMoney(_paidTotal),
                    const Color(0xFF34D399),
                    ink,
                    muted,
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statChip(
                    'Balance',
                    formatMoney(balance),
                    balance < 0 ? AppColors.danger : const Color(0xFFFBBF24),
                    ink,
                    muted,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _card(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleRow('New payment (optional)', Icons.payments_rounded, ink, accent),
            const SizedBox(height: 4),
            Text(
              'Fill amount to add a payment when you save.',
              style: GoogleFonts.inter(fontSize: 11.5, color: muted),
            ),
            const SizedBox(height: 12),
            ..._paymentFields(
              ink: ink,
              muted: muted,
              accent: accent,
              softFill: softFill,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _saveEntry,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: accent.withValues(alpha: 0.45),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Text(
                  'Save changes',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                ),
        ),
      ),
    ];
  }

  List<Widget> _paymentsBody({
    required Color ink,
    required Color muted,
    required bool isDark,
    required Color accent,
    required Color softFill,
  }) {
    final editing = _editingPayment;
    return [
      if (editing != null) ...[
        _card(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _titleRow('Edit payment', Icons.edit_rounded, ink, accent),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(_clearPaymentFields),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._paymentFields(
                ink: ink,
                muted: muted,
                accent: accent,
                softFill: softFill,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveEditedPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent.withValues(alpha: 0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Update payment',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      _card(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleRow(
              'Payment list (${_payments.length})',
              Icons.receipt_long_rounded,
              ink,
              accent,
            ),
            const SizedBox(height: 10),
            if (_item == null)
              Text(
                'Save the todo on Entry first, then payments will appear here.',
                style: GoogleFonts.inter(fontSize: 12.5, color: muted),
              )
            else if (_payments.isEmpty)
              Text(
                'No payments yet. Add one from the Entry section.',
                style: GoogleFonts.inter(fontSize: 12.5, color: muted),
              )
            else
              ..._payments.map(
                (p) => _paymentTile(p, ink, muted, accent, softFill, isDark),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _paymentFields({
    required Color ink,
    required Color muted,
    required Color accent,
    required Color softFill,
  }) {
    return [
      _field(
        label: 'Amount',
        controller: _payAmount,
        hint: '0',
        ink: ink,
        muted: muted,
        accent: accent,
        softFill: softFill,
        enabled: !_saving,
        number: true,
        errorText: _payError,
        onChanged: (_) {
          if (_payError != null) setState(() => _payError = null);
        },
      ),
      const SizedBox(height: 10),
      Text(
        'Date',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
      ),
      const SizedBox(height: 6),
      _pickerTile(
        icon: Icons.calendar_today_rounded,
        label: formatDate(_payDate),
        ink: ink,
        muted: muted,
        accent: accent,
        softFill: softFill,
        onTap: _saving ? null : _pickPayDate,
      ),
      const SizedBox(height: 10),
      Text(
        'Mode',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
      ),
      const SizedBox(height: 6),
      _pickerTile(
        icon: Icons.payments_rounded,
        label: _payVia,
        ink: ink,
        muted: muted,
        accent: accent,
        softFill: softFill,
        onTap: _saving ? null : _pickPayVia,
      ),
      if (_payVia != 'Cash') ...[
        const SizedBox(height: 10),
        _field(
          label: eventPaidViaDetailLabel(_payVia),
          controller: _payDetail,
          hint: eventPaidViaDetailHint(_payVia),
          ink: ink,
          muted: muted,
          accent: accent,
          softFill: softFill,
          enabled: !_saving,
        ),
      ],
    ];
  }

  Widget _paymentTile(
    EventItemPayment p,
    Color ink,
    Color muted,
    Color accent,
    Color softFill,
    bool isDark,
  ) {
    final selected = _editingPayment?.id == p.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: softFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: selected ? 0.45 : 0.16),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMoney(p.amount),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.paymentDate.isEmpty ? '-' : formatDate(p.paymentDate)} · ${p.modeLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: _saving ? null : () => _startEditPayment(p),
            icon: Icon(Icons.edit_rounded, size: 18, color: accent),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: _saving ? null : () => _deletePayment(p),
            icon: Icon(
              Icons.delete_rounded,
              size: 18,
              color: AppColors.danger.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Color accent, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: child,
    );
  }

  Widget _titleRow(String title, IconData icon, Color ink, Color accent) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
          ),
        ),
      ],
    );
  }

  Widget _statChip(
    String label,
    String value,
    Color tint,
    Color ink,
    Color muted,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: isDark ? 0.32 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: ink),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required Color ink,
    required Color muted,
    required Color accent,
    required Color softFill,
    VoidCallback? onTap,
  }) {
    return Material(
      color: softFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: ink),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Color ink,
    required Color muted,
    required Color accent,
    required Color softFill,
    required bool enabled,
    String? errorText,
    bool number = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
              : null,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: muted.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            errorText: errorText,
            filled: true,
            fillColor: softFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditBudgetSheet extends StatefulWidget {
  const _EditBudgetSheet({required this.currentBudget, required this.accent});

  final double currentBudget;
  final Color accent;

  @override
  State<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends State<_EditBudgetSheet> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;

  static String _formatAmount(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toString();
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _formatAmount(widget.currentBudget));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_saving) return;
    final raw = _ctrl.text.trim().replaceAll(',', '');
    if (raw.isEmpty) {
      setState(() => _error = 'Enter a budget amount');
      return;
    }
    final value = double.tryParse(raw);
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final card = isDark ? AppColors.cardDark : Colors.white;
    final accent = widget.accent;
    final softFill = Color.lerp(accent, card, isDark ? 0.82 : 0.9) ?? AppColors.softPurpleOf(context);

    return Padding(
      padding: SafeInsets.floatingSheet(context),
      child: Material(
        color: card,
        elevation: 12,
        shadowColor: accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: softFill,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.account_balance_wallet_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit budget',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                        ),
                        Text(
                          'Total amount set aside for this event',
                          style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: muted, size: 22),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderOf(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total budget',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ctrl,
                    enabled: !_saving,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _submit(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ink),
                    cursorColor: accent,
                    decoration: InputDecoration(
                      hintText: 'e.g. 500000',
                      hintStyle: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w500),
                      errorText: _error,
                      prefixIcon: Icon(Icons.payments_rounded, color: accent, size: 20),
                      filled: true,
                      fillColor: softFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: accent, width: 1.4),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.2)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent.withValues(alpha: 0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Save budget', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its text controller so dispose is safe after the route is gone.
class _EditCeremonySheet extends StatefulWidget {
  const _EditCeremonySheet({this.existing, this.accent});

  final CeremonyDetail? existing;
  final Color? accent;

  @override
  State<_EditCeremonySheet> createState() => _EditCeremonySheetState();
}

class _EditCeremonySheetState extends State<_EditCeremonySheet> {
  late final TextEditingController _nameCtrl;
  String? _dateIso;
  String? _nameError;
  bool _saving = false;

  bool get _isAdd => widget.existing == null;

  CeremonyTheme get _theme {
    final typed = _nameCtrl.text.trim();
    if (typed.isNotEmpty) return ceremonyThemeFor(typed);
    if (widget.existing != null) return ceremonyThemeFor(widget.existing!.name);
    return ceremonyThemeFor('Ceremony');
  }

  Color get _sheetAccent {
    if (_isAdd && (_nameCtrl.text.trim().isEmpty)) {
      return widget.accent ?? _theme.accent;
    }
    return _theme.accent;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _dateIso = widget.existing?.date;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    DateTime? initial;
    if (_dateIso != null && _dateIso!.isNotEmpty) {
      initial = DateTime.tryParse(_dateIso!);
    }
    final picked = await showAppDateSheet(
      context,
      initial: initial,
      accent: _sheetAccent,
    );
    if (!mounted || picked == null) return;
    setState(() => _dateIso = DateFormat('yyyy-MM-dd').format(picked));
  }

  void _submit() {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a ceremony name');
      return;
    }
    final lower = name.toLowerCase();
    if (lower == 'other' || lower == 'general') {
      setState(() => _nameError = 'Please enter a real ceremony name');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    // Pop after the keyboard/frame settles to avoid InheritedWidget dispose races.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop((name: name, date: _dateIso));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final card = isDark ? AppColors.cardDark : Colors.white;
    final theme = _theme;
    final accent = _sheetAccent;
    final softFill = Color.lerp(accent, card, isDark ? 0.82 : 0.9) ?? AppColors.softPurpleOf(context);

    return Padding(
      padding: SafeInsets.floatingSheet(context),
      child: Material(
        color: card,
        elevation: 12,
        shadowColor: accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: softFill,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    alignment: Alignment.center,
                    child: theme.key == 'engagement'
                        ? EngagementRingIcon(color: accent, size: 20)
                        : Icon(
                            _isAdd && _nameCtrl.text.trim().isEmpty
                                ? Icons.add_rounded
                                : theme.icon,
                            color: accent,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAdd ? 'Add ceremony' : 'Edit ceremony',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                        ),
                        Text(
                          _isAdd
                              ? 'Name and date for your timeline'
                              : (widget.existing?.name ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: muted, size: 22),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderOf(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Name',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    enabled: !_saving,
                    autofocus: _isAdd,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      setState(() {
                        if (_nameError != null) _nameError = null;
                      });
                    },
                    onSubmitted: (_) => _submit(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ink),
                    cursorColor: accent,
                    decoration: InputDecoration(
                      hintText: _isAdd ? 'e.g. Haldi, Mehendi, Reception' : 'Ceremony name',
                      hintStyle: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w500),
                      errorText: _nameError,
                      filled: true,
                      fillColor: softFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: accent, width: 1.4),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.2)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Date',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: softFill,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving ? null : _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dateIso == null || _dateIso!.isEmpty ? 'Pick a date' : formatDate(_dateIso),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: _dateIso == null || _dateIso!.isEmpty ? muted : ink,
                                ),
                              ),
                            ),
                            if (_dateIso != null && _dateIso!.isNotEmpty)
                              GestureDetector(
                                onTap: _saving ? null : () => setState(() => _dateIso = null),
                                child: Icon(Icons.close_rounded, size: 18, color: muted),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent.withValues(alpha: 0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isAdd ? 'Add ceremony' : 'Save changes',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CeremonyCard extends StatelessWidget {
  const _CeremonyCard({
    required this.ceremony,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  final CeremonyDetail ceremony;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = ceremonyThemeFor(ceremony.name);
    final quote = (ceremony.quote != null && ceremony.quote!.trim().isNotEmpty)
        ? ceremony.quote!.trim()
        : theme.quote;
    final top = theme.gradient.first.withValues(alpha: isDark ? 0.38 : 0.55);
    final mid = theme.gradient[1].withValues(alpha: isDark ? 0.22 : 0.35);
    final bottom = (isDark ? AppColors.cardDark : Colors.white).withValues(alpha: isDark ? 0.92 : 0.92);
    const danger = Color(0xFFDC2626);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [top, mid, bottom],
          ),
          border: Border.all(color: theme.accent.withValues(alpha: 0.35)),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: theme.accent.withValues(alpha: 0.35)),
                    ),
                    alignment: Alignment.center,
                    child: theme.key == 'engagement'
                        ? EngagementRingIcon(color: theme.accent, size: 12)
                        : Icon(theme.icon, size: 12, color: theme.accent),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ceremony.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: isDark ? Colors.white : theme.ink,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 10, color: theme.accent),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      ceremony.date != null ? formatDate(ceremony.date) : 'No date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : theme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  quote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    height: 1.25,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white60 : theme.ink.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: theme.accent.withValues(alpha: isDark ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(7),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(7),
                        onTap: onEdit,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(Icons.edit_rounded, size: 12, color: theme.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: danger.withValues(alpha: isDark ? 0.28 : 0.12),
                      borderRadius: BorderRadius.circular(7),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(7),
                        onTap: onDelete,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(Icons.delete_rounded, size: 13, color: danger),
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
  }
}
