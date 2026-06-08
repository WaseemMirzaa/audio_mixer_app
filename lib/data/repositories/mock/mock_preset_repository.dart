import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../remote/mock_seed_api.dart';
import '../../../domain/models/preset.dart';
import '../../../domain/repositories/preset_repository.dart';
import '../../local/prefs_keys.dart';

class MockPresetRepository implements PresetRepository {
  MockPresetRepository(this._prefs);

  final SharedPreferences _prefs;
  final _uuid = const Uuid();
  final _seedApi = MockSeedApi();

  List<MixerPreset> _load() {
    final raw = _prefs.getString(PrefsKeys.presetsJson);
    if (raw == null) return _seed();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MixerPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seed();
    }
  }

  List<MixerPreset> _seed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      MixerPreset(
        presetId: 'pre_warm',
        uid: 'demo_uid',
        name: 'Warm vocals',
        foregroundEq: const [1, 2, 2, 1, 0],
        backgroundEq: const [-2, -1, 0, 1, 2],
        foregroundVolume: 0.95,
        backgroundVolume: 0.4,
        masterGain: 1,
        balance: 0,
        createdAtMs: now - 86400000,
        updatedAtMs: now - 86400000,
      ),
      MixerPreset(
        presetId: 'pre_air',
        uid: 'demo_uid',
        name: 'Air & space',
        foregroundEq: const [-1, -1, 0, 2, 3],
        backgroundEq: const [2, 1, 0, -1, -2],
        foregroundVolume: 0.75,
        backgroundVolume: 0.55,
        masterGain: 0.92,
        balance: -0.05,
        createdAtMs: now - 43200000,
        updatedAtMs: now - 43200000,
        isPremium: true,
      ),
    ];
  }

  Future<void> _save(List<MixerPreset> items) async {
    await _prefs.setString(
      PrefsKeys.presetsJson,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<bool> canAddPreset({required bool isPro}) async {
    final count = _load().length;
    if (isPro) return true;
    return count < 3;
  }

  @override
  Future<void> deletePreset(String presetId) async {
    final list = _load()..removeWhere((e) => e.presetId == presetId);
    await _save(list);
  }

  @override
  Future<MixerPreset?> getPreset(String presetId) async {
    try {
      return _load().firstWhere((e) => e.presetId == presetId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MixerPreset>> listPresets() async {
    final raw = _prefs.getString(PrefsKeys.presetsJson);
    if (raw == null) {
      final internet = await _tryInternetSeed();
      if (internet.isNotEmpty) {
        await _save(internet);
        return internet;
      }
      final local = _seed();
      await _save(local);
      return local;
    }
    return _load();
  }

  @override
  Future<void> renamePreset({
    required String presetId,
    required String name,
  }) async {
    final list = _load();
    final i = list.indexWhere((e) => e.presetId == presetId);
    if (i < 0) return;
    final p = list[i];
    list[i] = MixerPreset(
      presetId: p.presetId,
      uid: p.uid,
      name: name,
      foregroundEq: p.foregroundEq,
      backgroundEq: p.backgroundEq,
      foregroundVolume: p.foregroundVolume,
      backgroundVolume: p.backgroundVolume,
      masterGain: p.masterGain,
      balance: p.balance,
      createdAtMs: p.createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      isPremium: p.isPremium,
    );
    await _save(list);
  }

  @override
  Future<MixerPreset> savePreset(MixerPreset preset) async {
    final list = _load();
    final i = list.indexWhere((e) => e.presetId == preset.presetId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = MixerPreset(
      presetId: preset.presetId.isEmpty ? _uuid.v4() : preset.presetId,
      uid: preset.uid,
      name: preset.name,
      foregroundEq: preset.foregroundEq,
      backgroundEq: preset.backgroundEq,
      foregroundVolume: preset.foregroundVolume,
      backgroundVolume: preset.backgroundVolume,
      masterGain: preset.masterGain,
      balance: preset.balance,
      createdAtMs: i >= 0 ? preset.createdAtMs : now,
      updatedAtMs: now,
      isPremium: preset.isPremium,
    );
    if (i >= 0) {
      list[i] = next;
    } else {
      list.insert(0, next);
    }
    await _save(list);
    return next;
  }

  Future<void> clearAll() async {
    await _prefs.setString(PrefsKeys.presetsJson, '[]');
  }

  Future<List<MixerPreset>> _tryInternetSeed() async {
    try {
      return await _seedApi.fetchPresetSeeds(
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return [];
    }
  }
}
