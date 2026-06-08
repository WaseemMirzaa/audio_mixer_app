import 'package:flutter/material.dart';

/// Plan icons drawn to match the Membership mockup SVGs exactly:
/// Basic = paper-plane (send), Plus = waveform line, Pro = gold crown.

class PaywallBasicGlyph extends StatelessWidget {
  const PaywallBasicGlyph({super.key, required this.color, this.width = 22});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(width),
      painter: _SendPainter(color),
    );
  }
}

class _SendPainter extends CustomPainter {
  _SendPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0; // viewBox 24×24
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final body = Path()
      ..moveTo(22 * s, 2 * s)
      ..lineTo(15 * s, 22 * s)
      ..lineTo(11 * s, 13 * s)
      ..lineTo(2 * s, 9 * s)
      ..close();
    final crease = Path()
      ..moveTo(22 * s, 2 * s)
      ..lineTo(11 * s, 13 * s);
    canvas.drawPath(body, p);
    canvas.drawPath(crease, p);
  }

  @override
  bool shouldRepaint(_SendPainter old) => old.color != color;
}

class PaywallPlusGlyph extends StatelessWidget {
  const PaywallPlusGlyph({super.key, required this.color, this.width = 32});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 22 / 40),
      painter: _WavePainter(color),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40.0; // viewBox 40×22
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // M1 11 h5 l2.5 -7 l4 14 l3.5 -9 l2.5 5 l2 -3 h5 l2 -5 l2.5 9 l2 -4 H39
    final pts = <Offset>[
      const Offset(1, 11),
      const Offset(6, 11),
      const Offset(8.5, 4),
      const Offset(12.5, 18),
      const Offset(16, 9),
      const Offset(18.5, 14),
      const Offset(20.5, 11),
      const Offset(25.5, 11),
      const Offset(27.5, 6),
      const Offset(30, 15),
      const Offset(32, 11),
      const Offset(39, 11),
    ];
    final path = Path()..moveTo(pts.first.dx * s, pts.first.dy * s);
    for (final pt in pts.skip(1)) {
      path.lineTo(pt.dx * s, pt.dy * s);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}

class PaywallProGlyph extends StatelessWidget {
  const PaywallProGlyph({super.key, this.width = 32});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 34 / 44),
      painter: _CrownPainter(),
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44.0; // viewBox 44×34
    Offset o(double x, double y) => Offset(x * s, y * s);

    final crown = Paint()..color = const Color(0xFFF5A623);
    final poly = Path()
      ..moveTo(4 * s, 30 * s)
      ..lineTo(10 * s, 12 * s)
      ..lineTo(18 * s, 22 * s)
      ..lineTo(22 * s, 4 * s)
      ..lineTo(26 * s, 22 * s)
      ..lineTo(34 * s, 12 * s)
      ..lineTo(40 * s, 30 * s)
      ..close();
    canvas.drawPath(poly, crown);

    final base = Paint()..color = const Color(0xFFE08B15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4 * s, 27 * s, 36 * s, 6 * s),
        Radius.circular(2.5 * s),
      ),
      base,
    );

    final jewel = Paint()..color = const Color(0xFFFFD234);
    canvas.drawCircle(o(22, 4), 3.5 * s, jewel);
    canvas.drawCircle(o(4, 12), 2.8 * s, jewel);
    canvas.drawCircle(o(40, 12), 2.8 * s, jewel);
    canvas.drawCircle(o(22, 30), 2.2 * s, Paint()..color = const Color(0xFFFF9A30));
  }

  @override
  bool shouldRepaint(_CrownPainter old) => false;
}
