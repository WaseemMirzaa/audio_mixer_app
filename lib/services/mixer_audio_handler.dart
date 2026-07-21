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
  /// True only after an explicit play(); cleared on user pause/stop/completion.
  bool _userWantsPlayback = false;

  double _fgVol = 1.0;
  double _bgVol = 0.5;
  bool _fgLoop = false;

  /// True when only a background track is loaded (no foreground audiobook). In
  /// this mode the background player becomes the primary transport track.
  bool _bgOnly = false;

  /// When true the audio session is configured to mix with other apps' audio
  /// (Audible, YouTube, Spotify…) instead of interrupting them.
  bool _mixWithOthers = false;

  MixerAudioHandler() {
    _fg.playbackEventStream.listen((_) {
      if (!_bgOnly) _broadcastState();
    });
    _fg.playerStateStream.listen((state) {
      // When FG finishes (loop off), reset both tracks to the start and pause
      // so the player returns to a clean, replayable state. (With loop on,
      // LoopMode.one restarts automatically and completed never fires.)
      if (state.processingState == ProcessingState.completed &&
          !_disposed &&
          !_bgOnly) {
        _handleCompletion();
      }
      if (!_bgOnly) _broadcastState();
    });
    // Mirror listeners on the background player for background-only sessions,
    // where the background track is the primary (position/state) source.
    _bg.playbackEventStream.listen((_) {
      if (_bgOnly) _broadcastState();
    });
    _bg.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          !_disposed &&
          _bgOnly) {
        _handleCompletion();
      }
      if (_bgOnly) _broadcastState();
    });
    _initAudioSession();
  }

  /// The player that drives the transport (position, duration, play state):
  /// the foreground audiobook when present, otherwise the background track.
  AudioPlayer get _primary => _bgOnly ? _bg : _fg;

  /// Track id ('fg'/'bg') of the primary player for native effect calls.
  String get _primaryId => _bgOnly ? 'bg' : 'fg';

  /// Builds the audio-session configuration for the current mode. The default
  /// ("music") takes over audio focus; the mix-with-others variant lets our
  /// output layer on top of whatever else is playing.
  AudioSessionConfiguration _sessionConfig() {
    if (!_mixWithOthers) return const AudioSessionConfiguration.music();
    return const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    );
  }

  /// Toggles "play alongside other apps" mode and reconfigures the session.
  Future<void> setMixWithOthers(bool enabled) async {
    if (_mixWithOthers == enabled || _disposed) return;
    _mixWithOthers = enabled;
    final session = await AudioSession.instance;
    await session.configure(_sessionConfig());
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(_sessionConfig());
    if (_interruptionsBound || _disposed) return;
    _interruptionsBound = true;
    session.interruptionEventStream.listen((event) {
      if (_disposed) return;
      // In mix-with-others mode we deliberately keep playing alongside other
      // apps, so we ignore focus-based interruptions.
      if (_mixWithOthers) return;
      if (event.begin) {
        // Remember intent before pausing — camera, calls, and recording all
        // steal the audio session temporarily.
        if (_userWantsPlayback) {
          _pausedByInterruption = true;
        }
        _pauseBoth(userInitiated: false);
      } else {
        final resumeAfterInterruption =
            _pausedByInterruption && _userWantsPlayback;
        _pausedByInterruption = false;
        if (resumeAfterInterruption &&
            (event.type == AudioInterruptionType.pause ||
                event.type == AudioInterruptionType.duck)) {
          _playBoth();
        } else if (!_userWantsPlayback) {
          // just_audio / AVAudioEngine may restart on session regain — stay off.
          _ensurePaused();
        }
      }
    });
  }

  // ── Public streams (same API as the old MixerAudioService) ─────────────────

  Stream<Duration> get positionStream =>
      _bgOnly ? _bg.positionStream : _fg.positionStream;
  Stream<Duration> get bgPositionStream => _bg.positionStream;
  Stream<bool> get playingStream =>
      _bgOnly ? _bg.playingStream : _fg.playingStream;
  bool get isPlaying => _primary.playing;
  Duration? get fgDuration => _bgOnly ? _bg.duration : _fg.duration;
  Duration? get bgDuration => _bg.duration;

  // ── Load ─────────────────────────────────────────────────────────────────────

  Future<void> load({
    String? fgSource,
    required String bgSource,
    String? fgTitle,
    required String bgTitle,
    int startPositionMs = 0,
  }) async {
    if (_disposed) return;

    final bgOnly = fgSource == null;
    final alreadyLoaded = _loadedFgSource == fgSource &&
        _loadedBgSource == bgSource &&
        _bgOnly == bgOnly;
    if (alreadyLoaded) return;
    _bgOnly = bgOnly;

    await _initAudioSession();
    await Future.wait([
      AudioEffectsChannel.closeEffects(trackId: 'fg'),
      AudioEffectsChannel.closeEffects(trackId: 'bg'),
    ]);
    if (Platform.isIOS) _iosNativeReady = false;

    try {
      if (bgOnly) {
        await _bg.setAudioSource(AudioSource.uri(_toUri(bgSource)));
      } else {
        await Future.wait([
          _fg.setAudioSource(AudioSource.uri(_toUri(fgSource))),
          _bg.setAudioSource(AudioSource.uri(_toUri(bgSource))),
        ]);
      }
    } on PlayerInterruptedException {
      // A newer load() (or a dispose/pause) superseded this one while the
      // sources were still loading — abort this stale load quietly.
      return;
    }
    if (_disposed) return;

    // As an ambient bed under an audiobook the background loops; as the sole
    // primary track it plays through and resets on completion.
    await _bg.setLoopMode(bgOnly ? LoopMode.off : LoopMode.one);

    if (startPositionMs > 0) {
      await _primary.seek(Duration(milliseconds: startPositionMs));
    }

    _loadedFgSource = fgSource;
    _loadedBgSource = bgSource;

    // Update lock-screen / notification media item.
    mediaItem.add(MediaItem(
      id: bgOnly ? bgSource : fgSource,
      title: bgOnly ? bgTitle : (fgTitle ?? bgTitle),
      artist: bgOnly ? 'Background sounds' : 'Background: $bgTitle',
      duration: _primary.duration,
    ));

    if (Platform.isAndroid) {
      await _openAndroidEffects();
    } else if (Platform.isIOS) {
      final bgBands = await AudioEffectsChannel.openEffects(
        trackId: 'bg',
        sessionId: 0,
      );
      final fgBands = bgOnly
          ? 0
          : await AudioEffectsChannel.openEffects(
              trackId: 'fg',
              sessionId: 0,
            );
      if (bgBands != null && fgBands != null) {
        final bgOk = await AudioEffectsChannel.setTrackFile(
          trackId: 'bg',
          path: bgSource,
          looping: !bgOnly,
        );
        final fgOk = bgOnly
            ? true
            : await AudioEffectsChannel.setTrackFile(
                trackId: 'fg',
                path: fgSource,
              );
        _iosNativeReady = fgOk && bgOk;
        if (_iosNativeReady) {
          // Native AVAudioEngine owns audible output; just_audio stays muted
          // for position / duration / UI sync only.
          await _muteJustAudio();
          if (startPositionMs > 0) {
            await AudioEffectsChannel.seekTrack(
                trackId: _primaryId, positionMs: startPositionMs);
          }
        } else {
          await _restoreJustAudioVolumes();
        }
      } else {
        await _restoreJustAudioVolumes();
      }
    }
  }

  /// Mute the just_audio players used only for UI sync on iOS.
  Future<void> _muteJustAudio() async {
    if (_bgOnly) {
      await _bg.setVolume(0);
    } else {
      await Future.wait([_fg.setVolume(0), _bg.setVolume(0)]);
    }
  }

  /// Restore audible just_audio volumes (native iOS engine unavailable / off).
  Future<void> _restoreJustAudioVolumes() async {
    _iosNativeReady = false;
    if (_bgOnly) {
      await _bg.setVolume(_bgVol);
    } else {
      await Future.wait([_fg.setVolume(_fgVol), _bg.setVolume(_bgVol)]);
    }
  }

  /// Fall back to just_audio output when native engine fails on iOS.
  Future<void> _iosFallbackToJustAudio() => _restoreJustAudioVolumes();

  /// Android session IDs can be 0 briefly after setAudioSource — retry attach.
  /// The foreground player is skipped entirely in background-only sessions.
  Future<void> _openAndroidEffects() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (_disposed) return;
      final fgSid = _bgOnly ? null : _fg.androidAudioSessionId;
      final bgSid = _bg.androidAudioSessionId;
      if (!_bgOnly && fgSid != null && fgSid != 0) {
        await AudioEffectsChannel.openEffects(trackId: 'fg', sessionId: fgSid);
      }
      if (bgSid != null && bgSid != 0) {
        await AudioEffectsChannel.openEffects(trackId: 'bg', sessionId: bgSid);
      }
      final fgReady = _bgOnly || (fgSid != null && fgSid != 0);
      final bgReady = bgSid != null && bgSid != 0;
      if (fgReady && bgReady) return;
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  // ── BaseAudioHandler overrides (media session controls) ────────────────────

  @override
  Future<void> play() => _playBoth();

  @override
  Future<void> pause() => _pauseBoth(userInitiated: true);

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
    _userWantsPlayback = true;
    _pausedByInterruption = false;
    // In mix-with-others mode on Android we deliberately do NOT request audio
    // focus, so other apps (Audible, YouTube…) keep playing and Android mixes
    // both streams at the output. iOS relies on the mixWithOthers category
    // option instead, so activating the session there is safe.
    if (!(_mixWithOthers && Platform.isAndroid)) {
      final session = await AudioSession.instance;
      await session.setActive(true);
    }
    // just_audio leaves a completed track at its end and won't restart on
    // play() — rewind to the start first so the play button always works.
    if (_primary.processingState == ProcessingState.completed) {
      await _primary.seek(Duration.zero);
      if (Platform.isIOS && _iosNativeReady) {
        await AudioEffectsChannel.seekTrack(trackId: _primaryId, positionMs: 0);
      }
    }
    if (Platform.isIOS && _iosNativeReady) {
      final bgOk = await AudioEffectsChannel.playTrack(trackId: 'bg');
      final fgOk =
          _bgOnly ? true : await AudioEffectsChannel.playTrack(trackId: 'fg');
      if (!fgOk || !bgOk) {
        await _iosFallbackToJustAudio();
      }
    }
    await _playLoaded();
  }

  Future<void> _playLoaded() async {
    if (_bgOnly) {
      await _bg.play();
    } else {
      await Future.wait([_fg.play(), _bg.play()]);
    }
  }

  Future<void> _pauseBoth({bool userInitiated = true}) async {
    if (userInitiated) {
      _userWantsPlayback = false;
      _pausedByInterruption = false;
    }
    if (_disposed) return;
    if (_bgOnly) {
      await _bg.pause();
    } else {
      await Future.wait([_fg.pause(), _bg.pause()]);
    }
    if (Platform.isIOS && _iosNativeReady) {
      await AudioEffectsChannel.pauseTrack(trackId: 'bg');
      if (!_bgOnly) await AudioEffectsChannel.pauseTrack(trackId: 'fg');
    }
  }

  Future<void> _ensurePaused() => _pauseBoth(userInitiated: false);

  Future<void> _seekFg(Duration position) async {
    if (_disposed) return;
    await _primary.seek(position);
    if (Platform.isIOS && _iosNativeReady) {
      await AudioEffectsChannel.seekTrack(
          trackId: _primaryId, positionMs: position.inMilliseconds);
    }
  }

  /// Repeat the primary track (audiobook, or background in background-only
  /// sessions) when it finishes.
  Future<void> setFgLoop(bool enabled) async {
    if (_disposed) return;
    _fgLoop = enabled;
    await _primary.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
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
    _userWantsPlayback = false;
    _pausedByInterruption = false;
    if (_bgOnly) {
      await _bg.pause();
      await _bg.seek(Duration.zero);
      if (Platform.isIOS && _iosNativeReady) {
        await Future.wait([
          AudioEffectsChannel.pauseTrack(trackId: 'bg'),
          AudioEffectsChannel.seekTrack(trackId: 'bg', positionMs: 0),
        ]);
      }
      return;
    }
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
    if (_bgOnly) {
      await _bg.setSpeed(speed);
    } else {
      await Future.wait([_fg.setSpeed(speed), _bg.setSpeed(speed)]);
    }
    if (Platform.isIOS && _iosNativeReady) {
      await AudioEffectsChannel.setSpeedIOS(trackId: 'bg', speed: speed);
      if (!_bgOnly) {
        await AudioEffectsChannel.setSpeedIOS(trackId: 'fg', speed: speed);
      }
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
      AudioEffectsChannel.setVolume(trackId: 'bg', volume: _bgVol);
      if (!_bgOnly) AudioEffectsChannel.setVolume(trackId: 'fg', volume: _fgVol);
    } else {
      _bg.setVolume(_bgVol);
      if (!_bgOnly) _fg.setVolume(_fgVol);
    }
  }

  // ── Effects ────────────────────────────────────────────────────────────────

  Future<void> applyFgEq(List<double> levels) async {
    if (_bgOnly) return;
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setEqBands(trackId: 'fg', levels: levels);
  }

  Future<void> applyBgEq(List<double> levels) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setEqBands(trackId: 'bg', levels: levels);
  }

  Future<void> applyFgBassBoost(double strength) async {
    if (_bgOnly) return;
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setBassBoost(trackId: 'fg', strength: strength);
  }

  Future<void> applyBgBassBoost(double strength) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setBassBoost(trackId: 'bg', strength: strength);
  }

  Future<void> applyFgVirtualizer(double strength) async {
    if (_bgOnly) return;
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setVirtualizer(trackId: 'fg', strength: strength);
  }

  Future<void> applyBgVirtualizer(double strength) async {
    if (Platform.isIOS && !_iosNativeReady) return;
    await AudioEffectsChannel.setVirtualizer(trackId: 'bg', strength: strength);
  }

  Future<void> applyFgLoudness(double gainDb) async {
    if (_bgOnly) return;
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
    _userWantsPlayback = false;
    await Future.wait([
      AudioEffectsChannel.closeEffects(trackId: 'fg'),
      AudioEffectsChannel.closeEffects(trackId: 'bg'),
    ]);
    await Future.wait([_fg.dispose(), _bg.dispose()]);
  }

  // ── Media session broadcast ────────────────────────────────────────────────

  void _broadcastState() {
    final p = _primary;
    final state = p.playerState;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        p.playing ? MediaControl.pause : MediaControl.play,
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
      playing: _userWantsPlayback && p.playing,
      updatePosition: p.position,
      bufferedPosition: p.bufferedPosition,
      speed: p.speed,
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
