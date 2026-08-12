import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One alert shown in the in-app Notifications page (and optionally OS shade).
class InboxNotification {
  InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type = 'emi',
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String type;
  final bool read;

  InboxNotification copyWith({bool? read}) {
    return InboxNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      type: type,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'type': type,
        'read': read,
      };

  factory InboxNotification.fromJson(Map<String, dynamic> j) {
    return InboxNotification(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      body: j['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      type: j['type']?.toString() ?? 'emi',
      read: j['read'] == true,
    );
  }
}

/// Persisted notification history for the in-app Notifications page.
///
/// Storage is **per user id** so account A never sees account B’s inbox.
/// Cleared / swiped-away ids are remembered per user so refresh does not re-create them.
/// Uncleared items auto-clear at end of their calendar month (last day 11:59 PM).
class NotificationInboxState extends ChangeNotifier {
  static const _prefsPrefix = 'sanchiva.notification_inbox_v2';
  static const _dismissedPrefix = 'sanchiva.notification_inbox_dismissed_v2';
  /// Legacy unscoped keys (migrated once into current user, then removed).
  static const _legacyPrefsKey = 'sanchiva.notification_inbox_v1';
  static const _legacyDismissedKey = 'sanchiva.notification_inbox_dismissed_v1';
  static const _maxItems = 100;
  static const _maxDismissed = 500;

  /// Bound so [NotificationService] can record without BuildContext.
  static NotificationInboxState? instance;

  NotificationInboxState() {
    instance = this;
    // Wait for [setUser] from AuthState — do not load global data.
    loading = false;
  }

  List<InboxNotification> items = [];
  /// Stable ids the user cleared (swipe or clear all) — never re-add these.
  final Set<String> _dismissedIds = {};
  bool loading = true;
  Timer? _monthEndTimer;

  /// Active account key (user id). Null when logged out.
  String? _userKey;

  int get unreadCount => items.where((e) => !e.read).length;

  String _itemsKey(String userKey) => '$_prefsPrefix.$userKey';
  String _dismissedKey(String userKey) => '$_dismissedPrefix.$userKey';

  /// Call on login / logout / session restore so inbox is always the right account.
  Future<void> setUser(String? userId) async {
    final next = (userId == null || userId.trim().isEmpty) ? null : userId.trim();
    if (next == _userKey) {
      // Same user — still purge expired if needed.
      if (next != null) await purgeExpiredMonthEnd();
      return;
    }

    // Persist outgoing user before switching away.
    if (_userKey != null) {
      await _save();
    }

    _monthEndTimer?.cancel();
    _userKey = next;
    items = [];
    _dismissedIds.clear();

    if (next == null) {
      loading = false;
      notifyListeners();
      return;
    }

    await _loadForUser(next);
  }

  /// Last moment of [year]/[month] that alerts still stay (11:59:00 PM).
  static DateTime monthEndDeadline(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, lastDay, 23, 59, 0);
  }

  /// Year-month this alert belongs to (from stable id or createdAt).
  static DateTime yearMonthOf(InboxNotification e) {
    final m = RegExp(r'(\d{4})-(\d{2})(?:-\d{2})?$').firstMatch(e.id);
    if (m != null) {
      final y = int.tryParse(m.group(1)!) ?? e.createdAt.year;
      final mo = int.tryParse(m.group(2)!) ?? e.createdAt.month;
      return DateTime(y, mo);
    }
    return DateTime(e.createdAt.year, e.createdAt.month);
  }

  static bool isPastMonthEnd(InboxNotification e, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final ym = yearMonthOf(e);
    return n.isAfter(monthEndDeadline(ym.year, ym.month));
  }

  Future<void> _loadForUser(String userKey) async {
    loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsKey = _itemsKey(userKey);
      final dismissedKey = _dismissedKey(userKey);

      var raw = prefs.getString(itemsKey);
      var dismissed = prefs.getStringList(dismissedKey);

      // One-time migrate legacy unscoped storage into this user, then delete it.
      if ((raw == null || raw.isEmpty) && prefs.containsKey(_legacyPrefsKey)) {
        raw = prefs.getString(_legacyPrefsKey);
        dismissed ??= prefs.getStringList(_legacyDismissedKey);
        if (raw != null) await prefs.setString(itemsKey, raw);
        if (dismissed != null) await prefs.setStringList(dismissedKey, dismissed);
        await prefs.remove(_legacyPrefsKey);
        await prefs.remove(_legacyDismissedKey);
      }

      items = [];
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          items = list
              .whereType<Map>()
              .map((e) => InboxNotification.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.id.isNotEmpty)
              .toList();
        }
      }
      _dismissedIds.clear();
      if (dismissed != null) {
        _dismissedIds.addAll(dismissed);
      }
      if (_dismissedIds.isNotEmpty) {
        items = items.where((e) => !_dismissedIds.contains(e.id)).toList();
      }
      await purgeExpiredMonthEnd(notify: false);
    } catch (e) {
      debugPrint('NotificationInbox load: $e');
      items = [];
      _dismissedIds.clear();
    } finally {
      loading = false;
      notifyListeners();
      _scheduleMonthEndAutoClear();
    }
  }

  Future<void> _save() async {
    final userKey = _userKey;
    if (userKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _itemsKey(userKey),
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
      final dismissedList = _dismissedIds.toList();
      if (dismissedList.length > _maxDismissed) {
        final trimmed = dismissedList.sublist(dismissedList.length - _maxDismissed);
        _dismissedIds
          ..clear()
          ..addAll(trimmed);
        await prefs.setStringList(_dismissedKey(userKey), trimmed);
      } else {
        await prefs.setStringList(_dismissedKey(userKey), dismissedList);
      }
    } catch (e) {
      debugPrint('NotificationInbox save: $e');
    }
  }

  /// Remove (and remember) all alerts whose calendar month has ended
  /// (after last day 11:59 PM). Safe to call on every app / inbox open.
  Future<void> purgeExpiredMonthEnd({bool notify = true}) async {
    if (_userKey == null) return;
    final now = DateTime.now();
    final expired = items.where((e) => isPastMonthEnd(e, now)).map((e) => e.id).toSet();
    if (expired.isEmpty) {
      if (notify) _scheduleMonthEndAutoClear();
      return;
    }
    for (final id in expired) {
      _dismissedIds.add(id);
    }
    items = items.where((e) => !expired.contains(e.id)).toList();
    if (notify) notifyListeners();
    await _save();
    _scheduleMonthEndAutoClear();
  }

  /// While the app is open, fire auto-clear at this month’s last day 11:59 PM.
  void _scheduleMonthEndAutoClear() {
    _monthEndTimer?.cancel();
    if (_userKey == null) return;
    final now = DateTime.now();
    final deadline = monthEndDeadline(now.year, now.month);
    if (now.isAfter(deadline)) return;
    final wait = deadline.difference(now);
    _monthEndTimer = Timer(wait, () async {
      await purgeExpiredMonthEnd();
    });
  }

  /// Add an alert to the inbox (newest first). No-op when logged out.
  Future<void> add({
    required String title,
    required String body,
    String type = 'emi',
    String? id,
  }) async {
    if (_userKey == null) return;
    await purgeExpiredMonthEnd(notify: false);

    final resolvedId = id ??
        '${DateTime.now().millisecondsSinceEpoch}_${items.length}_${title.hashCode}';

    if (_dismissedIds.contains(resolvedId)) return;
    if (items.any((e) => e.id == resolvedId)) return;

    final dup = items.any(
      (e) =>
          e.title == title &&
          e.body == body &&
          DateTime.now().difference(e.createdAt).inMinutes < 2,
    );
    if (dup) return;

    final item = InboxNotification(
      id: resolvedId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      type: type,
      read: false,
    );

    if (isPastMonthEnd(item)) {
      _dismissedIds.add(resolvedId);
      await _save();
      return;
    }

    items = [item, ...items].take(_maxItems).toList();
    notifyListeners();
    await _save();
    _scheduleMonthEndAutoClear();
  }

  Future<void> remove(String id) async {
    if (_userKey == null) return;
    _dismissedIds.add(id);
    items = items.where((e) => e.id != id).toList();
    notifyListeners();
    await _save();
  }

  Future<void> clearAll() async {
    if (_userKey == null) return;
    for (final e in items) {
      _dismissedIds.add(e.id);
    }
    items = [];
    notifyListeners();
    await _save();
  }

  Future<void> markAllRead() async {
    if (_userKey == null) return;
    if (items.every((e) => e.read)) return;
    items = items.map((e) => e.copyWith(read: true)).toList();
    notifyListeners();
    await _save();
  }

  Future<void> markRead(String id) async {
    if (_userKey == null) return;
    final i = items.indexWhere((e) => e.id == id);
    if (i < 0 || items[i].read) return;
    items = [
      ...items.sublist(0, i),
      items[i].copyWith(read: true),
      ...items.sublist(i + 1),
    ];
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    _monthEndTimer?.cancel();
    if (identical(instance, this)) instance = null;
    super.dispose();
  }
}
