import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/sanchiva_logo.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// Welcome screen with **Log in** and **Sign up** — same organic free-area
/// as onboarding (not a square). Shown after splash / logout.
class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);

  void _goLogin(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, animation, secondaryAnimation) => const LoginScreen(),
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
  }

  void _goSignup(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, animation, secondaryAnimation) => const SignupScreen(),
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
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final blobW = size.width * 0.78;
    final blobH = size.height * 0.42;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: Column(
                children: [
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
                        // Organic blob (same as onboarding) — not a square
                        _OrganicBlob(
                          width: blobW,
                          height: blobH,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SanchivaLogo(size: 120, brightness: Brightness.light),
                                SizedBox(height: 14),
                                _Wordmark(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _goLogin(context),
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
                      onPressed: () => _goSignup(context),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sanchiva',
      style: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1A1A2E),
      ),
    );
  }
}

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
