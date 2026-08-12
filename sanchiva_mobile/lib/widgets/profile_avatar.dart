import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/profile_photo_state.dart';

/// Circular profile image: custom file, Google, SVG avatar, or initials.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.radius = 32,
    this.backgroundColor,
    this.brand = const Color(0xFF5038F0),
  });

  final double radius;
  final Color? backgroundColor;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final photo = context.watch<ProfilePhotoState>();
    final user = context.watch<AuthState>().user;
    final name = user?['name']?.toString() ?? 'Guest';
    final email = user?['email']?.toString() ?? '';
    final googleUrl = user?['photo_url']?.toString();
    final bg = backgroundColor ?? brand.withValues(alpha: 0.12);

    Widget child;

    switch (photo.source) {
      case PhotoSource.file:
        if (photo.filePath != null && File(photo.filePath!).existsSync()) {
          child = Image.file(
            File(photo.filePath!),
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
          );
        } else {
          child = _initials(name, email);
        }
      case PhotoSource.google:
        if (googleUrl != null && googleUrl.isNotEmpty) {
          child = Image.network(
            googleUrl,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            errorBuilder: (_, __, ___) => _initials(name, email),
          );
        } else {
          child = _initials(name, email);
        }
      case PhotoSource.avatar:
        final opt = AvatarOption.byId(photo.avatarId);
        if (opt != null) {
          if (opt.isRaster) {
            child = Image.asset(
              opt.asset,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
            );
          } else {
            child = SvgPicture.asset(
              opt.asset,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
            );
          }
        } else {
          child = _initials(name, email);
        }
      case PhotoSource.none:
        child = _initials(name, email);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: child is Text
              ? Center(child: child)
              : child,
        ),
      ),
    );
  }

  Widget _initials(String name, String email) {
    return Text(
      _letters(name, email),
      style: GoogleFonts.inter(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w800,
        color: brand,
      ),
    );
  }

  String _letters(String name, String email) {
    final n = name.trim();
    if (n.isNotEmpty && n.toLowerCase() != 'guest') {
      final parts = n.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'G';
  }
}
