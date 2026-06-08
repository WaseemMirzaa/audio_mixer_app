import '../models/preset.dart';

abstract class PresetRepository {
  Future<List<MixerPreset>> listPresets();

  Future<MixerPreset?> getPreset(String presetId);

  Future<MixerPreset> savePreset(MixerPreset preset);

  Future<void> deletePreset(String presetId);

  Future<void> renamePreset({
    required String presetId,
    required String name,
  });

  Future<bool> canAddPreset({required bool isPro});
}
