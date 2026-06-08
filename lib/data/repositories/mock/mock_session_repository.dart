import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/mix_session.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../local/prefs_keys.dart';

class MockSessionRepository implements SessionRepository {
  MockSessionRepository(this._prefs);

  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  // Returns saved sessions sorted newest-updated-first.
  // Falls back to empty list on any parse error — never injects fake data.
  List<MixSession> _load() {
    final raw = _prefs.getString(PrefsKeys.sessionsJson);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final sessions = list
          .map((e) => MixSession.fromJson(e as Map<String, dynamic>))
          .toList();
      sessions.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<MixSession> items) async {
    await _prefs.setString(
      PrefsKeys.sessionsJson,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<MixSession>> listSessions() async {
    return _load();
  }

  @override
  Future<MixSession?> getSession(String sessionId) async {
    try {
      return _load().firstWhere((e) => e.sessionId == sessionId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MixSession> upsertSession(MixSession session) async {
    final list = _load();
    var sid = session.sessionId;
    if (sid.isEmpty) sid = _uuid.v4();
    final normalized = session.copyWith(sessionId: sid);
    final i = list.indexWhere((e) => e.sessionId == normalized.sessionId);
    final next = normalized.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    if (i >= 0) {
      list[i] = next;
    } else {
      list.insert(0, next);
    }
    await _save(list);
    return next;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final list = _load()..removeWhere((e) => e.sessionId == sessionId);
    await _save(list);
  }

  @override
  Future<void> renameSession({
    required String sessionId,
    required String title,
  }) async {
    final list = _load();
    final i = list.indexWhere((e) => e.sessionId == sessionId);
    if (i < 0) return;
    list[i] = list[i].copyWith(
      title: title,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _save(list);
  }

  Future<void> clearAll() async {
    await _prefs.setString(PrefsKeys.sessionsJson, '[]');
  }
}
