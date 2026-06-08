import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Horizontal yellow → orange track for mixer seek / volume sliders.
class MixerGradientSliderTrackShape extends SliderTrackShape {
  const MixerGradientSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(trackRect.height / 2);
    final inactiveColor = sliderTheme.inactiveTrackColor ??
        Colors.white.withValues(alpha: 0.22);

    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()..color = inactiveColor,
    );

    final activeEnd = thumbCenter.dx.clamp(trackRect.left, trackRect.right);
    if (activeEnd <= trackRect.left) return;

    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      activeEnd,
      trackRect.bottom,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, radius),
      Paint()
        ..shader = AppTheme.mixerLinearLr.createShader(
          Rect.fromLTWH(trackRect.left, trackRect.top, trackRect.width, trackRect.height),
        ),
    );
  }
}

SliderThemeData mixerGradientSliderTheme({
  required SliderThemeData base,
  double trackHeight = 4,
  double thumbRadius = 9,
  Color inactiveTrackColor = const Color(0x44FFFFFF),
}) {
  return base.copyWith(
    trackShape: const MixerGradientSliderTrackShape(),
    activeTrackColor: Colors.transparent,
    inactiveTrackColor: inactiveTrackColor,
    thumbColor: Colors.white,
    overlayColor: AppTheme.mixerLineGradient[1].withValues(alpha: 0.22),
    trackHeight: trackHeight,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
  );
}
