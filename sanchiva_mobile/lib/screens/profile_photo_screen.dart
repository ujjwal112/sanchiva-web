import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/auth_state.dart';
import '../core/profile_photo_state.dart';
import '../core/theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/profile_avatar.dart';

/// Edit profile photo: gallery, camera, Google (if any), or character avatars.
class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  static const _brand = Color(0xFF5038F0);
  bool _busy = false;

  Future<void> _pickGallery() async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (file == null) return;
      await context.read<ProfilePhotoState>().useFileFromPath(file.path);
      if (!mounted) return;
      AppSnack.success(context, 'Profile photo updated');
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, 'Could not pick image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCamera() async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (file == null) return;
      await context.read<ProfilePhotoState>().useFileFromPath(file.path);
      if (!mounted) return;
      AppSnack.success(context, 'Profile photo updated');
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, 'Could not use camera: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto(bool hasGoogle) async {
    await context.read<ProfilePhotoState>().removePhoto(hasGooglePhoto: hasGoogle);
    if (!mounted) return;
    if (hasGoogle) {
      AppSnack.info(context, 'Using your Google profile photo');
    } else {
      AppSnack.info(context, 'Using initials');
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = context.watch<ProfilePhotoState>();
    final user = context.watch<AuthState>().user;
    final googleUrl = user?['photo_url']?.toString();
    final hasGoogle = googleUrl != null && googleUrl.isNotEmpty;
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final muted = AppColors.mutedOf(context);
    final card = AppColors.cardOf(context);

    final showRemove = photo.source == PhotoSource.avatar || photo.source == PhotoSource.file;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Edit profile photo', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _brand.withValues(alpha: 0.35), width: 3),
                  ),
                  child: const ProfileAvatar(radius: 56),
                ),
                if (_busy)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (showRemove) ...[
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _busy ? null : () => _removePhoto(hasGoogle),
                child: Text(
                  'Remove',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          Text(
            'YOUR PHOTO',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  card: card,
                  ink: ink,
                  muted: muted,
                  isDark: isDark,
                  onTap: _busy ? null : _pickGallery,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera',
                  card: card,
                  ink: ink,
                  muted: muted,
                  isDark: isDark,
                  onTap: _busy ? null : _pickCamera,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          Text(
            'AVATARS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          _AvatarGrid(
            options: AvatarOption.all,
            selectedId: photo.source == PhotoSource.avatar ? photo.avatarId : null,
            onSelect: (id) async {
              await context.read<ProfilePhotoState>().useAvatar(id);
              if (!mounted) return;
              AppSnack.success(context, 'Avatar updated');
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.card,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color card;
  final Color ink;
  final Color muted;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF5038F0), size: 28),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
    required this.options,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AvatarOption> options;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final option = options[i];
        return _AvatarTile(
          option: option,
          selected: selectedId == option.id,
          onTap: () => onSelect(option.id),
        );
      },
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AvatarOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFF5038F0) : AppColors.borderOf(context),
              width: selected ? 2.2 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: option.isRaster
                    ? Image.asset(
                        option.asset,
                        width: 78,
                        height: 78,
                        fit: BoxFit.cover,
                      )
                    : SvgPicture.asset(
                        option.asset,
                        width: 78,
                        height: 78,
                        fit: BoxFit.cover,
                      ),
              ),
              if (selected)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF5038F0)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
