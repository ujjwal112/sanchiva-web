import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/auth_state.dart';
import 'core/finance_refresh.dart';
import 'core/navigation.dart';
import 'core/notification_inbox.dart';
import 'core/profile_photo_state.dart';
import 'core/settings_state.dart';
import 'core/shell_nav.dart';
import 'core/theme.dart';
import 'screens/app_gate.dart';
import 'services/notification_service.dart';

/// Splash → (onboarding once) → login | home + biometric lock + profile.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  // General local notifications (panel + lock screen when user enables).
  try {
    await NotificationService.instance.init();
  } catch (_) {}
  runApp(const SanchivaApp());
}

class SanchivaApp extends StatelessWidget {
  const SanchivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Inbox first so AuthState bootstrap can bind user storage.
        ChangeNotifierProvider(create: (_) => NotificationInboxState()),
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => SettingsState()),
        ChangeNotifierProvider(create: (_) => ProfilePhotoState()),
        ChangeNotifierProvider(create: (_) => FinanceRefresh()),
        ChangeNotifierProvider(create: (_) => ShellNav()),
      ],
      child: Consumer2<AuthState, SettingsState>(
        builder: (context, auth, settings, _) {
          return MaterialApp(
            navigatorKey: sanchivaNavKey,
            title: 'Sanchiva',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: const AppGate(),
          );
        },
      ),
    );
  }
}
