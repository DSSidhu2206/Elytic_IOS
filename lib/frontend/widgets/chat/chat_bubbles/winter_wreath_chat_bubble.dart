// lib/frontend/widgets/chat/chat_bubbles/winter_wreath_chat_bubble.dart

import 'package:flutter/material.dart';

// Adjust these values to match your actual PNG dimensions and border thickness
const double _kAssetSize = 1024.0;
const double _kBorderThickness = 100.0;
const double _kInteriorSize = _kAssetSize - 2 * _kBorderThickness;

/// A chat bubble decorated with a winter wreath border.
class WinterWreathChatBubble extends StatelessWidget {
  final String text;
  const WinterWreathChatBubble({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _BubbleClipper(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/wreath.png'),
            fit: BoxFit.fill,
            centerSlice: const Rect.fromLTWH(
              _kBorderThickness,
              _kBorderThickness,
              _kInteriorSize,
              _kInteriorSize,
            ),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

/// Draws a rounded-rect bubble with a bottom tail.
class _BubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double r = 16.0; // corner radius
    final double t = 10.0; // tail size
    final double w = size.width;
    final double h = size.height;

    return Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - r - t)
      ..quadraticBezierTo(w, h - t, w - r, h - t)
      ..lineTo(w / 2 + t, h - t)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 - t, h - t)
      ..lineTo(r, h - t)
      ..quadraticBezierTo(0, h - t, 0, h - r - t)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
