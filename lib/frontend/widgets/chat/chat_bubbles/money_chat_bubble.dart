// lib/widgets/chat_bubbles/money_chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MoneyChatBubble extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final String cornerImageAsset;

  const MoneyChatBubble({
    Key? key,
    required this.text,
    this.backgroundColor = const Color(0xFF2ECC71),
    this.cornerImageAsset = 'assets/chat_bubble_assets/money_stack.png',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double assetSize = 36;

    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: BoxConstraints(
              minWidth: 100,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              text,
              style: GoogleFonts.audiowide(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black45,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -12,
            left: -12,
            child: Image.asset(
              cornerImageAsset,
              width: assetSize,
              height: assetSize,
            ),
          ),
          Positioned(
            top: -12,
            right: -8,
            child: Image.asset(
              cornerImageAsset,
              width: assetSize,
              height: assetSize,
            ),
          ),
          Positioned(
            bottom: -12,
            left: -12,
            child: Image.asset(
              cornerImageAsset,
              width: assetSize,
              height: assetSize,
            ),
          ),
          Positioned(
            bottom: -12,
            right: -8,
            child: Image.asset(
              cornerImageAsset,
              width: assetSize,
              height: assetSize,
            ),
          ),
        ],
      ),
    );
  }
}
