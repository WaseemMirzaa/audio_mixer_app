import 'track_ref.dart';

class MixerDraft {
  const MixerDraft({
    this.sessionId,
    this.title = 'Untitled session',
    this.foreground,
    this.background,
    this.notes,
    this.fgVolume = 0.85,
    this.bgVolume = 0.45,
  });

  final String? sessionId;
  final String title;
  final TrackRef? foreground;
  final TrackRef? background;
  final String? notes;
  // Initial mix levels chosen on the New Session page.
  final double fgVolume;
  final double bgVolume;

  MixerDraft copyWith({
    String? sessionId,
    String? title,
    TrackRef? foreground,
    TrackRef? background,
    String? notes,
    double? fgVolume,
    double? bgVolume,
  }) {
    return MixerDraft(
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      notes: notes ?? this.notes,
      fgVolume: fgVolume ?? this.fgVolume,
      bgVolume: bgVolume ?? this.bgVolume,
    );
  }
}

class MixerUiState {
  const MixerUiState({
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 180000,
    this.bgPositionMs = 0,
    this.bgDurationMs = 0,
    this.fgVolume = 0.85,
    this.bgVolume = 0.45,
    this.fgMuted = false,
    this.bgMuted = false,
    this.masterGain = 1,
    this.playbackSpeed = 1.0,
    List<double>? fgEq,
    List<double>? bgEq,
    // Audio effects (0.0 – 1.0 unless noted)
    this.fgBassBoost = 0.0,
    this.bgBassBoost = 0.0,
    this.fgVirtualizer = 0.0,
    this.bgVirtualizer = 0.0,
    this.fgLoudness = 0.0, // extra gain in dB (0–12)
    this.bgLoudness = 0.0,
    this.loading = false,
    this.error,
  })  : fgEq = fgEq ?? const [0, 0, 0, 0, 0],
        bgEq = bgEq ?? const [0, 0, 0, 0, 0];

  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final int bgPositionMs;
  final int bgDurationMs;
  final double fgVolume;
  final double bgVolume;
  final bool fgMuted;
  final bool bgMuted;
  final double masterGain;
  final double playbackSpeed;
  final List<double> fgEq;
  final List<double> bgEq;
  // Effects
  final double fgBassBoost;
  final double bgBassBoost;
  final double fgVirtualizer;
  final double bgVirtualizer;
  final double fgLoudness;
  final double bgLoudness;
  final bool loading;
  final String? error;

  MixerUiState copyWith({
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    int? bgPositionMs,
    int? bgDurationMs,
    double? fgVolume,
    double? bgVolume,
    bool? fgMuted,
    bool? bgMuted,
    double? masterGain,
    double? playbackSpeed,
    List<double>? fgEq,
    List<double>? bgEq,
    double? fgBassBoost,
    double? bgBassBoost,
    double? fgVirtualizer,
    double? bgVirtualizer,
    double? fgLoudness,
    double? bgLoudness,
    bool? loading,
    String? error,
  }) {
    return MixerUiState(
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      bgPositionMs: bgPositionMs ?? this.bgPositionMs,
      bgDurationMs: bgDurationMs ?? this.bgDurationMs,
      fgVolume: fgVolume ?? this.fgVolume,
      bgVolume: bgVolume ?? this.bgVolume,
      fgMuted: fgMuted ?? this.fgMuted,
      bgMuted: bgMuted ?? this.bgMuted,
      masterGain: masterGain ?? this.masterGain,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      fgEq: fgEq ?? List<double>.from(this.fgEq),
      bgEq: bgEq ?? List<double>.from(this.bgEq),
      fgBassBoost: fgBassBoost ?? this.fgBassBoost,
      bgBassBoost: bgBassBoost ?? this.bgBassBoost,
      fgVirtualizer: fgVirtualizer ?? this.fgVirtualizer,
      bgVirtualizer: bgVirtualizer ?? this.bgVirtualizer,
      fgLoudness: fgLoudness ?? this.fgLoudness,
      bgLoudness: bgLoudness ?? this.bgLoudness,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}
