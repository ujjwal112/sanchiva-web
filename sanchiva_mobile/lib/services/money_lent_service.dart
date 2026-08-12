import '../core/api_client.dart';
import '../models/money_lent.dart';

class MoneyLentService {
  MoneyLentService._();
  static final MoneyLentService instance = MoneyLentService._();

  final _api = ApiClient.instance;

  Future<List<MoneyLent>> list() async {
    final raw = await _api.getList('/monetary/money-given');
    return raw
        .whereType<Map>()
        .map((e) => MoneyLent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MoneyLentSummary> summary() async {
    final data = await _api.get('/monetary/money-given/summary');
    return MoneyLentSummary.fromJson(data);
  }

  Future<MoneyLent> create({
    required String personName,
    required DateTime givenDate,
    required double amount,
    String notes = '',
  }) async {
    final iso =
        '${givenDate.year.toString().padLeft(4, '0')}-${givenDate.month.toString().padLeft(2, '0')}-${givenDate.day.toString().padLeft(2, '0')}';
    final data = await _api.post('/monetary/money-given', {
      'person_name': personName,
      'given_date': iso,
      'amount': amount,
      'notes': notes.isEmpty ? null : notes,
    });
    return MoneyLent.fromJson(data);
  }

  Future<MoneyLent> update(
    int id, {
    required String personName,
    required DateTime givenDate,
    required double amount,
    String notes = '',
  }) async {
    final iso =
        '${givenDate.year.toString().padLeft(4, '0')}-${givenDate.month.toString().padLeft(2, '0')}-${givenDate.day.toString().padLeft(2, '0')}';
    final data = await _api.put('/monetary/money-given/$id', {
      'person_name': personName,
      'given_date': iso,
      'amount': amount,
      'notes': notes.isEmpty ? null : notes,
    });
    return MoneyLent.fromJson(data);
  }

  Future<void> delete(int id) async {
    await _api.delete('/monetary/money-given/$id');
  }
}
