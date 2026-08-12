import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

import '../widgets/sanchiva_logo.dart';

/// System biometrics / device PIN before entering the app.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  static const _brand = Color(0xFF5038F0);
  final _auth = LocalAuthentication();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final canBio = await _auth.canCheckBiometrics;
      final deviceOk = await _auth.isDeviceSupported();
      if (!canBio && !deviceOk) {
        setState(() {
          _error =
              'No screen lock found. Set a PIN, pattern, fingerprint, or face unlock in phone Settings, then try again.';
        });
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Sanchiva',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: false,
      );
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Authentication canceled. Tap Unlock to try again.');
      }
    } on LocalAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.description ?? e.code.name);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brand, Color(0xFF7A40F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                const SanchivaLogo(size: 96),
                const SizedBox(height: 20),
                Text(
                  'Sanchiva is locked',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use Face unlock, fingerprint, or your device PIN',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFD0D0),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _unlock,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(_busy ? 'Waiting…' : 'Unlock'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _brand,
                      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
