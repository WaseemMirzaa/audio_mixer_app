// Renders the same stack as [AppTexturedPageBackdrop] + login [CeramicFilmGrain].
// Run: dart run tool/generate_auth_splash_background.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const w = 1290;
  const h = 2796;
  const photoOpacity = 0.4;

  const stops = [0.0, 0.28, 0.5, 0.72, 1.0];
  const baseColors = [
    0xFF1294AA,
    0xFF17A6B8,
    0xFF1BB3C2,
    0xFF1294AA,
    0xFF0E819A,
  ];

  final out = img.Image(width: w, height: h);

  // 1) Base vertical gradient.
  for (var y = 0; y < h; y++) {
    final t = y / (h - 1);
    final c = _lerpStops(stops, baseColors, t);
    for (var x = 0; x < w; x++) {
      out.setPixelRgba(x, y, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, 255);
    }
  }

  // 2) Ceramic photo — cover + 1.06 scale, teal matrix, vertical fade, 0.4 opacity.
  final photo = _loadCoverPhoto(
    'assets/textures/ceramic_reference.jpg',
    w,
    h,
    scale: 1.06,
  );
  if (photo != null) {
    for (var y = 0; y < h; y++) {
      final vMask = _verticalPhotoMask(y / (h - 1));
      for (var x = 0; x < w; x++) {
        final tp = photo.getPixel(x, y);
        final harmonized = _tealHarmonize(tp.r.toInt(), tp.g.toInt(), tp.b.toInt());
        final a = (photoOpacity * vMask * 255).round().clamp(0, 255);
        if (a == 0) continue;
        final dp = out.getPixel(x, y);
        out.setPixelRgba(
          x,
          y,
          _blend(dp.r.toInt(), harmonized[0], a),
          _blend(dp.g.toInt(), harmonized[1], a),
          _blend(dp.b.toInt(), harmonized[2], a),
          255,
        );
      }
    }
  }

  // 3) [_photoEdgeSoftener]
  const edgeColor = 0xFF1BB3C2;
  for (var y = 0; y < h; y++) {
    final t = y / (h - 1);
    final edgeA = _edgeSoftenerAlpha(t);
    if (edgeA <= 0) continue;
    for (var x = 0; x < w; x++) {
      final dp = out.getPixel(x, y);
      out.setPixelRgba(
        x,
        y,
        _blend(dp.r.toInt(), (edgeColor >> 16) & 0xFF, edgeA),
        _blend(dp.g.toInt(), (edgeColor >> 8) & 0xFF, edgeA),
        _blend(dp.b.toInt(), edgeColor & 0xFF, edgeA),
        255,
      );
    }
  }

  // 4) White veil (0.03) + CeramicFilmGrain gloss layers.
  _applyTopGloss(out, alpha: 0.09, stop: 0.22);
  _applyRightGloss(out, alpha: 0.06, stop: 0.55);
  _applyFlatVeil(out, alpha: 0.055); // 0.025 + 0.03 from backdrop stack

  final dir = Directory('assets/branding');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  const assetPath = 'assets/branding/auth_splash_background.png';
  File(assetPath).writeAsBytesSync(img.encodePng(out));
  stdout.writeln('Wrote $assetPath');

  const nodpiDir = 'android/app/src/main/res/drawable-nodpi';
  Directory(nodpiDir).createSync(recursive: true);
  final nodpiPath = '$nodpiDir/background.png';
  File(nodpiPath).writeAsBytesSync(File(assetPath).readAsBytesSync());
  for (final stub in [
    'android/app/src/main/res/drawable/background.png',
    'android/app/src/main/res/drawable-v21/background.png',
  ]) {
    final f = File(stub);
    if (f.existsSync()) f.deleteSync();
  }
  stdout.writeln('Wrote $nodpiPath (Android splash texture)');
}

img.Image? _loadCoverPhoto(
  String path,
  int destW,
  int destH, {
  required double scale,
}) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) return null;

  final targetW = (destW * scale).ceil();
  final targetH = (destH * scale).ceil();
  final coverScale = math.max(targetW / decoded.width, targetH / decoded.height);
  final rw = (decoded.width * coverScale).round();
  final rh = (decoded.height * coverScale).round();
  final resized = img.copyResize(decoded, width: rw, height: rh);

  final x0 = ((rw - destW) / 2).round().clamp(0, math.max(0, rw - destW)).toInt();
  final y0 = ((rh - destH) / 2).round().clamp(0, math.max(0, rh - destH)).toInt();
  return img.copyCrop(resized, x: x0, y: y0, width: destW, height: destH);
}

List<int> _tealHarmonize(int r, int g, int b) {
  return [
    (0.92 * r + 0.04 * g + 0.06 * b).round().clamp(0, 255),
    (0.05 * r + 0.95 * g + 0.08 * b).round().clamp(0, 255),
    (0.06 * r + 0.10 * g + 1.02 * b).round().clamp(0, 255),
  ];
}

double _verticalPhotoMask(double t) {
  if (t < 0.16) return t / 0.16;
  if (t > 0.84) return (1 - t) / 0.16;
  return 1.0;
}

int _edgeSoftenerAlpha(double t) {
  if (t < 0.2) {
    return ((1 - t / 0.2) * 255).round();
  }
  if (t > 0.8) {
    return (((t - 0.8) / 0.2) * 255).round();
  }
  return 0;
}

void _applyTopGloss(img.Image dest, {required double alpha, required double stop}) {
  final h = dest.height;
  for (var y = 0; y < h; y++) {
    final t = y / (h - 1);
    if (t > stop) continue;
    final a = ((1 - t / stop) * alpha * 255).round();
    for (var x = 0; x < dest.width; x++) {
      final p = dest.getPixel(x, y);
      dest.setPixelRgba(x, y, _blend(p.r.toInt(), 255, a), _blend(p.g.toInt(), 255, a),
          _blend(p.b.toInt(), 255, a), 255);
    }
  }
}

void _applyRightGloss(img.Image dest, {required double alpha, required double stop}) {
  final w = dest.width;
  for (var x = 0; x < w; x++) {
    final fromRight = 1 - x / (w - 1);
    if (fromRight > stop) continue;
    final a = ((1 - fromRight / stop) * alpha * 255).round();
    for (var y = 0; y < dest.height; y++) {
      final p = dest.getPixel(x, y);
      dest.setPixelRgba(x, y, _blend(p.r.toInt(), 255, a), _blend(p.g.toInt(), 255, a),
          _blend(p.b.toInt(), 255, a), 255);
    }
  }
}

void _applyFlatVeil(img.Image dest, {required double alpha}) {
  final a = (alpha * 255).round();
  for (var y = 0; y < dest.height; y++) {
    for (var x = 0; x < dest.width; x++) {
      final p = dest.getPixel(x, y);
      dest.setPixelRgba(x, y, _blend(p.r.toInt(), 255, a), _blend(p.g.toInt(), 255, a),
          _blend(p.b.toInt(), 255, a), 255);
    }
  }
}

int _blend(int base, int over, int alpha) =>
    ((base * (255 - alpha) + over * alpha) / 255).round().clamp(0, 255);

int _lerpStops(List<double> stops, List<int> colors, double t) {
  if (t <= stops.first) return colors.first;
  if (t >= stops.last) return colors.last;
  for (var i = 0; i < stops.length - 1; i++) {
    if (t >= stops[i] && t <= stops[i + 1]) {
      final local = (t - stops[i]) / (stops[i + 1] - stops[i]);
      return _lerpColor(colors[i], colors[i + 1], local);
    }
  }
  return colors.last;
}

int _lerpColor(int a, int b, double t) {
  final ar = (a >> 16) & 0xFF;
  final ag = (a >> 8) & 0xFF;
  final ab = a & 0xFF;
  final br = (b >> 16) & 0xFF;
  final bg = (b >> 8) & 0xFF;
  final bb = b & 0xFF;
  return ((ar + (br - ar) * t).round() << 16) |
      ((ag + (bg - ag) * t).round() << 8) |
      (ab + (bb - ab) * t).round();
}
