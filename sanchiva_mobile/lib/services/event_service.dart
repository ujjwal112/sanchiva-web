import '../core/api_client.dart';
import '../models/event.dart';

class EventService {
  EventService._();
  static final EventService instance = EventService._();

  final _api = ApiClient.instance;

  Future<List<EventSummary>> list() async {
    final raw = await _api.getList('/events');
    return raw
        .whereType<Map>()
        .map((e) => EventSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<EventDetail> getById(String id) async {
    final data = await _api.get('/events/$id');
    return EventDetail.fromJson(data);
  }

  Future<WizardMeta> wizardQuestions(String eventType) async {
    final data = await _api.get('/events/meta/wizard-questions/$eventType');
    return WizardMeta.fromJson(data);
  }

  Future<EventSummary> createFromWizard({
    required String name,
    required String eventType,
    required Map<String, dynamic> answers,
    bool generateTodos = true,
  }) async {
    final data = await _api.post('/events/wizard', {
      'name': name,
      'event_type': eventType,
      'answers': answers,
      'generate_todos': generateTodos,
    });
    return EventSummary.fromJson(data);
  }

  Future<void> deleteEvent(String id) async {
    await _api.delete('/events/$id');
  }

  /// Update event fields (e.g. total budget on overview).
  Future<EventSummary> updateEvent(
    String id, {
    double? budget,
    String? name,
    String? notes,
    String? location,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (budget != null) body['budget'] = budget;
    if (name != null) body['name'] = name;
    if (notes != null) body['notes'] = notes;
    if (location != null) body['location'] = location;
    if (status != null) body['status'] = status;
    final data = await _api.put('/events/$id', body);
    return EventSummary.fromJson(data);
  }

  Future<EventItem> addItem(
    String eventId, {
    required String title,
    String? category,
    double plannedAmount = 0,
    double tokenPaid = 0,
    String? vendorName,
    String? notes,
  }) async {
    final data = await _api.post('/events/$eventId/items', {
      'title': title,
      if (category != null && category.isNotEmpty) 'category': category,
      'planned_amount': plannedAmount,
      'token_paid': tokenPaid,
      if (vendorName != null && vendorName.isNotEmpty) 'vendor_name': vendorName,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return EventItem.fromJson(data);
  }

  Future<EventItem> updateItem(
    String itemId, {
    String? title,
    String? category,
    double? plannedAmount,
    double? tokenPaid,
    bool? isDone,
    String? vendorName,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (category != null) body['category'] = category;
    if (plannedAmount != null) body['planned_amount'] = plannedAmount;
    if (tokenPaid != null) body['token_paid'] = tokenPaid;
    if (isDone != null) body['is_done'] = isDone;
    if (vendorName != null) body['vendor_name'] = vendorName;
    if (notes != null) body['notes'] = notes;
    final data = await _api.put('/events/items/$itemId', body);
    return EventItem.fromJson(data);
  }

  Future<void> deleteItem(String itemId) async {
    await _api.delete('/events/items/$itemId');
  }

  Future<List<EventItemPayment>> listItemPayments(String itemId) async {
    final raw = await _api.getList('/events/items/$itemId/payments');
    return raw
        .whereType<Map>()
        .map((e) => EventItemPayment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Returns updated item + payments after adding a partial payment.
  Future<({EventItem item, List<EventItemPayment> payments})> addItemPayment(
    String itemId, {
    required double amount,
    required String paymentDate,
    required String paidVia,
    String paidViaDetail = '',
    String tag = '',
    String notes = '',
  }) async {
    final data = await _api.post('/events/items/$itemId/payments', {
      'amount': amount,
      'payment_date': paymentDate,
      'paid_via': paidVia,
      if (paidViaDetail.trim().isNotEmpty) 'paid_via_detail': paidViaDetail.trim(),
      if (tag.trim().isNotEmpty) 'tag': tag.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    final itemRaw = data['item'];
    final item = itemRaw is Map
        ? EventItem.fromJson(Map<String, dynamic>.from(itemRaw))
        : EventItem(id: itemId, eventId: '', title: '');
    final payments = <EventItemPayment>[];
    final rawPay = data['payments'];
    if (rawPay is List) {
      for (final e in rawPay) {
        if (e is Map) {
          payments.add(EventItemPayment.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return (item: item.copyWith(payments: payments), payments: payments);
  }

  Future<({EventItem item, List<EventItemPayment> payments})> updateItemPayment(
    String paymentId, {
    required double amount,
    required String paymentDate,
    required String paidVia,
    String paidViaDetail = '',
    String tag = '',
    String notes = '',
  }) async {
    final data = await _api.put('/events/payments/$paymentId', {
      'amount': amount,
      'payment_date': paymentDate,
      'paid_via': paidVia,
      'paid_via_detail': paidViaDetail.trim(),
      'tag': tag.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    final itemRaw = data['item'];
    final item = itemRaw is Map
        ? EventItem.fromJson(Map<String, dynamic>.from(itemRaw))
        : EventItem(id: '', eventId: '', title: '');
    final payments = <EventItemPayment>[];
    final rawPay = data['payments'];
    if (rawPay is List) {
      for (final e in rawPay) {
        if (e is Map) {
          payments.add(EventItemPayment.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return (item: item.copyWith(payments: payments), payments: payments);
  }

  Future<({EventItem? item, List<EventItemPayment> payments})> deleteItemPayment(
    String paymentId,
  ) async {
    final data = await _api.delete('/events/payments/$paymentId');
    EventItem? item;
    final itemRaw = data['item'];
    if (itemRaw is Map) {
      item = EventItem.fromJson(Map<String, dynamic>.from(itemRaw));
    }
    final payments = <EventItemPayment>[];
    final rawPay = data['payments'];
    if (rawPay is List) {
      for (final e in rawPay) {
        if (e is Map) {
          payments.add(EventItemPayment.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return (
      item: item?.copyWith(payments: payments),
      payments: payments,
    );
  }

  Future<EventGuest> addGuest(
    String eventId, {
    required String name,
    String? side,
    String? ceremony,
    String rsvp = 'maybe',
    int count = 1,
    String? phone,
    String? notes,
  }) async {
    final data = await _api.post('/events/$eventId/guests', {
      'name': name,
      if (side != null && side.isNotEmpty) 'side': side,
      if (ceremony != null && ceremony.isNotEmpty) 'ceremony': ceremony,
      'rsvp': rsvp,
      'count': count,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return EventGuest.fromJson(data);
  }

  Future<EventGuest> updateGuest(
    String guestId, {
    String? name,
    String? side,
    String? ceremony,
    String? rsvp,
    int? count,
    String? phone,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (side != null) body['side'] = side;
    if (ceremony != null) body['ceremony'] = ceremony;
    if (rsvp != null) body['rsvp'] = rsvp;
    if (count != null) body['count'] = count;
    if (phone != null) body['phone'] = phone;
    if (notes != null) body['notes'] = notes;
    final data = await _api.put('/events/guests/$guestId', body);
    return EventGuest.fromJson(data);
  }

  Future<void> deleteGuest(String guestId) async {
    await _api.delete('/events/guests/$guestId');
  }

  /// Add a ceremony after event creation (overview cards).
  Future<void> addCeremony(
    String eventId, {
    required String name,
    String? date,
  }) async {
    await _api.post('/events/$eventId/ceremonies', {
      'name': name,
      'date': date,
    });
  }

  /// Update one ceremony name and/or date (renames guests when the name changes).
  Future<void> updateCeremony(
    String eventId, {
    required String originalName,
    required String name,
    String? date,
  }) async {
    await _api.put('/events/$eventId/ceremonies', {
      'originalName': originalName,
      'name': name,
      'date': date,
    });
  }

  /// Remove a ceremony; clears that ceremony on guests (guests stay on the event).
  Future<void> deleteCeremony(String eventId, {required String name}) async {
    final q = Uri.encodeQueryComponent(name);
    await _api.delete('/events/$eventId/ceremonies?name=$q');
  }
}
