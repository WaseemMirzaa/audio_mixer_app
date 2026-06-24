import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_branding.dart';
import '../../../data/local/prefs_keys.dart';
import '../../providers/providers.dart';
import '../../widgets/sa_glass.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  /// Opened from Profile → replay; finish/skip returns with [context.pop] when possible.
  final bool replay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;

  Future<void> _finish() async {
    await ref.read(prefsProvider).setBool(PrefsKeys.onboardingDone, true);
    if (!mounted) return;
    _leaveOnboarding();
  }

  Future<void> _skip() async {
    await ref.read(prefsProvider).setBool(PrefsKeys.onboardingDone, true);
    if (!mounted) return;
    _leaveOnboarding();
  }

  void _leaveOnboarding() {
    if (widget.replay) {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go('/home');
      return;
    }
    context.go('/get-started');
  }

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);

    final titles = [
      'Play Audiobooks with Ambient Background',
      'Powerful Equalizer Controls',
      'Backup & Restore Mixes',
    ];
    final descriptions = [
      'Blend narration with calming rain, piano, or nature sounds.',
      'Tune voice and background channels independently for clarity.',
      'In Settings, export a backup of your mixed audiobooks or import a '
          'backup later.',
    ];

    final isLast = _index == 2;

    return SaGlassScaffold(
      splashBackground: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_index),
                  children: [
                     Container(
                      decoration: glass.card(radius: 24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Text(
                          'Step ${_index + 1} of 3',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                                        const Spacer(),

                    // Image / icon card — vertically centered.
                    const Spacer(),
                    _OnboardingHeroCard(index: _index),
                    const Spacer(),
                    // Text block — pinned toward the bottom.
                   
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Text(
                            titles[_index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            descriptions[_index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 10 : 7,
                  height: i == _index ? 10 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index ? glass.accent : glass.textMeta,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: glass.textMuted,
                  ),
                  child: const Text(
                    'SKIP',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 148,
                  child: SaPrimaryButton(
                    label: isLast ? 'Get Started' : 'Next',
                    onPressed: () {
                      if (isLast) {
                        _finish();
                        return;
                      }
                      setState(() => _index += 1);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingHeroCard extends StatelessWidget {
  const _OnboardingHeroCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SizedBox(
      width: 220,
      height: 220,
      child: Container(
        decoration: glass.hero(radius: 24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (index) {
            0 => const _HeroAudiobookAmbient(),
            1 => const _HeroEq(),
            _ => const _HeroExportImport(),
          },
        ),
      ),
    );
  }
}

class _HeroAudiobookAmbient extends StatelessWidget {
  const _HeroAudiobookAmbient();

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glass.accent.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(59),
            child: Image.asset(
              AppBranding.logoAsset,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.menu_book_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: glass.catGradients[0],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroEq extends StatelessWidget {
  const _HeroEq();

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    const heights = <double>[22, 48, 68, 38, 58];
    final barColors = glass.catGradients[0];
    Color barAt(double t) =>
        Color.lerp(barColors.first, barColors.last, t) ?? barColors.first;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            _OnboardingIconDisc(
              size: 88,
              child: FaIcon(
                FontAwesomeIcons.sliders,
                size: 40,
                color: glass.accent,
              ),
            ),
            Positioned(
              right: -6,
              bottom: -4,
              child: _OnboardingIconDisc(
                size: 40,
                child: const FaIcon(
                  FontAwesomeIcons.waveSquare,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FaIcon(
              FontAwesomeIcons.volumeLow,
              size: 14,
              color: glass.textMuted.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 8),
            ...List.generate(5, (i) {
              final c = barAt(i / 4);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 9,
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            FaIcon(
              FontAwesomeIcons.volumeHigh,
              size: 14,
              color: glass.textMuted.withValues(alpha: 0.55),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroExportImport extends StatelessWidget {
  const _HeroExportImport();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HeroTransferBadge(
            icon: FaIcon(
              FontAwesomeIcons.fileExport,
              size: 24,
              color: Colors.white,
            ),
            label: 'Export',
          ),
          const SizedBox(width: 8),
          _OnboardingIconDisc(
            size: 44,
            child: FaIcon(
              FontAwesomeIcons.arrowsRotate,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const _HeroTransferBadge(
            icon: FaIcon(
              FontAwesomeIcons.fileImport,
              size: 24,
              color: Colors.white,
            ),
            label: 'Import',
          ),
        ],
      ),
    );
  }
}

class _OnboardingIconDisc extends StatelessWidget {
  const _OnboardingIconDisc({
    required this.size,
    required this.child,
  });

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            glass.glassTop,
            glass.glassBottom,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: glass.accent.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

class _HeroTransferBadge extends StatelessWidget {
  const _HeroTransferBadge({
    required this.icon,
    required this.label,
  });

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OnboardingIconDisc(
          size: 58,
          child: icon,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
