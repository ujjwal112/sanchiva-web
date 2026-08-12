import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

/// Events — static demo only.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  static const _brand = Color(0xFF5038F0);

  static const _events = <(String, String, String, Color)>[
    ('Wedding · Ananya', '12 events · budget', '₹4.2L', Color(0xFFF472B6)),
    ('House warming', '8 guests planned', '₹45K', Color(0xFF60A5FA)),
    ('Birthday · Arjun', 'Todo 4/10 done', '₹12K', Color(0xFFFBBF24)),
  ];

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.softPurpleOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: AppColors.isDark(context) ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.celebration_rounded, color: _brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your events',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                    ),
                    Text(
                      '3 active · demo list',
                      style: GoogleFonts.inter(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._events.map((e) {
          final (title, sub, budget, color) = e;
          final iconBg = AppColors.isDark(context)
              ? color.withValues(alpha: 0.22)
              : color.withValues(alpha: 0.15);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.event_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ink)),
                      Text(sub, style: GoogleFonts.inter(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
                Text(budget, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _brand)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
