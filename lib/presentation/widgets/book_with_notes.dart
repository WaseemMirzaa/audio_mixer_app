import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sa_glass.dart';

/// The book artwork scaled to the available space, surrounded by music / media
/// icons scattered (and rotated) above and to the sides. Shared by the splash,
/// Get Started, and auth screens.
///
/// Pass [height] when used inside an unbounded/scrolling parent (auth screens);
/// omit it inside a bounded parent such as an [Expanded] (Get Started).
class BookWithNotes extends StatelessWidget {
  const BookWithNotes({super.key, this.height});

  final double? height;

  // (alignX, alignY, icon, glyph, sizeFactor, rotationTurns, opacity)
  static const _items =
      <(double, double, IconData?, String?, double, double, double)>[
    (-0.86, -0.55, null, '♪', 0.085, -0.05, 0.9),
    (0.86, -0.5, Icons.headphones_rounded, null, 0.085, 0.06, 0.8),
    (-0.58, -0.86, null, '♫', 0.075, 0.08, 0.85),
    (0.55, -0.86, Icons.music_note_rounded, null, 0.08, -0.06, 0.8),
    (0.02, -0.96, null, '♩', 0.065, 0.04, 0.7),
    (-0.95, -0.08, Icons.graphic_eq_rounded, null, 0.075, 0.05, 0.7),
    (0.95, -0.02, null, '♪', 0.08, -0.07, 0.8),
    (-0.82, 0.42, Icons.album_rounded, null, 0.07, 0.06, 0.6),
    (0.82, 0.44, null, '♫', 0.065, -0.08, 0.6),
    (-0.4, -0.64, Icons.audiotrack_rounded, null, 0.07, -0.05, 0.7),
    (0.42, -0.66, null, '♩', 0.06, 0.07, 0.65),
    (0.24, -0.82, null, '♪', 0.055, 0.04, 0.6),
    (-0.24, -0.8, Icons.queue_music_rounded, null, 0.065, -0.08, 0.6),
    (-0.97, -0.36, null, '♫', 0.05, 0.05, 0.5),
    (0.97, -0.3, null, '♩', 0.05, -0.06, 0.55),
    (-0.55, 0.55, Icons.equalizer_rounded, null, 0.06, 0.03, 0.5),
  ];

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final content = LayoutBuilder(
      builder: (context, c) {
        final maxH = c.maxHeight.isFinite ? c.maxHeight : c.maxWidth;
        final base = math.min(c.maxWidth, maxH);
        final bookSize = math.min(c.maxWidth * 0.76, maxH * 0.82);
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final n in _items)
              Align(
                alignment: Alignment(n.$1, n.$2),
                child: Transform.rotate(
                  angle: n.$6 * 2 * math.pi,
                  child: n.$3 != null
                      ? Icon(
                          n.$3,
                          size: base * n.$5,
                          color: glass.cyan.withValues(alpha: n.$7),
                          shadows: [
                            Shadow(
                              color: glass.cyan.withValues(alpha: 0.7),
                              blurRadius: 12,
                            ),
                          ],
                        )
                      : Text(
                          n.$4!,
                          style: TextStyle(
                            fontSize: base * n.$5,
                            color: Colors.white.withValues(alpha: n.$7),
                            shadows: [
                              Shadow(
                                color: glass.cyan.withValues(alpha: 0.75),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            SizedBox(
              width: bookSize,
              height: bookSize,
              child: Image.asset(
                'assets/branding/book_without_bg_1.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        );
      },
    );
    return height != null ? SizedBox(height: height, child: content) : content;
  }
}
