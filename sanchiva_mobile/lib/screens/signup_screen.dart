import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/google_sign_in_service.dart';
import '../core/navigation.dart';
import '../core/profile_photo_state.dart';
import '../core/theme.dart';
import '../widgets/sanchiva_logo.dart';
import 'auth_choice_screen.dart';
import 'login_screen.dart';

/// Create account — respects app light/dark theme.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _brand = Color(0xFF5038F0);
  static const _brandDeep = Color(0xFF7A40F8);

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _localError;
  bool _busy = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _localError = null;
      _busy = true;
    });
    try {
      await context.read<AuthState>().register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            confirmPassword: _confirm.text,
          );
      clearNavStack();
    } catch (e) {
      if (!mounted) return;
      setState(() => _localError = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AuthChoiceScreen()),
    );
  }

  void _goLogin() {
    // Replace signup with login (do not pop to Welcome).
    // Stack becomes Welcome → Login, or just Login if signup was root.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _localError = null;
      _busy = true;
    });
    try {
      await context.read<AuthState>().loginWithGoogle();
      if (!mounted) return;
      final auth = context.read<AuthState>();
      final photo = context.read<ProfilePhotoState>();
      await photo.preferGoogleIfUnset(hasGooglePhoto: auth.googlePhotoUrl != null);
      if (auth.googlePhotoUrl != null) await photo.useGoogle();
      if (!mounted) return;
      clearNavStack();
    } on GoogleSignInCanceled {
      // User closed the account picker — no error banner
    } catch (e) {
      if (!mounted) return;
      if (isGoogleSignInCanceled(e)) return;
      setState(() {
        _localError = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final sheet = AppColors.bgOf(context);
    final fieldFill = AppColors.softPurpleOf(context);
    final card = AppColors.cardOf(context);
    final fieldStyle = GoogleFonts.inter(fontWeight: FontWeight.w600, color: ink);

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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brand, _brandDeep],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _busy ? null : _goBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Column(
                    children: [
                      const SanchivaLogo(size: 80, brightness: Brightness.dark),
                      const SizedBox(height: 12),
                      Text(
                        'Create account',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Join Sanchiva in a few steps',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: sheet,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              style: fieldStyle,
                              decoration: _inputDecoration(
                                hint: 'Name',
                                icon: Icons.person_outline_rounded,
                                fill: fieldFill,
                                muted: muted,
                              ),
                              validator: (v) {
                                if ((v ?? '').trim().isEmpty) return 'Enter your name';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              style: fieldStyle,
                              decoration: _inputDecoration(
                                hint: 'Email',
                                icon: Icons.mail_outline_rounded,
                                fill: fieldFill,
                                muted: muted,
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Enter your email';
                                if (!s.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscurePass,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              style: fieldStyle,
                              decoration: _inputDecoration(
                                hint: 'Password',
                                icon: Icons.lock_outline_rounded,
                                fill: fieldFill,
                                muted: muted,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                  icon: Icon(
                                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: muted,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                final s = v ?? '';
                                if (s.isEmpty) return 'Enter a password';
                                if (s.length < 6) return 'At least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirm,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              style: fieldStyle,
                              decoration: _inputDecoration(
                                hint: 'Confirm password',
                                icon: Icons.lock_outline_rounded,
                                fill: fieldFill,
                                muted: muted,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: muted,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if ((v ?? '').isEmpty) return 'Confirm your password';
                                if (v != _password.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            if (_localError != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _localError!,
                                        style: GoogleFonts.inter(
                                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brand,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _brand.withValues(alpha: 0.5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                      )
                                    : const Text('Create account'),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.borderOf(context))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: GoogleFonts.inter(
                                      color: muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: AppColors.borderOf(context))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _busy ? null : _googleSignIn,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ink,
                                  backgroundColor: card,
                                  side: BorderSide(color: AppColors.borderOf(context)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.borderOf(context)),
                                      ),
                                      child: Text(
                                        'G',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF4285F4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Continue with Google'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w500),
                                  ),
                                  GestureDetector(
                                    onTap: _busy ? null : _goLogin,
                                    child: Text(
                                      'Log in',
                                      style: GoogleFonts.inter(color: _brand, fontWeight: FontWeight.w800),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color fill,
    required Color muted,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: muted, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: _brand.withValues(alpha: 0.85), size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.borderOf(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}
