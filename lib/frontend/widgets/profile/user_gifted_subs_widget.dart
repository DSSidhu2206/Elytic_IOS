// lib/frontend/widgets/profile/user_gifted_subs_widget.dart

import 'package:flutter/material.dart';

class UserGiftedSubsWidget extends StatelessWidget {
  final int count;
  final double size;
  final TextStyle? countStyle;

  const UserGiftedSubsWidget({
    Key? key,
    this.count = 0,
    this.size = 72, // PATCHED: Default is now 1.5x original (was 48)
    this.countStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Default white number style
    final style = countStyle ??
        TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.84, // PATCHED: 2x original (was size * 0.42)
          shadows: [
            Shadow(
              offset: const Offset(0, 1.5),
              blurRadius: 5,
              color: Colors.black26,
            ),
          ],
        );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gift Box Icon (background)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * 0.01), // similar to heart icon padding
              child: Image.asset(
                'assets/icons/gift_box.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Count (foreground)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(bottom: size * 0.30),
              child: Text(
                count.toString(),
                style: style,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
