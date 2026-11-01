import 'dart:math';

import 'package:flutter/material.dart';

/// A cube outline with an outward arrow at each corner. Material Icons has no
/// such glyph, so it is drawn here.
class ArModeIcon extends StatelessWidget {
  const ArModeIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ArModeIconPainter(color));
}

class _ArModeIconPainter extends CustomPainter {
  const _ArModeIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const top = Offset(12, 7);
    const left = Offset(7.7, 9.5);
    const right = Offset(16.3, 9.5);
    const center = Offset(12, 12);
    const bottom = Offset(12, 17);
    const lowerLeft = Offset(7.7, 14.5);
    const lowerRight = Offset(16.3, 14.5);
    canvas.drawPath(
      Path()
        ..addPolygon([top, right, lowerRight, bottom, lowerLeft, left], true)
        ..addPolygon([left, center, right], false)
        ..addPolygon([center, bottom], false),
      paint,
    );

    for (final (from, to) in const [
      (Offset(5.5, 5.5), Offset(1.5, 1.5)),
      (Offset(18.5, 5.5), Offset(22.5, 1.5)),
      (Offset(5.5, 18.5), Offset(1.5, 22.5)),
      (Offset(18.5, 18.5), Offset(22.5, 22.5)),
    ]) {
      final direction = (to - from).direction;
      canvas.drawLine(from, to, paint);
      for (final side in const [-pi * 3 / 4, pi * 3 / 4]) {
        canvas.drawLine(
          to,
          to + Offset.fromDirection(direction + side, 3),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ArModeIconPainter oldDelegate) =>
      color != oldDelegate.color;
}
