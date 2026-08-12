import 'package:flutter/material.dart';

/// Sanchiva mark from asset PNG (original style).
class SanchivaLogo extends StatelessWidget {
  const SanchivaLogo({
    super.key,
    this.size = 72,
    this.brightness = Brightness.light,
  });

  final double size;

  /// On purple headers use [Brightness.dark] so fallback icon stays light.
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final fallbackColor =
        brightness == Brightness.dark ? Colors.white : const Color(0xFF5038F0);

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/sanchiva-logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.savings_outlined,
          size: size * 0.72,
          color: fallbackColor,
        ),
      ),
    );
  }
}
