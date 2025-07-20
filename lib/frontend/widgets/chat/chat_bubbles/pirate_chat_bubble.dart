// lib/widgets/chat_bubbles/pirate_chat_bubble.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PirateChatBubble extends StatelessWidget {
  final String text;
  final List<Positioned>? icons;

  const PirateChatBubble({
    Key? key,
    required this.text,
    this.icons,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultIcons = [
      Positioned(
        top: -15,
        left: -10,
        child: Image.asset(
          'assets/chat_bubble_assets/treasure_chest.png',
          width: 28,
        ),
      ),
      Positioned(
        bottom: -15,
        left: -10,
        child: Image.asset(
          'assets/chat_bubble_assets/cannon.png',
          width: 28,
        ),
      ),
      Positioned(
        top: -15,
        right: -10,
        child: Image.asset(
          'assets/chat_bubble_assets/scary_flag.png',
          width: 28,
        ),
      ),
      Positioned(
        bottom: -15,
        right: -10,
        child: Image.asset(
          'assets/chat_bubble_assets/anchor.png',
          width: 28,
        ),
      ),
    ];

    return Align(
      alignment: Alignment.centerLeft, // Always left
      child: CustomPaint(
        painter: _BubblePainter(),
        child: Padding(
          padding: EdgeInsets.zero,
          child: IntrinsicWidth(
            child: IntrinsicHeight(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                    child: Center(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.medievalSharp(
                          fontSize: 14,
                          color: Colors.brown[900],
                        ),
                      ),
                    ),
                  ),
                  ...(icons ?? defaultIcons),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  static const int _segments = 20;
  static const double _amplitude = 6.0;
  final Random _rand = Random(0);

  Path _buildJaggedPath(Size size) {
    final path = Path();

    for (int i = 0; i <= _segments; i++) {
      final t = i / _segments;
      final dx = size.width * t;
      final dy = _rand.nextDouble() * 2 * _amplitude - _amplitude;
      if (i == 0) path.moveTo(dx, dy);
      else path.lineTo(dx, dy);
    }
    for (int i = 1; i <= _segments; i++) {
      final t = i / _segments;
      final dx = size.width + (_rand.nextDouble() * 2 * _amplitude - _amplitude);
      final dy = size.height * t;
      path.lineTo(dx, dy);
    }
    for (int i = 1; i <= _segments; i++) {
      final t = i / _segments;
      final dx = size.width * (1 - t);
      final dy = size.height + (_rand.nextDouble() * 2 * _amplitude - _amplitude);
      path.lineTo(dx, dy);
    }
    for (int i = 1; i <= _segments; i++) {
      final t = i / _segments;
      final dx = (_rand.nextDouble() * 2 * _amplitude - _amplitude);
      final dy = size.height * (1 - t);
      path.lineTo(dx, dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE1C17A);
    final borderPaint = Paint()
      ..color = const Color(0xFF3C2F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final jagged = _buildJaggedPath(size);
    canvas.drawPath(jagged, bgPaint);
    canvas.drawPath(jagged, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
