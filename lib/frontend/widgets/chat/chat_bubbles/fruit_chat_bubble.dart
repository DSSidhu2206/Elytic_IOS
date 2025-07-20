// lib/widgets/chat_bubbles/fruit_chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FruitChatBubble extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const FruitChatBubble({
    Key? key,
    required this.text,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double verticalPadding = 5.0;
    const double horizontalPadding = verticalPadding * 3;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/chat_bubble_assets/fruits.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Black outline text
          Text(
            text,
            style: textStyle ??
                GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = Colors.black,
                ),
          ),
          // White filled text on top
          Text(
            text,
            style: textStyle ??
                GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  shadows: const [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black26,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
