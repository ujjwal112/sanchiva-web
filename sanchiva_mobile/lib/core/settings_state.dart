import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'display_currency.dart';

/// Persisted app preferences: theme, biometric lock, onboarding, display currency, notifications.
class SettingsState extends ChangeNotifier {
  static const _kTheme = 'sanchiva.theme_mode'; // light | dark
  static const _kBiometric = 'sanchiva.biometric_enabled';
  static const _kOnboarding = 'sanchiva.onboarding_completed';
  /// Same key as web localStorage `sanchiva.displayCurrency`
  static const _kDisplayCurrency = 'sanchiva.displayCurrency';
  /// General app notifications (panel + lock screen).
  static const _kNotifications = 'sanchiva.notifications_enabled';
  /// Legacy EMI-only key — read once if general key missing.
  static const _kLegacyEmiNotifications = 'sanchiva.emi_notifications_enabled';

  bool loading = true;
  ThemeMode themeMode = ThemeMode.light;
  bool biometricEnabled = false;
  bool onboardingCompleted = false;
  /// User opted in to Sanchiva notifications (requires OS permission).
  bool notificationsEnabled = false;
  /// App-wide money symbol (not live FX / live metals).
  String displayCurrencyCode = 'INR';

  DisplayCurrencyMeta get displayCurrency => getCurrencyMeta(displayCurrencyCode);

  SettingsState() {
    _load();
  }

  Future<void> _load() async {
    loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_kTheme) ?? 'light';
      themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      biometricEnabled = prefs.getBool(_kBiometric) ?? false;
      onboardingCompleted = prefs.getBool(_kOnboarding) ?? false;
      if (prefs.containsKey(_kNotifications)) {
        notificationsEnabled = prefs.getBool(_kNotifications) ?? false;
      } else {
        notificationsEnabled = prefs.getBool(_kLegacyEmiNotifications) ?? false;
      }
      final cur = prefs.getString(_kDisplayCurrency) ?? 'INR';
      displayCurrencyCode = getCurrencyMeta(cur).code;
      setActiveDisplayCurrency(displayCurrencyCode);
    } catch (_) {
      // keep defaults
      setActiveDisplayCurrency(displayCurrencyCode);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometric, enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, enabled);
    await prefs.setBool(_kLegacyEmiNotifications, enabled);
  }

  Future<void> setDisplayCurrency(String code) async {
    final meta = getCurrencyMeta(code);
    displayCurrencyCode = meta.code;
    setActiveDisplayCurrency(meta.code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDisplayCurrency, meta.code);
  }

  Future<void> completeOnboarding() async {
    if (onboardingCompleted) return;
    onboardingCompleted = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
  }
}
