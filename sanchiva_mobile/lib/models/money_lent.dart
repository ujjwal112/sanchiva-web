class MoneyLent {
  MoneyLent({
    required this.id,
    required this.personName,
    required this.givenDate,
    required this.amount,
    this.notes = '',
  });

  final int id;
  final String personName;
  final DateTime givenDate;
  final double amount;
  final String notes;

  factory MoneyLent.fromJson(Map<String, dynamic> j) {
    DateTime date;
    final raw = j['given_date']?.toString() ?? '';
    date = DateTime.tryParse(raw.length >= 10 ? raw.substring(0, 10) : raw) ??
        DateTime.tryParse(raw) ??
        DateTime.now();
    return MoneyLent(
      id: int.tryParse('${j['id']}') ?? 0,
      personName: j['person_name']?.toString() ?? '',
      givenDate: date,
      amount: double.tryParse('${j['amount']}') ?? 0,
      notes: j['notes']?.toString() ?? '',
    );
  }
}

class MoneyLentSummary {
  MoneyLentSummary({
    required this.total,
    required this.byPerson,
    required this.count,
  });

  final double total;
  final Map<String, double> byPerson;
  final int count;

  factory MoneyLentSummary.fromJson(Map<String, dynamic> j) {
    final byPerson = <String, double>{};
    final raw = j['byPerson'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final name = e['name']?.toString() ?? '';
          if (name.isEmpty) continue;
          byPerson[name] = double.tryParse('${e['amount']}') ?? 0;
        }
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        byPerson[k.toString()] = double.tryParse('$v') ?? 0;
      });
    }
    return MoneyLentSummary(
      total: double.tryParse('${j['total']}') ?? 0,
      byPerson: byPerson,
      count: int.tryParse('${j['count']}') ?? byPerson.length,
    );
  }

  static MoneyLentSummary empty() =>
      MoneyLentSummary(total: 0, byPerson: {}, count: 0);
}
