import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/app_user.dart';
import '../../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// Normalises any Firebase error into an [AuthException] carrying the real
  /// backend code + message. This is what lets the UI show the *actual* reason
  /// (e.g. `operation-not-allowed`, `permission-denied`, `unavailable`,
  /// `api-key-not-valid`) instead of masking everything as "Network error".
  Never _rethrow(Object e) {
    if (e is FirebaseAuthException) {
      throw AuthException(e.code, e.message);
    }
    if (e is FirebaseException) {
      // Firestore / Storage / core errors (permission-denied, unavailable, …).
      throw AuthException(e.code, e.message);
    }
    if (e is AuthException) throw e;
    throw AuthException('unknown', e.toString());
  }

  AppUser? _mapUser(User u, Map<String, dynamic>? profile) {
    final data = profile ?? {};
    return AppUser(
      uid: u.uid,
      email: u.email ?? (data['email'] as String? ?? ''),
      displayName: data['displayName'] as String? ?? u.displayName ?? 'User',
      avatarUrl: data['avatarUrl'] as String?,
      avatarFileName: data['avatarFileName'] as String?,
      isGuest: u.isAnonymous,
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      preferredTheme: data['preferredTheme'] as String? ?? 'system',
      defaultPresetId: data['defaultPresetId'] as String?,
    );
  }

  Future<Map<String, dynamic>?> _profileDoc(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  /// Deletes all Storage objects whose basename (without extension) matches
  /// [uid] inside the `avatars/` prefix. Safe to call even if none exist.
  Future<void> _deleteAvatarFiles(String uid) async {
    try {
      final items = await _storage.ref().child('avatars').listAll();
      await Future.wait(
        items.items
            .where((r) => p.basenameWithoutExtension(r.name) == uid)
            .map((r) => r.delete()),
      );
    } catch (_) {}
  }

  /// Best-effort write of the user profile document. A failure here (e.g.
  /// Firestore rules locked, database not provisioned, offline) must NOT make a
  /// successful sign-in / sign-up look like a total failure — the auth account
  /// already exists and the user is authenticated. The doc is recreated on the
  /// next successful write, and [_mapUser] falls back to auth data meanwhile.
  Future<void> _writeProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseAuthRepository] profile write failed (continuing): $e');
    }
  }

  @override
  Stream<AppUser?> authState() {
    // Uses switchMap semantics: each new auth event cancels the previous
    // Firestore profile stream so auth transitions (e.g. anonymous → email)
    // are never blocked by an infinite sub-stream.
    late StreamController<AppUser?> controller;
    StreamSubscription<AppUser?>? profileSub;
    StreamSubscription<User?>? authSub;

    controller = StreamController<AppUser?>(
      onListen: () {
        authSub = _auth.authStateChanges().listen(
          (u) {
            profileSub?.cancel();
            profileSub = null;
            if (u == null) {
              controller.add(null);
            } else {
              profileSub = _profileStream(u).listen(
                controller.add,
                onError: (Object e) {
                  debugPrint(
                      '[FirebaseAuthRepository] profile stream error: $e');
                },
              );
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        profileSub?.cancel();
        profileSub = null;
        authSub?.cancel();
        authSub = null;
      },
    );

    return controller.stream;
  }

  Stream<AppUser?> _profileStream(User u) async* {
    // Emit an auth-only user first so the app works even if Firestore is down.
    yield _mapUser(u, null);
    yield* _db
        .collection('users')
        .doc(u.uid)
        .snapshots()
        .map((snap) => _mapUser(u, snap.data()))
        .handleError((Object e) {
      debugPrint('[FirebaseAuthRepository] profile stream error: $e');
    });
  }

  @override
  Future<AppUser?> currentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    Map<String, dynamic>? profile;
    try {
      profile = await _profileDoc(u.uid);
    } catch (e) {
      // Non-fatal: return a user built from auth data only.
      debugPrint('[FirebaseAuthRepository] currentUser profile read failed: $e');
    }
    return _mapUser(u, profile);
  }

  @override
  Future<void> continueAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      final u = cred.user!;
      await _writeProfile(u.uid, {
        'uid': u.uid,
        'email': '',
        'displayName': 'Guest',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboardingCompleted': false,
        'preferredTheme': 'system',
        'isPro': false,
      });
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<({String url, String storagePath})> uploadAvatar(
    String? localPath, {
    Uint8List? bytes,
    String? extension,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw AuthException('not-signed-in', 'Not signed in');

    final String ext;
    if (extension != null && extension.isNotEmpty) {
      ext = extension.toLowerCase();
    } else if (localPath != null) {
      final fromPath = p.extension(localPath).toLowerCase();
      ext = fromPath.isEmpty ? '.jpg' : fromPath;
    } else {
      ext = '.jpg';
    }

    final contentType = switch (ext) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    final storagePath = 'avatars/${u.uid}$ext';
    final ref = _storage.ref().child(storagePath);

    try {
      // Remove any previous avatar file (handles extension changes gracefully).
      await _deleteAvatarFiles(u.uid);

      // Upload: bytes-based on web, file-based on mobile/desktop.
      if (kIsWeb || bytes != null) {
        final data = bytes ?? Uint8List(0);
        await ref.putData(data, SettableMetadata(contentType: contentType));
      } else if (localPath != null) {
        await ref.putFile(
          File(localPath),
          SettableMetadata(contentType: contentType),
        );
      } else {
        throw ArgumentError('Provide either localPath or bytes');
      }

      final url = await ref.getDownloadURL();
      return (url: url, storagePath: storagePath);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      // Best-effort removal of the avatar object(s); ignore if none exist.
      await _deleteAvatarFiles(u.uid);
      await _db.collection('users').doc(u.uid).delete();
      await u.delete();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> markOnboardingComplete() async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _writeProfile(u.uid, {
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      _rethrow(e);
    }

    // The account now exists and the user is signed in. The steps below are
    // best-effort: if Firestore/Auth profile writes fail, the sign-up still
    // succeeds (otherwise the user sees an error yet the account was created,
    // and a retry fails with "email-already-in-use" — the classic confusing bug).
    final u = cred.user!;
    try {
      await u.updateDisplayName(displayName.trim());
    } catch (e) {
      debugPrint('[FirebaseAuthRepository] updateDisplayName failed: $e');
    }
    await _writeProfile(u.uid, {
      'uid': u.uid,
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': true,
      'preferredTheme': 'system',
      'isPro': false,
    });
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? preferredTheme,
    String? defaultPresetId,
    String? avatarUrl,
    String? avatarFileName,
    bool clearAvatar = false,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      if (displayName != null) {
        await u.updateDisplayName(displayName);
      }

      // When clearing the avatar, also remove the file from Storage.
      if (clearAvatar) {
        await _deleteAvatarFiles(u.uid);
      }

      await _db.collection('users').doc(u.uid).set({
        if (displayName != null) 'displayName': displayName,
        if (preferredTheme != null) 'preferredTheme': preferredTheme,
        if (defaultPresetId != null) 'defaultPresetId': defaultPresetId,
        if (clearAvatar) 'avatarUrl': FieldValue.delete(),
        if (clearAvatar) 'avatarFileName': FieldValue.delete(),
        if (!clearAvatar && avatarUrl != null) 'avatarUrl': avatarUrl,
        if (!clearAvatar && avatarFileName != null)
          'avatarFileName': avatarFileName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _rethrow(e);
    }
  }
}
