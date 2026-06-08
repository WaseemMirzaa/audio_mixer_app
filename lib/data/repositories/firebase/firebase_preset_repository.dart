import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../domain/models/preset.dart';
import '../../../domain/repositories/preset_repository.dart';

class FirebasePresetRepository implements PresetRepository {
  FirebasePresetRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('presets');

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u.uid;
  }

  MixerPreset _fromDoc(String id, Map<String, dynamic> m) {
    List<double> eq(dynamic v) =>
        (v as List?)?.map((e) => (e as num).toDouble()).toList() ??
        List<double>.filled(5, 0);

    int ts(dynamic t) {
      if (t is Timestamp) return t.millisecondsSinceEpoch;
      if (t is int) return t;
      return DateTime.now().millisecondsSinceEpoch;
    }

    return MixerPreset(
      presetId: id,
      uid: m['uid'] as String,
      name: m['name'] as String? ?? 'Preset',
      foregroundEq: eq(m['foregroundEQ'] ?? m['foregroundEq']),
      backgroundEq: eq(m['backgroundEQ'] ?? m['backgroundEq']),
      foregroundVolume:
          (m['foregroundVolume'] as num?)?.toDouble() ?? 1,
      backgroundVolume:
          (m['backgroundVolume'] as num?)?.toDouble() ?? 1,
      masterGain: (m['masterGain'] as num?)?.toDouble() ?? 1,
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
      createdAtMs: ts(m['createdAt']),
      updatedAtMs: ts(m['updatedAt']),
      isPremium: m['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _toMap(MixerPreset p) => {
        'presetId': p.presetId,
        'uid': p.uid,
        'name': p.name,
        'foregroundEQ': p.foregroundEq,
        'backgroundEQ': p.backgroundEq,
        'foregroundVolume': p.foregroundVolume,
        'backgroundVolume': p.backgroundVolume,
        'masterGain': p.masterGain,
        'balance': p.balance,
        'isPremium': p.isPremium,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(p.createdAtMs),
        'updatedAt': Timestamp.fromMillisecondsSinceEpoch(p.updatedAtMs),
      };

  @override
  Future<bool> canAddPreset({required bool isPro}) async {
    if (isPro) return true;
    final q = await _col.where('uid', isEqualTo: _uid).get();
    return q.docs.length < 3;
  }

  @override
  Future<void> deletePreset(String presetId) async {
    await _col.doc(presetId).delete();
  }

  @override
  Future<MixerPreset?> getPreset(String presetId) async {
    final doc = await _col.doc(presetId).get();
    final m = doc.data();
    if (!doc.exists || m == null) return null;
    if ((m['uid'] as String?) != _uid) return null;
    return _fromDoc(doc.id, m);
  }

  @override
  Future<List<MixerPreset>> listPresets() async {
    final q = await _col.where('uid', isEqualTo: _uid).get();
    final list = q.docs.map((d) => _fromDoc(d.id, d.data())).toList();
    list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return list;
  }

  @override
  Future<void> renamePreset({
    required String presetId,
    required String name,
  }) async {
    await _col.doc(presetId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<MixerPreset> savePreset(MixerPreset preset) async {
    final uid = _uid;
    var id = preset.presetId;
    if (id.isEmpty) {
      id = _col.doc().id;
    }
    final merged =
        (preset.uid == uid ? preset : preset.copyWith(uid: uid)).copyWith(
      presetId: id,
    );
    await _col.doc(id).set(_toMap(merged), SetOptions(merge: true));
    return merged;
  }
}
