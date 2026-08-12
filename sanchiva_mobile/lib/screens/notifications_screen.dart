import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/notification_inbox.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../widgets/app_confirm_dialog.dart';

/// In-app list of all Sanchiva alerts. Swipe to clear; Clear all in the app bar.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _brand = Color(0xFF5038F0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Refresh inbox history (independent of system push toggle).
      await NotificationService.instance.ensureInboxEntries();
      if (!mounted) return;
      context.read<NotificationInboxState>().markAllRead();
    });
  }

  Future<void> _clearAll() async {
    final inbox = context.read<NotificationInboxState>();
    if (inbox.items.isEmpty) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'Clear all?',
      message: 'Remove every notification from this list. This cannot be undone.',
      confirmLabel: 'Clear all',
      icon: Icons.notifications_off_rounded,
      tone: AppConfirmTone.danger,
    );
    if (ok && mounted) {
      await inbox.clearAll();
    }
  }

  String _when(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time = DateFormat.jm().format(local);
    if (day == today) return 'Today · $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday · $time';
    return '${DateFormat.MMMd().format(local)} · $time';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'emi_deduction':
        return Icons.event_rounded;
      case 'loan_remaining':
        return Icons.account_balance_rounded;
      case 'loan_ending':
        return Icons.flag_rounded;
      case 'cc_emi_remaining':
        return Icons.credit_card_rounded;
      case 'cc_emi_ending':
        return Icons.flag_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'emi_deduction':
        return _brand;
      case 'loan_remaining':
        return const Color(0xFF3B82F6);
      case 'loan_ending':
        return const Color(0xFFEF4444);
      case 'cc_emi_remaining':
        return const Color(0xFF8B5CF6);
      case 'cc_emi_ending':
        return const Color(0xFFF97316);
      default:
        return _brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkDark : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : AppColors.muted;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final inbox = context.watch<NotificationInboxState>();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: ink,
            fontSize: 18,
          ),
        ),
        actions: [
          if (inbox.items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(
                'Clear all',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: _brand,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: inbox.loading
          ? const Center(child: CircularProgressIndicator())
          : inbox.items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 56,
                          color: muted.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'EMI deduction, remaining months, and ending alerts will show up here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: inbox.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final n = inbox.items[index];
                    return Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        context.read<NotificationInboxState>().remove(n.id);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Clear',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                      child: Material(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            context.read<NotificationInboxState>().markRead(n.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFEDEAF8),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _iconColor(n.type).withValues(alpha: isDark ? 0.22 : 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _iconFor(n.type),
                                    color: _iconColor(n.type),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                          if (!n.read)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(left: 6),
                                              decoration: const BoxDecoration(
                                                color: _brand,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _when(n.createdAt),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: muted.withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
