import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/navigation.dart';
import '../core/settings_state.dart';
import '../core/shell_nav.dart';
import 'auth_choice_screen.dart';
import 'biometric_lock_screen.dart';
import 'onboarding_screen.dart';
import 'shell_screen.dart';
import 'splash_screen.dart';

/// Startup routing:
/// Splash → (onboarding once) → Auth choice | Home + biometric when enabled.
///
/// App lock shows when:
/// - cold start with a saved session + app lock ON, or
/// - returning from background with app lock ON.
/// It does **not** show right after an interactive login (user just signed in).
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  static const _brand = Color(0xFF5038F0);

  bool _splashDone = false;

  /// false until user passes lock (or just logged in interactively).
  bool _biometricUnlocked = false;

  bool? _wasAuthenticated;

  DateTime? _pausedAt;

  /// Only the first session restore blocks routing. Login/register must not
  /// unmount the whole app (that looked like a stuck loading screen).
  bool _coldStartDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = context.read<SettingsState>();
    final auth = context.read<AuthState>();

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (settings.biometricEnabled && auth.isAuthenticated && _biometricUnlocked) {
        _pausedAt = DateTime.now();
      }
    }

    if (state == AppLifecycleState.resumed) {
      if (settings.biometricEnabled &&
          auth.isAuthenticated &&
          _biometricUnlocked &&
          _pausedAt != null) {
        final away = DateTime.now().difference(_pausedAt!);
        if (away.inMilliseconds > 400) {
          setState(() => _biometricUnlocked = false);
        }
      }
      _pausedAt = null;
    }
  }

  void _onSplashDone() {
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  void _onBiometricUnlocked() {
    if (!mounted) return;
    setState(() => _biometricUnlocked = true);
  }

  void _syncAuthFlags(AuthState auth) {
    // Ignore mid-bootstrap: user is still null then flips to logged-in.
    // That false→true must NOT count as "just logged in" (or lock is skipped forever).
    if (auth.loading && !_coldStartDone) return;

    // Logout
    if (_wasAuthenticated == true && !auth.isAuthenticated) {
      _biometricUnlocked = false;
      _splashDone = true;
      // Reset bottom nav so next session opens Home
      try {
        context.read<ShellNav>().resetToHome();
      } catch (_) {}
      WidgetsBinding.instance.addPostFrameCallback((_) => clearNavStack());
    }

    // Interactive login only (already past splash, was logged out, now logged in)
    if (_wasAuthenticated == false && auth.isAuthenticated && _splashDone) {
      _biometricUnlocked = true;
      // Always land on Home after a fresh sign-in
      try {
        context.read<ShellNav>().resetToHome();
      } catch (_) {}
      WidgetsBinding.instance.addPostFrameCallback((_) => clearNavStack());
    }

    // Cold start with restored session: leave _biometricUnlocked == false
    // so lock shows after splash when settings.biometricEnabled.

    _wasAuthenticated = auth.isAuthenticated;
  }

  Widget _holdWhileBootstrapping() {
    return const Scaffold(
      backgroundColor: _brand,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final settings = context.watch<SettingsState>();

    final bootstrapping = auth.loading || settings.loading;

    // Finish cold-start once session + settings prefs have resolved once.
    if (!_coldStartDone && !bootstrapping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_coldStartDone) {
          setState(() => _coldStartDone = true);
        }
      });
    }

    _syncAuthFlags(auth);

    // Cold start: wait for restore (with timeouts) + splash animation.
    if (!_coldStartDone) {
      if (!_splashDone) {
        return SplashScreen(onFinished: _onSplashDone);
      }
      // Splash finished but prefs/session still loading — short branded hold.
      if (bootstrapping) {
        return _holdWhileBootstrapping();
      }
      // One frame before _coldStartDone flips true.
      return _holdWhileBootstrapping();
    }

    if (!_splashDone) {
      return SplashScreen(onFinished: _onSplashDone);
    }

    if (auth.isAuthenticated) {
      if (settings.biometricEnabled && !_biometricUnlocked) {
        return BiometricLockScreen(onUnlocked: _onBiometricUnlocked);
      }
      return const ShellScreen();
    }

    if (!settings.onboardingCompleted) {
      return const OnboardingScreen();
    }

    return const AuthChoiceScreen();
  }
}
