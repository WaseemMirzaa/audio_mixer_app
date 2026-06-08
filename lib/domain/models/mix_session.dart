class MixSession {
  const MixSession({
    required this.sessionId,
    required this.uid,
    required this.title,
    required this.foregroundAudioId,
    required this.backgroundAudioId,
    required this.foregroundDisplayName,
    required this.backgroundDisplayName,
    required this.foregroundVolume,
    required this.backgroundVolume,
    required this.foregroundEq,
    required this.backgroundEq,
    required this.masterGain,
    required this.balance,
    required this.durationMs,
    required this.playbackPositionMs,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.notes,
    this.presetName,
    this.syncStatus = 'local',
    this.foregroundPath,
    this.backgroundPath,
    // Audio effects (defaults to 0 for backward-compat with old saved sessions)
    this.foregroundBassBoost = 0.0,
    this.backgroundBassBoost = 0.0,
    this.foregroundVirtualizer = 0.0,
    this.backgroundVirtualizer = 0.0,
    this.foregroundLoudness = 0.0,
    this.backgroundLoudness = 0.0,
    this.playbackSpeed = 1.0,
    this.isFavorite = false,
  });

  final String sessionId;
  final String uid;
  final String title;
  final String foregroundAudioId;
  final String backgroundAudioId;
  final String foregroundDisplayName;
  final String backgroundDisplayName;
  final double foregroundVolume;
  final double backgroundVolume;
  final List<double> foregroundEq;
  final List<double> backgroundEq;
  final double masterGain;
  final double balance;
  final int durationMs;
  final int playbackPositionMs;
  final int createdAtMs;
  final int updatedAtMs;
  final String? notes;
  final String? presetName;
  final String syncStatus;
  final String? foregroundPath;
  final String? backgroundPath;
  // Effects
  final double foregroundBassBoost;
  final double backgroundBassBoost;
  final double foregroundVirtualizer;
  final double backgroundVirtualizer;
  final double foregroundLoudness;
  final double backgroundLoudness;
  final double playbackSpeed;
  final bool isFavorite;

  MixSession copyWith({
    String? sessionId,
    String? uid,
    String? title,
    String? foregroundAudioId,
    String? backgroundAudioId,
    String? foregroundDisplayName,
    String? backgroundDisplayName,
    double? foregroundVolume,
    double? backgroundVolume,
    List<double>? foregroundEq,
    List<double>? backgroundEq,
    double? masterGain,
    double? balance,
    int? durationMs,
    int? playbackPositionMs,
    int? createdAtMs,
    int? updatedAtMs,
    String? notes,
    String? presetName,
    String? syncStatus,
    String? foregroundPath,
    String? backgroundPath,
    double? foregroundBassBoost,
    double? backgroundBassBoost,
    double? foregroundVirtualizer,
    double? backgroundVirtualizer,
    double? foregroundLoudness,
    double? backgroundLoudness,
    double? playbackSpeed,
    bool? isFavorite,
  }) {
    return MixSession(
      sessionId: sessionId ?? this.sessionId,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      foregroundAudioId: foregroundAudioId ?? this.foregroundAudioId,
      backgroundAudioId: backgroundAudioId ?? this.backgroundAudioId,
      foregroundDisplayName:
          foregroundDisplayName ?? this.foregroundDisplayName,
      backgroundDisplayName:
          backgroundDisplayName ?? this.backgroundDisplayName,
      foregroundVolume: foregroundVolume ?? this.foregroundVolume,
      backgroundVolume: backgroundVolume ?? this.backgroundVolume,
      foregroundEq: foregroundEq ?? List<double>.from(this.foregroundEq),
      backgroundEq: backgroundEq ?? List<double>.from(this.backgroundEq),
      masterGain: masterGain ?? this.masterGain,
      balance: balance ?? this.balance,
      durationMs: durationMs ?? this.durationMs,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      notes: notes ?? this.notes,
      presetName: presetName ?? this.presetName,
      syncStatus: syncStatus ?? this.syncStatus,
      foregroundPath: foregroundPath ?? this.foregroundPath,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      foregroundBassBoost: foregroundBassBoost ?? this.foregroundBassBoost,
      backgroundBassBoost: backgroundBassBoost ?? this.backgroundBassBoost,
      foregroundVirtualizer:
          foregroundVirtualizer ?? this.foregroundVirtualizer,
      backgroundVirtualizer:
          backgroundVirtualizer ?? this.backgroundVirtualizer,
      foregroundLoudness: foregroundLoudness ?? this.foregroundLoudness,
      backgroundLoudness: backgroundLoudness ?? this.backgroundLoudness,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'uid': uid,
        'title': title,
        'foregroundAudioId': foregroundAudioId,
        'backgroundAudioId': backgroundAudioId,
        'foregroundDisplayName': foregroundDisplayName,
        'backgroundDisplayName': backgroundDisplayName,
        'foregroundVolume': foregroundVolume,
        'backgroundVolume': backgroundVolume,
        'foregroundEq': foregroundEq,
        'backgroundEq': backgroundEq,
        'masterGain': masterGain,
        'balance': balance,
        'durationMs': durationMs,
        'playbackPositionMs': playbackPositionMs,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'notes': notes,
        'presetName': presetName,
        'syncStatus': syncStatus,
        'foregroundPath': foregroundPath,
        'backgroundPath': backgroundPath,
        'foregroundBassBoost': foregroundBassBoost,
        'backgroundBassBoost': backgroundBassBoost,
        'foregroundVirtualizer': foregroundVirtualizer,
        'backgroundVirtualizer': backgroundVirtualizer,
        'foregroundLoudness': foregroundLoudness,
        'backgroundLoudness': backgroundLoudness,
        'playbackSpeed': playbackSpeed,
        'isFavorite': isFavorite,
      };

  factory MixSession.fromJson(Map<String, dynamic> m) {
    List<double> eq(dynamic v) =>
        (v as List?)?.map((e) => (e as num).toDouble()).toList() ??
        List<double>.filled(5, 0);
    double d(String k, [double def = 0.0]) =>
        (m[k] as num?)?.toDouble() ?? def;

    return MixSession(
      sessionId: m['sessionId'] as String,
      uid: m['uid'] as String,
      title: m['title'] as String,
      foregroundAudioId: m['foregroundAudioId'] as String,
      backgroundAudioId: m['backgroundAudioId'] as String,
      foregroundDisplayName: m['foregroundDisplayName'] as String,
      backgroundDisplayName: m['backgroundDisplayName'] as String,
      foregroundVolume: d('foregroundVolume', 0.85),
      backgroundVolume: d('backgroundVolume', 0.45),
      foregroundEq: eq(m['foregroundEq']),
      backgroundEq: eq(m['backgroundEq']),
      masterGain: d('masterGain', 1.0),
      balance: d('balance'),
      durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
      playbackPositionMs: (m['playbackPositionMs'] as num?)?.toInt() ?? 0,
      createdAtMs: (m['createdAtMs'] as num).toInt(),
      updatedAtMs: (m['updatedAtMs'] as num).toInt(),
      notes: m['notes'] as String?,
      presetName: m['presetName'] as String?,
      syncStatus: m['syncStatus'] as String? ?? 'local',
      foregroundPath: m['foregroundPath'] as String?,
      backgroundPath: m['backgroundPath'] as String?,
      foregroundBassBoost: d('foregroundBassBoost'),
      backgroundBassBoost: d('backgroundBassBoost'),
      foregroundVirtualizer: d('foregroundVirtualizer'),
      backgroundVirtualizer: d('backgroundVirtualizer'),
      foregroundLoudness: d('foregroundLoudness'),
      backgroundLoudness: d('backgroundLoudness'),
      playbackSpeed: d('playbackSpeed', 1.0),
      isFavorite: m['isFavorite'] as bool? ?? false,
    );
  }
}
