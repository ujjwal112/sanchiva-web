import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_option_sheet.dart';
import '../widgets/app_snack.dart';
import '../widgets/section_header_card.dart';
import 'event_detail_screen.dart';

/// Events hub: Create (wizard) and My events. Same pill tabs as Daily expense.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.initialTab = 0});

  /// 0 Create, 1 My events
  final int initialTab;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  /// Matches Home quick action Events tile.
  static const _eventsAccent = Color(0xFFE879F9);
  static const _eventsAccentDeep = Color(0xFFC026D3);

  static const _types = <(String id, String label, IconData icon, Color color)>[
    ('wedding', 'Wedding', Icons.diamond_rounded, Color(0xFFF472B6)),
    ('birthday', 'Birthday', Icons.cake_rounded, Color(0xFFFBBF24)),
    ('anniversary', 'Anniversary', Icons.favorite_rounded, Color(0xFFE879F9)),
    ('housewarming', 'Housewarming', Icons.home_rounded, Color(0xFF60A5FA)),
    ('corporate', 'Corporate', Icons.apartment_rounded, Color(0xFF818CF8)),
    ('other', 'Other', Icons.auto_awesome_rounded, Color(0xFF34D399)),
  ];

  static (IconData icon, Color color) typeStyle(String eventType) {
    final id = eventType.toLowerCase().trim();
    for (final t in _types) {
      if (t.$1 == id) return (t.$3, t.$4);
    }
    return (Icons.auto_awesome_rounded, const Color(0xFF34D399));
  }

  late final TabController _tabs;
  final _svc = EventService.instance;

  // List
  List<EventSummary> _events = [];
  bool _listLoading = true;
  String? _listError;
  int _listPage = 0;
  /// 2×2 grid: 4 cards per page.
  static const _listPageSize = 4;

  // Wizard
  String _wizStep = 'pick'; // pick | questions | done
  String? _eventType;
  List<WizardQuestion> _questions = [];
  String _intro = '';
  int _qIndex = 0;
  final Map<String, dynamic> _answers = {};
  final _answerCtrl = TextEditingController();
  FocusNode _answerFocus = FocusNode();
  int _answerFieldGen = 0;
  final Set<String> _multiSel = {};
  final List<String> _customCeremonies = [];
  final _customCtrl = TextEditingController();
  bool _creating = false;
  String? _createdId;
  String? _createdName;
  int _createdTodos = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _loadList();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _answerCtrl.dispose();
    _answerFocus.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  bool _isTypedAnswer(String type) =>
      type == 'text' || type == 'number' || type == 'textarea';

  TextInputType _keyboardFor(String type) {
    if (type == 'number') {
      return const TextInputType.numberWithOptions(decimal: true, signed: false);
    }
    if (type == 'textarea') {
      return TextInputType.multiline;
    }
    return TextInputType.text;
  }

  /// Fresh focus node each question so the keyboard opens reliably after Q3+.
  void _prepareAnswerFocus(WizardQuestion? q) {
    final old = _answerFocus;
    _answerFocus = FocusNode();
    _answerFieldGen++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
    });

    final question = q ?? _currentQ;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (question != null && _isTypedAnswer(question.type)) {
        FocusScope.of(context).requestFocus(_answerFocus);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_isTypedAnswer(question.type) && !_answerFocus.hasFocus) {
            _answerFocus.requestFocus();
          }
        });
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _restoreAnswerIntoUi(WizardQuestion q) {
    _answerCtrl.clear();
    _multiSel.clear();
    _customCeremonies.clear();
    _customCtrl.clear();
    final saved = _answers[q.id];
    if (q.type == 'multiselect' && saved is List) {
      final items = saved.map((e) => e.toString()).toList();
      final opts = q.options.toSet();
      for (final item in items) {
        if (opts.contains(item)) {
          _multiSel.add(item);
        } else if (item.toLowerCase() != 'other') {
          _customCeremonies.add(item);
        }
      }
      if (_customCeremonies.isNotEmpty) _multiSel.add('Other');
    } else if (saved != null && saved.toString().isNotEmpty) {
      _answerCtrl.text = saved.toString();
    } else if (q.defaultValue != null) {
      _answerCtrl.text = '${q.defaultValue}';
    }
  }

  /// Capture whatever is currently in the answer UI into [_answers] (no validation).
  void _persistCurrentAnswerDraft(WizardQuestion q) {
    dynamic value;
    if (q.type == 'multiselect') {
      final builtIn = _multiSel.where((x) => x != 'Other').toList();
      value = [...builtIn, ..._customCeremonies];
    } else if (q.type == 'number') {
      final t = _answerCtrl.text.trim();
      value = t.isEmpty ? '' : (num.tryParse(t) ?? t);
    } else {
      value = _answerCtrl.text.trim();
    }
    _answers[q.id] = value;
    if (q.id == 'name') _answers['name'] = value;
  }

  void _goBackQuestion() {
    if (_creating || _qIndex <= 0) return;
    final cur = _currentQ;
    if (cur != null) _persistCurrentAnswerDraft(cur);
    final prevIndex = _qIndex - 1;
    final prevQ = _questions[prevIndex];
    _prepareAnswerFocus(prevQ);
    setState(() {
      _qIndex = prevIndex;
      _restoreAnswerIntoUi(prevQ);
    });
  }

  void _goTab(int i) {
    if (_tabs.index != i) _tabs.animateTo(i);
  }

  /// Upcoming first (soonest on top), then undated, then past (newest past first).
  List<EventSummary> _sortEventsByDate(List<EventSummary> input) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime? parse(String? raw) {
      if (raw == null || raw.trim().isEmpty) return null;
      final d = DateTime.tryParse(raw.trim());
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }

    int bucket(DateTime? d) {
      if (d == null) return 1; // undated
      if (d.isBefore(today)) return 2; // past
      return 0; // upcoming / today
    }

    final copy = [...input];
    copy.sort((a, b) {
      final da = parse(a.eventDate);
      final db = parse(b.eventDate);
      final ba = bucket(da);
      final bb = bucket(db);
      if (ba != bb) return ba.compareTo(bb);
      if (ba == 0) {
        // upcoming: soonest first
        return da!.compareTo(db!);
      }
      if (ba == 2) {
        // past: most recent first
        return db!.compareTo(da!);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return copy;
  }

  Future<void> _loadList() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final list = await _svc.list();
      if (!mounted) return;
      final sorted = _sortEventsByDate(list);
      setState(() {
        _events = sorted;
        _listLoading = false;
        final maxPage = sorted.isEmpty ? 0 : ((sorted.length - 1) ~/ _listPageSize);
        if (_listPage > maxPage) _listPage = maxPage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = e.toString().replaceFirst('ApiException: ', '');
        _listLoading = false;
      });
    }
  }

  void _resetWizard() {
    setState(() {
      _wizStep = 'pick';
      _eventType = null;
      _questions = [];
      _intro = '';
      _qIndex = 0;
      _answers.clear();
      _answerCtrl.clear();
      _multiSel.clear();
      _customCeremonies.clear();
      _customCtrl.clear();
      _creating = false;
      _createdId = null;
      _createdName = null;
      _createdTodos = 0;
    });
  }

  Future<void> _startWizard(String type) async {
    setState(() => _creating = true);
    try {
      final meta = await _svc.wizardQuestions(type);
      if (!mounted) return;
      setState(() {
        _eventType = type;
        _questions = List.of(meta.questions);
        _intro = meta.intro;
        _qIndex = 0;
        _answers.clear();
        _answerCtrl.clear();
        _multiSel.clear();
        _customCeremonies.clear();
        _wizStep = 'questions';
        _creating = false;
        final q = _questions.isNotEmpty ? _questions[0] : null;
        if (q?.defaultValue != null) {
          _answerCtrl.text = '${q!.defaultValue}';
        }
      });
      _prepareAnswerFocus(_questions.isNotEmpty ? _questions[0] : null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  WizardQuestion? get _currentQ =>
      (_qIndex >= 0 && _qIndex < _questions.length) ? _questions[_qIndex] : null;

  bool _hasAnswerValue(dynamic v) {
    if (v == null) return false;
    if (v is String && v.trim().isEmpty) return false;
    if (v is List && v.isEmpty) return false;
    return true;
  }

  /// Live draft from the answer UI for the current question (for instant summary updates).
  dynamic _currentAnswerDraft(WizardQuestion q) {
    if (q.type == 'multiselect') {
      return [..._multiSel.where((x) => x != 'Other'), ..._customCeremonies];
    }
    if (q.type == 'number') {
      final t = _answerCtrl.text.trim();
      return t.isEmpty ? '' : (num.tryParse(t) ?? t);
    }
    return _answerCtrl.text.trim();
  }

  /// Persistent answered list — keeps every answered question even when going back.
  /// Current question uses the live draft so edits show immediately.
  List<(WizardQuestion q, dynamic value)> get _answeredPairs {
    final out = <(WizardQuestion, dynamic)>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      dynamic v;
      if (i == _qIndex) {
        final draft = _currentAnswerDraft(q);
        v = _hasAnswerValue(draft) ? draft : _answers[q.id];
      } else {
        v = _answers[q.id];
      }
      if (!_hasAnswerValue(v)) continue;
      out.add((q, v));
    }
    return out;
  }

  String _displayWizardAnswer(WizardQuestion q, dynamic value) {
    if (value == null) return '—';
    if (q.type == 'date') {
      final s = value.toString().trim();
      if (s.isEmpty) return '—';
      return formatDate(s);
    }
    if (value is List) {
      final parts = value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty && e.toLowerCase() != 'other')
          .toList();
      return parts.isEmpty ? '—' : parts.join(', ');
    }
    final s = value.toString().trim();
    if (s.isEmpty) return '—';
    if (q.type == 'number') {
      final n = num.tryParse(s);
      if (n != null) return formatMoney(n.toDouble());
    }
    return s;
  }

  Color get _wizColor => typeStyle(_eventType ?? 'other').$2;
  IconData get _wizIcon => typeStyle(_eventType ?? 'other').$1;
  Color get _wizDeep => Color.lerp(_wizColor, Colors.black, 0.18) ?? _wizColor;

  String get _wizTypeLabel {
    final id = (_eventType ?? '').toLowerCase();
    for (final t in _types) {
      if (t.$1 == id) return t.$2;
    }
    return _eventType ?? 'Event';
  }

  String _labelWithCurrency(String label) {
    final sample = formatMoney(0);
    final sym = sample.replaceAll(RegExp(r'[\d\s,.]'), '');
    var out = label.replaceAll('{currency}', sym.isEmpty ? '₹' : sym);
    if (sym.isNotEmpty) out = out.replaceAll('₹', sym);
    // Never show dash punctuation in UI copy.
    out = out.replaceAll('—', '. ').replaceAll('–', ' ');
    return out;
  }

  Future<void> _pickSelect(WizardQuestion q) async {
    final v = await showAppOptionSheet<String>(
      context: context,
      title: _labelWithCurrency(q.label),
      options: q.options,
      labelOf: (s) => s,
      selected: _answerCtrl.text.isEmpty ? null : _answerCtrl.text,
      icon: Icons.tune_rounded,
      accent: _wizColor,
    );
    if (v != null && mounted) {
      setState(() => _answerCtrl.text = v);
    }
  }

  Future<void> _pickDate() async {
    DateTime? initial;
    if (_answerCtrl.text.isNotEmpty) {
      initial = DateTime.tryParse(_answerCtrl.text);
    }
    final d = await showAppDateSheet(
      context,
      initial: initial,
      accent: _wizColor,
    );
    if (d != null && mounted) {
      setState(() {
        _answerCtrl.text = DateFormat('yyyy-MM-dd').format(d);
      });
    }
  }

  Future<void> _pushAnswer() async {
    final q = _currentQ;
    if (q == null || _creating) return;

    dynamic value;
    if (q.type == 'multiselect') {
      final builtIn = _multiSel.where((x) => x != 'Other').toList();
      value = [...builtIn, ..._customCeremonies];
      if (_multiSel.contains('Other') &&
          q.allowCustom &&
          _customCeremonies.isEmpty) {
        AppSnack.warning(context, 'Add a custom ceremony name, or unselect Other');
        return;
      }
    } else if (q.type == 'number') {
      final t = _answerCtrl.text.trim();
      value = t.isEmpty ? '' : (num.tryParse(t) ?? t);
    } else {
      value = _answerCtrl.text.trim();
    }

    final empty = value == null ||
        value == '' ||
        (value is List && value.isEmpty);
    if (q.required && empty) {
      AppSnack.warning(context, 'This field is required');
      return;
    }

    final next = Map<String, dynamic>.from(_answers);
    next[q.id] = value;
    if (q.id == 'name') next['name'] = value;

    // Inject ceremony date questions after ceremonies multiselect
    var questions = List<WizardQuestion>.from(_questions);
    var nextIndex = _qIndex + 1;

    if (q.id == 'ceremonies' && value is List && value.isNotEmpty) {
      final names = value
          .map((e) => e.toString())
          .where((n) => n.isNotEmpty && n.toLowerCase() != 'other')
          .toList();
      questions = questions
          .where((qq) => !qq.id.startsWith('ceremony_date_'))
          .toList();
      final idx = questions.indexWhere((qq) => qq.id == 'ceremonies');
      if (idx >= 0 && names.isNotEmpty) {
        final dateQs = <WizardQuestion>[];
        for (var i = 0; i < names.length; i++) {
          dateQs.add(
            WizardQuestion(
              id: 'ceremony_date_$i',
              label: 'When is the ${names[i]} ceremony?',
              type: 'date',
              required: true,
            ),
          );
          // Store ceremony name mapping like web does via answers ceremony_date_*
        }
        questions = [
          ...questions.sublist(0, idx + 1),
          ...dateQs,
          ...questions.sublist(idx + 1),
        ];
      }
      // Also store parallel ceremony_date__Name keys if answers use index
      for (var i = 0; i < names.length; i++) {
        // server buildCeremonyDetails looks at ceremony_date_$i
      }
    }

    setState(() {
      _answers
        ..clear()
        ..addAll(next);
      _questions = questions;
      _multiSel.clear();
      _customCeremonies.clear();
      _customCtrl.clear();
      _answerCtrl.clear();
    });

    if (nextIndex < questions.length) {
      final nq = questions[nextIndex];
      _prepareAnswerFocus(nq);
      setState(() {
        _qIndex = nextIndex;
        _restoreAnswerIntoUi(nq);
      });
      return;
    }

    // Finish wizard
    setState(() => _creating = true);
    try {
      final name = (next['name'] ?? '${_eventType ?? 'Event'} event').toString();
      final created = await _svc.createFromWizard(
        name: name,
        eventType: _eventType!,
        answers: next,
      );
      // Fetch detail for todo count
      int todos = 0;
      try {
        final d = await _svc.getById(created.id);
        todos = d.items.length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _creating = false;
        _wizStep = 'done';
        _createdId = created.id;
        _createdName = created.name;
        _createdTodos = todos;
      });
      await _loadList();
      AppSnack.success(context, 'Event created');
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
    }
  }

  Future<void> _deleteEvent(EventSummary ev) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete event?',
      message: 'Delete “${ev.name}”? This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
    );
    if (!ok) return;
    try {
      await _svc.deleteEvent(ev.id);
      await _loadList();
      if (mounted) AppSnack.danger(context, 'Event deleted');
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, e.toString().replaceFirst('ApiException: ', ''));
      }
    }
  }

  void _openDetail(String id) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(eventId: id),
      ),
    )
        .then((_) => _loadList());
  }

  bool get _inWizardFlow => _wizStep == 'questions' || _wizStep == 'done';

  void _exitWizardToPick() {
    FocusManager.instance.primaryFocus?.unfocus();
    _resetWizard();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final inWizard = _inWizardFlow;

    return PopScope(
      canPop: !inWizard,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (inWizard) _exitWizardToPick();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
              onPressed: () {
                if (inWizard) {
                  _exitWizardToPick();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              inWizard
                  ? (_wizStep == 'done' ? 'Event ready' : '$_wizTypeLabel questions')
                  : 'Events',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: ink,
              ),
            ),
          ),
          body: inWizard
              // Full-screen questions / done step — separate from Create/My events.
              ? _buildCreate(ink, muted, isDark)
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: SectionHeaderCard(
                        icon: Icons.celebration_rounded,
                        title: 'Events',
                        subtitle: 'Plan weddings, birthdays and more with smart checklists',
                        accent: _eventsAccent,
                        accentDeep: _eventsAccentDeep,
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
                            color: _eventsAccent.withValues(alpha: isDark ? 0.28 : 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          indicatorColor: Colors.transparent,
                          splashBorderRadius: BorderRadius.circular(14),
                          labelColor: _eventsAccentDeep,
                          unselectedLabelColor: muted,
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                          labelPadding: EdgeInsets.zero,
                          tabs: [
                            const Tab(height: 40, text: 'Create'),
                            Tab(
                              height: 40,
                              text: _events.isEmpty ? 'My events' : 'My events (${_events.length})',
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildCreate(ink, muted, isDark),
                          _buildList(ink, muted, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCreate(Color ink, Color muted, bool isDark) {
    final accent = _wizColor;
    final deep = _wizDeep;

    if (_wizStep == 'done') {
      final softFill = Color.lerp(accent, isDark ? AppColors.cardDark : Colors.white, isDark ? 0.82 : 0.9) ??
          AppColors.softPurpleOf(context);
      final eventName = _createdName?.trim().isNotEmpty == true ? _createdName!.trim() : 'Your event';
      final taskLabel = _createdTodos == 1 ? '1 planned task' : '$_createdTodos planned tasks';

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // Celebration hero
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, deep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 16),
                Text(
                  'All set!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your $_wizTypeLabel plan is ready. Checklist and budgets are waiting for you.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _DoneStatCard(
                  icon: (_eventType == 'anniversary')
                      ? null
                      : _wizIcon,
                  doubleHeart: _eventType == 'anniversary',
                  label: 'Type',
                  value: _wizTypeLabel,
                  ink: ink,
                  muted: muted,
                  accent: accent,
                  softFill: softFill,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DoneStatCard(
                  icon: Icons.checklist_rounded,
                  label: 'Checklist',
                  value: taskLabel,
                  ink: ink,
                  muted: muted,
                  accent: accent,
                  softFill: softFill,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: softFill,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.event_available_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event name',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        eventName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: ink,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What next?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
          ),
          const SizedBox(height: 10),
          if (_createdId != null)
            _DoneActionCard(
              icon: Icons.open_in_new_rounded,
              title: 'Open event',
              subtitle: 'See checklist, budgets, and guests',
              accent: accent,
              ink: ink,
              muted: muted,
              softFill: softFill,
              primary: true,
              onTap: () => _openDetail(_createdId!),
            ),
          if (_createdId != null) const SizedBox(height: 10),
          _DoneActionCard(
            icon: Icons.folder_open_rounded,
            title: 'Go to My events',
            subtitle: 'Browse everything you have planned',
            accent: accent,
            ink: ink,
            muted: muted,
            softFill: softFill,
            onTap: () {
              _resetWizard();
              _goTab(1);
            },
          ),
          const SizedBox(height: 10),
          _DoneActionCard(
            icon: Icons.add_circle_outline_rounded,
            title: 'Plan another event',
            subtitle: 'Start fresh with a new type',
            accent: accent,
            ink: ink,
            muted: muted,
            softFill: softFill,
            onTap: _resetWizard,
          ),
        ],
      );
    }

    if (_wizStep == 'questions' && _currentQ != null) {
      final q = _currentQ!;
      final progress = _questions.isEmpty ? 0.0 : (_qIndex + 1) / _questions.length;
      final softFill = Color.lerp(accent, isDark ? AppColors.cardDark : Colors.white, isDark ? 0.82 : 0.9) ??
          AppColors.softPurpleOf(context);

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Type header + note
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: isDark ? 0.28 : 0.16),
                  accent.withValues(alpha: isDark ? 0.1 : 0.04),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      alignment: Alignment.center,
                      child: (_eventType == 'anniversary')
                          ? _DoubleHeartIcon(color: accent, size: 18)
                          : Icon(_wizIcon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planning $_wizTypeLabel',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Question ${_qIndex + 1} of ${_questions.length}',
                            style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${((_qIndex + 1) * 100 / _questions.length).round()}%',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: deep),
                      ),
                    ),
                  ],
                ),
                if (_intro.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context).withValues(alpha: isDark ? 0.55 : 0.72),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sticky_note_2_rounded, size: 15, color: accent),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _labelWithCurrency(_intro),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: muted,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              color: accent,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: softFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 10, top: 1),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: isDark ? 0.32 : 0.18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${_qIndex + 1}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: deep,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _labelWithCurrency(q.label),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (q.type == 'select')
                        _FieldTap(
                          value: _answerCtrl.text.isEmpty ? 'Choose…' : _answerCtrl.text,
                          muted: _answerCtrl.text.isEmpty,
                          accent: accent,
                          onTap: () => _pickSelect(q),
                        )
                      else if (q.type == 'date')
                        _FieldTap(
                          value: _answerCtrl.text.isEmpty ? 'Pick a date…' : formatDate(_answerCtrl.text),
                          muted: _answerCtrl.text.isEmpty,
                          icon: Icons.calendar_month_rounded,
                          accent: accent,
                          onTap: _pickDate,
                        )
                      else if (q.type == 'multiselect')
                        _buildMulti(q, ink, muted, isDark, accent)
                      else
                        TextField(
                          key: ValueKey('wiz_answer_${q.id}_${_qIndex}_$_answerFieldGen'),
                          controller: _answerCtrl,
                          focusNode: _answerFocus,
                          autofocus: _isTypedAnswer(q.type),
                          keyboardType: _keyboardFor(q.type),
                          textInputAction:
                              q.type == 'textarea' ? TextInputAction.newline : TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (!_creating && q.type != 'textarea') _pushAnswer();
                          },
                          maxLines: q.type == 'textarea' ? 4 : 1,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ink),
                          cursorColor: accent,
                          decoration: InputDecoration(
                            hintText: q.type == 'number' ? '0' : 'Your answer',
                            hintStyle: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w500),
                            filled: true,
                            fillColor: AppColors.cardOf(context),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: accent, width: 1.4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: accent.withValues(alpha: 0.18)),
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
                const SizedBox(height: 14),
                // Back / Next only move between questions
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: (_creating || _qIndex == 0) ? null : _goBackQuestion,
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            size: 22,
                            color: (_creating || _qIndex == 0)
                                ? muted.withValues(alpha: 0.45)
                                : deep,
                          ),
                          label: Text(
                            'Back',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: (_creating || _qIndex == 0)
                                  ? muted.withValues(alpha: 0.45)
                                  : deep,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: deep,
                            disabledForegroundColor: muted.withValues(alpha: 0.45),
                            side: BorderSide(
                              color: (_creating || _qIndex == 0)
                                  ? AppColors.borderOf(context)
                                  : accent.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _creating ? null : _pushAnswer,
                          icon: _creating
                              ? const SizedBox.shrink()
                              : Icon(
                                  _qIndex + 1 >= _questions.length
                                      ? Icons.check_rounded
                                      : Icons.chevron_right_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                          label: _creating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : Text(
                                  _qIndex + 1 >= _questions.length ? 'Create' : 'Next',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: accent.withValues(alpha: 0.45),
                            elevation: 0,
                            iconAlignment: IconAlignment.end,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Separate answers section card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: softFill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: accent.withValues(alpha: 0.22)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.fact_check_rounded, size: 16, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your answers',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_answeredPairs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Text(
                        'No answers yet',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(_answeredPairs.length, (i) {
                    final pair = _answeredPairs[i];
                    final aq = pair.$1;
                    final av = pair.$2;
                    final isCurrent = aq.id == q.id;
                    final isLast = i == _answeredPairs.length - 1;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                bottom: BorderSide(color: AppColors.borderOf(context)),
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _labelWithCurrency(aq.label),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: muted,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _displayWizardAnswer(aq, av),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isCurrent ? deep : ink,
                              height: 1.3,
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
      );
    }

    // pick type
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (_creating)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final t in _types)
                _EventTypeCard(
                  id: t.$1,
                  label: t.$2,
                  subtitle: _typeSubtitle(t.$1),
                  icon: t.$3,
                  color: t.$4,
                  ink: ink,
                  muted: muted,
                  isDark: isDark,
                  onTap: () => _startWizard(t.$1),
                ),
            ],
          ),
      ],
    );
  }

  String _typeSubtitle(String id) {
    switch (id) {
      case 'wedding':
        return 'Ceremonies, guests and a smart checklist';
      case 'birthday':
        return 'Party plans with a smart checklist';
      case 'anniversary':
        return 'A special day with a smart checklist';
      case 'housewarming':
        return 'Home setup with a smart checklist';
      case 'corporate':
        return 'Agenda and budget with a smart checklist';
      default:
        return 'Custom plans with a smart checklist';
    }
  }

  Widget _buildMulti(WizardQuestion q, Color ink, Color muted, bool isDark, Color accent) {
    final allowCustom = q.allowCustom || q.options.contains('Other') || q.id == 'ceremonies';
    final chipFill = accent.withValues(alpha: isDark ? 0.28 : 0.16);
    final inputFill = AppColors.cardOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in q.options)
              FilterChip(
                label: Text(o),
                selected: _multiSel.contains(o),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _multiSel.add(o);
                    } else {
                      _multiSel.remove(o);
                      if (o == 'Other') _customCeremonies.clear();
                    }
                  });
                },
                selectedColor: chipFill,
                checkmarkColor: accent,
                side: BorderSide(
                  color: _multiSel.contains(o) ? accent.withValues(alpha: 0.45) : AppColors.borderOf(context),
                ),
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: _multiSel.contains(o) ? accent : ink,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        if (allowCustom && _multiSel.contains('Other')) ...[
          // Custom tags appear above the textbox, matching selected chip style
          if (_customCeremonies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _customCeremonies)
                  InputChip(
                    label: Text(c),
                    selected: true,
                    showCheckmark: true,
                    onDeleted: () => setState(() => _customCeremonies.remove(c)),
                    deleteIcon: Icon(Icons.close_rounded, size: 16, color: accent),
                    selectedColor: chipFill,
                    checkmarkColor: accent,
                    backgroundColor: chipFill,
                    side: BorderSide(color: accent.withValues(alpha: 0.45)),
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontSize: 13,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCtrl,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ink),
                  cursorColor: accent,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomCeremony(q),
                  decoration: InputDecoration(
                    hintText: 'Add custom ceremony',
                    hintStyle: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w500),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: accent.withValues(alpha: 0.18)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: accent.withValues(alpha: 0.18)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: accent, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _addCustomCeremony(q),
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _addCustomCeremony(WizardQuestion q) {
    final name = _customCtrl.text.trim();
    if (name.isEmpty) {
      AppSnack.warning(context, 'Enter a ceremony name');
      return;
    }
    if (name.toLowerCase() == 'other') {
      AppSnack.warning(context, 'Enter a real ceremony name');
      return;
    }
    if (_customCeremonies.any((c) => c.toLowerCase() == name.toLowerCase()) ||
        q.options.any((o) => o.toLowerCase() == name.toLowerCase() && o != 'Other')) {
      AppSnack.warning(context, 'Already in the list');
      return;
    }
    setState(() {
      _customCeremonies.add(name);
      _customCtrl.clear();
    });
  }

  Widget _buildList(Color ink, Color muted, bool isDark) {
    if (_listLoading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _eventsAccent));
    }

    final total = _events.length;
    final pageCount = total == 0 ? 0 : ((total + _listPageSize - 1) ~/ _listPageSize);
    final maxPage = pageCount <= 1 ? 0 : pageCount - 1;
    final page = _listPage.clamp(0, maxPage);
    final start = page * _listPageSize;
    final pageRows = total == 0
        ? const <EventSummary>[]
        : _events.sublist(start, (start + _listPageSize).clamp(0, total));

    return RefreshIndicator(
      onRefresh: _loadList,
      color: _eventsAccent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (_listError != null)
            Material(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                title: Text(_listError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
                trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadList),
              ),
            ),
          if (_events.isEmpty && _listError == null)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _eventsAccent.withValues(alpha: isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.celebration_outlined, size: 36, color: _eventsAccent),
                  ),
                  const SizedBox(height: 14),
                  Text('No events yet', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                  const SizedBox(height: 6),
                  Text(
                    'Create your first event to get a smart checklist.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _resetWizard();
                      _goTab(0);
                    },
                    child: Text(
                      'Create event',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _eventsAccentDeep),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (pageCount > 1) ...[
              Row(
                children: [
                  Text(
                    'Page ${page + 1} of $pageCount · 4 per page',
                    style: GoogleFonts.inter(fontSize: 12, color: muted),
                  ),
                  const Spacer(),
                  _EventsPageNav(
                    label: '${page + 1}/$pageCount',
                    canPrev: page > 0,
                    canNext: page < maxPage,
                    onPrev: () => setState(() => _listPage = page - 1),
                    onNext: () => setState(() => _listPage = page + 1),
                    muted: muted,
                    accent: _eventsAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              // Fixed ratio so every card is the same size.
              childAspectRatio: 0.78,
              children: [
                for (final ev in pageRows)
                  _EventListCard(
                    event: ev,
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    typeIcon: typeStyle(ev.eventType).$1,
                    typeColor: typeStyle(ev.eventType).$2,
                    onOpen: () => _openDetail(ev.id),
                    onDelete: () => _deleteEvent(ev),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DoneStatCard extends StatelessWidget {
  const _DoneStatCard({
    required this.label,
    required this.value,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.softFill,
    this.icon,
    this.doubleHeart = false,
  });

  final IconData? icon;
  final bool doubleHeart;
  final String label;
  final String value;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color softFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: softFill,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: doubleHeart
                ? _DoubleHeartIcon(color: accent, size: 16)
                : Icon(icon ?? Icons.auto_awesome_rounded, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: ink, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _DoneActionCard extends StatelessWidget {
  const _DoneActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.softFill,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color ink;
  final Color muted;
  final Color softFill;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(accent, Colors.black, 0.18) ?? accent;
    return Material(
      color: primary ? accent : AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary ? accent.withValues(alpha: 0.1) : accent.withValues(alpha: 0.22),
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : AppColors.cardShadow(context),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withValues(alpha: 0.2) : softFill,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.28)
                        : accent.withValues(alpha: 0.28),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: primary ? Colors.white : accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: primary ? Colors.white : ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: primary ? Colors.white.withValues(alpha: 0.88) : muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: primary ? Colors.white.withValues(alpha: 0.9) : deep,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTypeCard extends StatelessWidget {
  const _EventTypeCard({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.onTap,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color ink;
  final Color muted;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(color, Colors.black, 0.18) ?? color;

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Two-shade header like My events / Home cards
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: isDark ? 0.34 : 0.2),
                      color.withValues(alpha: isDark ? 0.12 : 0.05),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: id == 'anniversary'
                          ? _DoubleHeartIcon(color: color, size: 18)
                          : Icon(icon, color: color, size: 22),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: deep, size: 22),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: muted,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: color.withValues(alpha: 0.28)),
                        ),
                        child: Text(
                          'Start planning',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: deep,
                          ),
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
}

class _DoubleHeartIcon extends StatelessWidget {
  const _DoubleHeartIcon({required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 8,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 1,
            child: Icon(Icons.favorite_rounded, color: color.withValues(alpha: 0.55), size: size * 0.88),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.favorite_rounded, color: color, size: size),
          ),
        ],
      ),
    );
  }
}

class _EventsPageNav extends StatelessWidget {
  const _EventsPageNav({
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
          _navBtn(
            icon: Icons.chevron_left_rounded,
            enabled: canPrev,
            onTap: onPrev,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: muted),
            ),
          ),
          _navBtn(
            icon: Icons.chevron_right_rounded,
            enabled: canNext,
            onTap: onNext,
          ),
        ],
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? accent : muted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _EventListCard extends StatelessWidget {
  const _EventListCard({
    required this.event,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.typeIcon,
    required this.typeColor,
    required this.onOpen,
    required this.onDelete,
  });

  final EventSummary event;
  final Color ink;
  final Color muted;
  final bool isDark;
  final IconData typeIcon;
  final Color typeColor;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusKey = event.lifecycleStatus;
    final statusLabel = event.statusLabel;
    final statusColor = switch (statusKey) {
      'completed' => const Color(0xFF34D399),
      'ongoing' => const Color(0xFF60A5FA),
      _ => const Color(0xFFFBBF24),
    };
    final deep = Color.lerp(typeColor, Colors.black, 0.2) ?? typeColor;
    final dateLabel = event.eventDate != null ? formatDate(event.eventDate) : 'No date';
    final place = (event.location ?? '').trim();

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored top strip + icon / delete
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      typeColor.withValues(alpha: isDark ? 0.32 : 0.18),
                      typeColor.withValues(alpha: isDark ? 0.14 : 0.06),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: typeColor.withValues(alpha: 0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: event.eventType.toLowerCase() == 'anniversary'
                          ? _DoubleHeartIcon(color: typeColor, size: 16)
                          : Icon(typeIcon, color: typeColor, size: 18),
                    ),
                    const Spacer(),
                    Material(
                      color: typeColor.withValues(alpha: isDark ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onOpen,
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(Icons.visibility_rounded, size: 15, color: deep),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: AppColors.danger.withValues(alpha: isDark ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onDelete,
                        child: const SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(Icons.delete_rounded, size: 15, color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body fills remaining height so all cards match.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          height: 1.25,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.styleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: deep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 11, color: muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (place.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 12, color: muted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 11, color: muted, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color.lerp(statusColor, Colors.black, isDark ? 0 : 0.25) ??
                                statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatMoney(event.budget),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: ink,
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
}

class _FieldTap extends StatelessWidget {
  const _FieldTap({
    required this.value,
    required this.onTap,
    this.muted = false,
    this.icon = Icons.expand_more_rounded,
    this.accent = const Color(0xFF5038F0),
  });

  final String value;
  final VoidCallback onTap;
  final bool muted;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final isDark = AppColors.isDark(context);
    final fill = Color.lerp(accent, isDark ? AppColors.cardDark : Colors.white, isDark ? 0.82 : 0.9) ??
        AppColors.softPurpleOf(context);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: muted ? AppColors.mutedOf(context) : ink,
                  ),
                ),
              ),
              Icon(icon, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
