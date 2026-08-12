import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/settings_state.dart';
import '../widgets/sanchiva_logo.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// 4-step onboarding (reference layout + brand purple).
/// 0–2: free area + → · 3: logo + Login / Sign up
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// 0,1,2 = pages with arrow · 3 = auth choice (logo + buttons)
  int _step = 0;

  static const int _authStep = 3;
  static const int _totalSteps = 4;

  // From color.png
  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);

  // Free area matches login logo circle: white @ ~16% on purple brand

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      headline: 'Everything that matters,\none place',
      kind: _PageKind.logoOnly,
    ),
    _OnboardPage(
      headline: 'Track spends &\nloans with ease',
      kind: _PageKind.spend,
    ),
    _OnboardPage(
      headline: 'Live rates when\nyou need them',
      kind: _PageKind.rates,
    ),
  ];

  void _onSkip() => setState(() => _step = _authStep);

  void _onNext() {
    if (_step < _authStep) {
      setState(() => _step += 1);
    }
  }

  Future<void> _markOnboardingDone() async {
    await context.read<SettingsState>().completeOnboarding();
  }

  Future<void> _goLogin() async {
    // Capture navigator first — AppGate rebuilds when onboarding is marked done.
    final nav = Navigator.of(context);
    // Push login immediately so the first tap always works.
    nav.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
    // Persist so next cold start skips onboarding.
    await _markOnboardingDone();
  }

  Future<void> _goSignup() async {
    final nav = Navigator.of(context);
    nav.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) => const SignupScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
    await _markOnboardingDone();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final blobW = size.width * 0.78;
    final blobH = size.height * 0.42;
    final isAuth = _step == _authStep;
    final progress = (_step + 1) / _totalSteps;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _brand,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [_brand, _brandDeep],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: Column(
                children: [
                  // Skip only on content pages
                  SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: isAuth
                          ? const SizedBox.shrink()
                          : TextButton(
                              onPressed: _onSkip,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withValues(alpha: 0.95),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                'Skip',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Center free area
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 24,
                          right: 8,
                          child: _GhostBlob(
                            width: blobW * 0.55,
                            height: blobH * 0.45,
                            opacity: 0.14,
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: 0,
                          child: _GhostBlob(
                            width: blobW * 0.4,
                            height: blobH * 0.35,
                            opacity: 0.1,
                          ),
                        ),
                        _OrganicBlob(
                          width: blobW,
                          height: blobH,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: isAuth
                                ? const _LogoOnlyFreeArea(key: ValueKey('auth_logo'))
                                : _ContentFreeArea(
                                    key: ValueKey('page_$_step'),
                                    page: _pages[_step],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (!isAuth) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _pages[_step].headline,
                        key: ValueKey('title_$_step'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Page dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalSteps, (i) {
                        final active = i == _step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: active ? 1 : 0.35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    _NextCircleButton(
                      progress: progress,
                      onPressed: _onNext,
                    ),
                  ] else ...[
                    Text(
                      'Welcome to Sanchiva',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in or create an account to continue',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Login + Sign up
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _goLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _brand,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('Log in'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _goSignup,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('Sign up'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page model ──────────────────────────────────────────────────────────────

enum _PageKind { logoOnly, spend, rates }

class _OnboardPage {
  const _OnboardPage({
    required this.headline,
    required this.kind,
  });

  final String headline;
  final _PageKind kind;
}

// ── Free area contents ──────────────────────────────────────────────────────

class _ContentFreeArea extends StatelessWidget {
  const _ContentFreeArea({super.key, required this.page});

  final _OnboardPage page;

  @override
  Widget build(BuildContext context) {
    switch (page.kind) {
      case _PageKind.logoOnly:
        return const _LogoOnlyFreeArea(key: ValueKey('first_logo'));
      case _PageKind.spend:
        return const _IllustrationFreeArea(
          key: ValueKey('spend'),
          painter: _SpendIllustrationPainter(),
          accent: Color(0xFF5038F0),
        );
      case _PageKind.rates:
        return const _IllustrationFreeArea(
          key: ValueKey('rates'),
          painter: _RatesIllustrationPainter(),
          accent: Color(0xFF0EA5E9),
        );
    }
  }
}

/// Creative center art only — no label text (headline lives under the blob)
class _IllustrationFreeArea extends StatelessWidget {
  const _IllustrationFreeArea({
    super.key,
    required this.painter,
    required this.accent,
  });

  final CustomPainter painter;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(painter: painter),
              ),
            ),
          ),
          // Decorative accent bar (no text)
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.35),
                  accent,
                  accent.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Three soft dots under the bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                width: i == 1 ? 7 : 5,
                height: i == 1 ? 7 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: i == 1 ? 0.85 : 0.35),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Wallet + rising bars + soft coin — spends / loans
class _SpendIllustrationPainter extends CustomPainter {
  const _SpendIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Soft ring
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.38,
      Paint()..color = const Color(0xFF5038F0).withValues(alpha: 0.08),
    );

    // Wallet body
    final wallet = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + h * 0.04), width: w * 0.42, height: h * 0.28),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      wallet,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFF6366F1), Color(0xFF5038F0)],
        ).createShader(wallet.outerRect),
    );
    // Wallet flap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.21, cy - h * 0.06, w * 0.42, h * 0.08),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFF7A40F8),
    );
    // Card slot line
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + h * 0.06), width: w * 0.28, height: h * 0.05),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Rising chart bars (loans / progress)
    final bases = [0.22, 0.34, 0.48, 0.38];
    final left = cx - w * 0.36;
    for (var i = 0; i < 4; i++) {
      final bw = w * 0.055;
      final bh = h * bases[i];
      final x = left + i * (bw + w * 0.03);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, cy + h * 0.22 - bh, bw, bh),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF5038F0).withValues(alpha: 0.35),
              const Color(0xFF22D3EE),
            ],
          ).createShader(rect.outerRect),
      );
    }

    // Coin
    final coinC = Offset(cx + w * 0.28, cy - h * 0.18);
    canvas.drawCircle(coinC, w * 0.09, Paint()..color = const Color(0xFFFBBF24));
    canvas.drawCircle(
      coinC,
      w * 0.065,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFF59E0B),
    );
    // ₹ hint mark
    final tp = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: const Color(0xFF78350F).withValues(alpha: 0.85),
          fontSize: w * 0.08,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, coinC - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Globe / FX arrows + metal bars — live rates
class _RatesIllustrationPainter extends CustomPainter {
  const _RatesIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.30;

    // Soft glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.25,
      Paint()..color = const Color(0xFF5038F0).withValues(alpha: 0.07),
    );

    // Globe
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF818CF8), Color(0xFF5038F0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
    // Latitude lines
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(cx, cy), r, line);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 1.1, height: r * 2),
      line,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 0.7),
      line,
    );
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), line);

    // Swap / FX arrows around globe
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF22D3EE);

    // Top-right curved arrow
    final a1 = Path()
      ..moveTo(cx + r * 0.55, cy - r * 1.15)
      ..quadraticBezierTo(cx + r * 1.25, cy - r * 1.05, cx + r * 1.2, cy - r * 0.35);
    canvas.drawPath(a1, arrow);
    canvas.drawPath(
      _arrowHead(Offset(cx + r * 1.2, cy - r * 0.35), math.pi * 0.55),
      Paint()..color = const Color(0xFF22D3EE),
    );

    // Bottom-left curved arrow
    final a2 = Path()
      ..moveTo(cx - r * 0.55, cy + r * 1.15)
      ..quadraticBezierTo(cx - r * 1.25, cy + r * 1.05, cx - r * 1.2, cy + r * 0.35);
    canvas.drawPath(a2, arrow);
    canvas.drawPath(
      _arrowHead(Offset(cx - r * 1.2, cy + r * 0.35), math.pi * 1.55),
      Paint()..color = const Color(0xFF22D3EE),
    );

    // Metal chips: Au / Ag
    void chip(Offset o, Color c, String t) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: o, width: w * 0.16, height: h * 0.1),
          const Radius.circular(10),
        ),
        Paint()..color = c,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            color: Colors.white,
            fontSize: w * 0.055,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    chip(Offset(cx - w * 0.28, cy - h * 0.22), const Color(0xFFF59E0B), 'Au');
    chip(Offset(cx + w * 0.30, cy + h * 0.20), const Color(0xFF94A3B8), 'Ag');
  }

  Path _arrowHead(Offset tip, double angle) {
    const len = 10.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - len * math.cos(angle - 0.45),
        tip.dy - len * math.sin(angle - 0.45),
      )
      ..lineTo(
        tip.dx - len * math.cos(angle + 0.45),
        tip.dy - len * math.sin(angle + 0.45),
      )
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LogoOnlyFreeArea extends StatelessWidget {
  const _LogoOnlyFreeArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SanchivaLogo(size: 120, brightness: Brightness.light),
          const SizedBox(height: 14),
          Text(
            'Sanchiva',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shapes & next button ────────────────────────────────────────────────────

class _OrganicBlob extends StatelessWidget {
  const _OrganicBlob({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Same surface as login logo circle: Colors.white @ 0.16 on purple
    return SizedBox(
      width: width,
      height: height,
      child: ClipPath(
        clipper: const _BlobClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GhostBlob extends StatelessWidget {
  const _GhostBlob({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipPath(
          clipper: const _BlobClipper(seed: 2),
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
  }
}

class _BlobClipper extends CustomClipper<Path> {
  const _BlobClipper({this.seed = 1});

  final int seed;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final k = seed == 1 ? 1.0 : 0.92;

    final path = Path();
    path.moveTo(w * 0.22 * k, h * 0.08);
    path.cubicTo(w * 0.05, h * 0.12, w * 0.02, h * 0.38, w * 0.08, h * 0.55);
    path.cubicTo(w * 0.12, h * 0.78, w * 0.28, h * 0.96, w * 0.52, h * 0.94);
    path.cubicTo(w * 0.78, h * 0.92, w * 0.96, h * 0.72, w * 0.94, h * 0.48);
    path.cubicTo(w * 0.92, h * 0.22, w * 0.72, h * 0.04, w * 0.45, h * 0.05);
    path.cubicTo(w * 0.35, h * 0.05, w * 0.28, h * 0.06, w * 0.22 * k, h * 0.08);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _BlobClipper oldClipper) => oldClipper.seed != seed;
}

class _NextCircleButton extends StatelessWidget {
  const _NextCircleButton({
    required this.progress,
    required this.onPressed,
  });

  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(78, 78),
            painter: _RingPainter(progress: progress),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: const SizedBox(
                width: 58,
                height: 58,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF1A1A2E),
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final active = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
