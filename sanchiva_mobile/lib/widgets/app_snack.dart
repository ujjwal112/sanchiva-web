import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/navigation.dart';
import '../core/theme.dart';

enum AppSnackKind { success, error, info, warning }

/// Floating, rounded toast that matches Sanchiva light/dark theme.
class AppSnack {
  AppSnack._();

  /// Resolve a live [ScaffoldMessengerState] from the given context, root
  /// navigator, or the app [sanchivaNavKey] — never from messenger.context
  /// (findAncestor skips the messenger element itself).
  static ScaffoldMessengerState? _resolveMessenger(BuildContext? context) {
    if (context != null && context.mounted) {
      final m = ScaffoldMessenger.maybeOf(context);
      if (m != null) return m;
      final nav = Navigator.maybeOf(context, rootNavigator: true);
      if (nav != null && nav.context.mounted) {
        final fromNav = ScaffoldMessenger.maybeOf(nav.context);
        if (fromNav != null) return fromNav;
      }
    }
    final rootCtx = sanchivaNavKey.currentContext;
    if (rootCtx != null && rootCtx.mounted) {
      return ScaffoldMessenger.maybeOf(rootCtx);
    }
    return null;
  }

  static void show(
    BuildContext context,
    String message, {
    AppSnackKind kind = AppSnackKind.info,
    Duration duration = const Duration(seconds: 2, milliseconds: 600),
    IconData? icon,
  }) {
    // Capture messenger now; do NOT re-lookup via messenger.context later
    // (ScaffoldMessenger.maybeOf only searches ancestors, so it returns null
    // when started from the messenger's own element — snacks never showed).
    final messenger = _resolveMessenger(context);
    if (messenger == null) return;

    // Defer so we never show during deactivate/unmount (avoids _dependents assert).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!messenger.mounted) return;
      // Prefer the captured messenger; fall back if it was disposed.
      final m = messenger.mounted ? messenger : _resolveMessenger(context);
      if (m == null || !m.mounted) return;
      try {
        m
          ..hideCurrentSnackBar()
          ..showSnackBar(
            _build(
              m.context,
              message,
              kind: kind,
              duration: duration,
              icon: icon,
              messenger: m,
            ),
          );
      } catch (_) {
        // Ignore if scaffold tree is mid-teardown.
      }
    });
  }

  static void success(BuildContext context, String message, {IconData? icon}) =>
      show(context, message, kind: AppSnackKind.success, icon: icon);

  static void error(BuildContext context, String message, {IconData? icon}) =>
      show(context, message, kind: AppSnackKind.error, icon: icon ?? Icons.error_rounded);

  /// Destructive actions (delete, remove).
  static void danger(BuildContext context, String message, {IconData? icon}) =>
      show(context, message, kind: AppSnackKind.error, icon: icon ?? Icons.delete_rounded);

  static void info(BuildContext context, String message, {IconData? icon}) =>
      show(context, message, kind: AppSnackKind.info, icon: icon);

  static void warning(BuildContext context, String message, {IconData? icon}) =>
      show(context, message, kind: AppSnackKind.warning, icon: icon);

  static SnackBar _build(
    BuildContext context,
    String message, {
    required AppSnackKind kind,
    required Duration duration,
    IconData? icon,
    required ScaffoldMessengerState messenger,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _styleFor(kind, isDark);
    final leadingIcon = icon ?? style.icon;

    // Scaffold already places floating snacks above bottomNavigationBar;
    // only a small gap so the toast sits close to the nav capsule.
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      duration: duration,
      dismissDirection: DismissDirection.horizontal,
      content: Material(
        color: style.bg,
        elevation: 10,
        shadowColor: style.accent.withValues(alpha: isDark ? 0.35 : 0.22),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: style.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: style.accent.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(leadingIcon, size: 18, color: style.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: style.fg,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: messenger.hideCurrentSnackBar,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: style.fg.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _SnackStyle _styleFor(AppSnackKind kind, bool isDark) {
    switch (kind) {
      case AppSnackKind.success:
        return _SnackStyle(
          icon: Icons.check_circle_rounded,
          accent: AppColors.purple,
          bg: isDark ? const Color(0xFF1E1A35) : const Color(0xFFEEEDFE),
          fg: isDark ? const Color(0xFFE0D9FF) : const Color(0xFF3B2FA0),
          border: AppColors.purple.withValues(alpha: isDark ? 0.4 : 0.22),
        );
      case AppSnackKind.error:
        return _SnackStyle(
          icon: Icons.delete_rounded,
          accent: AppColors.danger,
          bg: isDark ? const Color(0xFF2A1518) : const Color(0xFFFEF2F2),
          fg: isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
          border: AppColors.danger.withValues(alpha: isDark ? 0.4 : 0.22),
        );
      case AppSnackKind.warning:
        return _SnackStyle(
          icon: Icons.warning_amber_rounded,
          accent: const Color(0xFFF59E0B),
          bg: isDark ? const Color(0xFF2A2310) : const Color(0xFFFFFBEB),
          fg: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
          border: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.4 : 0.22),
        );
      case AppSnackKind.info:
        return _SnackStyle(
          icon: Icons.info_rounded,
          accent: const Color(0xFF0EA5E9),
          bg: isDark ? const Color(0xFF0F2430) : const Color(0xFFF0F9FF),
          fg: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0C4A6E),
          border: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.4 : 0.22),
        );
    }
  }
}

class _SnackStyle {
  const _SnackStyle({
    required this.icon,
    required this.accent,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final IconData icon;
  final Color accent;
  final Color bg;
  final Color fg;
  final Color border;
}
