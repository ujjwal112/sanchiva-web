import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

/// Polished section intro card — icon badge + title + subtitle
/// (same style language as Monetary live headers).
class SectionHeaderCard extends StatelessWidget {
  const SectionHeaderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// When set, whole card is tappable (e.g. open section menu) and shows chevron.
  final VoidCallback? onTap;

  /// Optional extra trailing widget (instead of / with chevron).
  final Widget? trailing;

  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final isDark = AppColors.isDark(context);

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  _brand.withValues(alpha: 0.28),
                  AppColors.cardDark,
                ]
              : [
                  const Color(0xFFEEEDFE),
                  Colors.white,
                ],
        ),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [_brand, _brandDeep]),
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12.5, color: muted, fontWeight: FontWeight.w500, height: 1.3),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: _brand.withValues(alpha: 0.9), size: 26),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }
}
