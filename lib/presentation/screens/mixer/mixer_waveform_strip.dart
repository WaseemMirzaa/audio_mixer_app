import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_waveform/just_waveform.dart';

import '../../../core/theme/app_theme.dart';
import 'mixer_waveform_loader_stub.dart'
    if (dart.library.io) 'mixer_waveform_loader_io.dart';

/// Extracts and paints real audio waveform when supported (mobile/desktop);
/// otherwise uses synthetic bars.
class MixerWaveformStrip extends StatefulWidget {
  const MixerWaveformStrip({
    super.key,
    required this.audioSource,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    this.mirrorVertically = false,
    this.fallbackBarsGrowUp = true,
    this.strokeWidth = 2,
    this.pixelsPerStep = 5,
  });

  final String audioSource;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final bool mirrorVertically;
  final bool fallbackBarsGrowUp;
  final double strokeWidth;
  final double pixelsPerStep;

  @override
  State<MixerWaveformStrip> createState() => _MixerWaveformStripState();
}

class _MixerWaveformStripState extends State<MixerWaveformStrip> {
  Waveform? _waveform;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MixerWaveformStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioSource != widget.audioSource) {
      _waveform = null;
      _ready = false;
      _load();
    }
  }

  Future<void> _load() async {
    final w = await loadMixerWaveform(widget.audioSource);
    if (!mounted) return;
    setState(() {
      _waveform = w;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final painter = _ready && _waveform != null
        ? _RealWaveformPainter(
            waveform: _waveform!,
            progress: widget.progress,
            playedColor: widget.playedColor,
            unplayedColor: widget.unplayedColor,
            strokeWidth: widget.strokeWidth,
            pixelsPerStep: widget.pixelsPerStep,
            mirrorVertically: widget.mirrorVertically,
          )
        : _FallbackBarWaveformPainter(
            progress: widget.progress,
            playedColor: widget.playedColor,
            unplayedColor: widget.unplayedColor,
            growUpward: widget.fallbackBarsGrowUp,
          );

    return ClipRect(child: CustomPaint(painter: painter));
  }
}

class _RealWaveformPainter extends CustomPainter {
  _RealWaveformPainter({
    required this.waveform,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.strokeWidth,
    required this.pixelsPerStep,
    required this.mirrorVertically,
  });

  final Waveform waveform;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final double strokeWidth;
  final double pixelsPerStep;
  final bool mirrorVertically;

  static const double _unplayedLineAlpha = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    void drawWave() {
      final width = size.width;
      final height = size.height;
      if (waveform.length <= 0 || width <= 0) return;

      final duration = waveform.duration;
      if (duration == Duration.zero) return;

      final waveformPixelsPerWindow = waveform.positionToPixel(duration);
      if (waveformPixelsPerWindow <= 0) return;

      final waveformPixelsPerDevicePixel = waveformPixelsPerWindow / width;
      final waveformPixelsPerStep =
          waveformPixelsPerDevicePixel * pixelsPerStep;
      const start = Duration.zero;
      final sampleOffset = waveform.positionToPixel(start);
      final sampleStart = -sampleOffset % waveformPixelsPerStep;
      final pxEdge = progress.clamp(0.0, 1.0) * width;

      for (
        var i = sampleStart.toDouble();
        i <= waveformPixelsPerWindow + 1.0;
        i += waveformPixelsPerStep
      ) {
        final sampleIdx = (sampleOffset + i).floor();
        final pixelIdx = sampleIdx
            .clamp(0, max(0, waveform.length - 1))
            .toInt();
        final x = i / waveformPixelsPerDevicePixel;
        if (x < 0 || x > width) continue;

        final minY = _normalise(waveform.getPixelMin(pixelIdx), height);
        final maxY = _normalise(waveform.getPixelMax(pixelIdx), height);
        final played = x <= pxEdge;
        final t = width > 0 ? (x / width).clamp(0.0, 1.0) : 0.0;
        final lineColor = AppTheme.mixerLineColorAt(t);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = played
              ? lineColor
              : lineColor.withValues(alpha: _unplayedLineAlpha);

        canvas.drawLine(
          Offset(x + strokeWidth / 2, max(strokeWidth * 0.75, minY)),
          Offset(x + strokeWidth / 2, min(height - strokeWidth * 0.75, maxY)),
          paint,
        );
      }
    }

    if (mirrorVertically) {
      canvas.save();
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
      drawWave();
      canvas.restore();
    } else {
      drawWave();
    }
  }

  double _normalise(int s, double height) {
    const scale = 1.0;
    if (waveform.flags == 0) {
      final y = 32768 + (scale * s).clamp(-32768.0, 32767.0).toDouble();
      return height - 1 - y * height / 65536;
    } else {
      final y = 128 + (scale * s).clamp(-128.0, 127.0).toDouble();
      return height - 1 - y * height / 256;
    }
  }

  @override
  bool shouldRepaint(covariant _RealWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor ||
        oldDelegate.mirrorVertically != mirrorVertically;
  }
}

class _FallbackBarWaveformPainter extends CustomPainter {
  _FallbackBarWaveformPainter({
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.growUpward,
  });

  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final bool growUpward;

  static const double _unplayedLineAlpha = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / 5.5).floor().clamp(30, 76);
    final step = size.width / barCount;

    for (var i = 0; i < barCount; i++) {
      final frac = i / barCount;
      final lineColor = AppTheme.mixerLineColorAt(frac);
      final color = frac <= progress
          ? lineColor
          : lineColor.withValues(alpha: _unplayedLineAlpha);

      final hNorm = (((i * 7919) % 43) / 43.0) * 0.7 + 0.2;
      final barH = size.height * hNorm;
      final x = i * step + step * 0.16;
      final w = step * 0.54;

      final rect = growUpward
          ? Rect.fromLTWH(x, size.height - barH, w, barH)
          : Rect.fromLTWH(x, 0, w, barH);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FallbackBarWaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.unplayedColor != unplayedColor ||
      oldDelegate.growUpward != growUpward;
}
