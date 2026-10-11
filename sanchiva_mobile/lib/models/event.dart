// Event domain models (matches `/api/events`).

/// Lifecycle tag:
/// - **completed** — has todos and every todo is closed
/// - **ongoing** — on/after the event day (and not all todos closed)
/// - **planning** — before the event day (or undated, with open/no todos)
String deriveEventLifecycleStatus({
  String? eventDate,
  int itemsDone = 0,
  int itemsTotal = 0,
}) {
  if (itemsTotal > 0 && itemsDone >= itemsTotal) return 'completed';
  final day = (eventDate ?? '').trim();
  if (day.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(day)) {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (day.substring(0, 10).compareTo(today) <= 0) return 'ongoing';
  }
  return 'planning';
}

String eventLifecycleStatusLabel(String status) {
  switch (status.toLowerCase().trim()) {
    case 'completed':
      return 'Completed';
    case 'ongoing':
      return 'Ongoing';
    case 'planning':
    default:
      return 'Planning';
  }
}

class EventSummary {
  EventSummary({
    required this.id,
    required this.name,
    required this.eventType,
    this.subType,
    this.eventDate,
    this.endDate,
    this.location,
    this.budget = 0,
    this.notes,
    this.status = 'planning',
    this.itemsDone = 0,
    this.itemsTotal = 0,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final String eventType;
  final String? subType;
  final String? eventDate;
  final String? endDate;
  final String? location;
  final double budget;
  final String? notes;
  final String status;
  final int itemsDone;
  final int itemsTotal;
  final Map<String, dynamic> metadata;

  factory EventSummary.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> meta = {};
    final raw = j['metadata'];
    if (raw is Map) {
      meta = Map<String, dynamic>.from(raw);
    }
    final itemsDone = int.tryParse('${j['items_done'] ?? j['itemsDone']}') ?? 0;
    final itemsTotal =
        int.tryParse('${j['items_total'] ?? j['itemsTotal']}') ?? 0;
    final eventDate = _dateStr(j['event_date']);
    final derived = deriveEventLifecycleStatus(
      eventDate: eventDate,
      itemsDone: itemsDone,
      itemsTotal: itemsTotal,
    );
    // Prefer derived when we have todo counts or a date; otherwise fall back
    // to whatever the API stored (still normalized).
    final rawStatus = (j['status']?.toString() ?? '').trim().toLowerCase();
    final status = (itemsTotal > 0 || eventDate != null)
        ? derived
        : (rawStatus.isEmpty ? 'planning' : rawStatus);
    return EventSummary(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? 'Event',
      eventType: j['event_type']?.toString() ?? 'other',
      subType: j['sub_type']?.toString(),
      eventDate: eventDate,
      endDate: _dateStr(j['end_date']),
      location: j['location']?.toString(),
      budget: double.tryParse('${j['budget']}') ?? 0,
      notes: j['notes']?.toString(),
      status: status,
      itemsDone: itemsDone,
      itemsTotal: itemsTotal,
      metadata: meta,
    );
  }

  /// Always recompute from date + todos so UI stays correct offline/local.
  String get lifecycleStatus => deriveEventLifecycleStatus(
        eventDate: eventDate,
        itemsDone: itemsDone,
        itemsTotal: itemsTotal,
      );

  String get statusLabel => eventLifecycleStatusLabel(lifecycleStatus);

  String get styleLabel {
    final type = eventType.trim();
    final sub = (subType ?? '').trim();
    if (sub.isEmpty) {
      if (type.isEmpty) return 'Event';
      return type[0].toUpperCase() + type.substring(1);
    }
    return '$sub ${type[0].toUpperCase()}${type.substring(1)}';
  }
}

class EventItem {
  EventItem({
    required this.id,
    required this.eventId,
    required this.title,
    this.category,
    this.plannedAmount = 0,
    this.tokenPaid = 0,
    this.remainingAmount = 0,
    this.dueDate,
    this.isDone = false,
    this.vendorName,
    this.notes,
    this.sortOrder = 0,
  });

  final String id;
  final String eventId;
  final String title;
  final String? category;
  final double plannedAmount;
  final double tokenPaid;
  final double remainingAmount;
  final String? dueDate;
  final bool isDone;
  final String? vendorName;
  final String? notes;
  final int sortOrder;

  factory EventItem.fromJson(Map<String, dynamic> j) {
    final planned = double.tryParse('${j['planned_amount']}') ?? 0;
    final paid = double.tryParse('${j['token_paid']}') ?? 0;
    final rem = double.tryParse('${j['remaining_amount']}');
    return EventItem(
      id: j['id']?.toString() ?? '',
      eventId: j['event_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      category: j['category']?.toString(),
      plannedAmount: planned,
      tokenPaid: paid,
      remainingAmount: rem ?? (planned - paid).clamp(0, double.infinity),
      dueDate: _dateStr(j['due_date']),
      isDone: j['is_done'] == true || j['is_done']?.toString() == 'true',
      vendorName: j['vendor_name']?.toString(),
      notes: j['notes']?.toString(),
      sortOrder: int.tryParse('${j['sort_order']}') ?? 0,
    );
  }
}

class EventGuest {
  EventGuest({
    required this.id,
    required this.eventId,
    required this.name,
    this.side,
    this.ceremony = 'General',
    this.rsvp = 'maybe',
    this.count = 1,
    this.phone,
    this.notes,
  });

  final String id;
  final String eventId;
  final String name;
  final String? side;
  final String ceremony;
  final String rsvp;
  final int count;
  final String? phone;
  final String? notes;

  factory EventGuest.fromJson(Map<String, dynamic> j) {
    return EventGuest(
      id: j['id']?.toString() ?? '',
      eventId: j['event_id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      side: j['side']?.toString(),
      ceremony: j['ceremony']?.toString() ?? 'General',
      rsvp: j['rsvp']?.toString() ?? 'maybe',
      count: int.tryParse('${j['count']}') ?? 1,
      phone: j['phone']?.toString(),
      notes: j['notes']?.toString(),
    );
  }
}

class CeremonyDetail {
  CeremonyDetail({
    required this.name,
    this.date,
    this.quote,
    this.theme,
  });

  final String name;
  final String? date;
  final String? quote;
  final String? theme;

  factory CeremonyDetail.fromJson(Map<String, dynamic> j) {
    return CeremonyDetail(
      name: j['name']?.toString() ?? '',
      date: _dateStr(j['date']),
      quote: j['quote']?.toString(),
      theme: j['theme']?.toString(),
    );
  }
}

class EventSummaryMoney {
  EventSummaryMoney({
    this.planned = 0,
    this.paid = 0,
    this.remaining = 0,
    this.itemsDone = 0,
    this.itemsTotal = 0,
    this.guestCount = 0,
  });

  final double planned;
  final double paid;
  final double remaining;
  final int itemsDone;
  final int itemsTotal;
  final int guestCount;

  factory EventSummaryMoney.fromJson(Map<String, dynamic>? j) {
    if (j == null) return EventSummaryMoney();
    return EventSummaryMoney(
      planned: double.tryParse('${j['planned']}') ?? 0,
      paid: double.tryParse('${j['paid']}') ?? 0,
      remaining: double.tryParse('${j['remaining']}') ?? 0,
      itemsDone: int.tryParse('${j['itemsDone']}') ?? 0,
      itemsTotal: int.tryParse('${j['itemsTotal']}') ?? 0,
      guestCount: int.tryParse('${j['guestCount']}') ?? 0,
    );
  }
}

class EventDetail {
  EventDetail({
    required this.summary,
    required this.items,
    required this.guests,
    required this.ceremonies,
    required this.ceremonyDetails,
    required this.guestsByCeremony,
    required this.money,
  });

  final EventSummary summary;
  final List<EventItem> items;
  final List<EventGuest> guests;
  final List<String> ceremonies;
  final List<CeremonyDetail> ceremonyDetails;
  final Map<String, List<EventGuest>> guestsByCeremony;
  final EventSummaryMoney money;

  String get id => summary.id;
  String get name => summary.name;

  String get lifecycleStatus => deriveEventLifecycleStatus(
        eventDate: summary.eventDate,
        itemsDone: items.where((i) => i.isDone).length,
        itemsTotal: items.length,
      );

  String get statusLabel => eventLifecycleStatusLabel(lifecycleStatus);

  factory EventDetail.fromJson(Map<String, dynamic> j) {
    final summary = EventSummary.fromJson(j);
    final items = <EventItem>[];
    final rawItems = j['items'];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map) items.add(EventItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final guests = <EventGuest>[];
    final rawGuests = j['guests'];
    if (rawGuests is List) {
      for (final e in rawGuests) {
        if (e is Map) guests.add(EventGuest.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final ceremonies = <String>[];
    final rawCer = j['ceremonies'];
    if (rawCer is List) {
      for (final e in rawCer) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) ceremonies.add(s);
      }
    }
    final ceremonyDetails = <CeremonyDetail>[];
    final rawDet = j['ceremony_details'];
    if (rawDet is List) {
      for (final e in rawDet) {
        if (e is Map) {
          ceremonyDetails.add(CeremonyDetail.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final byCer = <String, List<EventGuest>>{};
    final rawBy = j['guestsByCeremony'];
    if (rawBy is Map) {
      rawBy.forEach((k, v) {
        final list = <EventGuest>[];
        if (v is List) {
          for (final e in v) {
            if (e is Map) list.add(EventGuest.fromJson(Map<String, dynamic>.from(e)));
          }
        }
        byCer[k.toString()] = list;
      });
    }
    final moneyRaw = j['summary'] is Map
        ? Map<String, dynamic>.from(j['summary'] as Map)
        : null;
    return EventDetail(
      summary: summary,
      items: items,
      guests: guests,
      ceremonies: ceremonies,
      ceremonyDetails: ceremonyDetails,
      guestsByCeremony: byCer,
      money: EventSummaryMoney.fromJson(moneyRaw),
    );
  }
}

class WizardQuestion {
  WizardQuestion({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.allowCustom = false,
    this.defaultValue,
  });

  final String id;
  final String label;
  final String type; // text | number | select | multiselect | date | textarea
  final bool required;
  final List<String> options;
  final bool allowCustom;
  final dynamic defaultValue;

  factory WizardQuestion.fromJson(Map<String, dynamic> j) {
    final opts = <String>[];
    final raw = j['options'];
    if (raw is List) {
      for (final o in raw) {
        opts.add(o.toString());
      }
    }
    return WizardQuestion(
      id: j['id']?.toString() ?? '',
      label: j['label']?.toString() ?? '',
      type: j['type']?.toString() ?? 'text',
      required: j['required'] == true,
      options: opts,
      allowCustom: j['allowCustom'] == true,
      defaultValue: j['default'],
    );
  }
}

class WizardMeta {
  WizardMeta({
    required this.eventType,
    required this.intro,
    required this.questions,
  });

  final String eventType;
  final String intro;
  final List<WizardQuestion> questions;

  factory WizardMeta.fromJson(Map<String, dynamic> j) {
    final qs = <WizardQuestion>[];
    final raw = j['questions'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) qs.add(WizardQuestion.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return WizardMeta(
      eventType: j['event_type']?.toString() ?? '',
      intro: j['intro']?.toString() ?? '',
      questions: qs,
    );
  }
}

String? _dateStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty || s == 'null') return null;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return s.substring(0, 10);
  try {
    return DateTime.parse(s).toIso8601String().substring(0, 10);
  } catch (_) {
    return s;
  }
}
