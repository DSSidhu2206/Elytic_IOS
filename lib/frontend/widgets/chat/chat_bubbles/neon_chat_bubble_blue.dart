// lib/frontend/widgets/chat_bubbles/neon_chat_bubble_blue.dart

import 'package:flutter/material.dart';

class NeonChatBubbleBlue extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const NeonChatBubbleBlue({
    Key? key,
    required this.text,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double verticalPadding = 8.0;
    const double horizontalPadding = verticalPadding * 2;

    final Color neonColor = Colors.cyanAccent;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neonColor, width: 5),
        boxShadow: [
          // Glow starts faintly outside the border
          BoxShadow(
            color: neonColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2 * 1.25,  // 25% increase = 2.5
          ),
          BoxShadow(
            color: neonColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 6 * 1.25,  // 7.5
          ),
          BoxShadow(
            color: neonColor.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 12 * 1.25, // 15
          ),
        ],
      ),
      child: Text(
        text,
        style: textStyle ??
            TextStyle(
              color: neonColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: neonColor.withOpacity(0.8),
                  offset: Offset(0, 0),
                ),
              ],
            ),
      ),
    );
  }
}
