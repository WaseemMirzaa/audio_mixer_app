import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/mix_session.dart';
import '../../navigation/route_args.dart';
import '../../providers/providers.dart';
import '../../widgets/app_loading_state.dart';
import '../../widgets/sa_glass.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const _DarkHomeDashboard() : const _LightHomeDashboard();
  }
}

/// SoundAxis light-mode tokens — sampled from the reference design (teal glass).
abstract final class _LightColors {
  // Brand teal — used by the hero "plus" button icon.
  static const teal = Color(0xFF137E90);

  // Text
  static const textPrimary = Color(0xFFDCEAF2); // cool white headings
  static const textMuted = Color(0xFF9CC2CC); // subtitles
  static const textMeta = Color(0xFF6F9CA6); // dates / meta

  // Accents
  static const cyan = Color(0xFF83EAF1); // play icons / active nav
  static const thumb = Color(0xFF5DC0C5); // slider thumb

  // Glass surface
  static const glassBorder = Color(0x2EB4EBF0); // rgba(180,235,240,.18)
  static const glassTop = Color(0x4D3CAAB9); // rgba(60,170,185,.30)
  static const glassBottom = Color(0x290F6473); // rgba(15,100,115,.16)
  static const glassShadow = Color(0x47001E26); // rgba(0,30,38,.28)

  // Hero add button
  static const plusBtnBg = Color(0xEBFFFFFF); // rgba(255,255,255,.92)
  static const plusBtnBorder = Color(0x99FFFFFF); // rgba(255,255,255,.6)
  static const plusBtnIcon = teal;

  // Play ring (recent session tiles)
  static const playRingBg = Color(0x730A7082); // rgba(10,112,130,.45)
  static const playRingBorder = Color(0x6683EAF1); // rgba(131,234,241,.4)

  // Category icon tiles — gradient + glyph (cycled by index).
  static const catGradients = [
    [Color(0xFF2E9BE0), Color(0xFF1E6FD0)], // blue
    [Color(0xFFE6A93F), Color(0xFFC2762B)], // gold
    [Color(0xFF5566C4), Color(0xFF2E4F9A)], // indigo
  ];
  static const catIcons = [
    Icons.headphones_rounded,
    Icons.access_time_rounded,
    Icons.headphones_rounded,
  ];
}

/// Translucent teal "glass" surface shared by all light-mode home cards.
BoxDecoration _lightGlass({double radius = 18}) => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_LightColors.glassTop, _LightColors.glassBottom],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _LightColors.glassBorder, width: 1),
      boxShadow: const [
        BoxShadow(
          color: _LightColors.glassShadow,
          blurRadius: 26,
          offset: Offset(0, 10),
        ),
      ],
    );

abstract final class _HomeTokens {
  static const accent = Color(0xFF4FD1D9);
}

// ── Light home ────────────────────────────────────────────────────────────────

class _LightHomeDashboard extends ConsumerWidget {
  const _LightHomeDashboard();

  static const _textPrimary = _LightColors.textPrimary;
  static const _textMuted = _LightColors.textMuted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;
    final sessions = ref.watch(sessionsProvider);
    final name = user?.displayName ?? 'Listener';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SaPlayerBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, $name 👋',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Good to see you back!',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    children: [
                      _NewSessionCard(
                        isDark: false,
                        onTap: () => context.push('/picker'),
                      ),
                      const SizedBox(height: 24),
                      _RecentSessionsHeader(
                        textColor: _textPrimary,
                        linkColor: _textMuted,
                        underlineLink: true,
                        onSeeAll: () => context.go('/history'),
                      ),
                      const SizedBox(height: 14),
                      _SessionList(
                        sessions: sessions,
                        emptyColor: _textMuted,
                        builder: (session, i) =>
                            _LightSessionCard(session: session, index: i),
                      ),
                    ],
                  ),
                ),
                _MiniPlayerSlot(isDark: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Light-mode recent-session tile — teal glass card, colored icon tile, play ring.
class _LightSessionCard extends StatelessWidget {
  const _LightSessionCard({required this.session, required this.index});

  final MixSession session;
  final int index;

  static final _dateFmt = DateFormat('MMM d, yyyy • HH:mm');

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(session.createdAtMs);
    final gradient =
        _LightColors.catGradients[index % _LightColors.catGradients.length];
    final glyph = _LightColors.catIcons[index % _LightColors.catIcons.length];

    return GestureDetector(
      onTap: () => context.push('/session/${session.sessionId}'),
      child: Container(
        decoration: _lightGlass(),
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: gradient.last.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(glyph, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      color: _LightColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'with ${session.backgroundDisplayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _LightColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateFmt.format(created),
                    style: const TextStyle(
                      color: _LightColors.textMeta,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final ref = ProviderScope.containerOf(context, listen: false);
                ref.read(mixerLaunchArgsProvider.notifier).state =
                    MixerLaunchArgs(sessionId: session.sessionId);
                context.push('/mixer');
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _LightColors.playRingBg,
                  border:
                      Border.all(color: _LightColors.playRingBorder, width: 1.5),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: _LightColors.cyan,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dark home ─────────────────────────────────────────────────────────────────

class _DarkHomeDashboard extends ConsumerWidget {
  const _DarkHomeDashboard();

  static const _glass = SaGlass.dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;
    final sessions = ref.watch(sessionsProvider);
    final name = user?.displayName ?? 'Listener';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SaPlayerBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, $name 👋',
                              style: TextStyle(
                                color: _glass.textPrimary,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Good to see you back!',
                              style: TextStyle(
                                color: _glass.textMuted,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    children: [
                      _NewSessionCard(
                        isDark: true,
                        onTap: () => context.push('/picker'),
                      ),
                      const SizedBox(height: 24),
                      _RecentSessionsHeader(
                        textColor: _glass.textPrimary,
                        linkColor: _glass.seeAll,
                        onSeeAll: () => context.go('/history'),
                      ),
                      const SizedBox(height: 14),
                      _SessionList(
                        sessions: sessions,
                        emptyColor: _glass.textMuted,
                        builder: (session, i) =>
                            _GlassSessionCard(glass: _glass, session: session, index: i),
                      ),
                    ],
                  ),
                ),
                _MiniPlayerSlot(isDark: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent-session tile in the shared glass style (used by Home dark).
class _GlassSessionCard extends StatelessWidget {
  const _GlassSessionCard({
    required this.glass,
    required this.session,
    required this.index,
  });

  final SaGlass glass;
  final MixSession session;
  final int index;

  static final _dateFmt = DateFormat('MMM d, yyyy • HH:mm');

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(session.createdAtMs);

    return GestureDetector(
      onTap: () => context.push('/session/${session.sessionId}'),
      child: Container(
        decoration: glass.card(),
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            SaCategoryIcon(glass: glass, index: index, size: 52),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: TextStyle(
                      color: glass.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'with ${session.backgroundDisplayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: glass.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateFmt.format(created),
                    style: TextStyle(color: glass.textMeta, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SaPlayRing(
              glass: glass,
              size: 48,
              onTap: () {
                final ref = ProviderScope.containerOf(context, listen: false);
                ref.read(mixerLaunchArgsProvider.notifier).state =
                    MixerLaunchArgs(sessionId: session.sessionId);
                context.push('/mixer');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _RecentSessionsHeader extends StatelessWidget {
  const _RecentSessionsHeader({
    required this.textColor,
    required this.onSeeAll,
    this.linkColor = _HomeTokens.accent,
    this.underlineLink = false,
  });

  final Color textColor;
  final Color linkColor;
  final bool underlineLink;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Sessions',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See All',
            style: TextStyle(
              color: linkColor,
              fontSize: 14,
              fontWeight: underlineLink ? FontWeight.w500 : FontWeight.w700,
              decoration:
                  underlineLink ? TextDecoration.underline : TextDecoration.none,
              decorationColor: linkColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _NewSessionCard extends StatelessWidget {
  const _NewSessionCard({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = isDark ? SaGlass.dark : null;
    final titleColor = isDark ? glass!.textPrimary : _LightColors.textPrimary;
    final subColor = isDark ? glass!.textMuted : _LightColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration:
            isDark ? glass!.hero(radius: 22) : _lightGlass(radius: 22),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const _GlowingBookArt(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Session',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mix your audiobook\nwith ambient sounds',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark
                    ? LinearGradient(
                        begin: const Alignment(-0.3, -1),
                        end: const Alignment(0.3, 1),
                        colors: glass!.plusGradient,
                      )
                    : null,
                color: isDark ? null : _LightColors.plusBtnBg,
                border: Border.all(
                  color: isDark
                      ? glass!.plusBorder
                      : _LightColors.plusBtnBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? glass!.plusShadow
                        : const Color(0x59002830), // rgba(0,40,48,.35)
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_rounded,
                color: isDark ? glass!.plusIcon : _LightColors.plusBtnIcon,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowingBookArt extends StatelessWidget {
  const _GlowingBookArt();

  static const _asset = 'assets/branding/book_without_bg_1.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: _HomeTokens.accent.withValues(alpha: 0.22),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Image.asset(
              _asset,
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const Positioned(top: -4, right: 2, child: _FloatingNote('♪', 18)),
          const Positioned(top: 4, left: 4, child: _FloatingNote('♫', 15)),
          const Positioned(top: 0, right: 20, child: _FloatingNote('♩', 13)),
        ],
      ),
    );
  }
}

class _FloatingNote extends StatelessWidget {
  const _FloatingNote(this.char, this.size);

  final String char;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      char,
      style: TextStyle(
        fontSize: size,
        color: Colors.white,
        shadows: [
          Shadow(
            color: _HomeTokens.accent.withValues(alpha: 0.75),
            blurRadius: 12,
          ),
          Shadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

/// Shows the mini player only when audio is actively playing.
/// Looks up the current session from [mixerLaunchArgsProvider].
class _MiniPlayerSlot extends ConsumerWidget {
  const _MiniPlayerSlot({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider).valueOrNull ?? false;
    if (!isPlaying) return const SizedBox.shrink();

    final launchArgs = ref.watch(mixerLaunchArgsProvider);
    final sessionId = launchArgs?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return const SizedBox.shrink();

    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));
    return sessionAsync.when(
      data: (session) {
        if (session == null) return const SizedBox.shrink();
        return _HomeMiniPlayer(session: session, isDark: isDark);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HomeMiniPlayer extends StatelessWidget {
  const _HomeMiniPlayer({required this.session, required this.isDark});

  final MixSession session;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final volPct = (session.backgroundVolume * 100).round().clamp(0, 100);

    if (!isDark) {
      // Light "ambient" bar — matches the reference: wave / info / shuffle row,
      // then a slider row driven by the ambient volume.
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: _lightGlass(radius: 18),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: _LightColors.cyan,
                    size: 28,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.backgroundDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _LightColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _LightColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.shuffle_rounded,
                    color: _LightColors.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: _LightColors.thumb,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                        thumbColor: _LightColors.thumb,
                      ),
                      child: Slider(value: volPct / 100, onChanged: null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '$volPct%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _LightColors.textPrimary,
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
      );
    }

    // Dark "ambient" bar — blue glass, matching the reference mockup.
    const glass = SaGlass.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: glass.card(radius: 18),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: glass.cyan,
                  size: 28,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.backgroundDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: glass.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: glass.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                _VolumeBars(level: volPct / 100, isDark: true),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: glass.sliderActive,
                      inactiveTrackColor: glass.sliderInactive,
                      thumbColor: glass.sliderThumb,
                    ),
                    child: Slider(value: volPct / 100, onChanged: null),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 38,
                  child: Text(
                    '$volPct%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: glass.textPrimary,
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
    );
  }
}

class _VolumeBars extends StatelessWidget {
  const _VolumeBars({required this.level, required this.isDark});

  final double level;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final heights = [6.0, 10.0, 14.0, 18.0];
    final filled = (level * heights.length).ceil().clamp(0, heights.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < heights.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
            child: Container(
              width: 3,
              height: heights[i],
              decoration: BoxDecoration(
                color: i < filled
                    ? _HomeTokens.accent
                    : _HomeTokens.accent.withValues(alpha: isDark ? 0.25 : 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.emptyColor,
    required this.builder,
  });

  final AsyncValue<List<MixSession>> sessions;
  final Color emptyColor;
  final Widget Function(MixSession session, int index) builder;

  @override
  Widget build(BuildContext context) {
    return sessions.when(
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No sessions yet — start a New Session.',
              style: TextStyle(color: emptyColor, fontSize: 14),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              builder(list[i], i),
            ],
          ],
        );
      },
      loading: () => const AppLoadingState(
        message: 'Loading sessions...',
        compact: true,
      ),
      error: (e, _) => Text('Error: $e', style: TextStyle(color: emptyColor)),
    );
  }
}


