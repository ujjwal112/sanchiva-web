import '../core/api_client.dart';
import '../models/expense.dart';

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  final _api = ApiClient.instance;

  Future<List<Expense>> listAll() async {
    final raw = await _api.getList('/expenses');
    return raw
        .whereType<Map>()
        .map((e) => Expense.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<WeekSummary>> weeks({required int year, required int month}) async {
    final raw = await _api.getList('/expenses/summary/weeks?year=$year&month=$month');
    return raw
        .whereType<Map>()
        .map((e) => WeekSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<MonthSummary>> months({required int year}) async {
    final raw = await _api.getList('/expenses/summary/months?year=$year');
    return raw
        .whereType<Map>()
        .map((e) => MonthSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Expense> create({
    required String category,
    required double amount,
    required String expenseDate,
    required String itemName,
    String? customCategory,
    String paidVia = 'Cash',
    String paidViaDetail = '',
  }) async {
    final data = await _api.post('/expenses', {
      'category': category,
      if (customCategory != null && customCategory.isNotEmpty) 'custom_category': customCategory,
      'amount': amount,
      'expense_date': expenseDate,
      'item_name': itemName,
      'paid_via': paidVia,
      'paid_via_detail': paidVia == 'Cash' ? '' : paidViaDetail,
    });
    return Expense.fromJson(data);
  }

  Future<Expense> update(
    int id, {
    required String category,
    required double amount,
    required String expenseDate,
    required String itemName,
    String? customCategory,
    String paidVia = 'Cash',
    String paidViaDetail = '',
  }) async {
    final data = await _api.put('/expenses/$id', {
      'category': category,
      if (customCategory != null && customCategory.isNotEmpty) 'custom_category': customCategory,
      'amount': amount,
      'expense_date': expenseDate,
      'item_name': itemName,
      'paid_via': paidVia,
      'paid_via_detail': paidVia == 'Cash' ? '' : paidViaDetail,
    });
    return Expense.fromJson(data);
  }

  Future<void> delete(int id) async {
    await _api.delete('/expenses/$id');
  }
}
