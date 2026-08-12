import '../core/api_client.dart';
import '../models/dashboard.dart';

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  final _api = ApiClient.instance;

  Future<DashboardData> fetch() async {
    final data = await _api.get('/dashboard');
    return DashboardData.fromJson(data);
  }
}
