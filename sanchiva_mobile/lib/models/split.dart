/// Set from AuthState when Splits opens — used when API still has "You" for self.
String? splitSelfDisplayName;

/// Resolve member label: self → logged-in name, others → stored name.
String splitMemberLabel(String name, {bool isYou = false}) {
  final raw = name.trim();
  if (isYou) {
    if (raw.isNotEmpty && raw.toLowerCase() != 'you') return raw;
    final self = splitSelfDisplayName?.trim();
    if (self != null && self.isNotEmpty && self.toLowerCase() != 'you') return self;
    return raw.isNotEmpty && raw.toLowerCase() != 'you' ? raw : 'Me';
  }
  return raw.isNotEmpty ? raw : 'Member';
}

class SplitMember {
  SplitMember({
    required this.id,
    required this.name,
    this.isYou = false,
  });

  final int id;
  final String name;
  final bool isYou;

  factory SplitMember.fromJson(Map<String, dynamic> j) {
    return SplitMember(
      id: int.tryParse('${j['id']}') ?? 0,
      name: j['name']?.toString() ?? '',
      isYou: j['is_you'] == true || j['is_you'] == 'true' || j['is_you'] == 1,
    );
  }

  /// Prefer stored name; for self, use logged-in name instead of "You".
  String get displayName => splitMemberLabel(name, isYou: isYou);
}

class SplitBalance {
  SplitBalance({
    required this.id,
    required this.name,
    this.isYou = false,
    this.balance = 0,
  });

  final int id;
  final String name;
  final bool isYou;
  final double balance;

  factory SplitBalance.fromJson(Map<String, dynamic> j) {
    return SplitBalance(
      id: int.tryParse('${j['id']}') ?? 0,
      name: j['name']?.toString() ?? '',
      isYou: j['is_you'] == true || j['is_you'] == 'true' || j['is_you'] == 1,
      balance: double.tryParse('${j['balance']}') ?? 0,
    );
  }

  String get displayName => splitMemberLabel(name, isYou: isYou);
}

class SplitTransfer {
  SplitTransfer({
    required this.fromMemberId,
    required this.fromName,
    required this.toMemberId,
    required this.toName,
    required this.amount,
  });

  final int fromMemberId;
  final String fromName;
  final int toMemberId;
  final String toName;
  final double amount;

  factory SplitTransfer.fromJson(Map<String, dynamic> j) {
    final fromIsYou =
        j['from_is_you'] == true || j['from_is_you'] == 'true' || j['from_is_you'] == 1;
    final toIsYou = j['to_is_you'] == true || j['to_is_you'] == 'true' || j['to_is_you'] == 1;
    return SplitTransfer(
      fromMemberId: int.tryParse('${j['from_member_id']}') ?? 0,
      fromName: splitMemberLabel(j['from_name']?.toString() ?? '', isYou: fromIsYou),
      toMemberId: int.tryParse('${j['to_member_id']}') ?? 0,
      toName: splitMemberLabel(j['to_name']?.toString() ?? '', isYou: toIsYou),
      amount: double.tryParse('${j['amount']}') ?? 0,
    );
  }
}

class SplitShare {
  SplitShare({
    required this.memberId,
    required this.memberName,
    this.isYou = false,
    required this.shareAmount,
  });

  final int memberId;
  final String memberName;
  final bool isYou;
  final double shareAmount;

  factory SplitShare.fromJson(Map<String, dynamic> j) {
    return SplitShare(
      memberId: int.tryParse('${j['member_id']}') ?? 0,
      memberName: j['member_name']?.toString() ?? '',
      isYou: j['is_you'] == true || j['is_you'] == 'true' || j['is_you'] == 1,
      shareAmount: double.tryParse('${j['share_amount']}') ?? 0,
    );
  }

  String get displayName => splitMemberLabel(memberName, isYou: isYou);
}

class SplitAmountChange {
  SplitAmountChange({
    required this.id,
    required this.expenseId,
    required this.oldAmount,
    required this.newAmount,
    this.note = '',
    this.changedByName = '',
    this.createdAt,
    this.expenseDescription = '',
  });

  final int id;
  final int expenseId;
  final double oldAmount;
  final double newAmount;
  final String note;
  final String changedByName;
  final DateTime? createdAt;
  final String expenseDescription;

  factory SplitAmountChange.fromJson(Map<String, dynamic> j) {
    DateTime? created;
    final raw = j['created_at']?.toString();
    if (raw != null && raw.isNotEmpty) {
      // API sends UTC (…Z). Show device local time in history.
      final parsed = DateTime.tryParse(raw);
      created = parsed?.toLocal();
    }
    return SplitAmountChange(
      id: int.tryParse('${j['id']}') ?? 0,
      expenseId: int.tryParse('${j['expense_id']}') ?? 0,
      oldAmount: double.tryParse('${j['old_amount']}') ?? 0,
      newAmount: double.tryParse('${j['new_amount']}') ?? 0,
      note: j['note']?.toString() ?? '',
      changedByName: j['changed_by_name']?.toString() ??
          j['changed_by_email']?.toString() ??
          '',
      createdAt: created,
      expenseDescription: j['expense_description']?.toString() ?? '',
    );
  }
}

class SplitExpense {
  SplitExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidByMemberId,
    required this.paidByName,
    this.paidByIsYou = false,
    required this.expenseDate,
    this.notes = '',
    this.shares = const [],
    this.amountEditCount = 0,
    this.lastAmountChange,
    this.amountHistory = const [],
  });

  final int id;
  final String description;
  final double amount;
  final int paidByMemberId;
  final String paidByName;
  final bool paidByIsYou;
  final DateTime expenseDate;
  final String notes;
  final List<SplitShare> shares;
  final int amountEditCount;
  final SplitAmountChange? lastAmountChange;
  final List<SplitAmountChange> amountHistory;

  factory SplitExpense.fromJson(Map<String, dynamic> j) {
    final raw = j['expense_date']?.toString() ?? '';
    final date = DateTime.tryParse(raw.length >= 10 ? raw.substring(0, 10) : raw) ??
        DateTime.tryParse(raw) ??
        DateTime.now();
    final shares = <SplitShare>[];
    final sharesRaw = j['shares'];
    if (sharesRaw is List) {
      for (final s in sharesRaw) {
        if (s is Map) {
          shares.add(SplitShare.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    final history = <SplitAmountChange>[];
    final histRaw = j['amount_history'];
    if (histRaw is List) {
      for (final h in histRaw) {
        if (h is Map) {
          history.add(SplitAmountChange.fromJson(Map<String, dynamic>.from(h)));
        }
      }
    }
    SplitAmountChange? last;
    final lastRaw = j['last_amount_change'];
    if (lastRaw is Map) {
      last = SplitAmountChange.fromJson(Map<String, dynamic>.from(lastRaw));
    } else if (history.isNotEmpty) {
      last = history.first;
    }
    return SplitExpense(
      id: int.tryParse('${j['id']}') ?? 0,
      description: j['description']?.toString() ?? '',
      amount: double.tryParse('${j['amount']}') ?? 0,
      paidByMemberId: int.tryParse('${j['paid_by_member_id']}') ?? 0,
      paidByName: j['paid_by_name']?.toString() ?? '',
      paidByIsYou:
          j['paid_by_is_you'] == true || j['paid_by_is_you'] == 'true' || j['paid_by_is_you'] == 1,
      expenseDate: date,
      notes: j['notes']?.toString() ?? '',
      shares: shares,
      amountEditCount: int.tryParse('${j['amount_edit_count']}') ?? history.length,
      lastAmountChange: last,
      amountHistory: history,
    );
  }

  String get paidByDisplay => splitMemberLabel(paidByName, isYou: paidByIsYou);
}

class SplitSettlement {
  SplitSettlement({
    required this.id,
    required this.fromMemberId,
    required this.fromName,
    this.fromIsYou = false,
    required this.toMemberId,
    required this.toName,
    this.toIsYou = false,
    required this.amount,
    required this.settledDate,
    this.notes = '',
  });

  final int id;
  final int fromMemberId;
  final String fromName;
  final bool fromIsYou;
  final int toMemberId;
  final String toName;
  final bool toIsYou;
  final double amount;
  final DateTime settledDate;
  final String notes;

  factory SplitSettlement.fromJson(Map<String, dynamic> j) {
    final raw = j['settled_date']?.toString() ?? '';
    final date = DateTime.tryParse(raw.length >= 10 ? raw.substring(0, 10) : raw) ??
        DateTime.tryParse(raw) ??
        DateTime.now();
    return SplitSettlement(
      id: int.tryParse('${j['id']}') ?? 0,
      fromMemberId: int.tryParse('${j['from_member_id']}') ?? 0,
      fromName: j['from_name']?.toString() ?? '',
      fromIsYou: j['from_is_you'] == true || j['from_is_you'] == 'true' || j['from_is_you'] == 1,
      toMemberId: int.tryParse('${j['to_member_id']}') ?? 0,
      toName: j['to_name']?.toString() ?? '',
      toIsYou: j['to_is_you'] == true || j['to_is_you'] == 'true' || j['to_is_you'] == 1,
      amount: double.tryParse('${j['amount']}') ?? 0,
      settledDate: date,
      notes: j['notes']?.toString() ?? '',
    );
  }

  String get fromDisplay => splitMemberLabel(fromName, isYou: fromIsYou);
  String get toDisplay => splitMemberLabel(toName, isYou: toIsYou);
}

class SplitGroupSummary {
  SplitGroupSummary({
    required this.id,
    required this.name,
    this.notes = '',
    this.memberCount = 0,
    this.totalSpent = 0,
    this.yourBalance = 0,
  });

  final int id;
  final String name;
  final String notes;
  final int memberCount;
  final double totalSpent;
  final double yourBalance;

  factory SplitGroupSummary.fromJson(Map<String, dynamic> j) {
    return SplitGroupSummary(
      id: int.tryParse('${j['id']}') ?? 0,
      name: j['name']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      memberCount: int.tryParse('${j['member_count']}') ?? 0,
      totalSpent: double.tryParse('${j['total_spent']}') ?? 0,
      yourBalance: double.tryParse('${j['your_balance']}') ?? 0,
    );
  }
}

class SplitGroupDetail {
  SplitGroupDetail({
    required this.id,
    required this.name,
    this.notes = '',
    this.members = const [],
    this.balances = const [],
    this.transfers = const [],
    this.expenses = const [],
    this.settlements = const [],
    this.totalSpent = 0,
    this.yourBalance = 0,
  });

  final int id;
  final String name;
  final String notes;
  final List<SplitMember> members;
  final List<SplitBalance> balances;
  final List<SplitTransfer> transfers;
  final List<SplitExpense> expenses;
  final List<SplitSettlement> settlements;
  final double totalSpent;
  final double yourBalance;

  factory SplitGroupDetail.fromJson(Map<String, dynamic> j) {
    List<T> mapList<T>(dynamic raw, T Function(Map<String, dynamic>) f) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => f(Map<String, dynamic>.from(e)))
          .toList();
    }

    return SplitGroupDetail(
      id: int.tryParse('${j['id']}') ?? 0,
      name: j['name']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      members: mapList(j['members'], SplitMember.fromJson),
      balances: mapList(j['balances'], SplitBalance.fromJson),
      transfers: mapList(j['transfers'], SplitTransfer.fromJson),
      expenses: mapList(j['expenses'], SplitExpense.fromJson),
      settlements: mapList(j['settlements'], SplitSettlement.fromJson),
      totalSpent: double.tryParse('${j['total_spent']}') ?? 0,
      yourBalance: double.tryParse('${j['your_balance']}') ?? 0,
    );
  }
}
