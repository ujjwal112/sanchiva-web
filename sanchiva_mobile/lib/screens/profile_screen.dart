import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/display_currency.dart';
import '../core/navigation.dart';
import '../core/settings_state.dart';
import '../core/shell_nav.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snack.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/sanchiva_logo.dart';
import 'profile_photo_screen.dart';

/// Profile: user info, about, theme, biometric lock, EMI alerts, logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _brand = Color(0xFF5038F0);
  final _auth = LocalAuthentication();
  bool _bioBusy = false;
  bool _notifBusy = false;

  void _openPhotoEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePhotoScreen()),
    );
  }

  Future<void> _setBiometric(bool enable) async {
    final settings = context.read<SettingsState>();
    if (!enable) {
      await settings.setBiometricEnabled(false);
      return;
    }

    setState(() => _bioBusy = true);
    try {
      final canBio = await _auth.canCheckBiometrics;
      final deviceOk = await _auth.isDeviceSupported();
      if (!canBio && !deviceOk) {
        if (!mounted) return;
        AppSnack.warning(
          context,
          'This device has no biometrics or screen lock set up. '
          'Add Face unlock, fingerprint, or PIN in phone Settings.',
        );
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Confirm to enable Sanchiva app lock',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: false,
      );
      if (!ok) {
        if (!mounted) return;
        AppSnack.info(context, 'Not confirmed — app lock stays off.');
        return;
      }
      await settings.setBiometricEnabled(true);
      if (!mounted) return;
      AppSnack.success(
        context,
        'App lock on. You’ll be asked for face, fingerprint, or PIN when opening the app.',
        icon: Icons.lock_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, 'Could not enable app lock: $e');
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _setNotifications(bool enable) async {
    final settings = context.read<SettingsState>();
    final svc = NotificationService.instance;

    if (!enable) {
      // Flip UI immediately — cancel work runs in background.
      await settings.setNotificationsEnabled(false);
      await svc.setEnabledFlag(false);
      if (mounted) AppSnack.info(context, 'Disabled');
      // ignore: unawaited_futures
      svc.cancelAll();
      return;
    }

    setState(() => _notifBusy = true);
    try {
      final granted = await svc.requestPermissions();
      if (!granted) {
        if (!mounted) return;
        AppSnack.warning(context, 'Allow notifications in system Settings');
        return;
      }
      await settings.setNotificationsEnabled(true);
      await svc.setEnabledFlag(true);
      if (!mounted) return;
      AppSnack.success(context, 'Enabled', icon: Icons.notifications_active_rounded);
      // Push sample of every alert type for testing, then schedule real ones.
      // ignore: unawaited_futures
      () async {
        try {
          await svc.pushAllSampleNotifications();
          await svc.syncLoanEmiReminders();
        } catch (e) {
          debugPrint('notif background: $e');
        }
      }();
    } catch (e) {
      if (mounted) {
        await settings.setNotificationsEnabled(false);
        await svc.setEnabledFlag(false);
        AppSnack.error(context, 'Could not enable');
      }
    } finally {
      if (mounted) setState(() => _notifBusy = false);
    }
  }

  void _openAbout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkDark : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : AppColors.muted;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      showDragHandle: false,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bodyStyle = GoogleFonts.inter(
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w500,
          color: ink,
        );
        final sectionStyle = GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: _brand,
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: muted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const SanchivaLogo(size: 36),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About Sanchiva',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            Text(
                              'Version 1.0.0',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sanchiva', style: sectionStyle),
                          const SizedBox(height: 8),
                          Text(
                            'Sanchiva helps you track personal money in one place. '
                            'See your balance on Home, log daily spends, manage loans and card EMIs, '
                            'follow salary and assets, and note money you lent. '
                            'Share group expenses with friends using Splits, with balances, settlements and Excel export.',
                            style: bodyStyle,
                          ),
                          const SizedBox(height: 20),
                          Text('Inside the app', style: sectionStyle),
                          const SizedBox(height: 12),
                          _aboutFeatureRow(
                            icon: Icons.home_rounded,
                            title: 'Home',
                            detail: 'Balance, EMI summary, spending by category and trends',
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          ),
                          _aboutFeatureRow(
                            icon: Icons.receipt_long_rounded,
                            title: 'Daily expense',
                            detail: 'Add spends, view charts and download CSV or PDF',
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          ),
                          _aboutFeatureRow(
                            icon: Icons.account_balance_rounded,
                            title: 'Loans and card EMI',
                            detail: 'Track repayments and get deduction day alerts',
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          ),
                          _aboutFeatureRow(
                            icon: Icons.currency_exchange_rounded,
                            title: 'Monetary',
                            detail: 'Live rates, salary, assets and money lent',
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          ),
                          _aboutFeatureRow(
                            icon: Icons.call_split_rounded,
                            title: 'Splits',
                            detail:
                                'Create groups, split expenses equally, track who owes whom, '
                                'record settlements and download Excel with expenses, balance and settled sheets',
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          ),
                          _aboutFeatureRow(
                            icon: Icons.notifications_rounded,
                            title: 'Alerts and settings',
                            detail: 'Inbox, display currency, theme and app lock',
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                            isLast: true,
                          ),
                          const SizedBox(height: 20),
                          Text('Built by', style: sectionStyle),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.softPurpleOf(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderOf(context)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [_brand, Color(0xFF7A40F8)],
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'UG',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ujjwal Gupta',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: ink,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Creator of Sanchiva. Idea, design and full development.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _aboutFeatureRow({
    required IconData icon,
    required String title,
    required String detail,
    required Color ink,
    required Color muted,
    required bool isDark,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: isDark ? 0.22 : 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: _brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDisplayCurrency() async {
    final settings = context.read<SettingsState>();
    final selected = settings.displayCurrencyCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkDark : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : AppColors.muted;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Display currency',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: ink),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      itemCount: kDisplayCurrencies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = kDisplayCurrencies[i];
                        final sel = c.code == selected;
                        return Material(
                          color: sel
                              ? _brand.withValues(alpha: isDark ? 0.22 : 0.12)
                              : AppColors.softPurpleOf(ctx),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, c.code),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _brand.withValues(alpha: isDark ? 0.28 : 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      c.symbol,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w900,
                                        fontSize: c.symbol.length > 2 ? 12 : 16,
                                        color: _brand,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.code,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: ink,
                                          ),
                                        ),
                                        Text(
                                          c.label,
                                          style: GoogleFonts.inter(fontSize: 12, color: muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (sel)
                                    const Icon(Icons.check_circle_rounded, color: _brand, size: 22)
                                  else
                                    Icon(Icons.chevron_right_rounded, color: muted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;
    if (picked == selected) return;
    await settings.setDisplayCurrency(picked);
    if (!mounted) return;
    final meta = getCurrencyMeta(picked);
    AppSnack.success(
      context,
      'Display currency set to ${meta.code} (${meta.symbol})',
      icon: Icons.payments_rounded,
    );
  }

  Future<void> _logout() async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to use Sanchiva on this device.',
      confirmLabel: 'Log out',
      icon: Icons.logout_rounded,
      tone: AppConfirmTone.danger,
    );
    if (!ok || !mounted) return;
    // Next login should land on Home, not the tab we left on
    context.read<ShellNav>().resetToHome();
    await context.read<AuthState>().logout();
    // Remove Profile (and any other) routes so Welcome shows immediately
    clearNavStack();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final settings = context.watch<SettingsState>();
    final user = auth.user;
    final name = user?['name']?.toString() ?? 'Guest';
    final email = user?['email']?.toString() ?? '';
    final isGuest = auth.isGuest ||
        (email.isEmpty && (name.toLowerCase().contains('guest') || name == 'Guest'));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final ink = isDark ? AppColors.inkDark : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : AppColors.muted;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // —— User section ——
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: _brand.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Photo + edit pencil
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _brand.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: const ProfileAvatar(radius: 34),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: _brand,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _openPhotoEditor,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (isGuest) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Guest',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _brand,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _SectionLabel(text: 'Preferences', color: muted),
          const SizedBox(height: 8),
          _SettingsCard(
            cardColor: cardColor,
            isDark: isDark,
            children: [
              // System-wide display currency (does not affect live FX / metals)
              ListTile(
                leading: Icon(Icons.payments_rounded, color: _brand),
                title: Text(
                  'Display currency',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                ),
                subtitle: Text(
                  '${settings.displayCurrency.code} · ${settings.displayCurrency.symbol} ${settings.displayCurrency.label}',
                  style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w500),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: muted),
                onTap: _pickDisplayCurrency,
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              // Dark theme — single on/off
              SwitchListTile(
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (on) {
                  settings.setThemeMode(on ? ThemeMode.dark : ThemeMode.light);
                },
                activeThumbColor: Colors.white,
                activeTrackColor: _brand,
                secondary: Icon(
                  settings.themeMode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: _brand,
                ),
                title: Text(
                  'Dark theme',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                ),
                subtitle: Text(
                  settings.themeMode == ThemeMode.dark ? 'On' : 'Off',
                  style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w500),
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              // App lock — single on/off
              SwitchListTile(
                value: settings.biometricEnabled,
                onChanged: _bioBusy
                    ? null
                    : (on) {
                        _setBiometric(on);
                      },
                activeThumbColor: Colors.white,
                activeTrackColor: _brand,
                secondary: _bioBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        settings.biometricEnabled
                            ? Icons.fingerprint_rounded
                            : Icons.lock_open_rounded,
                        color: _brand,
                      ),
                title: Text(
                  'App lock',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                ),
                subtitle: Text(
                  settings.biometricEnabled
                      ? 'On · Face, fingerprint or PIN'
                      : 'Off · Open without lock',
                  style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w500),
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              // General notifications — OS permission + panel / lock screen
              SwitchListTile(
                value: settings.notificationsEnabled,
                onChanged: _notifBusy
                    ? null
                    : (on) {
                        _setNotifications(on);
                      },
                activeThumbColor: Colors.white,
                activeTrackColor: _brand,
                secondary: _notifBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        settings.notificationsEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color: _brand,
                      ),
                title: Text(
                  'Notifications',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                ),
                subtitle: Text(
                  settings.notificationsEnabled ? 'Enabled' : 'Disabled',
                  style: GoogleFonts.inter(fontSize: 12, color: muted, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _SectionLabel(text: 'App', color: muted),
          const SizedBox(height: 8),
          _SettingsCard(
            cardColor: cardColor,
            isDark: isDark,
            children: [
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: _brand),
                title: Text(
                  'About',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink),
                ),
                subtitle: Text(
                  'Version & description',
                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: muted),
                onTap: _openAbout,
              ),
            ],
          ),

          const SizedBox(height: 28),
          // Log out — soft danger card (not a plain outline button)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _logout,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: isDark
                        ? [
                            const Color(0xFF3A1A1A),
                            const Color(0xFF2A1518),
                          ]
                        : [
                            const Color(0xFFFFF1F2),
                            const Color(0xFFFFE4E6),
                          ],
                  ),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: isDark ? 0.45 : 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: isDark ? 0.18 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: isDark ? 0.28 : 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.danger,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log out',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sign out of this device',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFFE8A0A8)
                                    : const Color(0xFFBE123C).withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: AppColors.danger.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.cardColor,
    required this.isDark,
    required this.children,
  });

  final Color cardColor;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Column(children: children),
      ),
    );
  }
}
