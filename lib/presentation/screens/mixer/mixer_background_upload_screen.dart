import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/mixer_state.dart';
import '../../../domain/models/track_ref.dart';
import '../../providers/providers.dart';
import '../../widgets/sa_glass.dart';

class MixerBackgroundUploadScreen extends ConsumerStatefulWidget {
  const MixerBackgroundUploadScreen({super.key});

  @override
  ConsumerState<MixerBackgroundUploadScreen> createState() =>
      _MixerBackgroundUploadScreenState();
}

class _MixerBackgroundUploadScreenState
    extends ConsumerState<MixerBackgroundUploadScreen> {
  static const _allowed = {'mp3', 'wav', 'aac', 'm4a'};
  static const _maxBytes = 100 * 1024 * 1024;
  String? _error;
  TrackRef? _foreground;
  TrackRef? _background;
  // Initial mix levels carried into the player (mockup defaults: 80% / 30%).
  double _fgVolume = 0.8;
  double _bgVolume = 0.3;
  @override
  void initState() {
    super.initState();
    // Always start with empty selections — new session begins fresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mixerDraftProvider.notifier).state = null;
      ref.read(mixerReadyProvider.notifier).state = false;
      ref.read(mixerUiProvider.notifier).state = const MixerUiState();
    });
  }

  Future<void> _pick(bool forForeground) async {
    setState(() => _error = null);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowed.toList(),
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final path = f.path;
    if (path == null) {
      setState(() => _error = 'Could not read file path.');
      return;
    }
    final ext = f.extension?.toLowerCase() ?? '';
    if (!_allowed.contains(ext)) {
      setState(() => _error = 'Unsupported format.');
      return;
    }
    if (f.size > _maxBytes) {
      setState(() => _error = 'File too large (max 100MB).');
      return;
    }
    if (!File(path).existsSync()) {
      setState(() => _error = 'Missing permissions or file missing.');
      return;
    }

    // Copy the picked file into the app's private storage so the path
    // remains valid after the file picker's temporary URI expires.
    String localPath;
    try {
      localPath = await _copyToAppStorage(path, f.name, ext);
    } catch (e) {
      setState(() => _error = 'Failed to copy file: $e');
      return;
    }

    // Duration is set to 0 here and updated from the real player after load.
    setState(() {
      final track = TrackRef(
        id: const Uuid().v4(),
        localPath: localPath,
        displayName: f.name,
        durationMs: 0,
        mimeType: ext,
      );
      if (forForeground) {
        _foreground = track;
      } else {
        _background = track;
      }
    });
  }

  /// Copies [sourcePath] into `<appDocs>/audio/` with a UUID filename and
  /// returns the new path. Idempotent: if the file is already inside the app
  /// docs directory, it is returned as-is without copying.
  Future<String> _copyToAppStorage(
      String sourcePath, String name, String ext) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docsDir.path, 'audio'));
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

    // If the file is already in our directory (e.g. re-selected), reuse it.
    if (sourcePath.startsWith(audioDir.path)) return sourcePath;

    final destName = '${const Uuid().v4()}.$ext';
    final dest = File(p.join(audioDir.path, destName));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  void _continue() {
    if (_foreground == null || _background == null) {
      setState(() => _error = 'Select foreground and background audio first.');
      return;
    }
    // Duration may be 0 for user-picked tracks (will be updated by real player
    // after load in MixerTransportScreen). Fall back to 3-minute placeholder.
    final fgMs = _foreground!.durationMs;
    final bgMs = _background!.durationMs;
    final duration =
        fgMs > 0 || bgMs > 0 ? (fgMs > bgMs ? fgMs : bgMs) : 180000;

    ref.read(mixerDraftProvider.notifier).state = MixerDraft(
      title: 'My Audiobook Session',
      foreground: _foreground,
      background: _background,
      fgVolume: _fgVolume,
      bgVolume: _bgVolume,
    );
    ref.read(mixerUiProvider.notifier).state = ref.read(mixerUiProvider).copyWith(
          durationMs: duration,
          fgVolume: _fgVolume,
          bgVolume: _bgVolume,
        );
    ref.read(mixerReadyProvider.notifier).state = true;
    context.push('/mixer');
  }

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final ready = _foreground != null && _background != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SaPlayerBackground(),
          SafeArea(
            child: Column(
              children: [
                _Header(glass: glass, onBack: () => context.pop()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      const SizedBox(height: 14),
                      _TrackCard(
                  glass: glass,
                  label: 'Foreground Track',
                  icon: Icons.menu_book_rounded,
                  iconGradient: glass.isDark
                      ? const [Color(0xFF2E86E0), Color(0xFF0E4FC0)]
                      : const [Color(0xFF1DBEC8), Color(0xFF0D929E)],
                  track: _foreground,
                  selectedSubtitle: 'Your audiobook or voice track',
                  onPick: () => _pick(true),
                  onClear: _foreground == null
                      ? null
                      : () => setState(() => _foreground = null),
                ),
                const SizedBox(height: 12),
                _TrackCard(
                  glass: glass,
                  label: 'Background Track',
                  icon: Icons.graphic_eq_rounded,
                  iconGradient: glass.isDark
                      ? const [Color(0xFF1580A0), Color(0xFF0A4E6C)]
                      : const [Color(0xFF13949E), Color(0xFF086472)],
                  track: _background,
                  selectedSubtitle: 'Ambient or nature sounds',
                  onPick: () => _pick(false),
                  onClear: _background == null
                      ? null
                      : () => setState(() => _background = null),
                ),
                const SizedBox(height: 18),
                _MixSettings(
                  glass: glass,
                  fgVolume: _fgVolume,
                  bgVolume: _bgVolume,
                  onFg: (v) => setState(() => _fgVolume = v),
                  onBg: (v) => setState(() => _bgVolume = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'Supported: MP3 · WAV · AAC · M4A',
                  style: TextStyle(color: glass.textMeta, fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFFF7A9D), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFF7A9D),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                      const SizedBox(height: 22),
                      _ContinuePill(
                        glass: glass,
                        enabled: ready,
                        onPressed: _continue,
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
}

class _Header extends StatelessWidget {
  const _Header({required this.glass, required this.onBack});

  final SaGlass glass;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Icon(Icons.chevron_left_rounded,
                color: glass.textPrimary, size: 28),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Session',
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Select two audio tracks',
                style: TextStyle(color: glass.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.glass,
    required this.label,
    required this.icon,
    required this.iconGradient,
    required this.track,
    required this.selectedSubtitle,
    required this.onPick,
    required this.onClear,
  });

  final SaGlass glass;
  final String label;
  final IconData icon;
  final List<Color> iconGradient;
  final TrackRef? track;
  final String selectedSubtitle;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final selected = track != null;

    return Container(
      decoration: glass.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: glass.cyan,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (selected && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded,
                      color: glass.textMuted, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: iconGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.last.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.displayName ?? 'No file selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: glass.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      selected
                          ? selectedSubtitle
                          : 'Tap below to choose a file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: glass.textMuted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      selected
                          ? (track!.mimeType?.toUpperCase() ?? 'Audio file')
                          : '—',
                      style: TextStyle(color: glass.textMeta, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: glass.secondaryButton(radius: 10),
                child: Text(
                  selected ? 'Change Audio' : 'Select Audio',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinuePill extends StatelessWidget {
  const _ContinuePill({
    required this.glass,
    required this.enabled,
    required this.onPressed,
  });

  final SaGlass glass;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: glass.continueGradient,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: glass.continueGradient.last.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Text(
              'Continue to Player',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mix Settings" — foreground / background starting volume sliders.
class _MixSettings extends StatelessWidget {
  const _MixSettings({
    required this.glass,
    required this.fgVolume,
    required this.bgVolume,
    required this.onFg,
    required this.onBg,
  });

  final SaGlass glass;
  final double fgVolume;
  final double bgVolume;
  final ValueChanged<double> onFg;
  final ValueChanged<double> onBg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mix Settings',
          style: TextStyle(
            color: glass.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _VolumeRow(
          glass: glass,
          label: 'Foreground Volume',
          value: fgVolume,
          onChanged: onFg,
        ),
        const SizedBox(height: 6),
        _VolumeRow(
          glass: glass,
          label: 'Background Volume',
          value: bgVolume,
          onChanged: onBg,
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.glass,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final SaGlass glass;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(color: glass.textMuted, fontSize: 11.5)),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: glass.sliderThumb,
            inactiveTrackColor: glass.sliderInactive,
            thumbColor: glass.sliderThumb,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
      ],
    );
  }
}
