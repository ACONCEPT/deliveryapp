import 'package:flutter/material.dart';

class CheckeredPainter extends CustomPainter {
  final double squareSize;
  final Color color1;
  final Color color2;

  CheckeredPainter({
    this.squareSize = 40.0,
    Color? color1,
    Color? color2,
  })  : color1 = color1 ?? Colors.grey[200]!,
        color2 = color2 ?? Colors.grey[100]!;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    for (int i = 0; i < (size.height / squareSize).ceil(); i++) {
      for (int j = 0; j < (size.width / squareSize).ceil(); j++) {
        final paint = (i + j) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(
            j * squareSize,
            i * squareSize,
            squareSize,
            squareSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CheckeredPainter oldDelegate) {
    return oldDelegate.squareSize != squareSize ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2;
  }
}
