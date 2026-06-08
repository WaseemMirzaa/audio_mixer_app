import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/app_user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../local/prefs_keys.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._prefs) {
    _restoreFromPrefs();
  }

  final SharedPreferences _prefs;
  final _uuid = const Uuid();
  final _ctrl = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _user;

  void _emit() => _ctrl.add(_user);

  void _restoreFromPrefs() {
    final raw = _prefs.getString(PrefsKeys.mockUserJson);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _user = AppUser(
        uid: m['uid'] as String,
        email: m['email'] as String,
        displayName: m['displayName'] as String,
        avatarUrl: m['avatarUrl'] as String?,
        isGuest: m['isGuest'] as bool? ?? false,
        onboardingCompleted: m['onboardingCompleted'] as bool? ?? false,
        preferredTheme: m['preferredTheme'] as String? ?? 'system',
        defaultPresetId: m['defaultPresetId'] as String?,
      );
    } catch (_) {}
  }

  void _persist() {
    final u = _user;
    if (u == null) {
      _prefs.remove(PrefsKeys.mockUserJson);
      return;
    }
    _prefs.setString(
      PrefsKeys.mockUserJson,
      jsonEncode({
        'uid': u.uid,
        'email': u.email,
        'displayName': u.displayName,
        'avatarUrl': u.avatarUrl,
        'isGuest': u.isGuest,
        'onboardingCompleted': u.onboardingCompleted,
        'preferredTheme': u.preferredTheme,
        'defaultPresetId': u.defaultPresetId,
      }),
    );
  }

  @override
  Stream<AppUser?> authState() async* {
    yield _user;
    yield* _ctrl.stream;
  }

  @override
  Future<AppUser?> currentUser() async => _user;

  @override
  Future<void> continueAsGuest() async {
    _user = AppUser(
      uid: 'guest_${_uuid.v4()}',
      email: '',
      displayName: 'Guest',
      isGuest: true,
      onboardingCompleted: _user?.onboardingCompleted ?? false,
    );
    _persist();
    _emit();
  }

  @override
  Future<void> deleteAccount() async {
    _user = null;
    _persist();
    _emit();
  }

  @override
  Future<void> markOnboardingComplete() async {
    final u = _user;
    if (u == null) return;
    _user = u.copyWith(onboardingCompleted: true);
    _persist();
    _emit();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!email.contains('@')) {
      throw AuthException('invalid-email');
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) throw AuthException('invalid-email');
    if (e == 'demo@app.com' && password == '123456') {
      _user = AppUser(
        uid: 'demo_uid',
        email: e,
        displayName: 'Demo User',
        onboardingCompleted: true,
      );
      _persist();
      _emit();
      return;
    }
    throw AuthException('wrong-password');
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _persist();
    _emit();
  }

  @override
  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) throw AuthException('invalid-email');
    if (password.length < 6) throw AuthException('weak-password');
    _user = AppUser(
      uid: _uuid.v4(),
      email: e,
      displayName: displayName.trim(),
      onboardingCompleted: true,
    );
    _persist();
    _emit();
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? preferredTheme,
    String? defaultPresetId,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    final u = _user;
    if (u == null) return;
    var next = u;
    if (displayName != null) {
      next = next.copyWith(displayName: displayName);
    }
    if (preferredTheme != null) {
      next = next.copyWith(preferredTheme: preferredTheme);
    }
    if (defaultPresetId != null) {
      next = next.copyWith(defaultPresetId: defaultPresetId);
    }
    if (clearAvatar) {
      next = next.copyWith(clearAvatar: true);
    } else if (avatarUrl != null) {
      next = next.copyWith(avatarUrl: avatarUrl.isEmpty ? null : avatarUrl);
    }
    _user = next;
    _persist();
    _emit();
  }

  @override
  Future<String> uploadAvatar(String localPath) async {
    // Mock backend has no remote storage — the local file path is rendered
    // directly by [UserAvatar] via FileImage.
    return localPath;
  }

  /// Dev / demo selector hooks (mock backend only).
  Future<void> applyDemoPersona(String persona) async {
    await _prefs.setString(PrefsKeys.demoPersona, persona);
    switch (persona) {
      case 'guest':
        await _prefs.setBool('mock_is_pro', false);
        await continueAsGuest();
        break;
      case 'pro':
        await signInWithEmail(email: 'demo@app.com', password: '123456');
        await _prefs.setBool('mock_is_pro', true);
        break;
      default:
        await signInWithEmail(email: 'demo@app.com', password: '123456');
        await _prefs.setBool('mock_is_pro', false);
    }
  }

  void dispose() => _ctrl.close();
}

class AuthException implements Exception {
  AuthException(this.code);
  final String code;
}
