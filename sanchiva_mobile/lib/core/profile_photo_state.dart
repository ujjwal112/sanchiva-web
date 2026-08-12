import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the profile image is sourced (device-local preference).
enum PhotoSource {
  /// Initials / default placeholder
  none,

  /// Built-in character avatar image
  avatar,

  /// Image file on device
  file,

  /// Google account photo URL (when signed in with Google)
  google,
}

/// Built-in character avatars.
class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.asset,
    required this.label,
  });

  final String id;
  final String asset;
  final String label;

  /// Whether this asset is a raster image (png/jpg) vs svg.
  bool get isRaster {
    final p = asset.toLowerCase();
    return p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.webp');
  }

  static const all = <AvatarOption>[
    AvatarOption(id: 'hulk', asset: 'assets/avatars/hulk.png', label: 'Hulk'),
    AvatarOption(id: 'spiderman', asset: 'assets/avatars/spiderman.png', label: 'Spider-Man'),
    AvatarOption(id: 'ironman', asset: 'assets/avatars/ironman.png', label: 'Iron Man'),
    AvatarOption(id: 'scarlet_witch', asset: 'assets/avatars/scarlet_witch.png', label: 'Scarlet Witch'),
    AvatarOption(id: 'black_widow', asset: 'assets/avatars/black_widow.png', label: 'Black Widow'),
    AvatarOption(id: 'valkyrie', asset: 'assets/avatars/valkyrie.png', label: 'Valkyrie'),
  ];

  static AvatarOption? byId(String? id) {
    if (id == null) return null;
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Local-only profile photo preference (not uploaded to server).
class ProfilePhotoState extends ChangeNotifier {
  static const _kSource = 'sanchiva.photo.source';
  static const _kAvatarId = 'sanchiva.photo.avatar_id';
  static const _kFilePath = 'sanchiva.photo.file_path';

  bool loading = true;
  PhotoSource source = PhotoSource.none;
  String? avatarId;
  String? filePath;

  ProfilePhotoState() {
    _load();
  }

  Future<void> _load() async {
    loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSource) ?? 'none';
      source = PhotoSource.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => PhotoSource.none,
      );
      avatarId = prefs.getString(_kAvatarId);
      filePath = prefs.getString(_kFilePath);

      if (source == PhotoSource.file && (filePath == null || !File(filePath!).existsSync())) {
        source = PhotoSource.none;
        filePath = null;
      }
      if (source == PhotoSource.avatar && AvatarOption.byId(avatarId) == null) {
        source = PhotoSource.none;
        avatarId = null;
      }
    } catch (_) {
      source = PhotoSource.none;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSource, source.name);
    if (avatarId != null) {
      await prefs.setString(_kAvatarId, avatarId!);
    } else {
      await prefs.remove(_kAvatarId);
    }
    if (filePath != null) {
      await prefs.setString(_kFilePath, filePath!);
    } else {
      await prefs.remove(_kFilePath);
    }
  }

  Future<void> preferGoogleIfUnset({required bool hasGooglePhoto}) async {
    if (!hasGooglePhoto) return;
    if (source != PhotoSource.none) return;
    source = PhotoSource.google;
    await _persist();
    notifyListeners();
  }

  Future<void> useAvatar(String id) async {
    source = PhotoSource.avatar;
    avatarId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> useGoogle() async {
    source = PhotoSource.google;
    await _persist();
    notifyListeners();
  }

  Future<void> useFileFromPath(String pickedPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_photo.jpg');
    await File(pickedPath).copy(dest.path);
    source = PhotoSource.file;
    filePath = dest.path;
    await _persist();
    notifyListeners();
  }

  /// Remove custom photo/avatar.
  /// Google users fall back to Google photo; others get initials.
  Future<void> removePhoto({required bool hasGooglePhoto}) async {
    avatarId = null;
    if (hasGooglePhoto) {
      source = PhotoSource.google;
    } else {
      source = PhotoSource.none;
    }
    await _persist();
    notifyListeners();
  }
}
