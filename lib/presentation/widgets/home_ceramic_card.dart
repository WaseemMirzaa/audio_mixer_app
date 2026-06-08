import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/mix_session.dart';
import 'ceramic_texture.dart';

/// Glazed ceramic shell used on Home (hero + recent session rows).
class HomeCeramicCardShell extends StatelessWidget {
  const HomeCeramicCardShell({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 22,
    this.photoOpacity = 0.4,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final double photoOpacity;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final fill = ClipRRect(
      borderRadius: r,
      child: CeramicHeroFill(
        gradient: AppTheme.ceramicHeroRadial,
        borderRadius: r,
        photoOpacity: photoOpacity,
        child: child,
      ),
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: AppTheme.ceramicGradient[0].withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: fill,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: r, child: card),
    );
  }
}

/// Outer margin so ceramic card shadows are not clipped by lists.
class SessionCeramicGutter extends StatelessWidget {
  const SessionCeramicGutter({super.key, required this.child});

  static const EdgeInsets margin =
      EdgeInsets.symmetric(horizontal: 20, vertical: 6);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: margin, child: child);
  }
}

/// Glazed content panel (session detail sections).
class SessionCeramicPanel extends StatelessWidget {
  const SessionCeramicPanel({
    super.key,
    this.title,
    required this.child,
    this.photoOpacity = 0.38,
  });

  final String? title;
  final Widget child;
  final double photoOpacity;

  static TextStyle get sectionTitleStyle => const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      );

  static TextStyle get bodyStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 15,
        height: 1.35,
      );

  static TextStyle get mutedStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.65),
        fontSize: 13,
        height: 1.3,
      );

  @override
  Widget build(BuildContext context) {
    return SessionCeramicGutter(
      child: HomeCeramicCardShell(
        photoOpacity: photoOpacity,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title!, style: sectionTitleStyle),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Label + value row on ceramic panels.
class SessionCeramicDetailRow extends StatelessWidget {
  const SessionCeramicDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SessionCeramicPanel.mutedStyle),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SessionCeramicPanel.bodyStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted circle behind hero / thumbnail icons.
class HomeCeramicIconBadge extends StatelessWidget {
  const HomeCeramicIconBadge({
    super.key,
    required this.icon,
    this.size = 52,
    this.iconSize = 26,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

/// Music note on frosted disc with concentric ripple rings (New Session hero).
class HomeRippleMusicBadge extends StatefulWidget {
  const HomeRippleMusicBadge({super.key, this.size = 80});

  final double size;

  @override
  State<HomeRippleMusicBadge> createState() => _HomeRippleMusicBadgeState();
}

class _HomeRippleMusicBadgeState extends State<HomeRippleMusicBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.size * 0.44;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return CustomPaint(
            painter: _RippleRingsPainter(
              t: _pulse.value,
              coreRadius: core * 0.5,
            ),
            child: child,
          );
        },
        child: Center(
          child: Container(
            width: core,
            height: core,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.42),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.music,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RippleRingsPainter extends CustomPainter {
  _RippleRingsPainter({required this.t, required this.coreRadius});

  final double t;
  final double coreRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;

    // Static base ripples.
    const staticStops = [1.05, 1.28, 1.52, 1.78];
    const staticAlphas = [0.22, 0.14, 0.09, 0.05];
    for (var i = 0; i < staticStops.length; i++) {
      final r = coreRadius * staticStops[i];
      if (r > maxR) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: staticAlphas[i]);
      canvas.drawCircle(center, r, paint);
    }

    // Two animated ripples expanding outward.
    for (var wave = 0; wave < 2; wave++) {
      final phase = ((t + wave * 0.5) % 1.0);
      final expand = coreRadius + (maxR - coreRadius) * phase;
      final alpha = (1.0 - phase) * 0.28;
      if (alpha <= 0.01) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 - phase * 0.6
        ..color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(center, expand, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RippleRingsPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// White circular action chip (add / chevron) on ceramic cards.
class HomeCeramicActionChip extends StatelessWidget {
  const HomeCeramicActionChip({
    super.key,
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppTheme.accentDark, size: 22),
        ),
      ),
    );
  }
}

class HomeNewSessionCard extends StatelessWidget {
  const HomeNewSessionCard({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return HomeCeramicCardShell(
      photoOpacity: 0.44,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const HomeRippleMusicBadge(size: 80),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Start audiobook + background',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            HomeCeramicActionChip(
              icon: Icons.add_rounded,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ceramic session row (Home + History lists).
class SessionCeramicListCard extends StatelessWidget {
  const SessionCeramicListCard({super.key, required this.session});

  final MixSession session;

  static final DateFormat _dateFmt = DateFormat.yMMMd();

  static String formatDuration(int ms) {
    final total = (ms / 1000).round();
    final min = (total ~/ 60).toString().padLeft(2, '0');
    final sec = (total % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(session.createdAtMs);
    return HomeCeramicCardShell(
      onTap: () => context.push('/session/${session.sessionId}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SessionCeramicMusicThumbnail(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${session.foregroundDisplayName}  ·  ${session.backgroundDisplayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_dateFmt.format(created)}  ·  ${formatDuration(session.durationMs)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: HomeCeramicActionChip(
                icon: Icons.chevron_right_rounded,
                onPressed: () =>
                    context.push('/session/${session.sessionId}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White tile + brand-gradient music note (session list leading).
class SessionCeramicMusicThumbnail extends StatelessWidget {
  const SessionCeramicMusicThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (b) => AppTheme.brandLinearTlBr.createShader(b),
          child: const FaIcon(
            FontAwesomeIcons.music,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Search field on glazed ceramic shell (History).
class SessionCeramicSearchField extends StatelessWidget {
  const SessionCeramicSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search sessions',
  });

  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return HomeCeramicCardShell(
      radius: 16,
      photoOpacity: 0.32,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        cursorColor: AppTheme.accentHover,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.72),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
