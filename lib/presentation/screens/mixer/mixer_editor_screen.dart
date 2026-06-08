import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/primary_button.dart';
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
    final draft = ref.watch(mixerDraftProvider);
    final ui = ref.watch(mixerUiProvider);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (draft?.background == null || draft?.foreground == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mixer Editor')),
        body: AppContent(
          child: PrimaryButton(
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

    return Scaffold(
      appBar: AppBar(title: const Text('Step 3 · Mixer Editor')),
      body: AppContent(
        child: ListView(
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Background')),
                ButtonSegment(value: 1, label: Text('Foreground')),
              ],
              selected: {_segment},
              onSelectionChanged: (v) => setState(() => _segment = v.first),
            ),
            const SizedBox(height: 10),
            AppSurfaceCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  isBackground ? 'Background channel' : 'Foreground channel',
                ),
              ),
            ),
            const SizedBox(height: 10),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channel volume',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: volume,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      final old = ref.read(mixerUiProvider);
                      ref.read(mixerUiProvider.notifier).state = isBackground
                          ? old.copyWith(bgVolume: v)
                          : old.copyWith(fgVolume: v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mute channel'),
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
            const SizedBox(height: 10),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EQ bands',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(eq.length, (i) {
                    const labels = ['60Hz', '250Hz', '1kHz', '4kHz', '12kHz'];
                    return Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(width: 52, child: Text(labels[i])),
                            Expanded(
                              child: Slider(
                                value: eq[i],
                                min: -12,
                                max: 12,
                                onChanged: (v) => _updateEq(i, v),
                              ),
                            ),
                            Text('${eq[i].toStringAsFixed(1)} dB'),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Master controls',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: ui.masterGain,
                    min: 0.5,
                    max: 1.5,
                    onChanged: (v) {
                      ref.read(mixerUiProvider.notifier).state = ui.copyWith(
                        masterGain: v,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Open Play/Pause Screen',
              onPressed: () => context.push('/mixer'),
            ),
          ],
        ),
      ),
    );
  }
}
