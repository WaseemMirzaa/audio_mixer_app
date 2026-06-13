import 'dart:typed_data';

import '../models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authState();

  Future<AppUser?> currentUser();

  Future<void> signInWithEmail({required String email, required String password});

  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> continueAsGuest();

  Future<void> markOnboardingComplete();

  Future<void> updateProfile({
    String? displayName,
    String? preferredTheme,
    String? defaultPresetId,
    String? avatarUrl,
    String? avatarFileName,
    bool clearAvatar = false,
  });

  /// Uploads the avatar to storage and returns the public download URL and
  /// the storage path (e.g. `avatars/uid.jpg`).
  ///
  /// Pass [localPath] on mobile/desktop; pass [bytes] + [extension] on web.
  /// Any previous avatar file for this user is deleted before the new one is
  /// written, preventing orphaned files when the extension changes.
  Future<({String url, String storagePath})> uploadAvatar(
    String? localPath, {
    Uint8List? bytes,
    String? extension,
  });

  Future<void> deleteAccount();
}
