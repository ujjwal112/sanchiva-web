import 'package:flutter/foundation.dart';

/// Bottom-nav index + optional deep-link into a section / sub-tab (Entry·Charts·Data).
///
/// Sub-tab: `0` Entry · `1` Charts · `2` Data
class ShellNav extends ChangeNotifier {
  int index = 2; // Home by default

  /// Bumps whenever a deep-link is requested (even to the same tab).
  int deepLinkToken = 0;

  /// Monetary area: `currency` | `metals` | `income` | `assets` | `lent`
  String? pendingMonetaryArea;

  /// Loans area: `loans` | `spends` | `emis`
  String? pendingLoansArea;

  /// When true, [pendingSubTab] should be applied by the target screen.
  bool pendingApplySubTab = false;

  /// Entry / Charts / Data (default Data for home KPI taps).
  int pendingSubTab = 2;

  void go(int i) {
    if (i == index &&
        pendingMonetaryArea == null &&
        pendingLoansArea == null &&
        !pendingApplySubTab) {
      return;
    }
    index = i;
    // Plain bottom-nav: don't force a sub-tab on nested screens.
    pendingMonetaryArea = null;
    pendingLoansArea = null;
    pendingApplySubTab = false;
    pendingSubTab = 0;
    notifyListeners();
  }

  /// After logout / fresh login always open Home (tab 2).
  void resetToHome() {
    index = 2;
    pendingMonetaryArea = null;
    pendingLoansArea = null;
    pendingApplySubTab = false;
    pendingSubTab = 0;
    deepLinkToken++;
    notifyListeners();
  }

  /// Home KPI / quick action: open a tab and optionally a nested section + sub-tab.
  void open({
    required int tab,
    String? monetaryArea,
    String? loansArea,
    int subTab = 2,
  }) {
    index = tab;
    pendingMonetaryArea = monetaryArea;
    pendingLoansArea = loansArea;
    pendingSubTab = subTab.clamp(0, 2);
    pendingApplySubTab = true;
    deepLinkToken++;
    notifyListeners();
  }

  void clearMonetaryDeepLink() {
    pendingMonetaryArea = null;
  }

  void clearLoansDeepLink() {
    pendingLoansArea = null;
  }

  void clearSubTabDeepLink() {
    pendingApplySubTab = false;
  }
}
