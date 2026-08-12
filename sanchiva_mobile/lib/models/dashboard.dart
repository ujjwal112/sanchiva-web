/// Response from GET /dashboard.
class DashboardData {
  DashboardData({
    required this.month,
    required this.year,
    required this.kpis,
    required this.categories,
    required this.expenseTrend,
    required this.loanMonth,
    required this.assetsByType,
    required this.moneyGivenByPerson,
  });

  final int month;
  final int year;
  final DashboardKpis kpis;
  final List<NamedAmount> categories;
  final List<TrendPoint> expenseTrend;
  final LoanMonthSnap loanMonth;
  final List<NamedAmount> assetsByType;
  final List<NamedAmount> moneyGivenByPerson;

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final kpisRaw = j['kpis'] is Map ? Map<String, dynamic>.from(j['kpis'] as Map) : <String, dynamic>{};
    final card = j['monthExpenseCard'] is Map
        ? Map<String, dynamic>.from(j['monthExpenseCard'] as Map)
        : <String, dynamic>{};
    final cats = <NamedAmount>[];
    final byCat = card['byCategory'];
    if (byCat is List) {
      for (final e in byCat) {
        if (e is Map) cats.add(NamedAmount.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    cats.sort((a, b) => b.amount.compareTo(a.amount));

    final trend = <TrendPoint>[];
    final rawTrend = j['expenseTrend'];
    if (rawTrend is List) {
      for (final e in rawTrend) {
        if (e is Map) trend.add(TrendPoint.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    final loanCard = j['loanMonthCard'] is Map
        ? Map<String, dynamic>.from(j['loanMonthCard'] as Map)
        : <String, dynamic>{};

    final assets = <NamedAmount>[];
    final rawAssets = j['assetsByType'];
    if (rawAssets is List) {
      for (final e in rawAssets) {
        if (e is Map) assets.add(NamedAmount.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    assets.sort((a, b) => b.amount.compareTo(a.amount));

    final given = <NamedAmount>[];
    final rawGiven = j['moneyGivenByPerson'];
    if (rawGiven is List) {
      for (final e in rawGiven) {
        if (e is Map) given.add(NamedAmount.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    given.sort((a, b) => b.amount.compareTo(a.amount));

    return DashboardData(
      month: int.tryParse('${j['month']}') ?? DateTime.now().month,
      year: int.tryParse('${j['year']}') ?? DateTime.now().year,
      kpis: DashboardKpis.fromJson(kpisRaw),
      categories: cats,
      expenseTrend: trend,
      loanMonth: LoanMonthSnap.fromJson(loanCard),
      assetsByType: assets,
      moneyGivenByPerson: given,
    );
  }
}

class DashboardKpis {
  DashboardKpis({
    required this.monthExpenseTotal,
    required this.monthIncome,
    required this.monthBalance,
    required this.monthlyEmi,
    required this.activeLoans,
    required this.closedLoans,
    required this.assetsTotal,
    required this.moneyGivenTotal,
    required this.ccSpendMonth,
  });

  final double monthExpenseTotal;
  final double monthIncome;
  final double monthBalance;
  final double monthlyEmi;
  final int activeLoans;
  final int closedLoans;
  final double assetsTotal;
  final double moneyGivenTotal;
  final double ccSpendMonth;

  factory DashboardKpis.fromJson(Map<String, dynamic> j) {
    return DashboardKpis(
      monthExpenseTotal: double.tryParse('${j['monthExpenseTotal']}') ?? 0,
      monthIncome: double.tryParse('${j['monthIncome']}') ?? 0,
      monthBalance: double.tryParse('${j['monthBalance']}') ?? 0,
      monthlyEmi: double.tryParse('${j['monthlyEmi']}') ?? 0,
      activeLoans: int.tryParse('${j['activeLoans']}') ?? 0,
      closedLoans: int.tryParse('${j['closedLoans']}') ?? 0,
      assetsTotal: double.tryParse('${j['assetsTotal']}') ?? 0,
      moneyGivenTotal: double.tryParse('${j['moneyGivenTotal']}') ?? 0,
      ccSpendMonth: double.tryParse('${j['ccSpendMonth']}') ?? 0,
    );
  }
}

class NamedAmount {
  NamedAmount({required this.name, required this.amount});
  final String name;
  final double amount;

  factory NamedAmount.fromJson(Map<String, dynamic> j) {
    return NamedAmount(
      name: j['name']?.toString() ?? '',
      amount: double.tryParse('${j['amount']}') ?? 0,
    );
  }
}

class TrendPoint {
  TrendPoint({required this.label, required this.total});
  final String label;
  final double total;

  factory TrendPoint.fromJson(Map<String, dynamic> j) {
    return TrendPoint(
      label: j['label']?.toString() ?? '',
      total: double.tryParse('${j['total']}') ?? 0,
    );
  }
}

class LoanMonthSnap {
  LoanMonthSnap({
    required this.totalLoanAmount,
    required this.deductedThisMonth,
    required this.remainingToDeduct,
  });

  final double totalLoanAmount;
  final double deductedThisMonth;
  final double remainingToDeduct;

  factory LoanMonthSnap.fromJson(Map<String, dynamic> j) {
    return LoanMonthSnap(
      totalLoanAmount: double.tryParse('${j['totalLoanAmount']}') ?? 0,
      deductedThisMonth: double.tryParse('${j['deductedThisMonth']}') ?? 0,
      remainingToDeduct: double.tryParse('${j['remainingToDeduct']}') ?? 0,
    );
  }
}
