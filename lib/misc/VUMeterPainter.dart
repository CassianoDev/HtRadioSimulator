import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class VUMeterPainter extends CustomPainter {
  final double needleValue;

  VUMeterPainter(this.needleValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    // Draw VU meter background
    canvas.drawCircle(center, radius, paint);

    // Draw needle
    final needleAngle = pi + pi * needleValue; // Adjust this formula as needed
    final needleLength = radius * 0.9;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );
    canvas.drawLine(center, needleEnd, paint..color = Colors.red);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
