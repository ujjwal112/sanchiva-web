import '../core/api_client.dart';
import '../models/loan.dart';

class LoanService {
  LoanService._();
  static final LoanService instance = LoanService._();

  final _api = ApiClient.instance;

  // ── Loans ────────────────────────────────────────────────────────────────

  Future<List<Loan>> listLoans() async {
    final raw = await _api.getList('/loans');
    return raw
        .whereType<Map>()
        .map((e) => Loan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<LoanSummary> loanSummary() async {
    final data = await _api.get('/loans/summary');
    return LoanSummary.fromJson(data);
  }

  Future<Loan> createLoan(Map<String, dynamic> body) async {
    final data = await _api.post('/loans', body);
    return Loan.fromJson(data);
  }

  Future<Loan> updateLoan(int id, Map<String, dynamic> body) async {
    final data = await _api.put('/loans/$id', body);
    return Loan.fromJson(data);
  }

  Future<void> deleteLoan(int id) => _api.delete('/loans/$id');

  // ── Credit card spends ───────────────────────────────────────────────────

  Future<List<CreditSpend>> listSpends() async {
    final raw = await _api.getList('/credit-cards/spends');
    return raw
        .whereType<Map>()
        .map((e) => CreditSpend.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CreditSpendSummary> spendSummary() async {
    final data = await _api.get('/credit-cards/spends/summary');
    return CreditSpendSummary.fromJson(data);
  }

  Future<CreditSpend> createSpend(Map<String, dynamic> body) async {
    final data = await _api.post('/credit-cards/spends', body);
    return CreditSpend.fromJson(data);
  }

  Future<CreditSpend> updateSpend(int id, Map<String, dynamic> body) async {
    final data = await _api.put('/credit-cards/spends/$id', body);
    return CreditSpend.fromJson(data);
  }

  Future<void> deleteSpend(int id) => _api.delete('/credit-cards/spends/$id');

  // ── Credit card EMIs ─────────────────────────────────────────────────────

  Future<List<CreditEmi>> listEmis() async {
    final raw = await _api.getList('/credit-cards/emis');
    return raw
        .whereType<Map>()
        .map((e) => CreditEmi.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CreditEmiSummary> emiSummary() async {
    final data = await _api.get('/credit-cards/emis/summary');
    return CreditEmiSummary.fromJson(data);
  }

  Future<CreditEmi> createEmi(Map<String, dynamic> body) async {
    final data = await _api.post('/credit-cards/emis', body);
    return CreditEmi.fromJson(data);
  }

  Future<CreditEmi> updateEmi(int id, Map<String, dynamic> body) async {
    final data = await _api.put('/credit-cards/emis/$id', body);
    return CreditEmi.fromJson(data);
  }

  Future<void> deleteEmi(int id) => _api.delete('/credit-cards/emis/$id');
}
