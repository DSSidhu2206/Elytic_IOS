// lib/frontend/widgets/pets/legendary_badge.dart

import 'package:flutter/material.dart';

class LegendaryBadge extends StatelessWidget {
  final double size;

  const LegendaryBadge({Key? key, this.size = 44}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ],
              stops: [0.0, 0.17, 0.33, 0.50, 0.67, 0.83, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(Rect.fromLTWH(0, 0, size, size));
          },
          child: Text(
            'L',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: size * 0.60,
              color: Colors.white, // The gradient will override this.
              shadows: [
                Shadow(
                  blurRadius: 6,
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(2, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
