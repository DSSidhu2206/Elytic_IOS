// lib/widgets/chat_bubbles/galaxy_chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GalaxyChatBubble extends StatelessWidget {
  final String text;
  final String backgroundImageAsset;

  const GalaxyChatBubble({
    Key? key,
    required this.text,
    this.backgroundImageAsset =
    'assets/chat_bubble_assets/galaxy_chat_bubble_background.jpg',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The bubble itself
            Container(
              constraints: BoxConstraints(
                minWidth: 100,
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                image: DecorationImage(
                  image: AssetImage(backgroundImageAsset),
                  fit: BoxFit.cover,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                text,
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    const Shadow(
                      blurRadius: 8,
                      color: Colors.black87,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Top-left: Earth
            Positioned(
              top: -12,
              left: -12,
              child: Image.asset(
                'assets/chat_bubble_assets/earth.png',
                width: 36,
                height: 36,
              ),
            ),
            // Top-right: Sun
            Positioned(
              top: -12,
              right: -12,
              child: Image.asset(
                'assets/chat_bubble_assets/sun.png',
                width: 36,
                height: 36,
              ),
            ),
            // Bottom-left: Saturn
            Positioned(
              bottom: -12,
              left: -12,
              child: Image.asset(
                'assets/chat_bubble_assets/saturn.png',
                width: 48,
                height: 48,
              ),
            ),
            // Bottom-right: Pluto
            Positioned(
              bottom: -12,
              right: -12,
              child: Image.asset(
                'assets/chat_bubble_assets/pluto.png',
                width: 36,
                height: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
