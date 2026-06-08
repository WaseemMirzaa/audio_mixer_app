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
    bool clearAvatar = false,
  });

  /// Persists the picked image at [localPath] as the signed-in user's avatar
  /// and returns the value to store in [updateProfile.avatarUrl].
  ///
  /// Firebase uploads the file to Cloud Storage (`avatars/{uid}`) and returns
  /// the public download URL; the mock backend returns [localPath] unchanged.
  Future<String> uploadAvatar(String localPath);

  Future<void> deleteAccount();
}
