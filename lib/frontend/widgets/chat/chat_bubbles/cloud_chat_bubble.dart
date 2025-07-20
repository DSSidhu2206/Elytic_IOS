// lib/frontend/widgets/chat_bubbles/cloud_chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CloudChatBubble extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const CloudChatBubble({
    Key? key,
    required this.text,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double verticalPadding = 5.0; // reduced by 50% from 8.0
    const double horizontalPadding = verticalPadding * 3; // reduced by 25% from 3 * 8.0 = 24.0, so 18.0 (which is 4.0 * 2.25)

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/chat_bubble_assets/clouds.jpg'),
          fit: BoxFit.fill,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Text(
        text,
        style: textStyle ??
            GoogleFonts.caveat(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 25,
            ),
      ),
    );
  }
}
