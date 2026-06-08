import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_effects_channel.dart';

/// Manages two synchronized [AudioPlayer] instances (foreground + background
/// tracks) and exposes the streams the UI needs.
///
/// **Android**: native AudioEffect objects (EQ, BassBoost, Virtualizer,
/// LoudnessEnhancer) are attached to each player's audio session.
///
/// **iOS**: just_audio handles position tracking and the lock-screen
/// notification while AVAudioEngine (via [AudioEffectsChannel]) handles actual
/// audio output with AVAudioUnitEQ effects applied. just_audio is set to
/// volume 0 on iOS so audio is not doubled.
///
/// The background player loops automatically so a short ambient clip keeps
/// playing for as long as the (typically longer) foreground audiobook runs.
class MixerAudioService {
  final _fg = AudioPlayer();
  final _bg = AudioPlayer();

  String? _loadedFgSource;
  String? _loadedBgSource;
  bool _disposed = false;

  // Cached volumes for iOS engine sync.
  double _fgVol = 0.85;
  double _bgVol = 0.45;

  // Android audio session IDs.
  int? _fgSessionId;
  int? _bgSessionId;

  // ── Public streams ──────────────────────────────────────────────────────────

  Stream<Duration> get positionStream => _fg.positionStream;
  Stream<bool> get playingStream => _fg.playingStream;
  bool get isPlaying => _fg.playing;
  Duration? get fgDuration => _fg.duration;

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> load({
    required String fgSource,
    required String bgSource,
    required String fgTitle,
    required String bgTitle,
    int startPositionMs = 0,
  }) async {
    if (_disposed) return;

    final alreadyLoaded =
        _loadedFgSource == fgSource && _loadedBgSource == bgSource;
    if (alreadyLoaded) return;

    // Configure audio session for media playback (focus, interruptions, etc.)
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.interruptionEventStream.listen((event) {
      if (_disposed) return;
      if (event.begin) {
        _fg.pause();
        _bg.pause();
        if (Platform.isIOS) {
          AudioEffectsChannel.pauseTrack(trackId: 'fg');
          AudioEffectsChannel.pauseTrack(trackId: 'bg');
        }
      } else if (event.type == AudioInterruptionType.pause ||
          event.type == AudioInterruptionType.duck) {
        _fg.play();
        _bg.play();
        if (Platform.isIOS) {
          AudioEffectsChannel.playTrack(trackId: 'fg');
          AudioEffectsChannel.playTrack(trackId: 'bg');
        }
      }
    });

    // Close existing native effects before reloading.
    await Future.wait([
      AudioEffectsChannel.closeEffects(trackId: 'fg'),
      AudioEffectsChannel.closeEffects(trackId: 'bg'),
    ]);

    await Future.wait([
      _fg.setAudioSource(AudioSource.uri(_toUri(fgSource))),
      _bg.setAudioSource(AudioSource.uri(_toUri(bgSource))),
    ]);

    // Background track loops so a short ambient clip never stops.
    await _bg.setLoopMode(LoopMode.one);

    if (startPositionMs > 0) {
      final pos = Duration(milliseconds: startPositionMs);
      await _fg.seek(pos);
    }

    _loadedFgSource = fgSource;
    _loadedBgSource = bgSource;

    if (Platform.isAndroid) {
      // Attach Android native audio effects to each player's session.
      _fgSessionId = _fg.androidAudioSessionId;
      _bgSessionId = _bg.androidAudioSessionId;
      if (_fgSessionId != null && _fgSessionId != 0) {
        await AudioEffectsChannel.openEffects(
            trackId: 'fg', sessionId: _fgSessionId!);
      }
      if (_bgSessionId != null && _bgSessionId != 0) {
        await AudioEffectsChannel.openEffects(
            trackId: 'bg', sessionId: _bgSessionId!);
      }
    } else if (Platform.isIOS) {
      // Open iOS AVAudioEngine pipelines, then load files into them.
      await Future.wait([
        AudioEffectsChannel.openEffects(trackId: 'fg', sessionId: 0),
        AudioEffectsChannel.openEffects(trackId: 'bg', sessionId: 0),
      ]);
      await Future.wait([
        AudioEffectsChannel.setTrackFile(trackId: 'fg', path: fgSource),
        AudioEffectsChannel.setTrackFile(
            trackId: 'bg', path: bgSource, looping: true),
      ]);
      // just_audio is muted on iOS — AVAudioEngine outputs the real audio.
      await Future.wait([
        _fg.setVolume(0),
        _bg.setVolume(0),
      ]);
      if (startPositionMs > 0) {
        await Future.wait([
          AudioEffectsChannel.seekTrack(
              trackId: 'fg', positionMs: startPositionMs),
          AudioEffectsChannel.seekTrack(
              trackId: 'bg', positionMs: startPositionMs),
        ]);
      }
    }
  }

  // ── Playback controls ───────────────────────────────────────────────────────

  Future<void> play() async {
    if (_disposed) return;
    await Future.wait([_fg.play(), _bg.play()]);
    if (Platform.isIOS) {
      await Future.wait([
        AudioEffectsChannel.playTrack(trackId: 'fg'),
        AudioEffectsChannel.playTrack(trackId: 'bg'),
      ]);
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    await Future.wait([_fg.pause(), _bg.pause()]);
    if (Platform.isIOS) {
      await Future.wait([
        AudioEffectsChannel.pauseTrack(trackId: 'fg'),
        AudioEffectsChannel.pauseTrack(trackId: 'bg'),
      ]);
    }
  }

  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    await Future.wait([_fg.setSpeed(speed), _bg.setSpeed(speed)]);
    if (Platform.isIOS) {
      await Future.wait([
        AudioEffectsChannel.setSpeedIOS(trackId: 'fg', speed: speed),
        AudioEffectsChannel.setSpeedIOS(trackId: 'bg', speed: speed),
      ]);
    }
  }

  /// Seek foreground to [position]. Background loops freely.
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await _fg.seek(position);
    if (Platform.isIOS) {
      await AudioEffectsChannel.seekTrack(
          trackId: 'fg', positionMs: position.inMilliseconds);
    }
  }

  // ── Volume / mute / master ─────────────────────────────────────────────────

  void applyVolumes({
    required double fgVolume,
    required bool fgMuted,
    required double bgVolume,
    required bool bgMuted,
    required double masterGain,
  }) {
    if (_disposed) return;
    _fgVol = (fgMuted ? 0.0 : fgVolume * masterGain).clamp(0.0, 1.0);
    _bgVol = (bgMuted ? 0.0 : bgVolume * masterGain).clamp(0.0, 1.0);
    if (Platform.isIOS) {
      // On iOS just_audio is muted; set volume on the AVAudioEngine mixers.
      AudioEffectsChannel.setVolume(trackId: 'fg', volume: _fgVol);
      AudioEffectsChannel.setVolume(trackId: 'bg', volume: _bgVol);
    } else {
      _fg.setVolume(_fgVol);
      _bg.setVolume(_bgVol);
    }
  }

  // ── Native audio effects ────────────────────────────────────────────────────

  Future<void> applyFgEq(List<double> levels) =>
      AudioEffectsChannel.setEqBands(trackId: 'fg', levels: levels);

  Future<void> applyBgEq(List<double> levels) =>
      AudioEffectsChannel.setEqBands(trackId: 'bg', levels: levels);

  Future<void> applyFgBassBoost(double strength) =>
      AudioEffectsChannel.setBassBoost(trackId: 'fg', strength: strength);

  Future<void> applyBgBassBoost(double strength) =>
      AudioEffectsChannel.setBassBoost(trackId: 'bg', strength: strength);

  Future<void> applyFgVirtualizer(double strength) =>
      AudioEffectsChannel.setVirtualizer(trackId: 'fg', strength: strength);

  Future<void> applyBgVirtualizer(double strength) =>
      AudioEffectsChannel.setVirtualizer(trackId: 'bg', strength: strength);

  Future<void> applyFgLoudness(double gainDb) =>
      AudioEffectsChannel.setLoudness(trackId: 'fg', gainDb: gainDb);

  Future<void> applyBgLoudness(double gainDb) =>
      AudioEffectsChannel.setLoudness(trackId: 'bg', gainDb: gainDb);

  Future<void> applyAllEffects({
    required List<double> fgEq,
    required List<double> bgEq,
    required double fgBassBoost,
    required double bgBassBoost,
    required double fgVirtualizer,
    required double bgVirtualizer,
    required double fgLoudness,
    required double bgLoudness,
  }) async {
    await Future.wait([
      applyFgEq(fgEq),
      applyBgEq(bgEq),
      applyFgBassBoost(fgBassBoost),
      applyBgBassBoost(bgBassBoost),
      applyFgVirtualizer(fgVirtualizer),
      applyBgVirtualizer(bgVirtualizer),
      applyFgLoudness(fgLoudness),
      applyBgLoudness(bgLoudness),
    ]);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _disposed = true;
    await Future.wait([
      AudioEffectsChannel.closeEffects(trackId: 'fg'),
      AudioEffectsChannel.closeEffects(trackId: 'bg'),
    ]);
    await Future.wait([_fg.dispose(), _bg.dispose()]);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Uri _toUri(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Uri.parse(source);
    }
    return Uri.file(source);
  }
}
