import 'package:flutter/material.dart';

import '../core/theme.dart';

class PurpleHeader extends StatelessWidget {
  const PurpleHeader({
    super.key,
    required this.child,
    this.height = 220,
    this.showWave = true,
  });

  final Widget child;
  final double height;
  final bool showWave;

  @override
  Widget build(BuildContext context) {
    final waveColor = AppColors.bgOf(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.purple, AppColors.purpleDeep],
                ),
              ),
            ),
          ),
          if (showWave)
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              height: 48,
              child: CustomPaint(painter: _WavePainter(color: waveColor)),
            ),
          SafeArea(bottom: false, child: child),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.85, size.width, size.height * 0.35)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.color != color;
}
