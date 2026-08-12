import '../core/api_client.dart';
import '../models/asset.dart';

class AssetService {
  AssetService._();
  static final AssetService instance = AssetService._();

  final _api = ApiClient.instance;

  Future<List<Asset>> list() async {
    final raw = await _api.getList('/monetary/assets');
    return raw
        .whereType<Map>()
        .map((e) => Asset.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AssetSummary> summary() async {
    final data = await _api.get('/monetary/assets/summary');
    return AssetSummary.fromJson(data);
  }

  Future<List<String>> categories() async {
    try {
      final data = await _api.get('/categories/asset');
      final list = data['categories'];
      if (list is List) {
        final cats = list.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        if (cats.isNotEmpty) return cats;
      }
    } catch (_) {}
    return List<String>.from(kDefaultAssetTypes);
  }

  Future<Asset> create({
    required String assetType,
    required double amount,
    String notes = '',
    String? customType,
  }) async {
    final body = <String, dynamic>{
      'asset_type': assetType,
      'amount': amount,
      'notes': notes.isEmpty ? null : notes,
    };
    if (assetType == 'Other' && customType != null && customType.trim().isNotEmpty) {
      body['custom_type'] = customType.trim();
    }
    final data = await _api.post('/monetary/assets', body);
    return Asset.fromJson(data);
  }

  Future<Asset> update(
    int id, {
    required String assetType,
    required double amount,
    String notes = '',
    String? customType,
  }) async {
    final body = <String, dynamic>{
      'asset_type': assetType,
      'amount': amount,
      'notes': notes.isEmpty ? null : notes,
    };
    if (assetType == 'Other' && customType != null && customType.trim().isNotEmpty) {
      body['custom_type'] = customType.trim();
    }
    final data = await _api.put('/monetary/assets/$id', body);
    return Asset.fromJson(data);
  }

  Future<void> delete(int id) async {
    await _api.delete('/monetary/assets/$id');
  }
}
