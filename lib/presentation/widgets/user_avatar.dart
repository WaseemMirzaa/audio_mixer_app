import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/app_user.dart';
import 'ceramic_texture.dart';

/// Circular avatar: network URL, local file path, raw bytes, or initials fallback.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 34,
    this.localPathOverride,
    this.localBytesOverride,
    this.preferInitials = false,
  });

  final AppUser? user;
  final double radius;
  final String? localPathOverride;

  /// Raw image bytes for an unsaved pick on web (where a file path is unavailable).
  final Uint8List? localBytesOverride;

  /// When true, skip photo (e.g. user chose “remove” before save).
  final bool preferInitials;

  double get _innerPhotoRadius => math.max(radius - 2.5, radius * 0.82);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bytes preview (web pick — no file path available).
    if (!preferInitials && localBytesOverride != null) {
      return _TexturedAvatarDisk(
        radius: radius,
        isDark: isDark,
        child: CircleAvatar(
          radius: _innerPhotoRadius,
          backgroundColor: Colors.transparent,
          backgroundImage: MemoryImage(localBytesOverride!),
        ),
      );
    }

    final path = preferInitials ? null : (localPathOverride ?? user?.avatarUrl);

    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return _TexturedAvatarDisk(
          radius: radius,
          isDark: isDark,
          child: CircleAvatar(
            radius: _innerPhotoRadius,
            backgroundColor: Colors.transparent,
            backgroundImage: NetworkImage(path),
            onBackgroundImageError: (_, __) {},
          ),
        );
      }
      if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          return _TexturedAvatarDisk(
            radius: radius,
            isDark: isDark,
            child: CircleAvatar(
              radius: _innerPhotoRadius,
              backgroundColor: Colors.transparent,
              backgroundImage: FileImage(file),
            ),
          );
        }
      }
    }

    final initial = (user?.displayName ?? 'U').trim().isNotEmpty
        ? (user?.displayName ?? 'U').trim().substring(0, 1).toUpperCase()
        : 'U';

    return _TexturedAvatarDisk(
      radius: radius,
      isDark: isDark,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.85,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.ceramicGradient[2],
          ),
        ),
      ),
    );
  }
}

class _TexturedAvatarDisk extends StatelessWidget {
  const _TexturedAvatarDisk({
    required this.radius,
    required this.isDark,
    required this.child,
  });

  final double radius;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            CeramicHeroFill(
              gradient: AppTheme.ceramicHeroRadial,
              borderRadius: BorderRadius.circular(radius),
              photoOpacity: isDark ? 0.4 : 0.36,
              child: const SizedBox.expand(),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
