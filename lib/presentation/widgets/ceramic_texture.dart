import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reference ceramic photo (same tile as design) blended over the base gradient.
const String _kCeramicReferenceAsset = 'assets/textures/ceramic_reference.jpg';

/// Photo-based glaze + light gloss veil (falls back to procedural if asset missing).
class CeramicFilmGrain extends StatelessWidget {
  const CeramicFilmGrain({
    super.key,
    this.photoOpacity = 0.52,
    this.harmonizeTeal = true,
    /// Fades photo opacity toward top/bottom (auth full-screen backdrop).
    this.softenVerticalEdges = false,
  });

  /// How much of the photograph is mixed over the UI gradient (0–1).
  final double photoOpacity;

  /// Nudge photo hues toward app teal so it matches [AppTheme] ramps.
  final bool harmonizeTeal;

  final bool softenVerticalEdges;

  @override
  Widget build(BuildContext context) {
    final photo = Transform.scale(
      scale: 1.06,
      alignment: Alignment.center,
      child: harmonizeTeal
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix(_tealHarmonizeMatrix),
                        child: Image.asset(
                          _kCeramicReferenceAsset,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              const CustomPaint(painter: _CeramicProceduralFallbackPainter()),
                        ),
                      )
                    : Image.asset(
                        _kCeramicReferenceAsset,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            const CustomPaint(painter: _CeramicProceduralFallbackPainter()),
                      ),
    );

    final layeredPhoto = softenVerticalEdges
        ? ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00000000),
              ],
              stops: [0.0, 0.16, 0.84, 1.0],
            ).createShader(bounds),
            child: Opacity(
              opacity: photoOpacity.clamp(0.0, 1.0),
              child: photo,
            ),
          )
        : Opacity(
            opacity: photoOpacity.clamp(0.0, 1.0),
            child: photo,
          );

    return RepaintBoundary(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            layeredPhoto,
            // Gloss roll-off (top + right, like kiln glaze)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.09),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.22, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.025),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slight push toward cooler teal / cyan while keeping luminance from the photo.
/// 5×4 color matrix + bias row (RGBA + extra).
const List<double> _tealHarmonizeMatrix = <double>[
  0.92, 0.04, 0.06, 0.0, 0.0,
  0.05, 0.95, 0.08, 0.0, 0.0,
  0.06, 0.10, 1.02, 0.0, 0.0,
  0.0, 0.0, 0.0, 1.0, 0.0,
];

/// Radial or linear base + glaze + veil; use on heroes / FABs / charts.
class CeramicHeroFill extends StatelessWidget {
  const CeramicHeroFill({
    super.key,
    required this.gradient,
    required this.borderRadius,
    required this.child,
    this.useFilm = true,
    this.photoOpacity = 0.5,
  });

  final Gradient gradient;
  final BorderRadius borderRadius;
  final Widget child;
  final bool useFilm;
  final double photoOpacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: gradient),
            ),
          ),
          if (useFilm)
            Positioned.fill(
              child: CeramicFilmGrain(photoOpacity: photoOpacity),
            ),
          if (useFilm)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Lightweight procedural stand-in if [Image.asset] fails (missing asset / test).
class _CeramicProceduralFallbackPainter extends CustomPainter {
  const _CeramicProceduralFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final s = math.min(w, h);

    for (var i = 0; i < 420; i++) {
      final x = (i * 37.1 % w + w) % w;
      final y = (i * 59.7 % h + h) % h;
      canvas.drawCircle(
        Offset(x, y),
        0.35 + (i % 3) * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.012 + (i % 4) * 0.006),
      );
    }
    final c = Offset(w * 0.45, h * 0.42);
    final r = 0.42 * s;
    final shader = RadialGradient(
      colors: [
        const Color(0xFF1BB3C2).withValues(alpha: 0.12),
        const Color(0x00000000),
      ],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, Paint()..shader = shader..blendMode = BlendMode.screen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
