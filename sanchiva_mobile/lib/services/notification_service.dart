import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/format.dart';
import '../core/notification_inbox.dart';
import '../models/loan.dart';
import 'loan_service.dart';

/// App notifications (shade + lock screen):
/// Only **loan EMI deduction day** — fires on that day each month (1–31) at 6:00 AM.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'sanchiva_general';
  static const _channelName = 'Sanchiva notifications';
  static const _prefsEnabled = 'sanchiva.notifications_enabled';
  static const _legacyEmiPrefs = 'sanchiva.emi_notifications_enabled';

  /// White silhouette status-bar / panel icon (Android requires alpha-only small icon).
  static const _smallIcon = 'ic_stat_sanchiva';
  /// Brand accent for notification chrome (tints small icon on some OEMs).
  static const _brandColor = Color(0xFF5038F0);

  static const _welcomeNotifId = 1001;
  /// Deduction-day monthly schedules (recurring).
  static const _deductIdBase = 710000;
  static const _deductIdMax = 719999;
  /// Legacy 1st-of-month ids — cancelled on resync so old schedules clear.
  static const _legacyMonthStartIdMax = 799999;

  static const _deductHour = 6;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      _ready = true;
      return;
    }

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings(_smallIcon);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Loan EMI deduction day alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    _ready = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_prefsEnabled)) {
      return prefs.getBool(_prefsEnabled) ?? false;
    }
    return prefs.getBool(_legacyEmiPrefs) ?? false;
  }

  Future<void> setEnabledFlag(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabled, enabled);
    await prefs.setBool(_legacyEmiPrefs, enabled);
  }

  Future<bool> requestPermissions() async {
    await init();
    if (kIsWeb) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final notif = await android.requestNotificationsPermission();
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {}
      return notif ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return ok ?? false;
    }
    return true;
  }

  NotificationDetails _details({required String title, required String body}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Loan EMI deduction day alerts',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        icon: _smallIcon,
        color: _brandColor,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> _recordInbox({
    required String title,
    required String body,
    String type = 'emi',
    String? id,
  }) async {
    final inbox = NotificationInboxState.instance;
    if (inbox == null) return;
    await inbox.add(title: title, body: body, type: type, id: id);
  }

  /// System shade/lock-screen push only when Profile → Notifications is on.
  /// Inbox history is independent — always recorded when [recordInbox] is true.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String inboxType = 'emi',
    bool recordInbox = true,
    bool systemPush = true,
  }) async {
    await init();
    if (kIsWeb) return;

    if (recordInbox) {
      await _recordInbox(title: title, body: body, type: inboxType);
    }

    if (!systemPush || !await isEnabled()) return;

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: _details(title: title, body: body),
    );
  }

  /// System push (if enabled): only loans whose deduction day is **today**.
  Future<void> pushAllSampleNotifications() async {
    await init();
    if (kIsWeb) return;

    // Always refresh full inbox history (not gated by system toggle).
    await ensureInboxEntries();

    if (!await isEnabled()) return;

    List<Loan> loans = const [];
    try {
      loans = await LoanService.instance.listLoans();
    } catch (e) {
      debugPrint('pushAllSampleNotifications load: $e');
    }

    final now = DateTime.now();
    final curKey = now.year * 12 + now.month;
    final todayDay = now.day;
    var id = 9000;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;

    final dueToday = loans.where((l) {
      if (l.isClosed) return false;
      final endKey = l.emiCloseYear * 12 + l.emiCloseMonth;
      if (curKey > endKey) return false;
      final day = l.emiDeductionDate.clamp(1, 31);
      final effectiveDay = day > lastDay ? lastDay : day;
      return effectiveDay == todayDay;
    }).toList();

    for (final loan in dueToday) {
      final bank = loan.bankName.trim().isEmpty ? 'Loan' : loan.bankName.trim();
      final deduct =
          loan.emiDeductionBank.trim().isEmpty ? 'your bank' : loan.emiDeductionBank.trim();
      final day = loan.emiDeductionDate.clamp(1, 31);
      final title = 'EMI deduction today';
      final body = '$bank · ${formatMoney(loan.emiAmount)} will be deducted from $deduct (day $day)';
      try {
        // Already in inbox via ensureInboxEntries; OS push only.
        await show(
          id: id++,
          title: title,
          body: body,
          payload: 'loan_deduct_today:${loan.id}',
          inboxType: 'emi_deduction',
          recordInbox: false,
          systemPush: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('deduct today ${loan.id}: $e');
      }
    }
  }

  /// Inbox history only (no system enable/disable).
  /// - Loan EMI deduction day (when that day is today)
  /// - 1st-of-month: remaining months for every active loan & card EMI
  /// - 1st-of-month: ending this month for any loan / card EMI that closes now
  Future<void> ensureInboxEntries() async {
    if (kIsWeb) return;

    // Drop uncleared inbox items past their month-end (last day 11:59 PM).
    await NotificationInboxState.instance?.purgeExpiredMonthEnd();

    List<Loan> loans = const [];
    List<CreditEmi> emis = const [];
    try {
      loans = await LoanService.instance.listLoans();
      emis = await LoanService.instance.listEmis();
    } catch (e) {
      debugPrint('ensureInboxEntries load: $e');
      return;
    }

    final now = DateTime.now();
    final curKey = now.year * 12 + now.month;
    final todayDay = now.day;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final dayKey =
        '$monthKey-${now.day.toString().padLeft(2, '0')}';

    // —— Loan EMI deduction day (same calendar day only) ——
    for (final loan in loans) {
      if (loan.isClosed) continue;
      final endKey = loan.emiCloseYear * 12 + loan.emiCloseMonth;
      if (curKey > endKey) continue;
      final day = loan.emiDeductionDate.clamp(1, 31);
      final effectiveDay = day > lastDay ? lastDay : day;
      if (effectiveDay != todayDay) continue;

      final bank = loan.bankName.trim().isEmpty ? 'Loan' : loan.bankName.trim();
      final deduct =
          loan.emiDeductionBank.trim().isEmpty ? 'your bank' : loan.emiDeductionBank.trim();
      await _recordInbox(
        title: 'EMI deduction today',
        body:
            '$bank · ${formatMoney(loan.emiAmount)} will be deducted from $deduct (day $day)',
        type: 'emi_deduction',
        id: 'loan_deduct_${loan.id}_$dayKey',
      );
    }

    // —— 1st-of-month remaining + ending (once per month when user opens app) ——
    // Available any day on/after the 1st of the current month (stable ids).
    for (final loan in loans) {
      if (loan.isClosed) continue;
      final startKey = loan.startYear * 12 + loan.startMonth;
      final endKey = loan.emiCloseYear * 12 + loan.emiCloseMonth;
      if (curKey < startKey || curKey > endKey) continue;

      final remaining = endKey - curKey + 1;
      final bank = loan.bankName.trim().isEmpty ? 'Loan' : loan.bankName.trim();
      final amount = formatMoney(loan.emiAmount);

      await _recordInbox(
        title: 'Loan EMI remaining',
        body: remaining == 1
            ? '$bank · last EMI this month · $amount / month'
            : '$bank · $remaining months remaining · $amount / month',
        type: 'loan_remaining',
        id: 'loan_remaining_${loan.id}_$monthKey',
      );

      if (curKey == endKey) {
        await _recordInbox(
          title: 'Loan ending this month',
          body: '$bank ends this month · final EMI $amount',
          type: 'loan_ending',
          id: 'loan_ending_${loan.id}_$monthKey',
        );
      }
    }

    for (final emi in emis) {
      if (emi.isCompleted) continue;
      final startKey = emi.startYear * 12 + emi.startMonth;
      final endKey = emi.endYear * 12 + emi.endMonth;
      if (curKey < startKey || curKey > endKey) continue;

      final remaining = endKey - curKey + 1;
      final name = emi.emiName.trim().isEmpty ? 'Card EMI' : emi.emiName.trim();
      final card = emi.creditCardName.trim().isEmpty ? 'card' : emi.creditCardName.trim();
      final amount = formatMoney(emi.amount);

      await _recordInbox(
        title: 'Card EMI remaining',
        body: remaining == 1
            ? '$name ($card) · last EMI this month · $amount / month'
            : '$name ($card) · $remaining months remaining · $amount / month',
        type: 'cc_emi_remaining',
        id: 'cc_remaining_${emi.id}_$monthKey',
      );

      if (curKey == endKey) {
        await _recordInbox(
          title: 'Card EMI ending this month',
          body: '$name on $card ends this month · final EMI $amount',
          type: 'cc_emi_ending',
          id: 'cc_ending_${emi.id}_$monthKey',
        );
      }
    }
  }

  /// @deprecated use [ensureInboxEntries]
  Future<void> ensureTodayInboxEntries() => ensureInboxEntries();

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  Future<void> _cancelRange(int from, int to) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= from && n.id <= to) {
        await _plugin.cancel(id: n.id);
      }
    }
  }

  /// Resync: cancel old schedules, set loan deduction-day only.
  Future<void> syncLoanEmiReminders() async {
    await init();
    // Clear deduction + any legacy remaining/ending schedules.
    await _cancelRange(_deductIdBase, _legacyMonthStartIdMax);
    if (kIsWeb || !await isEnabled()) return;
    try {
      final loans = await LoanService.instance.listLoans();
      await scheduleLoanDeductionDayReminders(loans);
    } catch (e) {
      debugPrint('syncLoanEmiReminders: $e');
    }
  }

  /// Call sites that pass loan list in memory.
  Future<void> scheduleLoanEmiReminders(List<Loan> loans) async {
    await init();
    if (kIsWeb || !await isEnabled()) return;
    await _cancelRange(_deductIdBase, _legacyMonthStartIdMax);
    await scheduleLoanDeductionDayReminders(loans);
  }

  /// Monthly 6:00 AM on each ongoing loan’s deduction day (1–31).
  Future<void> scheduleLoanDeductionDayReminders(List<Loan> loans) async {
    if (kIsWeb || !await isEnabled()) return;

    final now = DateTime.now();
    final curKey = now.year * 12 + now.month;

    for (final loan in loans) {
      if (loan.isClosed) continue;
      final endKey = loan.emiCloseYear * 12 + loan.emiCloseMonth;
      if (curKey > endKey) continue;

      final day = loan.emiDeductionDate.clamp(1, 31);
      final when = _nextAtHourOnDay(day, _deductHour);
      final id = _deductIdBase + (loan.id.abs() % (_deductIdMax - _deductIdBase));

      final bank = loan.bankName.trim().isEmpty ? 'Loan' : loan.bankName.trim();
      final deduct =
          loan.emiDeductionBank.trim().isEmpty ? 'your bank' : loan.emiDeductionBank.trim();
      final amount = formatMoney(loan.emiAmount);
      final title = 'EMI deduction today';
      final body = '$bank · $amount will be deducted from $deduct (day $day)';

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          notificationDetails: _details(title: title, body: body),
          payload: 'loan_deduct:${loan.id}',
        );
      } catch (e) {
        debugPrint('deduct schedule ${loan.id}: $e');
      }
    }
  }

  tz.TZDateTime _nextAtHourOnDay(int dayOfMonth, int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = _atHour(now.year, now.month, dayOfMonth, hour);
    if (!candidate.isAfter(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      candidate = _atHour(nextYear, nextMonth, dayOfMonth, hour);
    }
    return candidate;
  }

  tz.TZDateTime _atHour(int year, int month, int dayOfMonth, int hour) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = dayOfMonth.clamp(1, lastDay);
    return tz.TZDateTime(tz.local, year, month, day, hour, 0);
  }
}
