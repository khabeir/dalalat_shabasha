import 'dart:math' as math;

import 'package:flutter/material.dart';

class HomeSparklesPainter extends CustomPainter {
  const HomeSparklesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = const Color(0xFFFFB02E)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    for (final degrees in const [-150.0, -90.0, -30.0]) {
      final angle = degrees * math.pi / 180;
      final direction = Offset(math.cos(angle), math.sin(angle));

      canvas.drawLine(
        center + direction * 34,
        center + direction * 41,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
