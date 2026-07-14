import 'dart:io';

import 'track_ref.dart';

/// Out-of-box mix and effects for new sessions (fuller, clearer output).
abstract final class MixerDefaults {
  /// iOS AVAudioEngine tends to run quieter; boost defaults 96% above Android base.
  static const _iosBoost = 1.96;
  static const _eqMaxDb = 12.0;
  static const _loudnessMaxDb = 12.0;

  /// Speech-forward EQ lift (60 Hz – 14 kHz).
  static const _baseFgEq = [2.0, 2.5, 3.0, 2.5, 2.0];
  static const _baseBgEq = [1.0, 1.5, 2.0, 1.5, 1.0];

  static const _baseFgBassBoost = 0.8;
  static const _baseBgBassBoost = 0.8;
  static const _baseFgVirtualizer = 0.5;
  static const _baseBgVirtualizer = 0.55;
  // Push perceptual gain to the ceiling by default so first-time playback is
  // full and clear on both tracks (previously left 2.4 dB of headroom unused).
  static const _baseFgLoudness = 12.0;
  static const _baseBgLoudness = 12.0;

  static const fgVolume = 1.0;
  // Background sat at half amplitude (~-6 dB) under the voice by default, which
  // read as too quiet out of the box — lift it so the ambience is audible.
  static const _baseBgVolume = 0.75;
  static const playbackSpeed = 1.0;

  static bool get _ios => Platform.isIOS;

  static List<double> get fgEq => List<double>.from(_ios ? _boostEq(_baseFgEq) : _baseFgEq);

  static List<double> get bgEq => List<double>.from(_ios ? _boostEq(_baseBgEq) : _baseBgEq);

  static double get fgBassBoost =>
      _ios ? (_baseFgBassBoost * _iosBoost).clamp(0.0, 1.0) : _baseFgBassBoost;

  static double get bgBassBoost =>
      _ios ? (_baseBgBassBoost * _iosBoost).clamp(0.0, 1.0) : _baseBgBassBoost;

  static double get fgVirtualizer =>
      _ios ? (_baseFgVirtualizer * _iosBoost).clamp(0.0, 1.0) : _baseFgVirtualizer;

  static double get bgVirtualizer =>
      _ios ? (_baseBgVirtualizer * _iosBoost).clamp(0.0, 1.0) : _baseBgVirtualizer;

  static double get fgLoudness => _ios
      ? (_baseFgLoudness * _iosBoost).clamp(0.0, _loudnessMaxDb)
      : _baseFgLoudness;

  static double get bgLoudness => _ios
      ? (_baseBgLoudness * _iosBoost).clamp(0.0, _loudnessMaxDb)
      : _baseBgLoudness;

  static double get bgVolume =>
      _ios ? (_baseBgVolume * _iosBoost).clamp(0.0, 1.0) : _baseBgVolume;

  static List<double> _boostEq(List<double> bands) => [
        for (final v in bands)
          ((v * _iosBoost).clamp(-_eqMaxDb, _eqMaxDb) * 10).roundToDouble() / 10,
      ];
}
class MixerDraft {
  MixerDraft({
    this.sessionId,
    this.title = 'Untitled session',
    this.foreground,
    this.background,
    this.notes,
    double? fgVolume,
    double? bgVolume,
  })  : fgVolume = fgVolume ?? MixerDefaults.fgVolume,
        bgVolume = bgVolume ?? MixerDefaults.bgVolume;

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
  MixerUiState({
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 180000,
    this.bgPositionMs = 0,
    this.bgDurationMs = 0,
    double? fgVolume,
    double? bgVolume,
    this.fgMuted = false,
    this.bgMuted = false,
    this.masterGain = 1,
    double? playbackSpeed,
    List<double>? fgEq,
    List<double>? bgEq,
    double? fgBassBoost,
    double? bgBassBoost,
    double? fgVirtualizer,
    double? bgVirtualizer,
    double? fgLoudness,
    double? bgLoudness,
    this.loading = false,
    this.error,
  })  : fgVolume = fgVolume ?? MixerDefaults.fgVolume,
        bgVolume = bgVolume ?? MixerDefaults.bgVolume,
        playbackSpeed = playbackSpeed ?? MixerDefaults.playbackSpeed,
        fgEq = fgEq ?? List<double>.from(MixerDefaults.fgEq),
        bgEq = bgEq ?? List<double>.from(MixerDefaults.bgEq),
        fgBassBoost = fgBassBoost ?? MixerDefaults.fgBassBoost,
        bgBassBoost = bgBassBoost ?? MixerDefaults.bgBassBoost,
        fgVirtualizer = fgVirtualizer ?? MixerDefaults.fgVirtualizer,
        bgVirtualizer = bgVirtualizer ?? MixerDefaults.bgVirtualizer,
        fgLoudness = fgLoudness ?? MixerDefaults.fgLoudness,
        bgLoudness = bgLoudness ?? MixerDefaults.bgLoudness;

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
