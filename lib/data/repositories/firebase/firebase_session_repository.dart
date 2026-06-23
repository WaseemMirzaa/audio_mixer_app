import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../domain/models/mix_session.dart';
import '../../../domain/repositories/session_repository.dart';

class FirebaseSessionRepository implements SessionRepository {
  FirebaseSessionRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('mix_sessions');

  MixSession _fromDoc(String id, Map<String, dynamic> m) {
    List<double> eq(dynamic v) =>
        (v as List?)?.map((e) => (e as num).toDouble()).toList() ??
        List<double>.filled(5, 0);

    int ts(dynamic t) {
      if (t is Timestamp) return t.millisecondsSinceEpoch;
      if (t is int) return t;
      return DateTime.now().millisecondsSinceEpoch;
    }

    return MixSession(
      sessionId: id,
      uid: m['uid'] as String,
      title: m['title'] as String? ?? 'Untitled',
      foregroundAudioId: m['foregroundAudioId'] as String? ?? '',
      backgroundAudioId: m['backgroundAudioId'] as String? ?? '',
      foregroundDisplayName: m['foregroundDisplayName'] as String? ??
          m['foregroundAudioId'] as String? ??
          '',
      backgroundDisplayName: m['backgroundDisplayName'] as String? ??
          m['backgroundAudioId'] as String? ??
          '',
      foregroundVolume: (m['foregroundVolume'] as num?)?.toDouble() ?? 1,
      backgroundVolume: (m['backgroundVolume'] as num?)?.toDouble() ?? 1,
      foregroundEq: eq(m['foregroundEQ'] ?? m['foregroundEq']),
      backgroundEq: eq(m['backgroundEQ'] ?? m['backgroundEq']),
      masterGain: (m['masterGain'] as num?)?.toDouble() ?? 1,
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
      durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
      playbackPositionMs:
          (m['playbackPosition'] as num?)?.toInt() ??
              (m['playbackPositionMs'] as num?)?.toInt() ??
              0,
      createdAtMs: ts(m['createdAt']),
      updatedAtMs: ts(m['updatedAt']),
      notes: m['notes'] as String?,
      presetName: m['presetName'] as String?,
      syncStatus: m['syncStatus'] as String? ?? 'synced',
      foregroundPath: m['foregroundPath'] as String?,
      backgroundPath: m['backgroundPath'] as String?,
    );
  }

  Map<String, dynamic> _toMap(MixSession s) => {
        'sessionId': s.sessionId,
        'uid': s.uid,
        'title': s.title,
        'foregroundAudioId': s.foregroundAudioId,
        'backgroundAudioId': s.backgroundAudioId,
        'foregroundDisplayName': s.foregroundDisplayName,
        'backgroundDisplayName': s.backgroundDisplayName,
        'foregroundVolume': s.foregroundVolume,
        'backgroundVolume': s.backgroundVolume,
        'foregroundEQ': s.foregroundEq,
        'backgroundEQ': s.backgroundEq,
        'masterGain': s.masterGain,
        'balance': s.balance,
        'durationMs': s.durationMs,
        'playbackPosition': s.playbackPositionMs,
        'notes': s.notes,
        'presetName': s.presetName,
        'syncStatus': s.syncStatus,
        'foregroundPath': s.foregroundPath,
        'backgroundPath': s.backgroundPath,
        'isDeleted': false,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(s.createdAtMs),
        'updatedAt': Timestamp.fromMillisecondsSinceEpoch(s.updatedAtMs),
      };

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u.uid;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _col.doc(sessionId).update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<MixSession?> getSession(String sessionId) async {
    final doc = await _col.doc(sessionId).get();
    final m = doc.data();
    if (!doc.exists || m == null) return null;
    if ((m['uid'] as String?) != _uid) return null;
    return _fromDoc(doc.id, m);
  }

  @override
  Future<List<MixSession>> listSessions() async {
    final q = await _col.where('uid', isEqualTo: _uid).get();
    final list = q.docs
        .where((d) => (d.data()['isDeleted'] as bool?) != true)
        .map((d) => _fromDoc(d.id, d.data()))
        .toList();
    list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list;
  }

  @override
  Future<void> renameSession({
    required String sessionId,
    required String title,
  }) async {
    await _col.doc(sessionId).update({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<MixSession> upsertSession(MixSession session) async {
    final uid = _uid;
    var id = session.sessionId;
    if (id.isEmpty) {
      id = _col.doc().id;
    }
    final merged = (session.uid == uid ? session : session.copyWith(uid: uid))
        .copyWith(sessionId: id);
    await _col.doc(id).set(_toMap(merged), SetOptions(merge: true));
    return merged;
  }
}
