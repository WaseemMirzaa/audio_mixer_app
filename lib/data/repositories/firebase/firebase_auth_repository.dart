import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  AppUser? _mapUser(User u, Map<String, dynamic>? profile) {
    final data = profile ?? {};
    return AppUser(
      uid: u.uid,
      email: u.email ?? '',
      displayName: data['displayName'] as String? ?? u.displayName ?? 'User',
      avatarUrl: data['avatarUrl'] as String?,
      avatarFileName: data['avatarFileName'] as String?,
      isGuest: false,
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

  @override
  Stream<AppUser?> authState() {
    // For each signed-in user, follow their profile document's snapshots so
    // edits (display name, avatar, theme) propagate to the whole app live —
    // not just on sign-in/out. asyncExpand cancels the previous doc stream
    // when the auth user changes (switch-map behaviour).
    return _auth.authStateChanges().asyncExpand((u) {
      if (u == null) return Stream<AppUser?>.value(null);
      return _db
          .collection('users')
          .doc(u.uid)
          .snapshots()
          .map((snap) => _mapUser(u, snap.data()));
    });
  }

  @override
  Future<AppUser?> currentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final profile = await _profileDoc(u.uid);
    return _mapUser(u, profile);
  }

  @override
  Future<void> continueAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      final u = cred.user!;
      await _db.collection('users').doc(u.uid).set({
        'uid': u.uid,
        'email': '',
        'displayName': 'Guest',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboardingCompleted': false,
        'preferredTheme': 'system',
        'isPro': false,
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
  }

  @override
  Future<({String url, String storagePath})> uploadAvatar(
    String? localPath, {
    Uint8List? bytes,
    String? extension,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');

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
  }

  @override
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    // Best-effort removal of the avatar object(s); ignore if none exist.
    await _deleteAvatarFiles(u.uid);
    await _db.collection('users').doc(u.uid).delete();
    await u.delete();
  }

  @override
  Future<void> markOnboardingComplete() async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).set({
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
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
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
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
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user!;
      await u.updateDisplayName(displayName.trim());
      await _db.collection('users').doc(u.uid).set({
        'uid': u.uid,
        'email': email.trim().toLowerCase(),
        'displayName': displayName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboardingCompleted': true,
        'preferredTheme': 'system',
        'isPro': false,
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
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
  }
}
