import '../core/api_client.dart';
import '../models/split.dart';

class SplitService {
  SplitService._();
  static final SplitService instance = SplitService._();

  final _api = ApiClient.instance;

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<SplitGroupSummary>> listGroups() async {
    final raw = await _api.getList('/splits/groups');
    return raw
        .whereType<Map>()
        .map((e) => SplitGroupSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SplitGroupDetail> getGroup(int id) async {
    final data = await _api.get('/splits/groups/$id');
    return SplitGroupDetail.fromJson(data);
  }

  Future<SplitGroupDetail> createGroup({
    required String name,
    String notes = '',
    List<String> members = const [],
  }) async {
    final data = await _api.post('/splits/groups', {
      'name': name,
      if (notes.isNotEmpty) 'notes': notes,
      'members': members,
    });
    final id = int.tryParse('${data['id']}') ?? 0;
    if (id > 0) return getGroup(id);
    return SplitGroupDetail.fromJson(data);
  }

  Future<void> deleteGroup(int id) async {
    await _api.delete('/splits/groups/$id');
  }

  Future<SplitMember> addMember(int groupId, String name) async {
    final data = await _api.post('/splits/groups/$groupId/members', {'name': name});
    return SplitMember.fromJson(data);
  }

  Future<SplitExpense> addExpense({
    required int groupId,
    required String description,
    required double amount,
    required int paidByMemberId,
    required DateTime expenseDate,
    String notes = '',
    List<int>? splitMemberIds,
  }) async {
    final data = await _api.post('/splits/groups/$groupId/expenses', {
      'description': description,
      'amount': amount,
      'paid_by_member_id': paidByMemberId,
      'expense_date': _isoDate(expenseDate),
      'notes': notes.isEmpty ? null : notes,
      if (splitMemberIds != null && splitMemberIds.isNotEmpty)
        'split_member_ids': splitMemberIds,
    });
    return SplitExpense.fromJson(data);
  }

  Future<SplitExpense> updateExpense({
    required int groupId,
    required int expenseId,
    required String description,
    required double amount,
    required int paidByMemberId,
    required DateTime expenseDate,
    String notes = '',
    List<int>? splitMemberIds,
    String historyNote = '',
  }) async {
    final data = await _api.put('/splits/groups/$groupId/expenses/$expenseId', {
      'description': description,
      'amount': amount,
      'paid_by_member_id': paidByMemberId,
      'expense_date': _isoDate(expenseDate),
      'notes': notes.isEmpty ? null : notes,
      if (splitMemberIds != null && splitMemberIds.isNotEmpty)
        'split_member_ids': splitMemberIds,
      if (historyNote.isNotEmpty) 'history_note': historyNote,
    });
    return SplitExpense.fromJson(data);
  }

  Future<void> deleteExpense(int groupId, int expenseId) async {
    await _api.delete('/splits/groups/$groupId/expenses/$expenseId');
  }

  Future<List<SplitAmountChange>> amountHistory(int groupId, int expenseId) async {
    final raw = await _api.getList('/splits/groups/$groupId/expenses/$expenseId/amount-history');
    return raw
        .whereType<Map>()
        .map((e) => SplitAmountChange.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SplitSettlement> addSettlement({
    required int groupId,
    required int fromMemberId,
    required int toMemberId,
    required double amount,
    required DateTime settledDate,
    String notes = '',
  }) async {
    final data = await _api.post('/splits/groups/$groupId/settlements', {
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'settled_date': _isoDate(settledDate),
      if (notes.isNotEmpty) 'notes': notes,
    });
    return SplitSettlement.fromJson(data);
  }

  Future<void> deleteSettlement(int groupId, int settlementId) async {
    await _api.delete('/splits/groups/$groupId/settlements/$settlementId');
  }
}
