import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_effects_channel.dart';

/// A [BaseAudioHandler] that manages two [AudioPlayer] instances simultaneously
/// (foreground audiobook + background ambient) and wires them into the Android /
/// iOS media session so lock-screen controls and notifications work.
///
/// Audio effects (EQ, BassBoost, Virtualizer, LoudnessEnhancer) are applied
/// via [AudioEffectsChannel]:
///   - Android: native AudioEffect session IDs
///   - iOS:     AVAudioEngine pipeline
class MixerAudioHandler extends BaseAudioHandler with SeekHandler {
  final _fg = AudioPlayer();
  final _bg = AudioPlayer();

  String? _loadedFgSource;
  String? _loadedBgSource;
  bool _disposed = false;
  bool _iosNativeReady = false;
  bool _pausedByInterruption = false;
  bool _interruptionsBound = false;

  double _fgVol = 1.0;
  double _bgVol = 0.5;
  bool _fgLoop = false;

  MixerAudioHandler() {
    _fg.playbackEventStream.listen((_) => _broadcastState());
    _fg.playerStateStream.listen((state) {
      // When FG finishes (loop off), reset both tracks to the start and pause
      // so the player returns to a clean, replayable state. (With loop on,
      // LoopMode.one restarts automatically and completed never fires.)
      if (state.processingState == ProcessingState.completed && !_disposed) {
        _handleCompletion();
      }
      _broadcastState();
    });
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    if (_interruptionsBound || _disposed) return;
    _interruptionsBound = true;
    session.interruptionEventStream.listen((event) {
      if (_disposed) return;
      if (event.begin) {
        // Only mark for auto-resume if we were actually playing when the call
        // started — not if the user had already paused.
        if (_fg.playing) {
          _pausedByInterruption = true;
          _pauseBoth();
        }
      } else if (_pausedByInterruption &&
          (event.type == AudioInterruptionType.pause ||
              event.type == AudioInterruptionType.duck)) {
        _pausedByInterruption = false;
        _playBoth();
      } else {
        _pausedByInterruption = false;
      }
    });
  }

  // ── Public streams (same API as the old MixerAudioService) ─────────────────

  Stream<Duration> get positionStream => _fg.positionStream;
  Stream<Duration> get bgPositionStream => _bg.positionStream;
  Stream<bool> get playingStream => _fg.playingStream;
  bool get isPlaying => _fg.playing;
  Duration? get fgDuration => _fg.duration;
  Duration? get bgDuration => _bg.duration;

  // ── Load ─────────────────────────────────────────────────────────────────────

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

    await _initAudioSession();
    if (Platform.isAndroid) {
      await Future.wait([
        AudioEffectsChannel.closeEffects(trackId: 'fg'),
        AudioEffectsChannel.closeEffects(trackId: 'bg'),
      ]);
    } else if (Platform.isIOS) {
      await Future.wait([
        AudioEffectsChannel.closeEffects(trackId: 'fg'),
        AudioEffectsChannel.closeEffects(trackId: 'bg'),
      ]);
      _iosNativeReady = false;
    }

    try {
      await Future.wait([
        _fg.setAudioSource(AudioSource.uri(_toUri(fgSource))),
        _bg.setAudioSource(AudioSource.uri(_toUri(bgSource))),
      ]);
    } on PlayerInterruptedException {
      // A newer load() (or a dispose/pause) superseded this one while the
      // sources were still loading — abort this stale load quietly.
      return;
    }
    if (_disposed) return;

    await _bg.setLoopMode(LoopMode.one);

    if (startPositionMs > 0) {
      await _fg.seek(Duration(milliseconds: startPositionMs));
    }

    _loadedFgSource = fgSource;
    _loadedBgSource = bgSource;

    // Update lock-screen / notification media item.
    mediaItem.add(MediaItem(
      id: fgSource,
      title: fgTitle,
      artist: 'Background: $bgTitle',
      duration: _fg.duration,
    ));

    if (Platform.isAndroid) {
      await _openAndroidEffects();
    } else if (Platform.isIOS) {
      final fgBands = await AudioEffectsChannel.openEffects(
        trackId: 'fg',
        sessionId: 0,
      );
      final bgBands = await AudioEffectsChannel.openEffects(
        trackId: 'bg',
        sessionId: 0,
      );
      if (fgBands != null && bgBands != null) {
        final fgOk = await AudioEffectsChannel.setTrackFile(
          trackId: 'fg',
          path: fgSource,
        );
        final bgOk = await AudioEffectsChannel.setTrackFile(
          trackId: 'bg',
          path: bgSource,
          looping: true,
        );
        _iosNativeReady = fgOk && bgOk;
        if (_iosNativeReady) {
          // Native AVAudioEngine owns audible output; just_audio stays muted
          // for position / duration / UI sync only.
          await Future.wait([_fg.setVolume(0), _bg.setVolume(0)]);
          if (startPositionMs > 0) {
            await Future.wait([
              AudioEffectsChannel.seekTrack(
                  trackId: 'fg', positionMs: startPositionMs),
              AudioEffectsChannel.seekTrack(
                  trackId: 'bg', positionMs: startPositionMs),
            ]);
          }
        } else {
          await Future.wait([_fg.setVolume(_fgVol), _bg.setVolume(_bgVol)]);
        }
      } else {
        await Future.wait([_fg.setVolume(_fgVol), _bg.setVolume(_bgVol)]);
      }
    }
  }

  /// Fall back to just_audio output when native engine fails on iOS.
  Future<void> _iosFallbackToJustAudio() async {
    _iosNativeReady = false;
    await Future.wait([_fg.setVolume(_fgVol), _bg.setVolume(_bgVol)]);
  }

  /// Android session IDs can be 0 briefly after setAudioSource — retry attach.
  Future<void> _openAndroidEffects() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (_disposed) return;
      final fgSid = _fg.androidAudioSessionId;
      final bgSid = _bg.androidAudioSessionId;
      if (fgSid != null && fgSid != 0) {
        await AudioEffectsChannel.openEffects(trackId: 'fg', sessionId: fgSid);
      }
      if (bgSid != null && bgSid != 0) {
        await AudioEffectsChannel.openEffects(trackId: 'bg', sessionId: bgSid);
      }
      if (fgSid != null && fgSid != 0 && bgSid != null && bgSid != 0) return;
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  // ── BaseAudioHandler overrides (media session controls) ────────────────────

  @override
  Future<void> play() => _playBoth();

  @override
  Future<void> pause() => _pauseBoth();

  @override
  Future<void> seek(Duration position) => _seekFg(position);

  @override
  Future<void> stop() async {
    await _pauseBoth();
    await super.stop();
  }

  // ── Internal playback helpers ───────────────────────────────────────────────

  Future<void> _playBoth() async {
    if (_disposed) return;
    _pausedByInterruption = false;
    final session = await AudioSession.instance;
    await session.setActive(true);
    // just_audio leaves a completed track at its end and won't restart on
    // play() — rewind to the start first so the play button always works.
    if (_fg.processingState == ProcessingState.completed) {
      await _fg.seek(Duration.zero);
      if (Platform.isIOS && _iosNativeReady) {
        await AudioEffectsChannel.seekTrack(trackId: 'fg', positionMs: 0);
      }
    }
    if (Platform.isIOS && _iosNativeReady) {
      final fgOk = await AudioEffectsChannel.playTrack(trackId: 'fg');
      final bgOk = await AudioEffectsChannel.playTrack(trackId: 'bg');
      if (!fgOk || !bgOk) {
        await _iosFallbackToJustAudio();
      }
      await Future.wait([_fg.play(), _bg.play()]);
    } else {
      await Future.wait([_fg.play(), _bg.play()]);
    }
  }

  Future<void> _pauseBoth() async {
    if (_disposed) return;
    await Future.wait([_fg.pause(), _bg.pause()]);
    if (Platform.isIOS && _iosNativeReady) {
      await Future.wait([
        AudioEffectsChannel.pauseTrack(trackId: 'fg'),
        AudioEffectsChannel.pauseTrack(trackId: 'bg'),
      ]);
    }
  }

  Future<void> _seekFg(Duration position) async {
    if (_disposed) return;
    await _fg.seek(position);
    if (Platform.isIOS && _iosNativeReady) {
      await AudioEffectsChannel.seekTrack(
          trackId: 'fg', positionMs: position.inMilliseconds);
    }
  }

  /// Repeat the foreground (audiobook) track when it finishes.
  Future<void> setFgLoop(bool enabled) async {
    if (_disposed) return;
    _fgLoop = enabled;
    await _fg.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
  }

  Future<void> seekBg(Duration position) async {
    if (_disposed) return;
    await _bg.seek(position);
    if (Platform.isIOS && _iosNativeReady) {
      await AudioEffectsChannel.seekTrack(
          trackId: 'bg', positionMs: position.inMilliseconds);
    }
  }

  /// FG reached the end (loop off): pause both tracks and rewind to the start
  /// so the player shows a play button at 0:00 and is ready to replay.
  Future<void> _handleCompletion() async {
    if (_fgLoop) return;
    await Future.wait([_fg.pause(), _bg.pause()]);
    await Future.wait([_fg.seek(Duration.zero), _bg.seek(Duration.zero)]);
    if (Platform.isIOS && _iosNativeReady) {
      await Future.wait([
        AudioEffectsChannel.pauseTrack(trackId: 'fg'),
        AudioEffectsChannel.pauseTrack(trackId: 'bg'),
        AudioEffectsChannel.seekTrack(trackId: 'fg', positionMs: 0),
        AudioEffectsChannel.seekTrack(trackId: 'bg', positionMs: 0),
      ]);
    }
  }

  // ── Speed ─────────────────────────────────────────────────────────────────

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    await Future.wait([_fg.setSpeed(speed), _bg.setSpeed(speed)]);
    if (Platform.isIOS && _iosNativeReady) {
      await Future.wait([
        AudioEffectsChannel.setSpeedIOS(trackId: 'fg', speed: speed),
        AudioEffectsChannel.setSpeedIOS(trackId: 'bg', speed: speed),
      ]);
    }
  }

  // ── Volume / mute / master ────────────────────────────────────────────────

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
    if (Platform.isIOS && _iosNativeReady) {
      AudioEffectsChannel.setVolume(trackId: 'fg', volume: _fgVol);
      AudioEffectsChannel.setVolume(trackId: 'bg', volume: _bgVol);
    } else {
      _fg.setVolume(_fgVol);
      _bg.setVolume(_bgVol);
    }
  }

  // ── Effects ────────────────────────────────────────────────────────────────

  Future<void> applyFgEq(List<double> levels) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setEqBands(trackId: 'fg', levels: levels);
  }

  Future<void> applyBgEq(List<double> levels) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setEqBands(trackId: 'bg', levels: levels);
  }

  Future<void> applyFgBassBoost(double strength) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setBassBoost(trackId: 'fg', strength: strength);
  }

  Future<void> applyBgBassBoost(double strength) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setBassBoost(trackId: 'bg', strength: strength);
  }

  Future<void> applyFgVirtualizer(double strength) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setVirtualizer(trackId: 'fg', strength: strength);
  }

  Future<void> applyBgVirtualizer(double strength) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setVirtualizer(trackId: 'bg', strength: strength);
  }

  Future<void> applyFgLoudness(double gainDb) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setLoudness(trackId: 'fg', gainDb: gainDb);
  }

  Future<void> applyBgLoudness(double gainDb) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setLoudness(trackId: 'bg', gainDb: gainDb);
  }

  Future<void> applyAllEffects({
    required List<double> fgEq,
    required List<double> bgEq,
    required double fgBassBoost,
    required double bgBassBoost,
    required double fgVirtualizer,
    required double bgVirtualizer,
    required double fgLoudness,
    required double bgLoudness,
  }) =>
      Future.wait([
        applyFgEq(fgEq),
        applyBgEq(bgEq),
        applyFgBassBoost(fgBassBoost),
        applyBgBassBoost(bgBassBoost),
        applyFgVirtualizer(fgVirtualizer),
        applyBgVirtualizer(bgVirtualizer),
        applyFgLoudness(fgLoudness),
        applyBgLoudness(bgLoudness),
      ]);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> disposeHandler() async {
    _disposed = true;
    _pausedByInterruption = false;
    await Future.wait([
      AudioEffectsChannel.closeEffects(trackId: 'fg'),
      AudioEffectsChannel.closeEffects(trackId: 'bg'),
    ]);
    await Future.wait([_fg.dispose(), _bg.dispose()]);
  }

  // ── Media session broadcast ────────────────────────────────────────────────

  void _broadcastState() {
    final state = _fg.playerState;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        _fg.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (state.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _fg.playing,
      updatePosition: _fg.position,
      bufferedPosition: _fg.bufferedPosition,
      speed: _fg.speed,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Uri _toUri(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Uri.parse(source);
    }
    return Uri.file(source);
  }
}
