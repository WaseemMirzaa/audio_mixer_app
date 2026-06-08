import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    final p = await _profileDoc(u.uid);
    return _mapUser(u, p);
  }

  @override
  Future<void> continueAsGuest() async {
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
  }

  @override
  Future<String> uploadAvatar(String localPath) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    final ext = p.extension(localPath).toLowerCase();
    final contentType = switch (ext) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    final ref = _storage.ref().child('avatars/${u.uid}$ext');
    await ref.putFile(
      File(localPath),
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    // Best-effort removal of the avatar object(s); ignore if none exist.
    try {
      final items = await _storage.ref().child('avatars').listAll();
      await Future.wait(
        items.items
            .where((r) => p.basenameWithoutExtension(r.name) == u.uid)
            .map((r) => r.delete()),
      );
    } catch (_) {}
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
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? preferredTheme,
    String? defaultPresetId,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    if (displayName != null) {
      await u.updateDisplayName(displayName);
    }
    await _db.collection('users').doc(u.uid).set({
      if (displayName != null) 'displayName': displayName,
      if (preferredTheme != null) 'preferredTheme': preferredTheme,
      if (defaultPresetId != null) 'defaultPresetId': defaultPresetId,
      if (clearAvatar) 'avatarUrl': FieldValue.delete(),
      if (!clearAvatar && avatarUrl != null) 'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
