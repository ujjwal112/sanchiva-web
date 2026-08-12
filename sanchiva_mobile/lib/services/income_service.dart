import '../core/api_client.dart';
import '../models/income.dart';

class IncomeService {
  IncomeService._();
  static final IncomeService instance = IncomeService._();

  final _api = ApiClient.instance;

  Future<List<IncomeSource>> list({int? month, int? year}) async {
    final q = <String>[];
    if (month != null) q.add('month=$month');
    if (year != null) q.add('year=$year');
    final path = q.isEmpty ? '/monetary/income' : '/monetary/income?${q.join('&')}';
    final raw = await _api.getList(path);
    return raw
        .whereType<Map>()
        .map((e) => IncomeSource.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<IncomeSummary> summary({required int month, required int year}) async {
    final data = await _api.get('/monetary/income/summary?month=$month&year=$year');
    return IncomeSummary.fromJson(data);
  }

  Future<IncomeSource> create({
    required String sourceName,
    required double amount,
    required int month,
    required int year,
  }) async {
    final data = await _api.post('/monetary/income', {
      'source_name': sourceName,
      'amount': amount,
      'month': month,
      'year': year,
    });
    return IncomeSource.fromJson(data);
  }

  Future<IncomeSource> update(
    int id, {
    required String sourceName,
    required double amount,
    required int month,
    required int year,
  }) async {
    final data = await _api.put('/monetary/income/$id', {
      'source_name': sourceName,
      'amount': amount,
      'month': month,
      'year': year,
    });
    return IncomeSource.fromJson(data);
  }

  Future<void> delete(int id) async {
    await _api.delete('/monetary/income/$id');
  }
}
