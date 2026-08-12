/// Loan + credit card models (aligned with server routes).

class LoanProgress {
  LoanProgress({
    required this.totalAmount,
    required this.deducted,
    required this.remaining,
    required this.totalMonths,
    required this.monthsPaid,
    required this.monthsLeft,
  });

  final double totalAmount;
  final double deducted;
  final double remaining;
  final int totalMonths;
  final int monthsPaid;
  final int monthsLeft;

  double get fraction {
    if (totalAmount <= 0) return 0;
    return (deducted / totalAmount).clamp(0.0, 1.0);
  }

  factory LoanProgress.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return LoanProgress(
        totalAmount: 0,
        deducted: 0,
        remaining: 0,
        totalMonths: 0,
        monthsPaid: 0,
        monthsLeft: 0,
      );
    }
    return LoanProgress(
      totalAmount: double.tryParse('${j['totalAmount']}') ?? 0,
      deducted: double.tryParse('${j['deducted']}') ?? 0,
      remaining: double.tryParse('${j['remaining']}') ?? 0,
      totalMonths: int.tryParse('${j['totalMonths']}') ?? 0,
      monthsPaid: int.tryParse('${j['monthsPaid']}') ?? 0,
      monthsLeft: int.tryParse('${j['monthsLeft']}') ?? 0,
    );
  }
}

class Loan {
  Loan({
    required this.id,
    required this.bankName,
    required this.emiDeductionBank,
    required this.emiDeductionDate,
    required this.emiCloseMonth,
    required this.emiCloseYear,
    required this.emiAmount,
    this.roi = 0,
    required this.status,
    required this.startMonth,
    required this.startYear,
    required this.progress,
  });

  final int id;
  final String bankName;
  final String emiDeductionBank;
  final int emiDeductionDate;
  final int emiCloseMonth;
  final int emiCloseYear;
  final double emiAmount;
  /// Rate of interest (%).
  final double roi;
  final String status; // ongoing | closed
  final int startMonth;
  final int startYear;
  final LoanProgress progress;

  bool get isClosed => status.toLowerCase() == 'closed';

  int get _startKey => startYear * 12 + startMonth;
  int get _endKey => emiCloseYear * 12 + emiCloseMonth;

  /// Inclusive months from start → EMI close (entry months/years).
  int get tenureMonths {
    final n = _endKey - _startKey + 1;
    return n < 1 ? 1 : n;
  }

  /// Months already paid through current calendar month (or full tenure if closed).
  int paidMonths([DateTime? now]) {
    if (isClosed) return tenureMonths;
    final n = now ?? DateTime.now();
    final cur = n.year * 12 + n.month;
    if (cur < _startKey) return 0;
    if (cur >= _endKey) return tenureMonths;
    return (cur - _startKey + 1).clamp(0, tenureMonths);
  }

  /// True if this loan has an EMI due in [month]/[year] (inclusive of start → close).
  bool isActiveIn(int month, int year) {
    if (isClosed) return false;
    final cur = year * 12 + month;
    return cur >= _startKey && cur <= _endKey;
  }

  factory Loan.fromJson(Map<String, dynamic> j) {
    final prog = j['progress'];
    return Loan(
      id: int.tryParse('${j['id']}') ?? 0,
      bankName: j['bank_name']?.toString() ?? '',
      emiDeductionBank: j['emi_deduction_bank']?.toString() ?? '',
      emiDeductionDate: int.tryParse('${j['emi_deduction_date']}') ?? 1,
      emiCloseMonth: int.tryParse('${j['emi_close_month']}') ?? 12,
      emiCloseYear: int.tryParse('${j['emi_close_year']}') ?? DateTime.now().year,
      emiAmount: double.tryParse('${j['emi_amount']}') ?? 0,
      roi: double.tryParse('${j['roi']}') ?? 0,
      status: j['status']?.toString() ?? 'ongoing',
      startMonth: int.tryParse('${j['start_month']}') ?? DateTime.now().month,
      startYear: int.tryParse('${j['start_year']}') ?? DateTime.now().year,
      progress: LoanProgress.fromJson(
        prog is Map ? Map<String, dynamic>.from(prog) : null,
      ),
    );
  }
}

class LoanClosureYear {
  LoanClosureYear({
    required this.year,
    required this.closingCount,
    required this.closedCount,
    required this.activeCount,
  });

  final int year;
  /// All loans scheduled to close in this year.
  final int closingCount;
  /// Already closed in this year.
  final int closedCount;
  /// Still active (will close) in this year.
  final int activeCount;

  factory LoanClosureYear.fromJson(Map<String, dynamic> j) {
    return LoanClosureYear(
      year: int.tryParse('${j['year']}') ?? 0,
      closingCount: int.tryParse('${j['closingCount']}') ?? 0,
      closedCount: int.tryParse('${j['closedCount']}') ?? 0,
      activeCount: int.tryParse('${j['activeCount']}') ?? 0,
    );
  }
}

class LoanSummary {
  LoanSummary({
    required this.month,
    required this.year,
    required this.totalLoanAmount,
    required this.deductedThisMonth,
    required this.remainingToDeduct,
    required this.totalMonthlyEmi,
    required this.activeCount,
    required this.closedCount,
    required this.byBank,
    required this.closureYears,
  });

  final int month;
  final int year;
  final double totalLoanAmount;
  final double deductedThisMonth;
  final double remainingToDeduct;
  final double totalMonthlyEmi;
  final int activeCount;
  final int closedCount;
  final Map<String, double> byBank; // bank -> total EMI
  final List<LoanClosureYear> closureYears;

  factory LoanSummary.fromJson(Map<String, dynamic> j) {
    final month = j['monthCard'] is Map ? Map<String, dynamic>.from(j['monthCard'] as Map) : <String, dynamic>{};
    final bank = j['bankCard'] is Map ? Map<String, dynamic>.from(j['bankCard'] as Map) : <String, dynamic>{};
    final byBank = <String, double>{};
    final banks = bank['banks'];
    if (banks is List) {
      for (final b in banks) {
        if (b is Map) {
          final name = b['bank']?.toString() ?? 'Bank';
          byBank[name] = double.tryParse('${b['totalEmi']}') ?? 0;
        }
      }
    }
    final closure = <LoanClosureYear>[];
    final rawClosure = j['closureYearCard'];
    if (rawClosure is List) {
      for (final c in rawClosure) {
        if (c is Map) {
          closure.add(LoanClosureYear.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }
    return LoanSummary(
      month: int.tryParse('${month['month']}') ?? DateTime.now().month,
      year: int.tryParse('${month['year']}') ?? DateTime.now().year,
      totalLoanAmount: double.tryParse('${month['totalLoanAmount']}') ?? 0,
      deductedThisMonth: double.tryParse('${month['deductedThisMonth']}') ?? 0,
      remainingToDeduct: double.tryParse('${month['remainingToDeduct']}') ?? 0,
      totalMonthlyEmi: double.tryParse('${bank['totalMonthlyEmi']}') ?? 0,
      activeCount: int.tryParse('${bank['totalActiveLoans']}') ?? 0,
      closedCount: int.tryParse('${bank['closedLoansCount']}') ?? 0,
      byBank: byBank,
      closureYears: closure,
    );
  }
}

class CreditSpend {
  CreditSpend({
    required this.id,
    required this.spendDate,
    required this.spendType,
    required this.creditCardName,
    required this.amount,
  });

  final int id;
  final DateTime spendDate;
  final String spendType;
  final String creditCardName;
  final double amount;

  factory CreditSpend.fromJson(Map<String, dynamic> j) {
    final raw = j['spend_date']?.toString() ?? '';
    DateTime d;
    try {
      d = DateTime.parse(raw.length >= 10 ? raw.substring(0, 10) : raw);
    } catch (_) {
      d = DateTime.now();
    }
    return CreditSpend(
      id: int.tryParse('${j['id']}') ?? 0,
      spendDate: d,
      spendType: j['spend_type']?.toString() ?? '',
      creditCardName: j['credit_card_name']?.toString() ?? '',
      amount: double.tryParse('${j['amount']}') ?? 0,
    );
  }
}

class CreditSpendSummary {
  CreditSpendSummary({
    required this.total,
    required this.byType,
    required this.byCard,
    required this.count,
  });

  final double total;
  final Map<String, double> byType;
  final Map<String, double> byCard;
  final int count;

  factory CreditSpendSummary.fromJson(Map<String, dynamic> j) {
    final byType = <String, double>{};
    final byCard = <String, double>{};
    final t = j['byType'];
    if (t is List) {
      for (final e in t) {
        if (e is Map) {
          byType[e['name']?.toString() ?? ''] = double.tryParse('${e['amount']}') ?? 0;
        }
      }
    }
    final c = j['byCard'];
    if (c is List) {
      for (final e in c) {
        if (e is Map) {
          byCard[e['name']?.toString() ?? ''] = double.tryParse('${e['amount']}') ?? 0;
        }
      }
    }
    return CreditSpendSummary(
      total: double.tryParse('${j['total']}') ?? 0,
      byType: byType,
      byCard: byCard,
      count: int.tryParse('${j['count']}') ?? 0,
    );
  }
}

class CreditEmi {
  CreditEmi({
    required this.id,
    required this.emiName,
    required this.creditCardName,
    required this.startMonth,
    required this.startYear,
    required this.endMonth,
    required this.endYear,
    required this.amount,
    this.roi = 0,
  });

  final int id;
  final String emiName;
  final String creditCardName;
  final int startMonth;
  final int startYear;
  final int endMonth;
  final int endYear;
  final double amount;
  /// Rate of interest (%).
  final double roi;

  /// Number of installment months (inclusive).
  int get tenureMonths {
    final n = (endYear - startYear) * 12 + (endMonth - startMonth) + 1;
    return n < 1 ? 1 : n;
  }

  /// Full purchase / total EMI commitment (monthly × months).
  double get totalAmount => amount * tenureMonths;

  /// True if this EMI has an installment in [month]/[year].
  bool isActiveIn(int month, int year) {
    final cur = year * 12 + month;
    final start = startYear * 12 + startMonth;
    final end = endYear * 12 + endMonth;
    return cur >= start && cur <= end;
  }

  int get _startKey => startYear * 12 + startMonth;
  int get _endKey => endYear * 12 + endMonth;

  /// Installments already due through the current month (0…tenure).
  int paidMonths([DateTime? now]) {
    final n = now ?? DateTime.now();
    final cur = n.year * 12 + n.month;
    if (cur < _startKey) return 0;
    if (cur >= _endKey) return tenureMonths;
    return (cur - _startKey + 1).clamp(0, tenureMonths);
  }

  int remainingMonths([DateTime? now]) =>
      (tenureMonths - paidMonths(now)).clamp(0, tenureMonths);

  double get paidAmount => amount * paidMonths();
  double get remainingAmount => amount * remainingMonths();

  double get progressFraction {
    final t = tenureMonths;
    if (t <= 0) return 0;
    return (paidMonths() / t).clamp(0.0, 1.0);
  }

  /// Fully paid / past end month.
  bool get isCompleted {
    final n = DateTime.now();
    return n.year * 12 + n.month > _endKey;
  }

  /// Has not started yet.
  bool get isUpcoming {
    final n = DateTime.now();
    return n.year * 12 + n.month < _startKey;
  }

  bool get isOngoing => !isCompleted && !isUpcoming;

  factory CreditEmi.fromJson(Map<String, dynamic> j) {
    return CreditEmi(
      id: int.tryParse('${j['id']}') ?? 0,
      emiName: j['emi_name']?.toString() ?? '',
      creditCardName: j['credit_card_name']?.toString() ?? '',
      startMonth: int.tryParse('${j['start_month']}') ?? 1,
      startYear: int.tryParse('${j['start_year']}') ?? DateTime.now().year,
      endMonth: int.tryParse('${j['end_month']}') ?? 12,
      endYear: int.tryParse('${j['end_year']}') ?? DateTime.now().year,
      amount: double.tryParse('${j['amount']}') ?? 0,
      roi: double.tryParse('${j['roi']}') ?? 0,
    );
  }
}

class CreditEmiSummary {
  CreditEmiSummary({
    required this.totalMonthly,
    required this.byCard,
    required this.count,
  });

  final double totalMonthly;
  final Map<String, double> byCard;
  final int count;

  factory CreditEmiSummary.fromJson(Map<String, dynamic> j) {
    final byCard = <String, double>{};
    double monthly = double.tryParse('${j['totalMonthly']}') ?? 0;
    int count = int.tryParse('${j['count']}') ?? 0;
    final list = j['byCard'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          final name = e['name']?.toString() ?? '';
          final m = double.tryParse('${e['monthly'] ?? e['amount']}') ?? 0;
          byCard[name] = m;
        }
      }
      if (monthly <= 0) {
        monthly = byCard.values.fold<double>(0, (a, b) => a + b);
      }
    } else if (list is Map) {
      list.forEach((k, v) {
        if (v is Map) {
          byCard[k.toString()] = double.tryParse('${v['monthly']}') ?? 0;
        }
      });
      if (monthly <= 0) {
        monthly = byCard.values.fold<double>(0, (a, b) => a + b);
      }
    }
    return CreditEmiSummary(totalMonthly: monthly, byCard: byCard, count: count);
  }
}

const kMonthNamesShort = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const kSpendTypes = <String>[
  'Ecommerce',
  'Grocery',
  'Food',
  'Travel',
  'Electronics',
  'Miscellaneous',
  'Other',
];
