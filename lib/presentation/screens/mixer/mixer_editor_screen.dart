import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/sa_glass.dart';
import 'mixer_flow_support.dart';

class MixerEditorScreen extends ConsumerStatefulWidget {
  const MixerEditorScreen({super.key});

  @override
  ConsumerState<MixerEditorScreen> createState() => _MixerEditorScreenState();
}

class _MixerEditorScreenState extends ConsumerState<MixerEditorScreen> {
  int _segment = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await bootstrapMixerFlow(ref);
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  void _updateEq(int index, double value) {
    final ui = ref.read(mixerUiProvider);
    final next = List<double>.from(_segment == 0 ? ui.bgEq : ui.fgEq);
    next[index] = value;
    ref.read(mixerUiProvider.notifier).state = _segment == 0
        ? ui.copyWith(bgEq: next)
        : ui.copyWith(fgEq: next);
  }

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final draft = ref.watch(mixerDraftProvider);
    final ui = ref.watch(mixerUiProvider);

    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SaPlayerBackground(),
            Center(
              child: CircularProgressIndicator(color: glass.accent),
            ),
          ],
        ),
      );
    }

    if (draft?.background == null || draft?.foreground == null) {
      return SaGlassScaffold(
        header: SaBackHeader(
          title: 'Mixer Editor',
          onBack: () => context.pop(),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: SaPrimaryButton(
            label: 'Start with background audio',
            onPressed: () => context.go('/picker'),
          ),
        ),
      );
    }

    final isBackground = _segment == 0;
    final volume = isBackground ? ui.bgVolume : ui.fgVolume;
    final muted = isBackground ? ui.bgMuted : ui.fgMuted;
    final eq = isBackground ? ui.bgEq : ui.fgEq;
    final trackName = isBackground
        ? draft!.background!.displayName
        : draft!.foreground!.displayName;

    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Step 3 · Mixer Editor',
        onBack: () => context.pop(),
      ),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Background')),
              ButtonSegment(value: 1, label: Text('Foreground')),
            ],
            selected: {_segment},
            onSelectionChanged: (v) => setState(() => _segment = v.first),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: glass.card(radius: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isBackground
                      ? Icons.graphic_eq_rounded
                      : Icons.menu_book_rounded,
                  color: glass.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trackName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: glass.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isBackground ? 'Background channel' : 'Foreground channel',
                        style: TextStyle(color: glass.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: glass.card(radius: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Channel volume',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: volume,
                  min: 0,
                  max: 1,
                  activeColor: glass.sliderActive,
                  inactiveColor: glass.sliderInactive,
                  thumbColor: glass.sliderThumb,
                  onChanged: (v) {
                    final old = ref.read(mixerUiProvider);
                    ref.read(mixerUiProvider.notifier).state = isBackground
                        ? old.copyWith(bgVolume: v)
                        : old.copyWith(fgVolume: v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Mute channel',
                    style: TextStyle(color: glass.textPrimary, fontSize: 14),
                  ),
                  activeColor: glass.accent,
                  value: muted,
                  onChanged: (v) {
                    final old = ref.read(mixerUiProvider);
                    ref.read(mixerUiProvider.notifier).state = isBackground
                        ? old.copyWith(bgMuted: v)
                        : old.copyWith(fgMuted: v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: glass.card(radius: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EQ bands',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(eq.length, (i) {
                  const labels = ['60Hz', '250Hz', '1kHz', '4kHz', '12kHz'];
                  return Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(
                          labels[i],
                          style: TextStyle(color: glass.textMuted, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: eq[i],
                          min: -12,
                          max: 12,
                          activeColor: glass.sliderActive,
                          inactiveColor: glass.sliderInactive,
                          thumbColor: glass.sliderThumb,
                          onChanged: (v) => _updateEq(i, v),
                        ),
                      ),
                      Text(
                        '${eq[i].toStringAsFixed(1)} dB',
                        style: TextStyle(color: glass.textMuted, fontSize: 12),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: glass.card(radius: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Master controls',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: ui.masterGain,
                  min: 0.5,
                  max: 1.5,
                  activeColor: glass.sliderActive,
                  inactiveColor: glass.sliderInactive,
                  thumbColor: glass.sliderThumb,
                  onChanged: (v) {
                    ref.read(mixerUiProvider.notifier).state =
                        ui.copyWith(masterGain: v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SaPrimaryButton(
            label: 'Open Play/Pause Screen',
            onPressed: () => context.push('/mixer'),
          ),
        ],
      ),
    );
  }
}
