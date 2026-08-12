class Expense {
  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.itemName,
    this.paidVia = 'Cash',
    this.paidViaDetail = '',
  });

  final int id;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String itemName;
  /// UPI | Card | Cash | Bank transfer | Other
  final String paidVia;
  /// Bank / card name / note (empty for Cash).
  final String paidViaDetail;

  factory Expense.fromJson(Map<String, dynamic> j) {
    final rawDate = j['expense_date']?.toString() ?? '';
    DateTime d;
    try {
      d = DateTime.parse(rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate);
    } catch (_) {
      d = DateTime.now();
    }
    return Expense(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      category: j['category']?.toString() ?? 'Other',
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
      expenseDate: d,
      itemName: j['item_name']?.toString() ?? '',
      paidVia: j['paid_via']?.toString().isNotEmpty == true
          ? j['paid_via'].toString()
          : 'Cash',
      paidViaDetail: j['paid_via_detail']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPayload() => {
        'category': category,
        'amount': amount,
        'expense_date':
            '${expenseDate.year.toString().padLeft(4, '0')}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}',
        'item_name': itemName,
        'paid_via': paidVia,
        'paid_via_detail': paidVia == 'Cash' ? '' : paidViaDetail,
      };

  String get dateIso =>
      '${expenseDate.year.toString().padLeft(4, '0')}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}';

  /// Label for lists: "UPI · SBI" or "Cash".
  String get paidViaLabel {
    if (paidVia == 'Cash' || paidViaDetail.trim().isEmpty) return paidVia;
    return '$paidVia · $paidViaDetail';
  }
}

class WeekSummary {
  WeekSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.total,
    required this.byCategory,
    required this.expenses,
  });

  final String weekStart;
  final String weekEnd;
  final double total;
  final Map<String, double> byCategory;
  final List<Expense> expenses;

  factory WeekSummary.fromJson(Map<String, dynamic> j) {
    final by = <String, double>{};
    final raw = j['byCategory'];
    if (raw is Map) {
      raw.forEach((k, v) {
        by[k.toString()] = double.tryParse(v.toString()) ?? 0;
      });
    }
    final list = <Expense>[];
    final ex = j['expenses'];
    if (ex is List) {
      for (final e in ex) {
        if (e is Map) list.add(Expense.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return WeekSummary(
      weekStart: j['weekStart']?.toString() ?? '',
      weekEnd: j['weekEnd']?.toString() ?? '',
      total: double.tryParse(j['total']?.toString() ?? '0') ?? 0,
      byCategory: by,
      expenses: list,
    );
  }
}

class MonthSummary {
  MonthSummary({
    required this.month,
    required this.year,
    required this.total,
    required this.byCategory,
    required this.expenses,
  });

  final int month;
  final int year;
  final double total;
  final Map<String, double> byCategory;
  final List<Expense> expenses;

  factory MonthSummary.fromJson(Map<String, dynamic> j) {
    final by = <String, double>{};
    final raw = j['byCategory'];
    if (raw is Map) {
      raw.forEach((k, v) {
        by[k.toString()] = double.tryParse(v.toString()) ?? 0;
      });
    }
    final list = <Expense>[];
    final ex = j['expenses'];
    if (ex is List) {
      for (final e in ex) {
        if (e is Map) list.add(Expense.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return MonthSummary(
      month: int.tryParse(j['month']?.toString() ?? '0') ?? 0,
      year: int.tryParse(j['year']?.toString() ?? '0') ?? 0,
      total: double.tryParse(j['total']?.toString() ?? '0') ?? 0,
      byCategory: by,
      expenses: list,
    );
  }
}

/// Default expense categories — matches web / API defaults.
const kExpenseCategories = <String>[
  'Ecommerce',
  'Grocery',
  'Food',
  'Travel',
  'Electronics',
  'Miscellaneous',
  'Other',
];

/// Payment methods for daily expenses.
const kPaidViaOptions = <String>[
  'UPI',
  'Card',
  'Cash',
  'Bank transfer',
  'Other',
];

String paidViaDetailLabel(String via) {
  switch (via) {
    case 'UPI':
      return 'UPI bank';
    case 'Card':
      return 'Card name';
    case 'Bank transfer':
      return 'Bank name';
    case 'Other':
      return 'Payment note';
    default:
      return 'Detail';
  }
}

String paidViaDetailHint(String via) {
  switch (via) {
    case 'UPI':
      return 'e.g. SBI, HDFC';
    case 'Card':
      return 'e.g. HDFC Millennia';
    case 'Bank transfer':
      return 'e.g. ICICI, Axis';
    case 'Other':
      return 'e.g. Wallet, voucher';
    default:
      return '';
  }
}

const kMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
