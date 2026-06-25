import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/mixer_state.dart';
import '../../../domain/models/mix_session.dart';
import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/guest_sign_in_dialog.dart';
import '../../widgets/sa_glass.dart';
import '../../widgets/mixer_gradient_slider_track.dart';
import 'mixer_flow_support.dart';

/// Full-screen player / mixer — "My Mix".
class MixerTransportScreen extends ConsumerStatefulWidget {
  const MixerTransportScreen({super.key});

  @override
  ConsumerState<MixerTransportScreen> createState() =>
      _MixerTransportScreenState();
}

class _MixerTransportScreenState extends ConsumerState<MixerTransportScreen> {
  bool _alive = true;
  bool _loading = true;
  bool _isSeeking = false;
  bool _bgIsSeeking = false;
  bool _repeat = false;
  bool _fullscreen = false;
  // Which track the EQ + effects cards are editing (false = foreground).
  bool _eqBg = false;
  int? _sleepMinutes;
  Timer? _sleepTimer;
  // Sessions open with all fields visible (create on first setup, edit later);
  // tapping Save collapses to the clean player view.
  bool _editing = true;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _bgPosSub;
  StreamSubscription<bool>? _playingSub;

  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Cached so dispose() can call pause() without accessing ref after unmount.
  late final _handler = ref.read(mixerAudioHandlerProvider);

  void _setUi(MixerUiState state) {
    if (!_alive || !mounted) return;
    ref.read(mixerUiProvider.notifier).state = state;
  }

  void _updateUi(MixerUiState Function(MixerUiState current) patch) {
    if (!_alive || !mounted) return;
    _setUi(patch(ref.read(mixerUiProvider)));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!_alive || !mounted) return;
    // Android 13+ (API 33+) requires runtime notification permission before
    // the media-playback notification (lock screen / shade) will appear.
    // No-op on Android 12 and below, and skipped on iOS (media controls
    // there come from the audio background mode, not a notification).
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    if (!_alive || !mounted) return;
    await bootstrapMixerFlow(ref, keepAlive: () => _alive && mounted);
    if (!_alive || !mounted) return;
    final draft = ref.read(mixerDraftProvider);
    _titleCtrl.text = draft?.title ?? 'Untitled session';
    _notesCtrl.text = draft?.notes ?? '';
    // First-time creation (no saved session yet) opens in edit mode;
    // opening/playing an existing session opens in the clean player view.
    _editing = draft?.sessionId == null;
    await _loadAudio();
    if (!_alive || !mounted) return;
    setState(() => _loading = false);
  }

  // ── Audio lifecycle ─────────────────────────────────────────────────────────

  Future<void> _loadAudio() async {
    final draft = ref.read(mixerDraftProvider);
    if (draft?.foreground == null || draft?.background == null) return;

    final svc = _handler;
    final ui = ref.read(mixerUiProvider);

    await svc.load(
      fgSource: draft!.foreground!.localPath,
      bgSource: draft.background!.localPath,
      fgTitle: draft.foreground!.displayName,
      bgTitle: draft.background!.displayName,
      startPositionMs: ui.positionMs,
    );
    if (!mounted) return;

    // Apply all volume + effect + speed settings after load.
    await svc.setSpeed(ui.playbackSpeed);
    svc.applyVolumes(
      fgVolume: ui.fgVolume,
      fgMuted: ui.fgMuted,
      bgVolume: ui.bgVolume,
      bgMuted: ui.bgMuted,
      masterGain: ui.masterGain,
    );
    await svc.applyAllEffects(
      fgEq: ui.fgEq,
      bgEq: ui.bgEq,
      fgBassBoost: ui.fgBassBoost,
      bgBassBoost: ui.bgBassBoost,
      fgVirtualizer: ui.fgVirtualizer,
      bgVirtualizer: ui.bgVirtualizer,
      fgLoudness: ui.fgLoudness,
      bgLoudness: ui.bgLoudness,
    );

    // Update real durations from the players.
    final realFgDur = svc.fgDuration;
    final realBgDur = svc.bgDuration;
    var updatedUi = ui;
    if (realFgDur != null && realFgDur.inMilliseconds > 0) {
      updatedUi = updatedUi.copyWith(durationMs: realFgDur.inMilliseconds);
    }
    if (realBgDur != null && realBgDur.inMilliseconds > 0) {
      updatedUi = updatedUi.copyWith(bgDurationMs: realBgDur.inMilliseconds);
    }
    _setUi(updatedUi);

    _posSub?.cancel();
    _posSub = svc.positionStream.listen((pos) {
      if (!_alive || !mounted || _isSeeking) return;
      final cur = ref.read(mixerUiProvider);
      final ms = pos.inMilliseconds.clamp(0, cur.durationMs);
      if ((ms - cur.positionMs).abs() > 200) {
        _setUi(cur.copyWith(positionMs: ms));
      }
    });

    _bgPosSub?.cancel();
    _bgPosSub = svc.bgPositionStream.listen((pos) {
      if (!_alive || !mounted || _bgIsSeeking) return;
      final cur = ref.read(mixerUiProvider);
      final bgDurMs = cur.bgDurationMs > 0 ? cur.bgDurationMs : 1;
      final ms = pos.inMilliseconds.clamp(0, bgDurMs);
      if ((ms - cur.bgPositionMs).abs() > 200) {
        _setUi(cur.copyWith(bgPositionMs: ms));
      }
    });

    _playingSub?.cancel();
    _playingSub = svc.playingStream.listen((playing) {
      if (!_alive || !mounted) return;
      final cur = ref.read(mixerUiProvider);
      if (cur.isPlaying != playing) {
        _setUi(cur.copyWith(isPlaying: playing));
      }
    });
  }

  @override
  void dispose() {
    _alive = false;
    _posSub?.cancel();
    _bgPosSub?.cancel();
    _playingSub?.cancel();
    _sleepTimer?.cancel();
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _handler.pause();
    super.dispose();
  }

  // ── Playback controls ───────────────────────────────────────────────────────

  void _playPause() {
    if (!_alive || !mounted) return;
    final svc = _handler;
    final ui = ref.read(mixerUiProvider);
    if (ui.isPlaying) {
      svc.pause();
    } else {
      svc.play();
    }
    _setUi(ui.copyWith(isPlaying: !ui.isPlaying));
  }

  void _seekTo(int ms) {
    final ui = ref.read(mixerUiProvider);
    final clamped = ms.clamp(0, ui.durationMs);
    _setUi(ui.copyWith(positionMs: clamped));
    _handler.seek(Duration(milliseconds: clamped));
  }

  void _seekBgTo(int ms) {
    final ui = ref.read(mixerUiProvider);
    final bgDurMs = ui.bgDurationMs > 0 ? ui.bgDurationMs : 1;
    final clamped = ms.clamp(0, bgDurMs);
    _setUi(ui.copyWith(bgPositionMs: clamped));
    _handler.seekBg(Duration(milliseconds: clamped));
  }

  void _setSpeed(double speed) {
    _updateUi((ui) => ui.copyWith(playbackSpeed: speed));
    _handler.setSpeed(speed);
  }

  // ── Volume + master helpers ─────────────────────────────────────────────────

  void _pushVolumes() {
    final ui = ref.read(mixerUiProvider);
    _handler.applyVolumes(
          fgVolume: ui.fgVolume,
          fgMuted: ui.fgMuted,
          bgVolume: ui.bgVolume,
          bgMuted: ui.bgMuted,
          masterGain: ui.masterGain,
        );
  }

  // ── EQ ──────────────────────────────────────────────────────────────────────

  // ── Per-track EQ + effects (driven by the FG/BG selector) ───────────────────
  // The redesigned EQ + Effects cards keep the mockup's single-card look but a
  // Foreground/Background toggle (`_eqBg`) selects which track they edit.

  // Current-track accessors so the cards can read the right values.
  List<double> _selEq(MixerUiState ui) => _eqBg ? ui.bgEq : ui.fgEq;
  double _selBassBoost(MixerUiState ui) =>
      _eqBg ? ui.bgBassBoost : ui.fgBassBoost;
  double _selVirtualizer(MixerUiState ui) =>
      _eqBg ? ui.bgVirtualizer : ui.fgVirtualizer;
  double _selLoudness(MixerUiState ui) =>
      _eqBg ? ui.bgLoudness : ui.fgLoudness;

  void _updateEq(int i, double v) {
    final ui = ref.read(mixerUiProvider);
    final list = List<double>.from(_eqBg ? ui.bgEq : ui.fgEq)..[i] = v;
    _setUi(_eqBg ? ui.copyWith(bgEq: list) : ui.copyWith(fgEq: list));
    _eqBg ? _handler.applyBgEq(list) : _handler.applyFgEq(list);
  }

  void _resetEq() {
    final ui = ref.read(mixerUiProvider);
    final zero = List<double>.filled((_eqBg ? ui.bgEq : ui.fgEq).length, 0);
    _setUi(_eqBg ? ui.copyWith(bgEq: zero) : ui.copyWith(fgEq: zero));
    _eqBg ? _handler.applyBgEq(zero) : _handler.applyFgEq(zero);
  }

  void _updateBassBoost(double v) {
    final ui = ref.read(mixerUiProvider);
    _setUi(_eqBg ? ui.copyWith(bgBassBoost: v) : ui.copyWith(fgBassBoost: v));
    _eqBg ? _handler.applyBgBassBoost(v) : _handler.applyFgBassBoost(v);
  }

  void _updateVirtualizer(double v) {
    final ui = ref.read(mixerUiProvider);
    _setUi(
        _eqBg ? ui.copyWith(bgVirtualizer: v) : ui.copyWith(fgVirtualizer: v));
    _eqBg ? _handler.applyBgVirtualizer(v) : _handler.applyFgVirtualizer(v);
  }

  void _updateLoudness(double v) {
    final ui = ref.read(mixerUiProvider);
    _setUi(_eqBg ? ui.copyWith(bgLoudness: v) : ui.copyWith(fgLoudness: v));
    _eqBg ? _handler.applyBgLoudness(v) : _handler.applyFgLoudness(v);
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Persists the current session. Returns `true` on success, `false` when the
  /// save was blocked (guest, missing title/tracks) so the caller can keep the
  /// editor open instead of collapsing to the player view.
  Future<bool> _saveSession() async {
    // Guest guard — guests cannot save sessions.
    final user = ref.read(authStateProvider).valueOrNull;
    if (user?.isGuest == true) {
      if (!mounted) return false;
      showGuestSignInDialog(context);
      return false;
    }

    // Validate mandatory title.
    final titleText = _titleCtrl.text.trim();
    if (titleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return false;
    }

    // Flush text-field edits back into the draft before saving.
    ref.read(mixerDraftProvider.notifier).state =
        ref.read(mixerDraftProvider)?.copyWith(
              title: titleText,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            );
    final draft = ref.read(mixerDraftProvider);
    final ui = ref.read(mixerUiProvider);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? 'guest';
    if (draft?.foreground == null || draft?.background == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Two tracks are required')),
      );
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final sid = draft!.sessionId ?? const Uuid().v4();
    final previous =
        await ref.read(sessionRepositoryProvider).getSession(sid);
    final session = MixSession(
      sessionId: sid,
      uid: uid,
      title: draft.title,
      foregroundAudioId: draft.foreground!.id,
      backgroundAudioId: draft.background!.id,
      foregroundDisplayName: draft.foreground!.displayName,
      backgroundDisplayName: draft.background!.displayName,
      foregroundVolume: ui.fgVolume,
      backgroundVolume: ui.bgVolume,
      foregroundEq: ui.fgEq,
      backgroundEq: ui.bgEq,
      masterGain: ui.masterGain,
      balance: 0.0,
      durationMs: ui.durationMs,
      playbackPositionMs: ui.positionMs,
      createdAtMs: previous?.createdAtMs ?? now,
      updatedAtMs: now,
      notes: draft.notes,
      syncStatus: previous?.syncStatus ?? 'local',
      foregroundPath: draft.foreground!.localPath,
      backgroundPath: draft.background!.localPath,
      presetName: previous?.presetName,
      foregroundBassBoost: ui.fgBassBoost,
      backgroundBassBoost: ui.bgBassBoost,
      foregroundVirtualizer: ui.fgVirtualizer,
      backgroundVirtualizer: ui.bgVirtualizer,
      foregroundLoudness: ui.fgLoudness,
      backgroundLoudness: ui.bgLoudness,
      playbackSpeed: ui.playbackSpeed,
    );
    await ref.read(sessionRepositoryProvider).upsertSession(session);
    // Update the draft with the confirmed session ID so re-saves update in place.
    ref.read(mixerDraftProvider.notifier).state =
        draft.copyWith(sessionId: sid);
    // Refresh sessions list on Home and History.
    refreshSessionsList(ref);
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session saved')),
    );
    return true;
  }

  // ── Theme helpers ───────────────────────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  SaGlass get _glass => SaGlass.of(context);

  Color get _appBarFg => _glass.textPrimary;
  Color get _onCeramicMuted => _glass.textMuted;

  SystemUiOverlayStyle get _overlayStyle => _isDark
      ? SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent);

  // ── Widget helpers ──────────────────────────────────────────────────────────

  Widget _ceramicSection({required Widget child}) {
    return Container(
      decoration: _glass.card(radius: 18),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  String _fmtMmSs(int ms) {
    final s = (ms / 1000).floor().clamp(0, 360000);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  SliderThemeData _ceramicSliderTheme(BuildContext ctx) =>
      mixerGradientSliderTheme(
        base: SliderTheme.of(ctx),
        trackHeight: 3,
        thumbRadius: 9,
        inactiveTrackColor: _glass.sliderInactive,
      );

  // ── Section header building blocks (gradient badge + caption) ───────────────

  /// Solid colourful gradient badge with a glow (white glyph). Shared by track
  /// rows, EQ / effects / master / notes section headers.
  Widget _gradientBadge(IconData icon, List<Color> colors, {double size = 42}) {
    // Softer, subtler glow in light mode; bolder in dark mode.
    final outerAlpha = _isDark ? 0.6 : 0.28;
    final innerAlpha = _isDark ? 0.4 : 0.16;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.6, 1),
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: outerAlpha),
            blurRadius: _isDark ? 18 : 12,
            spreadRadius: _isDark ? 1 : 0,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: colors.first.withValues(alpha: innerAlpha),
            blurRadius: _isDark ? 10 : 6,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }

  /// Small uppercase caption used under section titles and as label chips.
  Widget _labelCap(String text, {Color? color}) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color ?? _glass.textMeta,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
        ),
      );

  /// Icon-led section header: colourful glowing glyph tile + title + caption.
  Widget _sectionHeader({
    required IconData icon,
    required List<Color> iconColors,
    required String title,
    required String caption,
    Widget? trailing,
  }) {
    return Row(
      children: [
        _gradientBadge(icon, iconColors),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _glass.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              _labelCap(caption),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── "Now Playing" hero ──────────────────────────────────────────────────────

  Widget _circHeaderBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _glass.glassBottom,
        ),
        child: Icon(icon, color: _glass.textMuted, size: 18),
      ),
    );
  }

  Widget _playerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _circHeaderBtn(
          Icons.keyboard_arrow_down_rounded,
          () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        Text(
          'Now Playing',
          style: TextStyle(
            color: _glass.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        _editSaveButton(),
      ],
    );
  }

  /// Top-right toggle: "Edit" reveals the equalizers + name field; tapping
  /// "Save" persists the session and returns to the player view.
  Widget _editSaveButton() {
    final isNew = ref.read(mixerDraftProvider)?.sessionId == null;
    final actionLabel = isNew ? 'Create' : 'Save';
    return GestureDetector(
      onTap: () async {
        if (_editing) {
          final saved = await _saveSession();
          if (!mounted || !saved) return;
          setState(() => _editing = false);
        } else {
          setState(() => _editing = true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: _editing
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _glass.continueGradient,
                ),
                borderRadius: BorderRadius.circular(20),
              )
            : BoxDecoration(
                color: _glass.glassBottom,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _glass.glassBorder),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _editing ? Icons.check_rounded : Icons.tune_rounded,
              size: 16,
              color: _editing ? Colors.white : _glass.accent,
            ),
            const SizedBox(width: 5),
            Text(
              _editing ? actionLabel : 'Edit',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _editing ? Colors.white : _glass.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Artwork section — a smaller centered card with music notes scattering out
  /// of it onto the screen background.
  Widget _artworkSection(String title) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ..._cardNotes(),
          FractionallySizedBox(
            widthFactor: 0.67,
            heightFactor: 0.67,
            child: _artworkCard(title),
          ),
        ],
      ),
    );
  }

  /// Notes drifting from the card edges onto the background (overlay).
  List<Widget> _cardNotes() {
    // (alignX, alignY, icon, glyph, sizeFactor, rotationTurns, opacity)
    const items =
        <(double, double, IconData?, String?, double, double, double)>[
      (-0.86, -0.70, null, '♪', 0.085, -0.05, 0.85),
      (0.84, -0.66, Icons.music_note_rounded, null, 0.08, 0.06, 0.8),
      (0.06, -0.96, null, '♫', 0.07, 0.04, 0.7),
      (-0.55, -0.92, Icons.headphones_rounded, null, 0.07, 0.05, 0.6),
      (0.5, -0.9, null, '♩', 0.065, -0.06, 0.65),
      (-0.97, -0.18, null, '♪', 0.075, -0.07, 0.7),
      (0.97, -0.12, Icons.graphic_eq_rounded, null, 0.07, 0.05, 0.6),
      (-0.93, 0.42, null, '♫', 0.06, 0.06, 0.55),
      (0.94, 0.40, null, '♪', 0.06, -0.08, 0.55),
      (-0.3, -0.98, null, '♩', 0.05, 0.05, 0.45),
      (0.32, -0.99, Icons.audiotrack_rounded, null, 0.055, -0.05, 0.5),
    ];
    final w = MediaQuery.of(context).size.width;
    return [
      for (final n in items)
        Align(
          alignment: Alignment(n.$1, n.$2),
          child: Transform.rotate(
            angle: n.$6 * 6.2831853,
            child: n.$3 != null
                ? Icon(
                    n.$3,
                    size: w * n.$5,
                    color: _glass.cyan.withValues(alpha: n.$7),
                    shadows: [
                      Shadow(
                          color: _glass.cyan.withValues(alpha: 0.7),
                          blurRadius: 12),
                    ],
                  )
                : Text(
                    n.$4!,
                    style: TextStyle(
                      fontSize: w * n.$5,
                      color: Colors.white.withValues(alpha: n.$7),
                      shadows: [
                        Shadow(
                            color: _glass.cyan.withValues(alpha: 0.75),
                            blurRadius: 12),
                      ],
                    ),
                  ),
          ),
        ),
    ];
  }

  /// Music notes scattered on top of the book artwork (inside the card).
  List<Widget> _bookNotes() {
    // (alignX, alignY, icon, glyph, sizeFactor, rotationTurns, opacity)
    const items =
        <(double, double, IconData?, String?, double, double, double)>[
      (-0.62, -0.58, null, '♪', 0.05, -0.05, 0.9),
      (0.6, -0.5, Icons.music_note_rounded, null, 0.045, 0.06, 0.85),
      (-0.3, -0.72, null, '♫', 0.04, 0.05, 0.8),
      (0.34, -0.7, null, '♩', 0.038, -0.06, 0.75),
      (0.66, -0.1, Icons.graphic_eq_rounded, null, 0.042, 0.05, 0.7),
      (-0.66, 0.0, null, '♪', 0.045, -0.07, 0.75),
      (0.0, -0.82, Icons.audiotrack_rounded, null, 0.04, 0.04, 0.65),
      (-0.5, 0.42, null, '♫', 0.038, 0.06, 0.6),
      (0.52, 0.4, null, '♩', 0.036, -0.05, 0.6),
    ];
    final w = MediaQuery.of(context).size.width;
    return [
      for (final n in items)
        Align(
          alignment: Alignment(n.$1, n.$2),
          child: Transform.rotate(
            angle: n.$6 * 6.2831853,
            child: n.$3 != null
                ? Icon(
                    n.$3,
                    size: w * n.$5,
                    color: _glass.cyan.withValues(alpha: n.$7),
                    shadows: [
                      Shadow(
                          color: _glass.cyan.withValues(alpha: 0.7),
                          blurRadius: 10),
                    ],
                  )
                : Text(
                    n.$4!,
                    style: TextStyle(
                      fontSize: w * n.$5,
                      color: Colors.white.withValues(alpha: n.$7),
                      shadows: [
                        Shadow(
                            color: _glass.cyan.withValues(alpha: 0.75),
                            blurRadius: 10),
                      ],
                    ),
                  ),
          ),
        ),
    ];
  }

  /// Translucent, colourish glass card (like the onboarding hero) with the
  /// book artwork as the foreground and the session title centered.
  Widget _artworkCard(String title) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          // Very faint colourish tint (10% opacity).
          colors: [
            _glass.heroTop.withValues(alpha: 0.02),
            _glass.heroBottom.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _glass.heroBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 44,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _glass.accent.withValues(alpha: 0.09),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Foreground book + headset artwork.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Image.asset(
              'assets/branding/book_with_headseat.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          // Music notes scattered on top of the artwork.
          ..._bookNotes(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.3,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 14),
                    Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Session title + track subtitle under the artwork. While editing, the title
  /// becomes a login-style glass name field; otherwise it's static text.
  Widget _trackTitleInfo(String subtitle) {
    final titleText = _titleCtrl.text.trim().isEmpty
        ? 'Untitled session'
        : _titleCtrl.text.trim();
    return Column(
      children: [
        if (_editing)
          SaGlassTextField(
            controller: _titleCtrl,
            label: 'Session name',
            hint: 'Enter a name for this mix',
          )
        else
          Text(
            titleText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _glass.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _glass.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }

  SliderThemeData _ambientSliderTheme(BuildContext ctx) =>
      SliderTheme.of(ctx).copyWith(
        trackHeight: 3.5,
        activeTrackColor: _glass.sliderThumb,
        inactiveTrackColor: _glass.sliderInactive,
        thumbColor: _glass.sliderThumb,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
        overlayShape: SliderComponentShape.noOverlay,
      );

  /// Ambient (background) quick control bar — a working seek bar for the
  /// background track's playback position.
  Widget _ambientBar(MixerUiState ui, String bgName) {
    final bgDur = ui.bgDurationMs > 0 ? ui.bgDurationMs : 1;
    final bgProgress = (ui.bgPositionMs / bgDur).clamp(0.0, 1.0);
    return Container(
      decoration: _glass.card(radius: 14),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: _glass.cyan, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bgName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _glass.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Background',
                      style:
                          TextStyle(color: _glass.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.equalizer_rounded, color: _glass.accent, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: _ambientSliderTheme(context),
                  child: Slider(
                    value: bgProgress,
                    onChangeStart: (_) => _bgIsSeeking = true,
                    onChanged: (v) {
                      _updateUi((cur) => cur.copyWith(
                            bgPositionMs: (v * bgDur).round(),
                          ));
                    },
                    onChangeEnd: (v) {
                      _bgIsSeeking = false;
                      _seekBgTo((v * bgDur).round());
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ui.bgDurationMs > 0 ? _fmtMmSs(ui.bgPositionMs) : '--:--',
                style: TextStyle(
                  color: _glass.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Thin, plain progress slider — accent track, cyan thumb (matches mockup).
  SliderThemeData _playerSeekTheme(BuildContext ctx) =>
      SliderTheme.of(ctx).copyWith(
        trackHeight: 4,
        activeTrackColor: _glass.accent,
        inactiveTrackColor: _glass.sliderInactive,
        thumbColor: _glass.sliderThumb,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: SliderComponentShape.noOverlay,
        trackShape: const RoundedRectSliderTrackShape(),
      );

  Widget _seekBar(double progress, MixerUiState ui) {
    return SliderTheme(
      data: _playerSeekTheme(context),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChangeStart: (_) => _isSeeking = true,
        onChanged: (v) {
          _setUi(ui.copyWith(positionMs: (v * ui.durationMs).round()));
        },
        onChangeEnd: (v) {
          _isSeeking = false;
          _seekTo((v * ui.durationMs).round());
        },
      ),
    );
  }

  // Secondary controls row (loop · sleep timer · speed · full screen).
  static const _speedCycle = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  String _speedLabel(double s) {
    final str = s.toStringAsFixed(2);
    // Trim to a single decimal where the hundredths are zero (1.00 → 1.0).
    return '${str.endsWith('0') ? str.substring(0, str.length - 1) : str}x';
  }

  void _cycleSpeed(double current) {
    var idx = _speedCycle.indexWhere((s) => (s - current).abs() < 0.01);
    idx = (idx + 1) % _speedCycle.length;
    _setSpeed(_speedCycle[idx]);
  }

  Widget _secIcon(IconData icon, VoidCallback onTap, {bool active = false}) {
    return IconButton(
      onPressed: onTap,
      iconSize: 22,
      splashRadius: 22,
      color: active ? _glass.accent : _glass.textMuted,
      icon: Icon(icon),
    );
  }

  // ── Loop / sleep timer / full screen (wired to real behaviour) ──────────────

  void _toggleRepeat() {
    setState(() => _repeat = !_repeat);
    _handler.setFgLoop(_repeat);
  }

  void _cycleSleepTimer() {
    const opts = <int?>[null, 15, 30, 60];
    final idx = opts.indexOf(_sleepMinutes);
    final next = opts[(idx + 1) % opts.length];
    _sleepTimer?.cancel();
    setState(() => _sleepMinutes = next);
    if (next != null) {
      _sleepTimer = Timer(Duration(minutes: next), () {
        _handler.pause();
        if (!mounted) return;
        _updateUi((ui) => ui.copyWith(isPlaying: false));
        setState(() => _sleepMinutes = null);
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(next == null ? 'Sleep timer off' : 'Sleep timer: $next min'),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    SystemChrome.setEnabledSystemUIMode(
      _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Widget _secondaryControls(MixerUiState ui) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _secIcon(Icons.repeat_rounded, _toggleRepeat, active: _repeat),
        _secIcon(
          _sleepMinutes != null
              ? Icons.timer_rounded
              : Icons.timer_outlined,
          _cycleSleepTimer,
          active: _sleepMinutes != null,
        ),
        GestureDetector(
          onTap: () => _cycleSpeed(ui.playbackSpeed),
          child: Text(
            _speedLabel(ui.playbackSpeed),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _glass.textMuted,
            ),
          ),
        ),
        _secIcon(
          _fullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.open_in_full_rounded,
          _toggleFullscreen,
          active: _fullscreen,
        ),
      ],
    );
  }

  /// Dark icon tone for the white play/pause disc (navy in dark, teal in light).
  Color get _playIconColor =>
      _isDark ? const Color(0xFF0A1525) : const Color(0xFF0A4050);

  /// Filled prev/next control (restart / jump-to-end).
  Widget _sideSeekButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      iconSize: 30,
      splashRadius: 24,
      color: _glass.textPrimary,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }

  /// Outlined circular ±15s skip button with ring arrow + "15" in the center.
  Widget _skip15Button({required bool forward, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _glass.glassBorder, width: 1.8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              forward
                  ? Icons.arrow_circle_right_outlined
                  : Icons.arrow_circle_left_outlined,
              size: 32,
              color: _glass.textPrimary.withValues(alpha: 0.85),
            ),
            Text(
              '15',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: _glass.textPrimary,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// White circular play/pause disc with a dark accent-tinted glyph.
  Widget _pausePlayButton(bool isPlaying) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: _isDark ? 0.22 : 0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _playPause,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 32,
                color: _playIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playbackCard(double progress, MixerUiState ui) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seekBar(progress, ui),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtMmSs(ui.positionMs),
                style: TextStyle(color: _glass.textMeta, fontSize: 11),
              ),
              Text(
                ui.durationMs > 0
                    ? '-${_fmtMmSs((ui.durationMs - ui.positionMs).clamp(0, ui.durationMs))}'
                    : '--:--',
                style: TextStyle(color: _glass.textMeta, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sideSeekButton(
                  icon: Icons.skip_previous_rounded,
                  onTap: () => _seekTo(0)),
              _skip15Button(
                  forward: false,
                  onTap: () => _seekTo(ui.positionMs - 15000)),
              _pausePlayButton(ui.isPlaying),
              _skip15Button(
                  forward: true,
                  onTap: () => _seekTo(ui.positionMs + 15000)),
              _sideSeekButton(
                  icon: Icons.skip_next_rounded,
                  onTap: () => _seekTo(ui.durationMs)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _secondaryControls(ui),
      ],
    );
  }

  // ── Track section ───────────────────────────────────────────────────────────

  /// Accent gradient for the foreground track badge / meter.
  List<Color> get _fgAccent => _glass.catGradients[0];

  /// Secondary (indigo) gradient for the background track + effect glyphs.
  List<Color> get _bgAccent => _glass.catGradients[2];

  Widget _hairline() => Container(
        height: 1,
        color: _glass.glassBorder,
      );

  // ── Track Mixer card (both layers: badge + meter + volume) ──────────────────

  Widget _tracksCard(MixerUiState ui, String fgName, String bgName) {
    return _ceramicSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _labelCap('Track Mixer'),
              _labelCap('2 Layers', color: _glass.textMuted),
            ],
          ),
          const SizedBox(height: 4),
          _trackMixRow(
            badge: _gradientBadge(Icons.graphic_eq_rounded, _fgAccent),
            name: 'Foreground: $fgName',
            meterColor: _fgAccent.last,
            volume: ui.fgVolume,
            muted: ui.fgMuted,
            active: ui.isPlaying && !ui.fgMuted,
            durMs: ui.durationMs,
            onVolume: (v) {
              _setUi(ui.copyWith(fgVolume: v));
              _pushVolumes();
            },
            onMute: () {
              _setUi(ui.copyWith(fgMuted: !ui.fgMuted));
              _pushVolumes();
            },
          ),
          _hairline(),
          _trackMixRow(
            badge: _gradientBadge(Icons.equalizer_rounded, _bgAccent),
            name: 'Background: $bgName',
            meterColor: _bgAccent.last,
            volume: ui.bgVolume,
            muted: ui.bgMuted,
            active: ui.isPlaying && !ui.bgMuted,
            durMs: ui.bgDurationMs,
            onVolume: (v) {
              _setUi(ui.copyWith(bgVolume: v));
              _pushVolumes();
            },
            onMute: () {
              _setUi(ui.copyWith(bgMuted: !ui.bgMuted));
              _pushVolumes();
            },
          ),
        ],
      ),
    );
  }

  Widget _trackMixRow({
    required Widget badge,
    required String name,
    required Color meterColor,
    required double volume,
    required bool muted,
    required bool active,
    required int durMs,
    required ValueChanged<double> onVolume,
    required VoidCallback onMute,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _glass.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LevelMeter(color: meterColor, active: active),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: muted ? _glass.textMeta : _glass.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SliderTheme(
                        data: _ceramicSliderTheme(context),
                        child: Slider(
                          value: volume.clamp(0, 1),
                          onChanged: muted ? null : onVolume,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${(volume * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _glass.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Track options',
                color: _glass.glassTop,
                onSelected: (_) => onMute(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'mute',
                    child: Text(muted ? 'Unmute' : 'Mute'),
                  ),
                ],
                child: Icon(
                  Icons.more_vert_rounded,
                  color: _glass.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                durMs > 0 ? _fmtMmSs(durMs) : '--:--',
                style: TextStyle(color: _glass.textMeta, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5-Band EQ card (curve graphic + faders, per-track) ──────────────────────

  /// Foreground / Background segmented selector shared by EQ + Effects cards.
  Widget _trackSelector() {
    Widget seg(String label, bool bg) {
      final selected = _eqBg == bg;
      final tint = bg ? _bgAccent.last : _fgAccent.last;
      return GestureDetector(
        onTap: () => setState(() => _eqBg = bg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? tint.withValues(alpha: 0.55) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _glass.textPrimary : _glass.textMuted,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _glass.glassBottom,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _glass.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('Foreground', false), seg('Background', true)],
      ),
    );
  }

  Widget _eqResetButton() {
    return GestureDetector(
      onTap: _resetEq,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: _glass.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _glass.accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 15, color: _glass.accent),
            const SizedBox(width: 6),
            Text(
              'Reset',
              style: TextStyle(
                color: _glass.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _axisLabel(String text) => Text(
        text,
        style: TextStyle(
          color: _glass.textMeta,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _sharedEqCard(MixerUiState ui) {
    final eq = _selEq(ui);
    const labels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
    const freqRowH = 22.0;

    return _ceramicSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.equalizer_rounded,
            iconColors: [_glass.cyan, _glass.accent],
            title: '5-Band EQ',
            caption: 'Parametric · Graphic',
            trailing: _eqResetButton(),
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: _trackSelector()),
          const SizedBox(height: 14),
          SizedBox(
            height: 236,
            child: Stack(
              children: [
                // Axis labels (+12 / 0 / -12) in the left gutter.
                Positioned(
                  left: 0,
                  top: 4,
                  bottom: freqRowH + 4,
                  width: 26,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _axisLabel('+12'),
                      _axisLabel('0'),
                      _axisLabel('-12'),
                    ],
                  ),
                ),
                // Curve + faders area.
                Positioned.fill(
                  left: 30,
                  child: Stack(
                    children: [
                      // Response curve drawn behind the faders.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: freqRowH,
                        child: CustomPaint(
                          painter: _EqCurvePainter(
                            gains: eq,
                            line: _glass.cyan,
                            line2: _glass.accent,
                            fill: _glass.accent,
                            grid: _glass.glassBorder,
                          ),
                        ),
                      ),
                      // The 5 faders + freq labels on top.
                      Positioned.fill(
                        child: Row(
                          children: List.generate(eq.length, (i) {
                            return Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _EqFader(
                                      value: eq[i],
                                      glass: _glass,
                                      onChanged: (v) => _updateEq(i, v),
                                    ),
                                  ),
                                  SizedBox(
                                    height: freqRowH,
                                    child: Center(
                                      child: Text(
                                        labels[i],
                                        style: TextStyle(
                                          color: _glass.textMuted,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sound Effects card (per-track) ──────────────────────────────────────────

  Widget _effectsCard(MixerUiState ui) {
    final bass = _selBassBoost(ui);
    final virt = _selVirtualizer(ui);
    final loud = _selLoudness(ui);
    return _ceramicSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [_labelCap('Sound Effects')]),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: _trackSelector()),
          const SizedBox(height: 2),
          _effectRow(
            icon: Icons.graphic_eq_rounded,
            iconColors: _glass.catGradients[0],
            name: 'Bass Boost',
            caption: 'Low-end enhancement',
            valueLabel: '${(bass * 100).round()}%',
            value: bass,
            min: 0,
            max: 1,
            onChanged: _updateBassBoost,
          ),
          _hairline(),
          _effectRow(
            icon: Icons.view_in_ar_rounded,
            iconColors: _glass.catGradients[2],
            name: 'Virtualizer (3D)',
            caption: 'Spatial widening',
            valueLabel: '${(virt * 100).round()}%',
            value: virt,
            min: 0,
            max: 1,
            onChanged: _updateVirtualizer,
          ),
          _hairline(),
          _effectRow(
            icon: Icons.surround_sound_rounded,
            iconColors: _glass.catGradients[1],
            name: 'Loudness',
            caption: 'Perceptual gain',
            valueLabel: '${loud.toStringAsFixed(1)} dB',
            value: loud,
            min: 0,
            max: 12,
            onChanged: _updateLoudness,
          ),
        ],
      ),
    );
  }

  Widget _effectRow({
    required IconData icon,
    required List<Color> iconColors,
    required String name,
    required String caption,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _gradientBadge(icon, iconColors),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: _glass.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            caption,
                            style:
                                TextStyle(color: _glass.textMeta, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      valueLabel,
                      style: TextStyle(
                        color: _glass.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: _ceramicSliderTheme(context),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Master volume card ──────────────────────────────────────────────────────

  Widget _masterCard(MixerUiState ui) {
    final g = ui.masterGain.clamp(0.0, 1.0);
    return _ceramicSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.speaker_rounded,
            iconColors: _bgAccent,
            title: 'Master Volume',
            caption: 'Output bus',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 46,
                child: Text('${(g * 100).round()}%',
                    style: TextStyle(
                        color: _glass.textMuted, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: SliderTheme(
                  data: _ceramicSliderTheme(context),
                  child: Slider(
                    value: g,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      _setUi(ui.copyWith(masterGain: v));
                      _pushVolumes();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 46,
                child: Text('${(g * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: _glass.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Notes card ──────────────────────────────────────────────────────────────

  Widget _notesCard() {
    return _ceramicSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.edit_note_rounded,
            iconColors: _bgAccent,
            title: 'Notes',
            caption: 'Session log',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            style: TextStyle(
                color: _glass.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            cursorColor: _glass.accent,
            decoration: InputDecoration(
              hintText: 'Add notes about this mix…',
              hintStyle: TextStyle(
                  color: _onCeramicMuted, fontWeight: FontWeight.w500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _glass.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _glass.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _glass.accent, width: 1.4),
              ),
              filled: true,
              fillColor: _glass.glassBottom,
              contentPadding: const EdgeInsets.all(12),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  // ── App bar + scaffold shell ────────────────────────────────────────────────

  PreferredSizeWidget _appBar({List<Widget>? actions}) => AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _appBarFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: _overlayStyle,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          'My Mix',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800, color: _appBarFg),
        ),
        centerTitle: true,
        actions: actions,
      );

  Widget _scaffold({PreferredSizeWidget? appBar, required Widget body}) =>
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SaPlayerBackground(),
            body,
          ],
        ),
      );

  // ── Build ────────────────────────────────────────────────────────────────────

  /// Playback position ticks often — isolate from mix/editor widgets.
  static int _transportTick(MixerUiState u) => Object.hash(
        u.positionMs,
        u.durationMs,
        u.isPlaying,
        u.bgPositionMs,
        u.bgDurationMs,
        u.playbackSpeed,
      );

  /// Mix controls — excludes position so scrolling stays smooth while playing.
  static int _mixControlsTick(MixerUiState u) => Object.hash(
        u.fgVolume,
        u.bgVolume,
        u.fgMuted,
        u.bgMuted,
        u.masterGain,
        u.fgEq,
        u.bgEq,
        u.fgBassBoost,
        u.bgBassBoost,
        u.fgVirtualizer,
        u.bgVirtualizer,
        u.fgLoudness,
        u.bgLoudness,
        u.isPlaying,
      );

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mixerDraftProvider);

    if (_loading) {
      return _scaffold(
        body: Center(
          child: CircularProgressIndicator(color: _glass.accent),
        ),
      );
    }

    final hasTracks = draft?.foreground != null && draft?.background != null;
    if (!hasTracks) {
      return _scaffold(
        appBar: _appBar(),
        body: AppContent(
          child: SaPrimaryButton(
            label: 'Start audio setup',
            onPressed: () => context.go('/picker'),
          ),
        ),
      );
    }

    final d = draft!;

    return _scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Pinned action bar (back · title · edit/save) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: _playerHeader(),
            ),
            Expanded(
              child: ListView(
                clipBehavior: Clip.hardEdge,
                cacheExtent: 480,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      ref.watch(
                        mixerUiProvider.select(_transportTick),
                      );
                      final ui = ref.read(mixerUiProvider);
                      final total =
                          ui.durationMs <= 0 ? 1 : ui.durationMs;
                      final progress =
                          (ui.positionMs / total).clamp(0.0, 1.0);
                      return RepaintBoundary(
                        child: _playerHeroSection(
                          draft: d,
                          progress: progress,
                          ui: ui,
                        ),
                      );
                    },
                  ),
                  if (_editing)
                    Consumer(
                      builder: (context, ref, _) {
                        ref.watch(
                          mixerUiProvider.select(_mixControlsTick),
                        );
                        final ui = ref.read(mixerUiProvider);
                        return RepaintBoundary(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 18),
                              _tracksCard(
                                ui,
                                d.foreground!.displayName,
                                d.background!.displayName,
                              ),
                              const SizedBox(height: 12),
                              _sharedEqCard(ui),
                              const SizedBox(height: 12),
                              _effectsCard(ui),
                              const SizedBox(height: 12),
                              _masterCard(ui),
                              const SizedBox(height: 12),
                              _notesCard(),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Artwork, title, transport, and ambient — scrolls below the pinned action bar.
  Widget _playerHeroSection({
    required MixerDraft draft,
    required double progress,
    required MixerUiState ui,
  }) {
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Untitled session'
        : _titleCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _artworkSection(title),
        const SizedBox(height: 12),
        _trackTitleInfo('with ${draft.background!.displayName}'),
        const SizedBox(height: 12),
        _playbackCard(progress, ui),
        const SizedBox(height: 14),
        _ambientBar(ui, draft.background!.displayName),
      ],
    );
  }
}

// ── Animated level meter ──────────────────────────────────────────────────────

/// Four little bars that bounce while a track plays (static + dim when paused).
class _LevelMeter extends StatefulWidget {
  const _LevelMeter({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_LevelMeter> createState() => _LevelMeterState();
}

class _LevelMeterState extends State<_LevelMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(_LevelMeter old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const phases = [0.0, 0.35, 0.7, 0.5];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 6.2831853;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final wave = widget.active
                ? 0.35 + 0.65 * (0.5 + 0.5 * _sin(t + phases[i] * 6.2831853))
                : 0.3;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
              child: Container(
                width: 2.5,
                height: 4 + wave * 8,
                decoration: BoxDecoration(
                  color: widget.color
                      .withValues(alpha: widget.active ? 0.95 : 0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Tiny sine without importing dart:math at the top of this large file.
  double _sin(double x) {
    // Normalise to [-pi, pi] then use a cheap polynomial approximation.
    const twoPi = 6.2831853071795864;
    var v = x % twoPi;
    if (v > 3.14159265) v -= twoPi;
    if (v < -3.14159265) v += twoPi;
    final v2 = v * v;
    return v * (1 - v2 / 6 + v2 * v2 / 120);
  }
}

// ── Vertical EQ fader (with value bubble) ─────────────────────────────────────

/// A custom vertical fader (-12 dB … +12 dB): rail, fill from the centre, a
/// draggable knob and a floating value bubble. Bottom = -12 dB, top = +12 dB.
class _EqFader extends StatelessWidget {
  const _EqFader({
    required this.value,
    required this.onChanged,
    required this.glass,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final SaGlass glass;

  static const double _pad = 12;
  static const double _min = -12;
  static const double _max = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final usable = (h - _pad * 2).clamp(1.0, double.infinity);
        final p = ((value - _min) / (_max - _min)).clamp(0.0, 1.0);
        final knobY = _pad + (1 - p) * usable;
        final zeroY = _pad + 0.5 * usable;
        final cx = w / 2;
        final up = value >= 0;

        void setFromDy(double dy) {
          var np = 1 - ((dy - _pad) / usable);
          np = np.clamp(0.0, 1.0);
          final v = (_min + np * (_max - _min)).roundToDouble();
          if (v != value) onChanged(v);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => setFromDy(d.localPosition.dy),
          onVerticalDragStart: (d) => setFromDy(d.localPosition.dy),
          onVerticalDragUpdate: (d) => setFromDy(d.localPosition.dy),
          child: Stack(
            children: [
              // Rail.
              Positioned(
                left: cx - 3.5,
                top: _pad,
                bottom: _pad,
                child: Container(
                  width: 7,
                  decoration: BoxDecoration(
                    color: glass.sliderInactive,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
              // Fill between centre and knob.
              Positioned(
                left: cx - 3.5,
                top: up ? knobY : zeroY,
                height: (knobY - zeroY).abs(),
                child: Container(
                  width: 7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: up
                          ? [glass.accent, glass.cyan]
                          : [glass.cyan, glass.accent],
                    ),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: glass.cyan.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              // Knob.
              Positioned(
                left: cx - 9,
                top: knobY - 9,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: glass.cyan.withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Value bubble above the knob.
              Positioned(
                left: 0,
                right: 0,
                top: (knobY - 34).clamp(0.0, h),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: glass.glassTop,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: glass.glassBorder),
                    ),
                    child: Text(
                      '${value > 0 ? '+' : ''}${value.round()}',
                      style: TextStyle(
                        color: glass.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── EQ response curve ─────────────────────────────────────────────────────────

/// Smooth glowing curve + filled area drawn behind the EQ faders, mapping the
/// five band gains (-12 … +12 dB) to a response shape.
class _EqCurvePainter extends CustomPainter {
  _EqCurvePainter({
    required this.gains,
    required this.line,
    required this.line2,
    required this.fill,
    required this.grid,
  });

  final List<double> gains;
  final Color line;
  final Color line2;
  final Color fill;
  final Color grid;

  static const double _pad = 12;

  double _gy(double g, double h) {
    final top = _pad;
    final bot = h - _pad;
    final mid = (top + bot) / 2;
    final half = (bot - top) / 2;
    return mid - (g / 12) * half;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (gains.isEmpty) return;

    // Horizontal grid + zero line.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.18, 0.5, 0.82]) {
      canvas.drawLine(Offset(0, h * f), Offset(w, h * f), gridPaint);
    }

    // Sample points across the width (endpoints clamp to the edge bands).
    final fracs = [0.1, 0.3, 0.5, 0.7, 0.9];
    final pts = <Offset>[Offset(0, _gy(gains.first, h))];
    for (var i = 0; i < gains.length; i++) {
      pts.add(Offset(fracs[i] * w, _gy(gains[i], h)));
    }
    pts.add(Offset(w, _gy(gains.last, h)));

    final path = _smooth(pts);

    // Filled area down to the bottom.
    final area = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill.withValues(alpha: 0.45), fill.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Glowing stroke.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..shader = LinearGradient(colors: [line, line2, line])
            .createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [line, line2, line])
            .createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  /// Catmull-Rom → cubic Bézier smoothing.
  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = i == 0 ? p[i] : p[i - 1];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = i + 2 < p.length ? p[i + 2] : p2;
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_EqCurvePainter old) =>
      old.gains != gains ||
      old.line != line ||
      old.line2 != line2 ||
      old.fill != fill ||
      old.grid != grid;
}
