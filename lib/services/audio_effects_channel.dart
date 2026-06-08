import 'dart:io';

import 'package:flutter/services.dart';

/// Dart wrapper around the native audio effects MethodChannel.
///
/// On Android: uses Android AudioEffect session IDs (EQ, BassBoost, Virtualizer,
/// LoudnessEnhancer via android.media.audiofx.*).
///
/// On iOS: uses AVAudioEngine with AVAudioUnitEQ per track. Playback is managed
/// by the native engine so call [setTrackFile] + [playTrack] after [openEffects].
///
/// On other platforms: all methods are no-ops.
class AudioEffectsChannel {
  static const _ch =
      MethodChannel('com.example.audio_mixer_app/audio_effects');

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  // ── Open / close ─────────────────────────────────────────────────────────

  /// Android: opens effects for [sessionId].
  /// iOS: [sessionId] is ignored — follow up with [setTrackFile].
  static Future<int?> openEffects({
    required String trackId,
    required int sessionId,
  }) async {
    if (!_supported) return null;
    try {
      final bands = await _ch.invokeMethod<int>('openEffects', {
        'trackId': trackId,
        'sessionId': sessionId,
      });
      return bands;
    } catch (_) {
      return null;
    }
  }

  static Future<void> closeEffects({required String trackId}) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('closeEffects', {'trackId': trackId});
    } catch (_) {}
  }

  // ── iOS-only: AVAudioEngine playback ─────────────────────────────────────

  /// iOS only. Loads [path] into the native AVAudioEngine for [trackId].
  /// Must be called before [playTrack]. No-op on Android.
  static Future<void> setTrackFile({
    required String trackId,
    required String path,
    bool looping = false,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod<void>('setTrackFile', {
        'trackId': trackId,
        'path': path,
        'looping': looping,
      });
    } catch (_) {}
  }

  /// iOS only. Starts or resumes playback of [trackId] through AVAudioEngine.
  static Future<void> playTrack({required String trackId}) async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod<void>('playTrack', {'trackId': trackId});
    } catch (_) {}
  }

  /// iOS only. Pauses [trackId] and saves playhead position.
  static Future<void> pauseTrack({required String trackId}) async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod<void>('pauseTrack', {'trackId': trackId});
    } catch (_) {}
  }

  /// iOS only. Seeks [trackId] to [positionMs].
  static Future<void> seekTrack({
    required String trackId,
    required int positionMs,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod<void>('seekTrack', {
        'trackId': trackId,
        'positionMs': positionMs,
      });
    } catch (_) {}
  }

  /// iOS only. Returns the current playhead position of [trackId] in ms.
  static Future<int> getPosition({required String trackId}) async {
    if (!Platform.isIOS) return 0;
    try {
      return await _ch.invokeMethod<int>('getPosition', {'trackId': trackId}) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// iOS only. Sets the output volume of [trackId]'s engine mixer.
  static Future<void> setVolume({
    required String trackId,
    required double volume,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod<void>('setVolume', {
        'trackId': trackId,
        'volume': volume,
      });
    } catch (_) {}
  }

  /// iOS only. Sets playback speed for [trackId] via AVAudioUnitTimePitch.
  static Future<void> setSpeedIOS({
    required String trackId,
    required double speed,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod<void>('setSpeed', {
        'trackId': trackId,
        'speed': speed,
      });
    } catch (_) {}
  }

  // ── 5-Band EQ ────────────────────────────────────────────────────────────

  /// [levels] is a list of dB values (±12 dB) — one per band.
  static Future<void> setEqBands({
    required String trackId,
    required List<double> levels,
  }) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('setEqBands', {
        'trackId': trackId,
        'levels': levels,
      });
    } catch (_) {}
  }

  // ── Bass Boost ────────────────────────────────────────────────────────────

  /// [strength] in 0.0–1.0.
  static Future<void> setBassBoost({
    required String trackId,
    required double strength,
  }) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('setBassBoost', {
        'trackId': trackId,
        'strength': strength,
      });
    } catch (_) {}
  }

  // ── Virtualizer (3-D stereo widening) ────────────────────────────────────

  /// [strength] in 0.0–1.0.
  static Future<void> setVirtualizer({
    required String trackId,
    required double strength,
  }) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('setVirtualizer', {
        'trackId': trackId,
        'strength': strength,
      });
    } catch (_) {}
  }

  // ── Loudness Enhancer ─────────────────────────────────────────────────────

  /// [gainDb] in 0.0–12.0 dB above unity.
  static Future<void> setLoudness({
    required String trackId,
    required double gainDb,
  }) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('setLoudness', {
        'trackId': trackId,
        'gainDb': gainDb,
      });
    } catch (_) {}
  }

  // ── Enable / disable ──────────────────────────────────────────────────────

  static Future<void> setEnabled({
    required String trackId,
    required bool enabled,
  }) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('setEnabled', {
        'trackId': trackId,
        'enabled': enabled,
      });
    } catch (_) {}
  }
}
