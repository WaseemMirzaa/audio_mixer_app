class MixerPreset {
  const MixerPreset({
    required this.presetId,
    required this.uid,
    required this.name,
    required this.foregroundEq,
    required this.backgroundEq,
    required this.foregroundVolume,
    required this.backgroundVolume,
    required this.masterGain,
    required this.balance,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.isPremium = false,
  });

  final String presetId;
  final String uid;
  final String name;
  final List<double> foregroundEq;
  final List<double> backgroundEq;
  final double foregroundVolume;
  final double backgroundVolume;
  final double masterGain;
  final double balance;
  final int createdAtMs;
  final int updatedAtMs;
  final bool isPremium;

  MixerPreset copyWith({
    String? presetId,
    String? uid,
    String? name,
    List<double>? foregroundEq,
    List<double>? backgroundEq,
    double? foregroundVolume,
    double? backgroundVolume,
    double? masterGain,
    double? balance,
    int? createdAtMs,
    int? updatedAtMs,
    bool? isPremium,
  }) {
    return MixerPreset(
      presetId: presetId ?? this.presetId,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      foregroundEq: foregroundEq ?? List<double>.from(this.foregroundEq),
      backgroundEq: backgroundEq ?? List<double>.from(this.backgroundEq),
      foregroundVolume: foregroundVolume ?? this.foregroundVolume,
      backgroundVolume: backgroundVolume ?? this.backgroundVolume,
      masterGain: masterGain ?? this.masterGain,
      balance: balance ?? this.balance,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  Map<String, dynamic> toJson() => {
        'presetId': presetId,
        'uid': uid,
        'name': name,
        'foregroundEq': foregroundEq,
        'backgroundEq': backgroundEq,
        'foregroundVolume': foregroundVolume,
        'backgroundVolume': backgroundVolume,
        'masterGain': masterGain,
        'balance': balance,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'isPremium': isPremium,
      };

  factory MixerPreset.fromJson(Map<String, dynamic> m) {
    List<double> eq(dynamic v) =>
        (v as List?)?.map((e) => (e as num).toDouble()).toList() ??
        List<double>.filled(5, 0);

    return MixerPreset(
      presetId: m['presetId'] as String,
      uid: m['uid'] as String,
      name: m['name'] as String,
      foregroundEq: eq(m['foregroundEq']),
      backgroundEq: eq(m['backgroundEq']),
      foregroundVolume: (m['foregroundVolume'] as num).toDouble(),
      backgroundVolume: (m['backgroundVolume'] as num).toDouble(),
      masterGain: (m['masterGain'] as num?)?.toDouble() ?? 1,
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
      createdAtMs: (m['createdAtMs'] as num).toInt(),
      updatedAtMs: (m['updatedAtMs'] as num).toInt(),
      isPremium: m['isPremium'] as bool? ?? false,
    );
  }
}
