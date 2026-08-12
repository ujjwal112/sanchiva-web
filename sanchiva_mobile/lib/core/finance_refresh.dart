import 'package:flutter/foundation.dart';

/// Lightweight bus so Salary / Income can refresh the moment expenses or
/// loans / card EMIs change (no pull-to-refresh required).
class FinanceRefresh extends ChangeNotifier {
  int _token = 0;
  int get token => _token;

  void bump() {
    _token++;
    notifyListeners();
  }
}
