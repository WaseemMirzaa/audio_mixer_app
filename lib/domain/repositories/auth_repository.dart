import 'dart:typed_data';

import '../models/app_user.dart';

class AuthException implements Exception {
  AuthException(this.code, [this.message]);

  /// Backend error code, e.g. `wrong-password`, `permission-denied`,
  /// `unavailable`, `network-request-failed`.
  final String code;

  /// Optional human-readable detail from the backend, surfaced for codes the
  /// UI does not explicitly translate (aids diagnosing config/backend issues).
  final String? message;

  @override
  String toString() => 'AuthException($code${message == null ? '' : ': $message'})';
}

/// Maps an [AuthException] to a user-facing message. Codes the UI does not
/// explicitly translate fall back to the backend message (or the raw code) so
/// configuration/backend problems surface clearly instead of being hidden
/// behind a generic "network error".
String authErrorMessage(AuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Invalid email address.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'user-not-found':
      return 'No account found with this email.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network and try again.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this project. '
          'Enable it in the Firebase console.';
    case 'permission-denied':
      return 'Request was rejected by the server (permission denied). '
          'Check your Firestore security rules.';
    case 'unavailable':
      return 'Service temporarily unavailable. Please try again.';
    case 'not-signed-in':
      return 'You need to be signed in to do that.';
    default:
      return e.message ?? 'Something went wrong (${e.code}).';
  }
}

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
