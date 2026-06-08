import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/preset.dart';
import '../../navigation/route_args.dart';
import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/app_loading_state.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/ceramic_texture.dart';

class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(presetsProvider);
    final sub = ref.watch(subscriptionStreamProvider).valueOrNull;
    final isPro = sub?.isPro ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Presets')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.transparent,
        elevation: 3,
        onPressed: () async {
          final repo = ref.read(presetRepositoryProvider);
          if (!await repo.canAddPreset(isPro: isPro)) {
            if (!context.mounted) return;
            context.push('/paywall');
            return;
          }
          if (!context.mounted) return;
          final ctrl = TextEditingController(text: 'My preset');
          final name = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Preset name'),
              content: TextField(controller: ctrl),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('Create'),
                ),
              ],
            ),
          );
          if (name == null || name.isEmpty) return;
          final uid =
              ref.read(authStateProvider).valueOrNull?.uid ?? 'guest_local';
          final now = DateTime.now().millisecondsSinceEpoch;
          await repo.savePreset(
            MixerPreset(
              presetId: '',
              uid: uid,
              name: name,
              foregroundEq: List<double>.filled(5, 0),
              backgroundEq: List<double>.filled(5, 0),
              foregroundVolume: 0.85,
              backgroundVolume: 0.45,
              masterGain: 1,
              balance: 0,
              createdAtMs: now,
              updatedAtMs: now,
            ),
          );
          ref.invalidate(presetsProvider);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandSampleMid.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandLinearTlBr,
                    ),
                  ),
                  const CeramicFilmGrain(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                  const Center(
                    child: FaIcon(FontAwesomeIcons.plus, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: presetsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No presets saved'));
          }
          return AppContent(
            child: FadeInUp(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final p = list[i];
                  final locked = p.isPremium && !isPro;
                  return AppSurfaceCard(
                    listTile: true,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              if (locked)
                                InkWell(
                                  onTap: () => context.push('/paywall'),
                                  child: Chip(
                                    avatar: const FaIcon(
                                      FontAwesomeIcons.lock,
                                      size: 14,
                                    ),
                                    label: const Text('PRO'),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _miniEqGraph(p.foregroundEq),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              TextButton(
                                onPressed: locked
                                    ? () => context.push('/paywall')
                                    : () {
                                        ref
                                            .read(
                                              mixerLaunchArgsProvider.notifier,
                                            )
                                            .state = MixerLaunchArgs(
                                          presetId: p.presetId,
                                        );
                                        context.push('/picker');
                                      },
                                child: const Text('Apply'),
                              ),
                              TextButton(
                                onPressed: locked
                                    ? null
                                    : () async {
                                        final ctrl = TextEditingController(
                                          text: p.name,
                                        );
                                        final name = await showDialog<String>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Rename'),
                                            content: TextField(
                                              controller: ctrl,
                                            ),
                                            actions: [
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  ctx,
                                                  ctrl.text,
                                                ),
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (name != null && name.isNotEmpty) {
                                          await ref
                                              .read(presetRepositoryProvider)
                                              .renamePreset(
                                                presetId: p.presetId,
                                                name: name,
                                              );
                                          ref.invalidate(presetsProvider);
                                        }
                                      },
                                child: const Text('Rename'),
                              ),
                              TextButton(
                                onPressed: locked
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete preset?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          await ref
                                              .read(presetRepositoryProvider)
                                              .deletePreset(p.presetId);
                                          ref.invalidate(presetsProvider);
                                        }
                                      },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const AppLoadingState(message: 'Loading presets...'),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _miniEqGraph(List<double> bands) {
    final mx = bands.fold<double>(
      0,
      (a, b) => a.abs() > b.abs() ? a.abs() : b.abs(),
    );
    final scale = mx < 0.01 ? 1.0 : mx;
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bands.asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          final h = 8 + (v.abs() / scale) * 32;
          final t = bands.length <= 1 ? 0.5 : i / (bands.length - 1);
          final c = AppTheme.mixerLineColorAt(t);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      c.withValues(alpha: 0.92),
                      Color.lerp(c, Colors.white, 0.12)!.withValues(alpha: 0.88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SizedBox(height: h),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
