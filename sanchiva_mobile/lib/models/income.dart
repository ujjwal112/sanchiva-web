/// Income source row from `/monetary/income`.
class IncomeSource {
  IncomeSource({
    required this.id,
    required this.sourceName,
    required this.amount,
    required this.month,
    required this.year,
  });

  final int id;
  final String sourceName;
  final double amount;
  final int month;
  final int year;

  factory IncomeSource.fromJson(Map<String, dynamic> j) {
    return IncomeSource(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      sourceName: j['source_name']?.toString() ?? '',
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
      month: int.tryParse(j['month']?.toString() ?? '') ?? DateTime.now().month,
      year: int.tryParse(j['year']?.toString() ?? '') ?? DateTime.now().year,
    );
  }
}

/// Summary from `/monetary/income/summary?month=&year=`.
class IncomeSummary {
  IncomeSummary({
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalSpend,
    required this.balance,
    required this.bySource,
    required this.incomes,
  });

  final int month;
  final int year;
  final double totalIncome;
  final double totalSpend;
  final double balance;
  final List<IncomeBySource> bySource;
  final List<IncomeSource> incomes;

  factory IncomeSummary.fromJson(Map<String, dynamic> j) {
    final by = <IncomeBySource>[];
    final rawBy = j['bySource'];
    if (rawBy is List) {
      for (final e in rawBy) {
        if (e is Map) {
          by.add(IncomeBySource.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final incomes = <IncomeSource>[];
    final rawIn = j['incomes'];
    if (rawIn is List) {
      for (final e in rawIn) {
        if (e is Map) {
          incomes.add(IncomeSource.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return IncomeSummary(
      month: int.tryParse(j['month']?.toString() ?? '') ?? DateTime.now().month,
      year: int.tryParse(j['year']?.toString() ?? '') ?? DateTime.now().year,
      totalIncome: double.tryParse(j['totalIncome']?.toString() ?? '0') ?? 0,
      totalSpend: double.tryParse(j['totalSpend']?.toString() ?? '0') ?? 0,
      balance: double.tryParse(j['balance']?.toString() ?? '0') ?? 0,
      bySource: by,
      incomes: incomes,
    );
  }
}

class IncomeBySource {
  IncomeBySource({required this.name, required this.amount});

  final String name;
  final double amount;

  factory IncomeBySource.fromJson(Map<String, dynamic> j) {
    return IncomeBySource(
      name: j['name']?.toString() ?? '',
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
    );
  }
}
