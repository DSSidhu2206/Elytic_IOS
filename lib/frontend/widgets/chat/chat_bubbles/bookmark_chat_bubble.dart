// lib/frontend/widgets/chat_bubbles/bookmark_bubble.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookmarkBubble extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const BookmarkBubble({
    Key? key,
    required this.text,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double verticalPadding = 15.0;
    const double leftPadding = 40;
    final double rightPadding = 45;

    return Container(
      padding: EdgeInsets.only(
        top: verticalPadding,
        bottom: verticalPadding,
        left: leftPadding,
        right: rightPadding,
      ),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/chat_bubble_assets/bookmark.png'),
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
            GoogleFonts.specialElite(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
      ),
    );
  }
}
