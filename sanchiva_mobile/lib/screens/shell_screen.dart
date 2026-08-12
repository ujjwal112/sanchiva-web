import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/finance_refresh.dart';
import '../core/notification_inbox.dart';
import '../core/profile_photo_state.dart';
import '../core/settings_state.dart';
import '../core/shell_nav.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../widgets/profile_avatar.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'loans_screen.dart';
import 'monetary_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'splits_screen.dart';

/// Post-login shell.
/// Bottom: Daily expense · Loans · [Home] · Monetary · Splits
/// Top-right: user profile.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const _brand = Color(0xFF5038F0);

  /// 0 Daily expense · 1 Loans · 2 Home · 3 Monetary · 4 Splits
  /// Driven by [ShellNav] so Home can jump tabs.
  int get _index => context.watch<ShellNav>().index;

  static const _pages = <Widget>[
    ExpensesScreen(),
    LoansScreen(),
    DashboardScreen(),
    MonetaryScreen(),
    SplitsScreen(),
  ];

  static const _titles = <String>[
    'Daily expense',
    'Loans & Credit',
    'Home',
    'Monetary',
    'Splits',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthState>();
      context.read<ProfilePhotoState>().preferGoogleIfUnset(
            hasGooglePhoto: auth.googlePhotoUrl != null,
          );
      // Bind inbox to this account, then fill history for current user only.
      final uid = auth.user?['id']?.toString();
      NotificationInboxState.instance?.setUser(uid).then((_) {
        NotificationService.instance.ensureInboxEntries();
      });
      final settings = context.read<SettingsState>();
      if (settings.notificationsEnabled) {
        NotificationService.instance.syncLoanEmiReminders();
      }
    });
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    // Rebuild all tabs immediately when display currency (or other prefs) change.
    final settings = context.watch<SettingsState>();
    final name = user?['name']?.toString() ?? user?['email']?.toString() ?? 'Guest';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkDark : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : AppColors.muted;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    // Key forces money UIs to rebuild with the new symbol without needing a tab switch.
    final currencyKey = settings.displayCurrencyCode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // Top bar + profile
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titles[_index],
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          if (_index == 2)
                            Text(
                              'Hi, ${name.split(' ').first}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Notifications (left of profile) — red dot only, no count
                    Consumer<NotificationInboxState>(
                      builder: (context, inbox, _) {
                        final hasUnread = inbox.unreadCount > 0;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openNotifications,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    Icons.notifications_rounded,
                                    color: _brand,
                                    size: 26,
                                  ),
                                  if (hasUnread)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: AppColors.danger,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).scaffoldBackgroundColor,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openProfile,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _brand.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: const ProfileAvatar(radius: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    KeyedSubtree(
                      key: ValueKey('shell_tab_${i}_$currencyKey'),
                      child: _pages[i],
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: _index,
          brand: _brand,
          onSelect: (i) {
            context.read<ShellNav>().go(i);
            // Home / Monetary — refresh live finance snapshot.
            if (i == 2 || i == 3) {
              context.read<FinanceRefresh>().bump();
            }
          },
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.brand,
    required this.onSelect,
  });

  final int index;
  final Color brand;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.cardDark : Colors.white;
    final barBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0EEFF);
    final inactive = isDark ? const Color(0xFF7A76A8) : const Color(0xFFB8B4E8);

    return SafeArea(
      top: false,
      child: Padding(
        // Floating bar — rounded capsule like the reference
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: brand.withValues(alpha: isDark ? 0.2 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: barBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Left: Expense, Loans
                Expanded(
                  child: _NavIcon(
                    icon: Icons.receipt_long_rounded,
                    active: index == 0,
                    brand: brand,
                    inactive: inactive,
                    onTap: () => onSelect(0),
                  ),
                ),
                Expanded(
                  child: _NavIcon(
                    icon: Icons.account_balance_rounded,
                    active: index == 1,
                    brand: brand,
                    inactive: inactive,
                    onTap: () => onSelect(1),
                  ),
                ),
                Expanded(
                  child: _NavIcon(
                    icon: Icons.home_rounded,
                    active: index == 2,
                    brand: brand,
                    inactive: inactive,
                    onTap: () => onSelect(2),
                    prominent: true,
                  ),
                ),
                Expanded(
                  child: _NavIcon(
                    icon: Icons.currency_exchange_rounded,
                    active: index == 3,
                    brand: brand,
                    inactive: inactive,
                    onTap: () => onSelect(3),
                  ),
                ),
                Expanded(
                  child: _NavIcon(
                    icon: Icons.call_split_rounded,
                    active: index == 4,
                    brand: brand,
                    inactive: inactive,
                    onTap: () => onSelect(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only nav item — solid purple when active, soft lavender when idle.
class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.active,
    required this.brand,
    required this.inactive,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final bool active;
  final Color brand;
  final Color inactive;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: prominent ? 46 : 42,
            height: prominent ? 46 : 42,
            decoration: BoxDecoration(
              color: active ? brand.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: prominent ? 28 : 24,
              color: active ? brand : inactive,
            ),
          ),
        ),
      ),
    );
  }
}
