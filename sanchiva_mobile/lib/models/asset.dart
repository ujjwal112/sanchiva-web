class Asset {
  Asset({
    required this.id,
    required this.assetType,
    required this.amount,
    this.notes = '',
    this.createdAt,
  });

  final int id;
  final String assetType;
  final double amount;
  final String notes;
  final DateTime? createdAt;

  factory Asset.fromJson(Map<String, dynamic> j) {
    return Asset(
      id: int.tryParse('${j['id']}') ?? 0,
      assetType: j['asset_type']?.toString() ?? '',
      amount: double.tryParse('${j['amount']}') ?? 0,
      notes: j['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
    );
  }
}

class AssetSummary {
  AssetSummary({
    required this.total,
    required this.byType,
    required this.count,
  });

  final double total;
  /// name → amount
  final Map<String, double> byType;
  final int count;

  factory AssetSummary.fromJson(Map<String, dynamic> j) {
    final byType = <String, double>{};
    final raw = j['byType'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final name = e['name']?.toString() ?? '';
          if (name.isEmpty) continue;
          byType[name] = double.tryParse('${e['amount']}') ?? 0;
        }
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        byType[k.toString()] = double.tryParse('$v') ?? 0;
      });
    }
    return AssetSummary(
      total: double.tryParse('${j['total']}') ?? 0,
      byType: byType,
      count: int.tryParse('${j['count']}') ?? byType.length,
    );
  }

  static AssetSummary empty() => AssetSummary(total: 0, byType: {}, count: 0);
}

/// Default asset types (same as web /categories/asset).
const kDefaultAssetTypes = <String>[
  'FD',
  'RD',
  'Mutual Funds',
  'Stocks',
  'Crypto',
  'Gold',
  'Silver',
  'Saving Account',
  'Other',
];
